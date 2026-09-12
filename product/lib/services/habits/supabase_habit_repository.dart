import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/habit.dart';
import 'habit_outbox.dart';
import 'habit_repository.dart';
import 'habit_rows.dart';

/// Habits kept in Supabase (`supabase/habits_setup.sql`), with a copy on the
/// device and changes from the account's other devices arriving live.
///
/// **Offline first.** A write goes into a [HabitOutbox] saved on the device
/// before any request is made, and the queue is sent in order whenever the
/// server can be reached: straight away, on pull to refresh, when the app
/// comes back to the foreground, when the realtime channel joins, and on a
/// backoff while none of those happen. A day logged on a train is not lost,
/// even if the app is killed before the train leaves the tunnel.
///
/// **Why broadcasts, and why the origin.** A database trigger announces each
/// change on a private topic only the owner can join. The device that made
/// the change hears it too, so every row carries the [origin] of the process
/// that wrote it and that echo is skipped rather than applied over a newer
/// tap. A change from elsewhere is also skipped while a write here to the
/// same row is still queued: the local write lands after it and wins, and
/// applying it in between would make the screen step back and forth.
///
/// **Why a snapshot waits on the queue.** The account is read back in one
/// request (`habits_snapshot()`), but only once the queue is empty, and the
/// answer is thrown away if a write was made while it was on its way. A
/// snapshot read before a queued write reached the server holds the older
/// rows, and showing it would briefly undo what the person just did.
class SupabaseHabitRepository implements HabitRepository {
  SupabaseHabitRepository(this._client, this._prefs);

  static Future<SupabaseHabitRepository> load(SupabaseClient client) async =>
      SupabaseHabitRepository(client, await SharedPreferences.getInstance());

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Written on every row this run of the app sends. Random per launch:
  /// nothing needs it to outlive the process, and a stable one would be one
  /// more identifier kept about the device.
  final String origin = _newOrigin();

  static const Duration _requestTimeout = Duration(seconds: 12);

  /// How long the device copy waits for a burst of taps to finish before it
  /// is written — one write for a run of holds, not one per unit.
  static const Duration _cacheDelay = Duration(milliseconds: 600);

  static const Duration _firstRetry = Duration(seconds: 2);
  static const Duration _lastRetry = Duration(minutes: 1);

  final StreamController<HabitChange> _changes =
      StreamController<HabitChange>.broadcast();

  final ValueNotifier<SyncStatus> _status = ValueNotifier<SyncStatus>(
    SyncStatus.syncing,
  );

  String? _accountId;
  HabitOutbox _outbox = HabitOutbox();
  RealtimeChannel? _channel;
  AppLifecycleListener? _lifecycle;
  DateTime? _lastSynced;

  /// Bumped by every write, so a snapshot can tell whether one was made while
  /// it was on its way.
  int _writeCount = 0;

  Future<void>? _flushing;
  bool _flushAgain = false;

  Future<void>? _refreshing;
  bool _refreshAgain = false;

  Timer? _retry;
  Duration _retryDelay = _firstRetry;

  Timer? _cacheTimer;
  List<Habit>? _unsaved;

  @override
  Stream<HabitChange> get changes => _changes.stream;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  DateTime? get lastSynced => _lastSynced;

  @override
  bool get hasPendingWrites => !_outbox.isEmpty;

  // --- The device copy ----------------------------------------------------

  @override
  List<Habit> cached(String? accountId) {
    if (accountId == null) return const [];
    final source = _prefs.getString(_cacheKey(accountId));
    if (source == null) return const [];
    try {
      final rows = jsonDecode(source);
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map) HabitRows.parseHabit(Map<String, dynamic>.from(row)),
      ].nonNulls.toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  void remember(List<Habit> habits) {
    final accountId = _accountId;
    if (accountId == null) return;
    _unsaved = habits;
    _cacheTimer ??= Timer(_cacheDelay, () {
      _cacheTimer = null;
      _writeCache(accountId);
    });
  }

  void _writeCache(String accountId) {
    final habits = _unsaved;
    _unsaved = null;
    if (habits == null || _accountId != accountId) return;
    unawaited(
      _prefs.setString(
        _cacheKey(accountId),
        jsonEncode([for (final habit in habits) HabitRows.snapshot(habit)]),
      ),
    );
  }

  // --- Following an account -----------------------------------------------

  @override
  void open(String accountId) {
    if (_accountId == accountId) return;
    if (_accountId != null) unawaited(close());

    _accountId = accountId;
    _outbox = HabitOutbox.decode(_prefs.getString(_outboxKey(accountId)));
    _lastSynced = null;
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    unawaited(_listen(accountId));
    unawaited(refresh());
  }

