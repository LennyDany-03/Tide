import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../../config/app_constants.dart';
import '../../config/pro_features.dart';
import '../habits/habit_repository.dart' show SyncStatus;
import '../tide_store.dart';
import 'task.dart';
import 'task_local.dart';
import 'task_remote.dart';
import 'task_reminders.dart';
import 'task_rows.dart';

/// How the open list is ordered.
enum TaskSort { dueDate, tag }

/// A completion that can still be taken back, from the snackbar that follows
/// it: the task as it was, and the next occurrence it made, if any.
@immutable
class TaskCompletion {
  const TaskCompletion({required this.before, this.spawnedId});

  final Task before;
  final String? spawnedId;
}

/// The to-do list: every task for the signed-in account, and its sync.
///
/// **Its own store, deliberately.** The habit tracker is the product and
/// this is a side module, so it must not cost the habit screens anything.
/// [TideStore] is listened to by every habit screen; putting tasks in it would
/// rebuild Today on every ticked checkbox. This store only *reads* the
/// habit store — who is signed in, and whether they are Pro — and nothing in
/// the habit tracker knows it exists.
///
/// **Offline first.** Every change lands in the list and on the device
/// before anything touches the network, and the UI never waits on a
/// request. Each task carries its own [TaskSyncStatus]; the pending ones
/// *are* the outbox. A sync pushes them — creates, then updates, then
/// deletes — and then pulls whatever the server has written since the last
/// pull. It runs after a change, on returning to the foreground, when the
/// connection comes back, and every [AppConstants.taskSyncIntervalMinutes]
/// minutes while the app is open; a failure retries on a doubling backoff.
/// A failed push leaves the task pending, so nothing is ever lost to one.
///
/// **Last write wins**, by [Task.updatedAt]. It is a one-person list; a
/// merge would be solving a problem nobody has.
class TaskStore extends ChangeNotifier {
  TaskStore({
    required this.tide,
    TaskLocal? local,
    this.remote,
    TaskReminders? reminders,
    Stream<void>? reconnects,
    DateTime Function()? clock,
  }) : local = local ?? MemoryTaskLocal(),
       reminders = reminders ?? NoTaskReminders(),
       _clock = clock ?? DateTime.now {
    _pro = tide.isPro;
    tide.sessionChanges.addListener(_onSession);
    tide.addListener(_onTide);
    tide.addLogOutHook(_beforeLogOut);
    _reconnects = reconnects?.listen((_) => unawaited(sync()));
    _openAccount(tide.account?.id);
  }

  /// Who is signed in and what plan they are on. Read, never written.
  final TideStore tide;

  final TaskLocal local;

  /// Null in tests and in builds with no project: tasks stay on the device.
  final TaskRemote? remote;

  final TaskReminders reminders;

  final DateTime Function() _clock;

  StreamSubscription<void>? _reconnects;
  AppLifecycleListener? _lifecycle;
  Timer? _periodic;
  Timer? _retry;
  Timer? _debounce;
  Timer? _reminderDebounce;
  int _failures = 0;

  String? _accountId;
  List<Task> _tasks = const [];
  late bool _pro;

  // --- Reads ----------------------------------------------------------------

  /// Every task the device holds, deleted ones included. For sync and tests.
  List<Task> get all => List.unmodifiable(_tasks);

