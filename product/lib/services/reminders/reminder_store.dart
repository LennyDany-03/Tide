import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../../theme/tide_colors.dart';
import '../models/reminder_options.dart';
import '../tasks/task.dart';
import '../tasks/task_reminders.dart';
import '../tasks/task_store.dart';
import '../tide_store.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';
import 'reminder_settings.dart';

/// Habit and to-do reminders: what the phone should hold, what it is
/// allowed to do, and what was answered where the app could not hear it.
///
/// **It only reads the other stores and writes through them.** The habit
/// store stays the source of truth: every change there is re-planned here, a
/// beat later, and handed to the phone only when the plan actually moved —
/// so logging a habit that has no reminder costs a comparison, not a trip
/// to native code. To-dos arrive through the task store's own
/// [TaskReminders] seam, which is [taskReminders] in the app.
///
/// **Answers from the lock screen come back as actions.** The call is shown
/// by a separate isolate, and a notification's buttons can be pressed with
/// no app running at all, so neither can reach a store. What they did is
/// queued on the device and applied here the next time the app runs — or at
/// once, when it already is — through the same store calls a tap would make.
class ReminderStore extends ChangeNotifier {
  ReminderStore({
    required this.tide,
    ReminderPlatform? platform,
    ReminderPrefs? prefs,
    DateTime Function()? clock,
    bool watchLifecycle = true,
  }) : platform = platform ?? NoReminderPlatform(),
       prefs = prefs ?? ReminderPrefs.memory(),
       _clock = clock ?? DateTime.now {
    tide.addListener(_onTide);
    tide.sessionChanges.addListener(_onSession);
    _queued = this.platform.actionsQueued.listen((_) => unawaited(drain()));
    if (watchLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: _onResume);
    }
    unawaited(refreshPermissions());
    unawaited(drain());
    _planHabits();
  }

  /// Read for habits and the account; written only through its mutations.
  final TideStore tide;

  final ReminderPlatform platform;

  final ReminderPrefs prefs;

  final DateTime Function() _clock;

  TaskStore? _tasks;

  /// The to-do list the last plan was built from, as the task store handed
  /// it over.
  List<Task> _tasksSeen = const [];

  late final StreamSubscription<void> _queued;
  AppLifecycleListener? _lifecycle;
  Timer? _habitTimer;

  String? _habitSignature;
  String? _taskSignature;

  /// What the task store should be built with. It hands its list here after
  /// every change.
  late final TaskReminders taskReminders = _TaskChannel(this);

  /// The task store to apply to-do actions through. Set once both exist —
  /// the task store is built with [taskReminders], so it comes second.
  void attachTasks(TaskStore tasks) {
    _tasks = tasks;
    unawaited(drain());
  }

  // --- Settings -------------------------------------------------------------

  ReminderSettings get settings => prefs.settings;

  void updateSettings(ReminderSettings next) {
    if (next == settings) return;
    prefs.settings = next;
    notifyListeners();
    _planHabits(force: true);
    unawaited(_planTasks(force: true));
  }

  // --- Permissions ------------------------------------------------------------

  Map<ReminderPermission, PermissionState> _permissions = const {};
  bool _permissionsKnown = false;

  /// Whether the phone has answered at least once. Until it has, nothing is
  /// reported missing — a banner that flashed on every launch while the
  /// answer was on its way would be crying wolf.
  bool get permissionsKnown => _permissionsKnown;

  /// The permissions that mean anything on this phone, in asking order.
  List<ReminderPermission> get permissionsAsked => platform.permissionsAsked;

  PermissionState permission(ReminderPermission which) {
    if (!platform.permissionsAsked.contains(which)) {
      return PermissionState.notApplicable;
    }
    return _permissions[which] ?? PermissionState.denied;
  }

  /// The permissions onboarding asks for that are granted — how high its
  /// water stands.
  int get grantedCount =>
      permissionsAsked.where((p) => permission(p).ok).length;

  /// Required permissions the phone is refusing.
  List<ReminderPermission> get missing => [
    for (final p in permissionsAsked)
      if (!p.optional && permission(p) == PermissionState.denied) p,
  ];

  Future<void> refreshPermissions() async {
    try {
      final next = await platform.permissions();
      final changed = !_permissionsKnown || !mapEquals(next, _permissions);
      _permissions = next;
      _permissionsKnown = true;
      if (changed) {
        notifyListeners();
        // Exact alarms granted since the plan was handed over: the phone
        // re-arms on its own, but a plan built while it was refused is
        // worth handing over again.
        _planHabits(force: true);
        unawaited(_planTasks(force: true));
      }
    } catch (error) {
      debugPrint('Reminder permissions not read: $error');
    }
  }

  /// Asks for [which]. A permission granted in the system's settings opens
  /// them; the answer arrives with the app's return to the foreground.
  Future<PermissionState> request(ReminderPermission which) async {
    try {
      await platform.request(which);
    } catch (error) {
      debugPrint('Reminder permission ${which.name} not requested: $error');
    }
    await refreshPermissions();
    return permission(which);
  }

  /// Reminders are switched on and something is asking for one, but the
  /// phone is refusing what they need to arrive. Today shows a quiet banner
  /// while this holds, until it is fixed or waved away.
  bool get needsAttention {
    if (_bannerDismissed || !_permissionsKnown) return false;
    if (!settings.enabled || !tide.signedIn) return false;
    if (missing.isEmpty) return false;
    final now = _clock();
    final habitsAsk = tide.allHabits.any((h) => h.reminderEnabled && !h.paused);
    final tasksAsk = _tasksSeen.any(
      (t) =>
          !t.isCompleted &&
          !t.isDeleted &&
          !t.isArchived &&
          t.reminders.any((r) => r.isAfter(now)),
    );
    return habitsAsk || tasksAsk;
  }

  bool _bannerDismissed = false;

  /// For this session. It comes back on the next launch if nothing changed,
  /// because the reminders still will not arrive.
  void dismissBanner() {
    if (_bannerDismissed) return;
    _bannerDismissed = true;
    notifyListeners();
  }

  // --- Plans ----------------------------------------------------------------

  void _onTide() {
    _habitTimer?.cancel();
    _habitTimer = Timer(const Duration(milliseconds: 350), _planHabits);
  }

  void _onSession() {
    _planHabits(force: true);
    unawaited(drain());
  }

  void _onResume() {
    unawaited(refreshPermissions());
    unawaited(drain());
    // The day may have turned while the app was away, which changes which
    // of today's reminders are still owed.
    _planHabits();
    unawaited(_planTasks());
  }

  void _planHabits({bool force = false}) {
    _habitTimer?.cancel();
    _habitTimer = null;
    final now = _clock();
    final account = tide.account?.id;
    final habits = tide.allHabits;
    final items = account == null
        ? const <PlannedReminder>[]
        : ReminderPlanner.habits(
            habits,
            settings,
            now: now,
            accountId: account,
          );
    final open = account == null
        ? const <String>{}
        : ReminderPlanner.openHabitSubjects(habits, now);
    final signature = _signature(items, open);
    if (!force && signature == _habitSignature) return;
    _habitSignature = signature;
    unawaited(_send(ReminderGroup.habits, items, open));
  }

  Future<void> _planTasks({bool force = false}) {
    final now = _clock();
    final account = tide.account?.id;
    final items = account == null
        ? const <PlannedReminder>[]
        : ReminderPlanner.tasks(
            _tasksSeen,
            settings,
            now: now,
            accountId: account,
          );
    final open = ReminderPlanner.openTaskSubjects(_tasksSeen);
    final signature = _signature(items, open);
    if (!force && signature == _taskSignature) return Future.value();
    _taskSignature = signature;
    return _send(ReminderGroup.tasks, items, open);
  }

  Future<void> _send(
    ReminderGroup group,
    List<PlannedReminder> items,
    Set<String> open,
  ) async {
    try {
      await platform.schedule(group, items, open: open);
    } catch (error) {
      debugPrint('Reminders (${group.name}) not scheduled: $error');
    }
  }

  /// What the phone was last handed, as one string. The palette is part of
  /// it because the phone draws its notifications in it.
  static String _signature(List<PlannedReminder> items, Set<String> open) =>
      jsonEncode([
        TideColors.palette.id,
        [for (final item in items) item.toJson()],
        open.toList()..sort(),
      ]);

  // --- Actions ----------------------------------------------------------------

  /// Applies whatever was answered where the app could not hear it.
  Future<void> drain() async {
    final List<ReminderAction> actions;
    try {
      actions = await platform.takeActions();
    } catch (error) {
      debugPrint('Reminder actions not read: $error');
      return;
    }
    for (final action in actions) {
      apply(action);
    }
  }

  /// Applies one answer through the stores, as a tap would. Returns false
  /// when there was nothing to do: another account's reminder, a habit
  /// deleted since, a day already kept.
  ///
  /// Nothing here celebrates. The call has its own moment on screen, and a
  /// completion reaching the app hours after it happened is bookkeeping.
  bool apply(ReminderAction action) {
    final account = tide.account?.id;
    if (account == null) return false;
    if (action.accountId != null && action.accountId != account) return false;
    final now = _clock();
    final day = DateUtils.dateOnly(action.day ?? now);

    switch (action.type) {
      case ReminderActionType.habitDone:
        final habit = tide.habitById(action.subjectId);
        if (habit == null || habit.isCompleteOn(day)) return false;
        tide.log(habit.id, date: day, celebrate: false);
        return true;
      case ReminderActionType.habitSkip:
        final habit = tide.habitById(action.subjectId);
        if (habit == null || habit.countsTowardStreak(day)) return false;
        return tide.freeze(habit.id, date: day, celebrate: false);
      case ReminderActionType.taskDone:
        final tasks = _tasks;
        final task = tasks?.byId(action.subjectId);
        if (tasks == null || task == null) return false;
        if (task.isCompleted || task.isDeleted || task.subtasksLeft > 0) {
          return false;
        }
        return tasks.toggleComplete(task.id) != null;
      case ReminderActionType.taskStep:
        final tasks = _tasks;
        final task = tasks?.byId(action.subjectId);
        if (tasks == null || task == null || task.isDeleted) return false;
        if (!task.subtasks.any((s) => s.id == action.stepId)) return false;
        tasks.update(
          task.copyWith(
            subtasks: [
              for (final step in task.subtasks)
                step.id == action.stepId
                    ? step.copyWith(isCompleted: action.value)
                    : step,
            ],
          ),
        );
        return true;
      case ReminderActionType.taskTomorrow:
        final tasks = _tasks;
        final task = tasks?.byId(action.subjectId);
        if (tasks == null || task == null || task.isDeleted) return false;
        if (task.isCompleted) return false;
        tasks.update(movedToTomorrow(task, now));
        return true;
    }
  }

  /// [task] put off to tomorrow from the Lighthouse: due tomorrow unless it
  /// was already due later, and every reminder that has gone by — the one
  /// that just rang among them — brought back at the same time tomorrow.
  /// Reminders still to come are left where they were.
  static Task movedToTomorrow(Task task, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final tomorrow = DateUtils.addDaysToDate(today, 1);
    final due = task.dueDate;
    final reminders = <DateTime>{
      for (final at in task.reminders)
        if (at.isAfter(now))
          at
        else
          DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            at.hour,
            at.minute,
          ),
    };
    return task.copyWith(
      dueDate: due == null || !due.isAfter(today) ? tomorrow : due,
      reminders: reminders.toList(),
    );
  }

  // --- Opening, testing -------------------------------------------------------

  /// Taps on reminders while the app runs.
  Stream<ReminderOpen> get opened => platform.opened;

  /// The tap that launched the app, if there was one.
  Future<ReminderOpen?> takeLaunch() async {
    try {
      return await platform.takeLaunch();
    } catch (error) {
      debugPrint('Reminder launch not read: $error');
      return null;
    }
  }

  /// Settings → Reminders → Test: the heads-up, then the call, for the first
  /// habit that has a reminder — or a stand-in, so it always shows something.
  Future<void> testHabit() {
    final habits = tide.habits;
    final habit =
        habits.where((h) => h.reminderEnabled).firstOrNull ??
        habits.firstOrNull;
    return platform.test(
      ReminderPlanner.habitTest(habit, settings, now: _clock()),
    );
  }

  /// The same for a to-do: the soonest open one with steps all ticked, or a
  /// stand-in.
  Future<void> testTask() {
    final task = _tasks?.open.firstOrNull;
    return platform.test(
      ReminderPlanner.taskTest(task, settings, now: _clock()),
    );
  }

  /// The call a test would ring, to show inside the app instead — for
  /// platforms that cannot take the screen, and for a look without waiting.
  PlannedReminder previewCall(ReminderGroup group) {
    final now = _clock();
    if (group == ReminderGroup.habits) {
      final habits = tide.habits;
      final habit =
          habits.where((h) => h.reminderEnabled).firstOrNull ??
          habits.firstOrNull;
      return ReminderPlanner.habitTest(habit, settings, now: now).last;
    }
    return ReminderPlanner.taskTest(
      _tasks?.open.firstOrNull,
      settings,
      now: now,
    ).last;
  }

  Future<void> previewTone(ReminderTone tone) => platform.previewTone(tone);

  @override
  void dispose() {
    tide.removeListener(_onTide);
    tide.sessionChanges.removeListener(_onSession);
    _habitTimer?.cancel();
    unawaited(_queued.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }
}

/// The task store's reminders, planned here with the to-do defaults.
class _TaskChannel implements TaskReminders {
  _TaskChannel(this._store);

  final ReminderStore _store;

  @override
  Future<void> schedule(List<Task> tasks) {
    _store._tasksSeen = tasks;
    return _store._planTasks();
  }

  @override
  Future<void> clear() {
    _store._tasksSeen = const [];
    return _store._planTasks(force: true);
  }

  @override
  Future<bool> requestPermission() async =>
      (await _store.request(ReminderPermission.notifications)).ok;
}