  @override
  Future<void> close({bool forget = false}) async {
    final accountId = _accountId;
    if (accountId == null) return;

    _cacheTimer?.cancel();
    _cacheTimer = null;
    if (forget) {
      _unsaved = null;
      unawaited(_prefs.remove(_cacheKey(accountId)));
      unawaited(_prefs.remove(_outboxKey(accountId)));
    } else {
      _writeCache(accountId);
      _saveOutbox(accountId);
    }

    // Everything below is let go before the first await, so an [open] that
    // follows straight after starts clean.
    _accountId = null;
    _outbox = HabitOutbox();
    _flushAgain = false;
    _refreshAgain = false;
    _retry?.cancel();
    _retry = null;
    _retryDelay = _firstRetry;
    _lifecycle?.dispose();
    _lifecycle = null;

    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } catch (error) {
      debugPrint('Habit channel not removed: $error');
    }
  }

  Future<void> _listen(String accountId) async {
    // A private channel is authorised by the token the socket holds when it
    // joins. The client passes realtime the token from its own auth listener,
    // which can still be on its way just after a sign-in, so it is passed
    // here too rather than joining on the publishable key and being refused.
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      try {
        await _client.realtime.setAuth(token);
      } catch (error) {
        debugPrint('Realtime token not set: $error');
      }
    }
    if (_accountId != accountId) return;

    final channel = _client.channel(
      'habits:$accountId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;

    var joinedBefore = false;
    channel
      ..onBroadcast(
        event: '*',
        callback: (message) => _onBroadcast(accountId, message),
      )
      ..subscribe((state, error) {
        if (!identical(_channel, channel)) return;
        if (state == RealtimeSubscribeStatus.subscribed) {
          // The first join is covered by the refresh [open] already started.
          // A later one follows a dropped socket, and anything announced while
          // it was down was missed, so the account is read again.
          if (joinedBefore) unawaited(refresh());
          joinedBefore = true;
        } else if (state != RealtimeSubscribeStatus.closed) {
          debugPrint('Habit channel ${state.name}: ${error ?? ''}');
        }
      });
  }

  void _onBroadcast(String accountId, Map<String, dynamic> message) {
    if (_accountId != accountId) return;
    final body = message['payload'];
    if (body is! Map) return;
    final table = body['table'];

    if (body['operation'] == 'DELETE') {
      final old = body['old_record'];
      final habitId = old is Map ? old['id'] : null;
      if (table != 'habits' || habitId is! String) return;
      // Anything still queued for it would be refused, or would bring it back.
      _outbox.dropHabit(habitId);
      _saveOutbox(accountId);
      _announce(HabitRemoved(accountId, habitId));
      return;
    }

    final record = body['record'];
    if (record is! Map) return;
    final row = Map<String, dynamic>.from(record);
    if (row['origin'] == origin) return;

    switch (table) {
      case 'habits':
        final habit = HabitRows.parseHabit(row);
        if (habit == null || _outbox.holds(PendingWrite.keyFor(habit.id))) {
          return;
        }
        _announce(HabitSaved(accountId, habit));
      case 'habit_entries':
        final entry = HabitRows.parseEntry(row);
        if (entry == null) return;
        final key = PendingWrite.keyFor(
          entry.habitId,
          day: HabitRows.dayText(entry.day),
        );
        if (_outbox.holds(key)) return;
        _announce(HabitEntrySaved(accountId, entry));
    }
  }

  void _announce(HabitChange change) {
    // A snapshot already on its way was read before this change and would put
    // the old row back, so another is read after it.
    if (_refreshing != null) _refreshAgain = true;
    _changes.add(change);
  }

  // --- Writes ---------------------------------------------------------------

  @override
  void saveHabit(Habit habit) =>
      _enqueue(PendingWrite.habit(HabitRows.habit(habit, origin: origin)));

  @override
  void saveEntry(Habit habit, DateTime day) => _enqueue(
    PendingWrite.entry(HabitRows.entry(habit, day, origin: origin)),
  );

  @override
  void removeHabit(String habitId) => _enqueue(PendingWrite.removal(habitId));

  void _enqueue(PendingWrite write) {
    final accountId = _accountId;
    if (accountId == null) return;
    _outbox.add(write);
    _writeCount++;
    _saveOutbox(accountId);
    if (_flushing != null) {
      // The running flush may already have found the queue empty and be on
      // its way out; it starts again rather than leave this write behind.
      _flushAgain = true;
    } else {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    // A block body, not an arrow: `whenComplete` waits on whatever its
    // callback returns, and `flush()` returns the future being completed.
    final next = _drain().whenComplete(() {
      _flushing = null;
      if (_flushAgain) {
        _flushAgain = false;
        unawaited(flush());
      }
    });
    _flushing = next;
    return next;
  }

  Future<void> _drain() async {
    final accountId = _accountId;
    if (accountId == null) return;
    final outbox = _outbox;

    while (_accountId == accountId) {
      final write = outbox.take();
      if (write == null) break;
      _status.value = SyncStatus.syncing;
      try {
        await _send(accountId, write).timeout(_requestTimeout);
        outbox.settle(write);
      } on PostgrestException catch (error) {
        if (!_refusedForGood(error)) {
          outbox.release(write);
          if (_accountId == accountId) _failed('Saving habits', error);
          return;
        }
        // Refused on its merits — its habit was deleted on another device, or
        // a value this schema will not take. Kept, it would block every write
        // queued behind it for good.
        debugPrint('Habit write dropped: ${error.code} ${error.message}');
        outbox.settle(write);
      } catch (error) {
        outbox.release(write);
        if (_accountId == accountId) _failed('Saving habits', error);
        return;
      } finally {
        if (_accountId == accountId) _saveOutbox(accountId);
      }
    }
    if (_accountId == accountId && outbox.isEmpty) _synced();
  }

  Future<void> _send(String accountId, PendingWrite write) async {
    switch (write.kind) {
      case PendingWriteKind.habit:
        await _client.from('habits').upsert({
          ...write.row,
          'user_id': accountId,
        });
      case PendingWriteKind.entry:
        await _client.from('habit_entries').upsert({
          ...write.row,
          'user_id': accountId,
        }, onConflict: 'habit_id,day');
      case PendingWriteKind.removal:
        await _client.from('habits').delete().eq('id', write.habitId);
    }
  }

  /// Whether the server turned a write down on its merits, so sending it again
  /// can only fail again: Postgres classes 22 (bad data) and 23 (a failed
  /// check, a missing habit), and 42501 (row level security). Anything else —
  /// no network, an expired token, tables not installed yet — is worth another
  /// try, and holding the write while it is fixed is how nothing is lost.
  static bool _refusedForGood(PostgrestException error) {
    final code = error.code ?? '';
    return code.startsWith('22') || code.startsWith('23') || code == '42501';
  }

  // --- Reads ----------------------------------------------------------------

  @override
  Future<void> refresh() {
    if (_accountId == null) return Future<void>.value();
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final next = _refresh().whenComplete(() {
      _refreshing = null;
      if (_refreshAgain) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    });
    _refreshing = next;
    return next;
  }

  Future<void> _refresh() async {
    final accountId = _accountId;
    if (accountId == null) return;
    _retry?.cancel();
    _retry = null;

    await flush();
    if (_accountId != accountId) return;
    if (!_outbox.isEmpty) {
      // Still sending — a write arrived mid-flush — so read once it is done.
      // A queue that could not be sent has already scheduled its own retry.
      if (_flushing != null) _refreshAgain = true;
      return;
    }

    _status.value = SyncStatus.syncing;
    final writesBefore = _writeCount;
    try {
      final result = await _client
          .rpc<dynamic>('habits_snapshot')
          .timeout(_requestTimeout);
      if (_accountId != accountId) return;
      if (writesBefore != _writeCount || !_outbox.isEmpty) {
        _refreshAgain = true;
        return;
      }
      final habits = [
        if (result is List)
          for (final row in result)
            if (row is Map)
              HabitRows.parseHabit(Map<String, dynamic>.from(row)),
      ].nonNulls.toList();
      _synced();
      _changes.add(HabitsReplaced(accountId, habits));
    } catch (error) {
      if (_accountId == accountId) _failed('Reading habits', error);
    }
  }

  // --- Status ---------------------------------------------------------------

  void _synced() {
    _lastSynced = DateTime.now();
    _retryDelay = _firstRetry;
    _status.value = SyncStatus.synced;
  }

  void _failed(String what, Object error) {
    debugPrint('$what failed: $error');
    if (error is PostgrestException &&
        (error.code == 'PGRST202' || error.code == 'PGRST205')) {
      debugPrint(
        'Habits are not set up on the server yet. Run '
        'supabase/habits_setup.sql in the SQL editor.',
      );
    }
    _status.value = SyncStatus.offline;
    _retry?.cancel();
    _retry = Timer(_retryDelay, () {
      _retry = null;
      unawaited(refresh());
    });
    final doubled = _retryDelay * 2;
    _retryDelay = doubled > _lastRetry ? _lastRetry : doubled;
  }

  void _saveOutbox(String accountId) {
    final key = _outboxKey(accountId);
    unawaited(
      _outbox.isEmpty
          ? _prefs.remove(key)
          : _prefs.setString(key, _outbox.encode()),
    );
  }

  static String _cacheKey(String accountId) => 'tide.habits.$accountId';

  static String _outboxKey(String accountId) => 'tide.habit_outbox.$accountId';

  static String _newOrigin() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 12; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
