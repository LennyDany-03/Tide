import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../config/app_constants.dart';
import '../habits/habit_rows.dart';
import '../models/reminder_options.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';

/// Reminders on iOS, through `flutter_local_notifications`.
///
/// iOS has no way for an app to take the lock screen, so a call arrives as a
/// time-sensitive notification — it breaks through a Focus that allows it —
/// with Done, Snooze and Skip on it, and a tap opens the Tide Call or the
/// Lighthouse inside the app. The heads-up is a notification of its own with
/// "I'm on it", "Done already" and "Skip today".
///
/// What this does not do yet, and why: a Notification Content Extension (the
/// wave card), a Live Activity (the countdown in the Dynamic Island) and
/// AlarmKit (a true system alarm, iOS 26) each need a target and
/// entitlements added in Xcode, which cannot be built from here. See
/// `docs/REMINDERS.md`.
///
/// iOS keeps 64 pending notifications per app and drops the rest silently,
/// so each group holds its soonest [_perGroup] and the rest are scheduled as
/// they come into range.
class DarwinReminderPlatform implements ReminderPlatform {
  DarwinReminderPlatform._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _perGroup = 28;

  static Future<ReminderPlatform> create() async {
    final platform = DarwinReminderPlatform._();
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: _settings,
        onDidReceiveNotificationResponse: platform._onResponse,
        onDidReceiveBackgroundNotificationResponse: onReminderBackground,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        platform._launch = _openFor(response);
        // An action pressed on the notification that launched the app is an
        // answer, not only a tap.
        final action = _actionFor(response);
        if (action != null) platform._inbox.add(action);
      }
    } catch (error) {
      debugPrint('iOS reminders unavailable: $error');
      return NoReminderPlatform();
    }
    return platform;
  }

  final List<ReminderAction> _inbox = [];
  final StreamController<void> _queued = StreamController<void>.broadcast();
  final StreamController<ReminderOpen> _opened =
      StreamController<ReminderOpen>.broadcast();
  ReminderOpen? _launch;

  void _onResponse(NotificationResponse response) {
    final item = _itemOf(response.payload);
    if (item == null) return;
    if (response.actionId == _Action.snooze) {
      unawaited(_snoozeAgain(item));
      return;
    }
    final action = _actionFor(response);
    if (action != null) {
      _inbox.add(action);
      _queued.add(null);
      return;
    }
    if (response.actionId == null || response.actionId!.isEmpty) {
      final open = _openFor(response);
      if (open != null) _opened.add(open);
    }
  }

  @override
  List<ReminderPermission> get permissionsAsked => const [
    ReminderPermission.notifications,
  ];

  @override
  bool get fullScreenCalls => false;

  @override
  bool get canPreviewTones => false;

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<Map<ReminderPermission, PermissionState>> permissions() async {
    final options = await _ios?.checkPermissions();
    final granted = options?.isEnabled ?? false;
    return {
      for (final p in ReminderPermission.values)
        p: p == ReminderPermission.notifications
            ? (granted ? PermissionState.granted : PermissionState.denied)
            : PermissionState.notApplicable,
    };
  }

  @override
  Future<PermissionState> request(ReminderPermission permission) async {
    if (permission != ReminderPermission.notifications) {
      return PermissionState.notApplicable;
    }
    final granted =
        await _ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    return granted ? PermissionState.granted : PermissionState.denied;
  }

  @override
  Future<void> schedule(
    ReminderGroup group,
    List<PlannedReminder> items, {
    required Set<String> open,
  }) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload ?? '';
      final item = _itemOf(payload);
      final planned = payload.startsWith(_prefix(group));
      final staleSnooze =
          payload.startsWith(_snoozePrefix) &&
          item != null &&
          item.kind.group == group &&
          !open.contains(item.subjectId);
      if (planned || staleSnooze) await _plugin.cancel(id: request.id);
    }
    for (final item in items.take(_perGroup)) {
      await _show(item, _prefix(group));
    }
  }

  @override
  Future<void> test(List<PlannedReminder> items) async {
    for (final item in items) {
      await _show(item, _testPrefix);
    }
  }

  @override
  Future<void> snooze(PlannedReminder item, Duration after, int snoozes) async {
    await _scheduleSnooze(_plugin, item, after, snoozes);
  }

  Future<void> _snoozeAgain(PlannedReminder item) async {
    final taken = (item.details['snoozes'] as num?)?.toInt() ?? 0;
    if (taken >= AppConstants.maxReminderSnoozes) return;
    await _scheduleSnooze(
      _plugin,
      item,
      Duration(minutes: item.options.snoozeMinutes),
      taken + 1,
    );
  }

  Future<void> _show(PlannedReminder item, String prefix) =>
      _scheduleItem(_plugin, item, prefix);

  @override
  Future<List<ReminderAction>> takeActions() async {
    final taken = List.of(_inbox);
    _inbox.clear();
    // Answers given from a notification with the app closed were written by
    // a background isolate straight to the device.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith(_inboxPrefix)) continue;
        final raw = prefs.getString(key);
        await prefs.remove(key);
        final action = raw == null
            ? null
            : ReminderAction.fromJson(jsonDecode(raw));
        if (action != null) taken.add(action);
      }
    } catch (error) {
      debugPrint('Reminder inbox not read: $error');
    }
    return taken;
  }

  @override
  Stream<void> get actionsQueued => _queued.stream;

  @override
  Stream<ReminderOpen> get opened => _opened.stream;

  @override
  Future<ReminderOpen?> takeLaunch() async {
    final launch = _launch;
    _launch = null;
    return launch;
  }

  @override
  Future<void> previewTone(ReminderTone tone) async {}
}