  Task? byId(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Iterable<Task> get _visible => _tasks.where((t) => !t.isDeleted);

  TaskSort sort = TaskSort.dueDate;

  /// Only honoured on Pro. A plan that lapses keeps the value but stops
  /// applying it, so the list never silently shows less than it holds.
  String? tagFilter;

  String? get activeTagFilter => locked(ProFeature.taskTags) ? null : tagFilter;

  /// Incomplete tasks: by due date (undated last), then by when they were
  /// made — or, sorted by tag, by first tag with untagged last.
  List<Task> get open {
    final filter = activeTagFilter;
    final list = _visible
        .where((t) => !t.isCompleted && !t.isArchived)
        .where((t) => filter == null || t.tags.contains(filter))
        .toList();
    list.sort(sort == TaskSort.tag ? _byTag : _byDue);
    return list;
  }

  /// Done and not archived, most recently finished first.
  List<Task> get completed {
    final filter = activeTagFilter;
    return _visible
        .where((t) => t.isCompleted && !t.isArchived)
        .where((t) => filter == null || t.tags.contains(filter))
        .toList()
      ..sort(_byCompletedDesc);
  }

  List<Task> get archived =>
      _visible.where((t) => t.isArchived).toList()..sort(_byCompletedDesc);

  /// Where today stands: tasks due today or already overdue, and how many of
  /// today's were finished. A task finished today counts toward both numbers
  /// whatever it was due, so ticking off tomorrow's early still moves the ring.
  ({int done, int total, int overdue}) get today {
    final now = _clock();
    final day = DateUtils.dateOnly(now);
    var done = 0, open = 0, overdue = 0;
    for (final task in _visible) {
      if (task.isArchived) continue;
      if (task.isCompleted) {
        final at = task.completedAt;
        if (at != null && DateUtils.isSameDay(at, now)) done++;
        continue;
      }
      final due = task.dueDate;
      if (due == null || due.isAfter(day)) continue;
      open++;
      if (due.isBefore(day)) overdue++;
    }
    return (done: done, total: done + open, overdue: overdue);
  }

  /// Whether the "swipe right to complete" tip has been read on this device.
  bool get swipeHintSeen => local.swipeHintSeen;

  void dismissSwipeHint() {
    if (local.swipeHintSeen) return;
    local.markSwipeHintSeen();
    notifyListeners();
  }

  /// Every tag in use, alphabetically.
  List<String> get tags =>
      ({for (final t in _visible) ...t.tags}.toList()..sort(_caseless));

  bool get hasPendingChanges =>
      _tasks.any((t) => t.syncStatus != TaskSyncStatus.synced);

  SyncStatus _status = SyncStatus.localOnly;
  SyncStatus get status => remote == null ? SyncStatus.localOnly : _status;

  bool locked(ProFeature feature) => tide.locked(feature);

  static int _byDue(Task a, Task b) {
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != bd) {
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  static int _byTag(Task a, Task b) {
    final at = a.tags.isEmpty ? null : a.tags.first;
    final bt = b.tags.isEmpty ? null : b.tags.first;
    if (at != bt) {
      if (at == null) return 1;
      if (bt == null) return -1;
      final byName = _caseless(at, bt);
      if (byName != 0) return byName;
    }
    return _byDue(a, b);
  }

  static int _byCompletedDesc(Task a, Task b) =>
      (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt);

  static int _caseless(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  // --- Quick add from outside the screen -----------------------------------

  /// Bumped by the home-screen shortcut; the list screen focuses its field.
  final ValueNotifier<int> quickAddRequests = ValueNotifier<int>(0);

  void requestQuickAdd() => quickAddRequests.value++;

  // --- Mutations -------------------------------------------------------------

  Task add({required String title, DateTime? dueDate}) {
    final now = _clock();
    final task = Task(
      id: tide.newHabitId(),
      title: title.trim(),
      dueDate: dueDate == null ? null : DateUtils.dateOnly(dueDate),
      createdAt: now,
      updatedAt: now,
    );
    _put(task);
    return task;
  }

  /// Saves an edit from the full editor, within what the plan allows.
  void update(Task edited) {
    final before = byId(edited.id);
    if (before == null || before.isDeleted) return;
    final allowed = withinPlan(edited, before);
    if (allowed.sameContent(before)) return;
    _put(allowed.copyWith(updatedAt: _clock()));
  }

  /// Ticks a task off, or back on.
  ///
  /// Completing a repeating task makes its next occurrence at the same time,
  /// so it is on the list the moment this one leaves it.
  TaskCompletion? toggleComplete(String id) {
    final task = byId(id);
    if (task == null || task.isDeleted) return null;
    final now = _clock();

    if (task.isCompleted) {
      _put(
        task.copyWith(isCompleted: false, completedAt: null, updatedAt: now),
      );
      return null;
    }

    final done = task.copyWith(
      isCompleted: true,
      completedAt: now,
      subtasks: [for (final s in task.subtasks) s.copyWith(isCompleted: true)],
      updatedAt: now,
    );
    final next = task.successor(
      id: tide.newHabitId(),
      completedAt: now,
      now: now,
    );
    _put(done, also: next);
    return TaskCompletion(before: task, spawnedId: next?.id);
  }

  /// Takes back a completion from its snackbar: the task returns as it was
  /// and the occurrence it made goes, provided nobody has touched it since.
  void undoCompletion(TaskCompletion completion) {
    final now = _clock();
    final spawned = completion.spawnedId == null
        ? null
        : byId(completion.spawnedId!);
    if (spawned != null && !spawned.isCompleted) _remove(spawned, now);
    final current = byId(completion.before.id);
    if (current == null || current.isDeleted) return;
    _put(
      completion.before.copyWith(
        updatedAt: now,
        syncStatus: current.syncStatus,
      ),
    );
  }

  /// Removes a task. Returns it, so the snackbar can offer it back.
  Task? delete(String id) {
    final task = byId(id);
    if (task == null || task.isDeleted) return null;
    _remove(task, _clock());
    return task;
  }

  /// Brings back a task deleted a moment ago.
  void restore(Task task) {
    final current = byId(task.id);
    final now = _clock();
    if (current == null) {
      // Already confirmed gone on the server: it comes back as new.
      _put(
        task.copyWith(updatedAt: now, syncStatus: TaskSyncStatus.pendingCreate),
      );
    } else {
      _put(
        task.copyWith(
          updatedAt: now,
          syncStatus: current.syncStatus == TaskSyncStatus.pendingDelete
              ? TaskSyncStatus.pendingUpdate
              : current.syncStatus,
        ),
      );
    }
  }

  /// Moves every completed task into the archive. False on the free plan,
  /// changing nothing; the caller opens the paywall.
  bool archiveCompleted() {
    if (locked(ProFeature.taskArchive)) return false;
    final now = _clock();
    final done = completed;
    if (done.isEmpty) return true;
    _putAll([
      for (final t in done) t.copyWith(isArchived: true, updatedAt: now),
    ]);
    return true;
  }

  void unarchive(String id) {
    final task = byId(id);
    if (task == null || !task.isArchived) return;
    _put(task.copyWith(isArchived: false, updatedAt: _clock()));
  }

  /// Deletes every completed task that is not archived.
  void clearCompleted() {
    final now = _clock();
    for (final task in completed) {
      _remove(task, now, notify: false);
    }
    _changed();
  }

  void setSort(TaskSort next) {
    if (sort == next) return;
    sort = next;
    notifyListeners();
  }

  /// False on the free plan; the caller opens the paywall.
  bool setTagFilter(String? tag) {
    if (tag != null && locked(ProFeature.taskTags)) return false;
    tagFilter = tag;
    notifyListeners();
    return true;
  }

  Future<bool> requestReminderPermission() => reminders.requestPermission();

  /// [edited] cut back to what the plan allows, given what the task already
  /// had.
  ///
  /// Enforced here and not only in the editor, so no path around the screen
  /// gets past it. And it only stops things *growing*: a task set up while a
  /// plan was running keeps its extra reminders, tags and custom repeat when
  /// the plan ends — the gate must not take away what somebody already has.
  Task withinPlan(Task edited, Task? before) {
    var task = edited;

    if (locked(ProFeature.taskCustomRepeat) &&
        task.recurrence == TaskRecurrence.custom &&
        before?.recurrence != TaskRecurrence.custom) {
      task = task.copyWith(
        recurrence: before?.recurrence ?? TaskRecurrence.none,
        customRecurrenceMonths: before?.customRecurrenceMonths,
      );
    }
    if (task.recurrence == TaskRecurrence.custom) {
      final months = (task.customRecurrenceMonths ?? 0).clamp(
        1,
        AppConstants.maxCustomRepeatMonths,
      );
      task = task.copyWith(customRecurrenceMonths: months);
    }

    if (locked(ProFeature.taskReminders)) {
      final ceiling = math.max(
        AppConstants.freeTaskReminders,
        before?.reminders.length ?? 0,
      );
      if (task.reminders.length > ceiling) {
        task = task.copyWith(reminders: task.reminders.take(ceiling).toList());
      }
    }

    if (locked(ProFeature.taskTags)) {
      final had = before?.tags ?? const <String>[];
      task = task.copyWith(tags: task.tags.where(had.contains).toList());
    }

    if (locked(ProFeature.taskArchive) &&
        task.isArchived &&
        !(before?.isArchived ?? false)) {
      task = task.copyWith(isArchived: false);
    }
    return task;
  }

  // --- The list and the device -----------------------------------------------

  /// A task written here: kept, persisted, and marked for the server.
  void _put(Task task, {Task? also}) => _putAll([task, ?also]);

  void _putAll(List<Task> tasks) {
    var list = _tasks;
    for (final task in tasks) {
      final existing = list.indexWhere((t) => t.id == task.id);
      final previous = existing < 0 ? null : list[existing];
      final marked = task.copyWith(
        syncStatus: _pendingAfterWrite(previous, task),
      );
      list = existing < 0
          ? [...list, marked]
          : [for (final t in list) t.id == task.id ? marked : t];
    }
    _tasks = list;
    _changed();
  }

  void _remove(Task task, DateTime now, {bool notify = true}) {
    // Always a tombstone, even for a task the server has never seen. Its
    // create may already be on the wire, and dropping the row here would
    // leave that create landing with nothing behind it to delete it.
    _tasks = [
      for (final t in _tasks)
        t.id == task.id
            ? t.copyWith(
                updatedAt: now,
                syncStatus: TaskSyncStatus.pendingDelete,
              )
            : t,
    ];
    if (notify) _changed();
  }

  /// A new row is a create until the server has it; after that every write
  /// is an update. The server only ever sees whole rows, so the distinction
  /// is about order — creates go first — not about what is sent.
  static TaskSyncStatus _pendingAfterWrite(Task? previous, Task next) {
    if (previous == null) return TaskSyncStatus.pendingCreate;
    if (next.syncStatus == TaskSyncStatus.pendingDelete) {
      return TaskSyncStatus.pendingDelete;
    }
    return previous.syncStatus == TaskSyncStatus.pendingCreate
        ? TaskSyncStatus.pendingCreate
        : TaskSyncStatus.pendingUpdate;
  }

  void _changed() {
    final accountId = _accountId;
    if (accountId != null) local.save(accountId, _tasks);
    notifyListeners();
    _scheduleReminders();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(sync()),
    );
  }

  void _scheduleReminders() {
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_accountId == null) return;
      unawaited(
        reminders.schedule(
          _visible.toList(),
          snooze: !locked(ProFeature.taskReminders),
        ),
      );
    });
  }

  // --- Account ---------------------------------------------------------------

  void _onSession() {
    final next = tide.account?.id;
    if (next == _accountId) return;
    final previous = _accountId;
    if (previous != null) _closeAccount(previous, forget: next == null);
    _openAccount(next);
  }

  void _onTide() {
    // The habit store notifies on every habit logged; only a plan change
    // matters here.
    if (tide.isPro == _pro) return;
    _pro = tide.isPro;
    notifyListeners();
    _scheduleReminders();
  }

  void _openAccount(String? accountId) {
    _accountId = accountId;
    if (accountId == null) {
      _tasks = const [];
      notifyListeners();
      return;
    }
    _tasks = local.load(accountId);
    _status = SyncStatus.syncing;
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    _periodic = Timer.periodic(
      const Duration(minutes: AppConstants.taskSyncIntervalMinutes),
      (_) => unawaited(sync()),
    );
    notifyListeners();
    _scheduleReminders();
    unawaited(sync());
  }

  void _closeAccount(String accountId, {required bool forget}) {
    _lifecycle?.dispose();
    _lifecycle = null;
    _periodic?.cancel();
    _periodic = null;
    _retry?.cancel();
    _retry = null;
    _debounce?.cancel();
    _reminderDebounce?.cancel();
    _failures = 0;
    tagFilter = null;
    if (forget) {
      // The next person to pick up the phone must find neither the list nor
      // its reminders.
      local.forget(accountId);
      unawaited(reminders.clear());
    } else {
      local.save(accountId, _tasks);
    }
  }

  /// Log out gives queued changes a few seconds to reach the server while
  /// there is still a session allowed to send them.
  Future<void> _beforeLogOut() async {
    if (!hasPendingChanges || remote == null) return;
    await sync().timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  // --- Sync ------------------------------------------------------------------

  Future<void>? _syncing;
  Future<void>? _queued;

  /// Pushes what is pending, then pulls what changed. Never throws.
  ///
  /// Resolves after a pass that *started* after the call. Joining a pass
  /// already under way would not do: it may have read the list before the
  /// change that prompted this call, so any number of calls made while one
  /// runs share a single follow-up pass instead.
  Future<void> sync() {
    final running = _syncing;
    if (running == null) return _startSync();
    return _queued ??= running.then((_) {
      _queued = null;
      return sync();
    });
  }

  Future<void> _startSync() {
    final pass = _runSync().whenComplete(() => _syncing = null);
    _syncing = pass;
    return pass;
  }

  Future<void> _runSync() async {
    final accountId = _accountId;
    final remote = this.remote;
    if (accountId == null || remote == null) return;
    _retry?.cancel();
    _retry = null;

    _setStatus(SyncStatus.syncing);
    try {
      await _push(accountId, remote);
      if (_accountId != accountId) return;
      await _pull(accountId, remote);
      if (_accountId != accountId) return;
      _failures = 0;
      _setStatus(hasPendingChanges ? SyncStatus.syncing : SyncStatus.synced);
    } catch (error) {
      if (_accountId != accountId) return;
      debugPrint('Task sync failed: $error');
      _setStatus(SyncStatus.offline);
      _failures++;
      final seconds = math.min(
        AppConstants.taskSyncMaxRetrySeconds,
        2 * math.pow(2, _failures - 1).toInt(),
      );
      _retry = Timer(Duration(seconds: seconds), () => unawaited(sync()));
    }
  }

  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<void> _push(String accountId, TaskRemote remote) async {
    int rank(TaskSyncStatus s) => switch (s) {
      TaskSyncStatus.pendingCreate => 0,
      TaskSyncStatus.pendingUpdate => 1,
      TaskSyncStatus.pendingDelete => 2,
      TaskSyncStatus.synced => 3,
    };
    final queue =
        _tasks.where((t) => t.syncStatus != TaskSyncStatus.synced).toList()
          ..sort((a, b) {
            final byKind = rank(a.syncStatus).compareTo(rank(b.syncStatus));
            return byKind != 0 ? byKind : a.updatedAt.compareTo(b.updatedAt);
          });

    for (final queued in queue) {
      if (_accountId != accountId) return;
      // Read again: an earlier push in this loop can take long enough for the
      // task to have been edited, or even pushed by a sync that overlapped.
      final sending = byId(queued.id);
      if (sending == null || sending.syncStatus == TaskSyncStatus.synced) {
        continue;
      }
      try {
        await remote.push(accountId, sending).timeout(_requestTimeout);
      } on TaskRefused catch (refused) {
        // Kept pending, it would block every sync behind it for good.
        debugPrint(
          'Task ${sending.id} refused by the server: ${refused.reason}',
        );
      }
      if (_accountId != accountId) return;
      _settle(accountId, sending);
    }
  }

  /// [sent] reached the server. Marked synced — or dropped, for a delete —
  /// unless it was changed again while the request was out, in which case it
  /// stays pending for the next push.
  void _settle(String accountId, Task sent) {
    final now = byId(sent.id);
    if (now == null) return;
    final changedSince =
        now.updatedAt != sent.updatedAt || now.syncStatus != sent.syncStatus;

    if (changedSince) {
      if (now.syncStatus == TaskSyncStatus.pendingCreate) {
        _replace(now.copyWith(syncStatus: TaskSyncStatus.pendingUpdate));
      }
    } else if (sent.syncStatus == TaskSyncStatus.pendingDelete) {
      _tasks = [
        for (final t in _tasks)
          if (t.id != sent.id) t,
      ];
    } else {
      _replace(now.copyWith(syncStatus: TaskSyncStatus.synced));
    }
    local.save(accountId, _tasks);
  }

  Future<void> _pull(String accountId, TaskRemote remote) async {
    const page = 500;
    var cursor = local.cursor(accountId);
    var changed = false;

    while (true) {
      final rows = await remote
          .pull(accountId, since: cursor, limit: page)
          .timeout(_requestTimeout);
      if (_accountId != accountId) return;

      for (final row in rows) {
        changed = _merge(row) || changed;
        final at = row.syncedAt;
        if (at != null && (cursor == null || at.isAfter(cursor))) cursor = at;
      }
      if (cursor != null) local.setCursor(accountId, cursor);
      if (rows.length < page) break;
    }

    if (changed) {
      local.save(accountId, _tasks);
      notifyListeners();
      _scheduleReminders();
    }
  }

  /// One server row against the device's copy, last write wins. True if the
  /// list changed.
  bool _merge(RemoteTask row) {
    final incoming = row.task;
    final mine = byId(incoming.id);

    if (mine == null) {
      if (row.deleted) return false;
      _tasks = [..._tasks, incoming];
      return true;
    }
    // A pending change made here after the server's version wins, and goes
    // up on the next push.
    if (mine.syncStatus != TaskSyncStatus.synced &&
        mine.updatedAt.isAfter(incoming.updatedAt)) {
      return false;
    }
    if (row.deleted) {
      _tasks = [
        for (final t in _tasks)
          if (t.id != incoming.id) t,
      ];
      return true;
    }
    if (mine.syncStatus == TaskSyncStatus.synced &&
        mine.updatedAt == incoming.updatedAt &&
        mine.sameContent(incoming)) {
      return false;
    }
    _replace(incoming);
    return true;
  }

  void _replace(Task task) {
    _tasks = [for (final t in _tasks) t.id == task.id ? task : t];
  }

  void _setStatus(SyncStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    tide.sessionChanges.removeListener(_onSession);
    tide.removeListener(_onTide);
    tide.removeLogOutHook(_beforeLogOut);
    unawaited(_reconnects?.cancel());
    final accountId = _accountId;
    if (accountId != null) _closeAccount(accountId, forget: false);
    quickAddRequests.dispose();
    super.dispose();
  }
}
