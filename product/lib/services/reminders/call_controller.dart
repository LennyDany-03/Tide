import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_constants.dart';
import '../habits/habit_rows.dart';
import '../models/habit.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';
import 'reminder_store.dart';

/// How a call was answered.
enum CallOutcome {
  /// Habit ridden in, to-do docked.
  done,
  snooze,

  /// A freeze spent on the day. Habits only.
  skip,

  /// Put off to tomorrow. To-dos only.
  tomorrow,

  /// Heard, and nothing more. The habit or to-do stays open.
  dismiss,
}

/// The calls on screen and what answering them does.
///
/// The screens never know where they are. On Android's lock screen they run
/// in their own isolate and answer through native code
/// ([NativeCallController]); inside the app — a tap on iOS, a preview from
/// Settings — they answer through the stores ([InAppCallController]).
///
/// **An answered call stays in [calls] until the screen retires it**, so its
/// farewell — the surge, the streak, "Back in 10 min" — plays out in full.
/// The answer itself is sent at once: the ringing must stop the moment the
/// water reaches the top, not a second and a half later.
abstract class CallController extends ChangeNotifier {
  final List<PlannedReminder> _calls = [];
  final Map<String, int> _snoozes = {};
  final Set<String> _answered = {};
  bool _loaded = false;
  bool _closed = false;

  List<PlannedReminder> get calls => List.unmodifiable(_calls);

  /// Whether [calls] has been read yet. Nothing is drawn before it has.
  bool get loaded => _loaded;

  /// Shown over the lock screen, where nothing but the call is reachable.
  bool get overLockScreen => false;

  /// Answered, and waiting on its farewell before it is retired.
  bool isAnswered(PlannedReminder call) => _answered.contains(call.key);

  int snoozesTaken(PlannedReminder call) => _snoozes[call.key] ?? 0;

  /// A snooze is still allowed: [AppConstants.maxReminderSnoozes] is the
  /// last. A test can be snoozed, to see it happen; it just does not come
  /// back.
  bool canSnooze(PlannedReminder call) =>
      snoozesTaken(call) < AppConstants.maxReminderSnoozes;

  /// Answers [call]. Sends the answer at once; the call stays on screen
  /// until [retire].
  Future<void> resolve(PlannedReminder call, CallOutcome outcome) async {
    if (!_answered.add(call.key)) return;
    notifyListeners();
    await send(call, outcome);
  }

  /// Ticks or unticks one of a to-do's steps from the call.
  Future<void> toggleStep(
    PlannedReminder call,
    String stepId,
    bool done,
  ) async {
    final index = _calls.indexWhere((c) => c.key == call.key);
    if (index < 0) return;
    final steps = call.details['steps'];
    if (steps is! List) return;
    _calls[index] = call.copyWith(
      details: {
        ...call.details,
        'steps': [
          for (final step in steps)
            if (step is Map && step['id'] == stepId)
              {...step, 'done': done}
            else
              step,
        ],
      },
    );
    notifyListeners();
    await sendStep(call, stepId, done);
  }

  /// Takes an answered call off the screen. The last one closes it.
  void retire(PlannedReminder call) {
    _calls.removeWhere((c) => c.key == call.key);
    _answered.remove(call.key);
    notifyListeners();
    if (_calls.isEmpty) unawaited(close());
  }

  /// Leaves the call for the app itself. On the lock screen this asks for
  /// the phone to be unlocked first.
  Future<void> openApp(PlannedReminder? call);

  /// The screen has nothing left to show.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await finish();
  }

  // --- For implementations ---------------------------------------------------

  @protected
  void show(List<PlannedReminder> next, {Map<String, int> snoozes = const {}}) {
    // Calls already answered keep their place until they are retired, even
    // if the phone has stopped listing them.
    final keep = _calls.where((c) => _answered.contains(c.key)).toList();
    _calls
      ..clear()
      ..addAll(keep)
      ..addAll(next.where((c) => !keep.any((k) => k.key == c.key)));
    _snoozes
      ..clear()
      ..addAll(snoozes);
    _loaded = true;
    notifyListeners();
  }

  @protected
  Future<void> send(PlannedReminder call, CallOutcome outcome);

  @protected
  Future<void> sendStep(PlannedReminder call, String stepId, bool done);

  @protected
  Future<void> finish();
}

/// Calls answered inside the app: a notification tapped on iOS, or a
/// preview from Settings → Reminders.
class InAppCallController extends CallController {
  InAppCallController({
    required this.reminders,
    required List<PlannedReminder> calls,
    required this.onClose,
    this.preview = false,
  }) {
    show(calls);
  }

  final ReminderStore reminders;

  /// Called once, when the screen has nothing left to show.
  final VoidCallback onClose;

  /// Answers change nothing: a look at the design, not a reminder.
  final bool preview;

  bool _live(PlannedReminder call) => !preview && !call.test;