// --- Shared with the background isolate ----------------------------------------

abstract final class _Action {
  static const onIt = 'on_it';
  static const done = 'done';
  static const skip = 'skip';
  static const snooze = 'snooze';
  static const tomorrow = 'tomorrow';
}

abstract final class _Category {
  static const habitHeadsUp = 'tide_habit_heads_up';
  static const habitCall = 'tide_habit_call';
  static const task = 'tide_task';
}

String _prefix(ReminderGroup group) => 'tide:${group.name}:';
const String _testPrefix = 'tide:test:';
const String _snoozePrefix = 'tide:snooze:';
const String _inboxPrefix = 'tide.reminders.inbox.';

InitializationSettings get _settings => InitializationSettings(
  iOS: DarwinInitializationSettings(
    // Asked on onboarding's permission page, or when a reminder is first
    // set — never by the plugin at launch.
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        _Category.habitHeadsUp,
        actions: [
          DarwinNotificationAction.plain(_Action.onIt, "I'm on it"),
          DarwinNotificationAction.plain(_Action.done, 'Done already'),
          DarwinNotificationAction.plain(_Action.skip, 'Skip today'),
        ],
      ),
      DarwinNotificationCategory(
        _Category.habitCall,
        actions: [
          DarwinNotificationAction.plain(_Action.done, 'Done'),
          DarwinNotificationAction.plain(_Action.snooze, 'Snooze'),
          DarwinNotificationAction.plain(_Action.skip, 'Skip today'),
        ],
      ),
      DarwinNotificationCategory(
        _Category.task,
        actions: [
          DarwinNotificationAction.plain(_Action.done, 'Done'),
          DarwinNotificationAction.plain(_Action.snooze, 'Snooze'),
          DarwinNotificationAction.plain(_Action.tomorrow, 'Tomorrow'),
        ],
      ),
    ],
  ),
);

/// FNV-1a over the key, so a reminder keeps its id across launches and a
/// reschedule replaces rather than stacks.
int _idFor(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

PlannedReminder? _itemOf(String? payload) {
  if (payload == null || !payload.startsWith('tide:')) return null;
  final json = payload.substring(payload.indexOf(':', 5) + 1);
  try {
    return PlannedReminder.fromJson(jsonDecode(json));
  } on FormatException {
    return null;
  }
}

Future<void> _scheduleItem(
  FlutterLocalNotificationsPlugin plugin,
  PlannedReminder item,
  String prefix,
) async {
  final kind = item.kind;
  final String title = item.title;
  final String body;
  final String category;
  if (kind == ReminderKind.habitHeadsUp) {
    body = item.copy['headsUpLine'] ?? item.copy['headsUp'] ?? '';
    category = _Category.habitHeadsUp;
  } else if (kind.isHabit) {
    body = [item.copy['callBody'], item.copy['subtitle']].nonNulls.join(' ');
    category = _Category.habitCall;
  } else if (kind == ReminderKind.taskHeadsUp) {
    body = item.copy['headsUpLine'] ?? item.copy['headsUp'] ?? '';
    category = _Category.task;
  } else {
    body = [
      item.copy['callBody'],
      if ((item.copy['steps'] ?? '').isNotEmpty) item.copy['steps'],
    ].nonNulls.join(' ');
    category = _Category.task;
  }
  final level = item.quiet
      ? InterruptionLevel.passive
      : kind.isCall
      ? InterruptionLevel.timeSensitive
      : InterruptionLevel.active;
  await plugin.zonedSchedule(
    id: _idFor(prefix + item.key),
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(item.at, tz.UTC),
    notificationDetails: NotificationDetails(
      iOS: DarwinNotificationDetails(
        categoryIdentifier: category,
        threadIdentifier: kind.group.name,
        interruptionLevel: level,
        presentSound: !item.quiet,
        subtitle: kind.isHeadsUp ? item.copy['headsUp'] : null,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: '$prefix${jsonEncode(item.toJson())}',
  );
}

Future<void> _scheduleSnooze(
  FlutterLocalNotificationsPlugin plugin,
  PlannedReminder item,
  Duration after,
  int snoozes,
) async {
  if (item.test) return;
  final at = DateTime.now().add(after);
  final copy = PlannedReminder.fromJson({
    ...item.toJson(),
    'key': '${item.occurrence}:snooze$snoozes',
    'at': at.millisecondsSinceEpoch,
    'dueAt': at.millisecondsSinceEpoch,
    'details': {...item.details, 'snoozes': snoozes},
  });
  if (copy == null) return;
  await _scheduleItem(plugin, copy, _snoozePrefix);
}

ReminderOpen? _openFor(NotificationResponse response) {
  final item = _itemOf(response.payload);
  if (item == null) return null;
  if (item.kind.isHeadsUp) {
    return ReminderOpen(
      item.kind.isHabit ? ReminderOpenTarget.habit : ReminderOpenTarget.task,
      item.subjectId,
    );
  }
  return ReminderOpen(ReminderOpenTarget.call, item.key, calls: [item]);
}

ReminderAction? _actionFor(NotificationResponse response) {
  final item = _itemOf(response.payload);
  if (item == null || item.test) return null;
  final type = switch (response.actionId) {
    _Action.done =>
      item.kind.isHabit
          ? ReminderActionType.habitDone
          : ReminderActionType.taskDone,
    _Action.skip => ReminderActionType.habitSkip,
    _Action.tomorrow => ReminderActionType.taskTomorrow,
    _ => null,
  };
  if (type == null) return null;
  return ReminderAction(
    id: '${item.key}:${response.actionId}:${DateTime.now().microsecondsSinceEpoch}',
    type: type,
    subjectId: item.subjectId,
    at: DateTime.now(),
    day: HabitRows.parseDay(item.details['day']),
    accountId: item.accountId,
  );
}

/// A notification's button pressed with the app closed. Top level and kept
/// by the compiler, so the background isolate can find it. It has no store:
/// an answer is written to the device and applied the next time the app
/// runs; a snooze is scheduled on the spot.
@pragma('vm:entry-point')
Future<void> onReminderBackground(NotificationResponse response) async {
  final item = _itemOf(response.payload);
  if (item == null) return;
  if (response.actionId == _Action.snooze) {
    tz_data.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: _settings);
    final taken = (item.details['snoozes'] as num?)?.toInt() ?? 0;
    if (taken >= AppConstants.maxReminderSnoozes) return;
    await _scheduleSnooze(
      plugin,
      item,
      Duration(minutes: item.options.snoozeMinutes),
      taken + 1,
    );
    return;
  }
  final action = _actionFor(response);
  if (action == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_inboxPrefix${action.id}',
      jsonEncode(action.toJson()),
    );
  } on PlatformException catch (error) {
    debugPrint('Reminder answer not kept: $error');
  }
}