  @override
  Future<void> send(PlannedReminder call, CallOutcome outcome) async {
    if (!_live(call)) return;
    final type = switch (outcome) {
      CallOutcome.done =>
        call.kind.isHabit
            ? ReminderActionType.habitDone
            : ReminderActionType.taskDone,
      CallOutcome.skip => ReminderActionType.habitSkip,
      CallOutcome.tomorrow => ReminderActionType.taskTomorrow,
      CallOutcome.snooze || CallOutcome.dismiss => null,
    };
    if (type != null) {
      reminders.apply(_action(call, type));
    } else if (outcome == CallOutcome.snooze) {
      await reminders.platform.snooze(
        call,
        Duration(minutes: call.options.snoozeMinutes),
        snoozesTaken(call) + 1,
      );
    }
  }

  @override
  Future<void> sendStep(PlannedReminder call, String stepId, bool done) async {
    if (!_live(call)) return;
    reminders.apply(
      _action(call, ReminderActionType.taskStep, step: stepId, value: done),
    );
  }

  ReminderAction _action(
    PlannedReminder call,
    ReminderActionType type, {
    String? step,
    bool value = true,
  }) {
    return ReminderAction(
      id: '${call.key}:${type.name}:${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      subjectId: call.subjectId,
      at: DateTime.now(),
      day:
          HabitRows.parseDay(call.details['day']) ??
          DateUtils.dateOnly(call.dueAt),
      stepId: step,
      value: value,
      accountId: call.accountId,
    );
  }

  @override
  Future<void> openApp(PlannedReminder? call) => close();

  @override
  Future<void> finish() async => onClose();
}

/// Calls on Android's lock screen, in the isolate `TideCallActivity` starts.
///
/// Native code owns the ringing, the queue of answers and the snoozes; this
/// asks it what is ringing, tells it what was answered, and hears when
/// another call joins the one on screen.
class NativeCallController extends CallController {
  NativeCallController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await load();
    });
  }

  static const MethodChannel _channel = MethodChannel('tide/call');

  final DateTime Function() _clock;

  bool _locked = true;

  @override
  bool get overLockScreen => _locked;

  /// Reads what is ringing, and brings each habit's figures up to date from
  /// the device's copy of the account.
  Future<void> load() async {
    try {
      final raw = await _channel.invokeMethod<String>('load');
      final json = raw == null ? null : jsonDecode(raw);
      if (json is! Map) {
        show(const []);
        return;
      }
      _locked = json['locked'] != false;
      final calls = [
        for (final item in (json['calls'] as List? ?? const []))
          ?PlannedReminder.fromJson(item),
      ];
      final pending = [
        for (final item in (json['pending'] as List? ?? const []))
          ?ReminderAction.fromJson(item),
      ];
      final snoozes = <String, int>{
        for (final entry in (json['snoozes'] as Map? ?? const {}).entries)
          if (entry.value is int) '${entry.key}': entry.value as int,
      };
      show(await _refreshed(calls, pending), snoozes: snoozes);
    } catch (error) {
      debugPrint('Calls not read: $error');
      show(const []);
    }
  }

  /// [calls] with streaks worked out from the device's copy, as it would
  /// stand once [pending] answers from earlier calls are applied. A call
  /// planned three days ago would otherwise show three-day-old figures.
  Future<List<PlannedReminder>> _refreshed(
    List<PlannedReminder> calls,
    List<ReminderAction> pending,
  ) async {
    final accounts = {
      for (final call in calls)
        if (call.kind.isHabit && !call.test) ?call.accountId,
    };
    if (accounts.isEmpty) return calls;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final now = _clock();
    final habits = <String, Habit>{};
    for (final account in accounts) {
      for (final habit in HabitRows.decodeCache(
        prefs.getString(HabitRows.cacheKey(account)),
      )) {
        habits[habit.id] = _withPending(habit, pending);
      }
    }
    return [
      for (final call in calls)
        if (call.kind.isHabit && habits[call.subjectId] != null)
          ReminderPlanner.refreshed(call, habits[call.subjectId]!, now: now)
        else
          call,
    ];
  }

  static Habit _withPending(Habit habit, List<ReminderAction> pending) {
    var result = habit;
    for (final action in pending) {
      if (action.subjectId != habit.id || action.day == null) continue;
      final day = DateUtils.dateOnly(action.day!);
      switch (action.type) {
        case ReminderActionType.habitDone:
          result = result.copyWith(logs: {...result.logs, day: result.target});
        case ReminderActionType.habitSkip:
          result = result.copyWith(frozenDays: {...result.frozenDays, day});
        default:
          break;
      }
    }
    return result;
  }

  @override
  Future<void> send(PlannedReminder call, CallOutcome outcome) async {
    try {
      await _channel.invokeMethod<void>('resolve', {
        'key': call.key,
        'outcome': outcome.name,
      });
    } catch (error) {
      debugPrint('Call not answered: $error');
    }
  }

  @override
  Future<void> sendStep(PlannedReminder call, String stepId, bool done) async {
    try {
      await _channel.invokeMethod<void>('step', {
        'key': call.key,
        'step': stepId,
        'value': done,
      });
    } catch (error) {
      debugPrint('Step not sent: $error');
    }
  }

  @override
  Future<void> openApp(PlannedReminder? call) async {
    try {
      await _channel.invokeMethod<void>('openApp', {'key': call?.key});
    } catch (error) {
      debugPrint('App not opened: $error');
    }
  }

  @override
  Future<void> finish() async {
    try {
      await _channel.invokeMethod<void>('close');
    } catch (error) {
      debugPrint('Call not closed: $error');
    }
  }
}
