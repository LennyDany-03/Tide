import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../config/app_constants.dart';
import 'task.dart';
import 'task_reminders.dart';

const String _channelId = 'tide_tasks';
const String _channelName = 'To-do reminders';
const String _category = 'tide_task';
const String _snoozeAction = 'snooze';

/// Payloads this file writes. A reminder is `task:<id>`; a snoozed copy is
/// `snoozed:<id>` so a reconcile, which cancels every `task:` request it
/// finds, leaves a snooze that is already counting down alone.
const String _taskPrefix = 'task:';
const String _snoozedPrefix = 'snoozed:';

/// Task reminders through `flutter_local_notifications`, on Android and iOS.
///
/// **Absolute instants.** Every reminder is one moment in time, so it is
/// scheduled in UTC and there is no time-zone database lookup to get wrong:
/// a reminder for 9:00 is converted to its instant when it is set, and fires
/// at that instant wherever the phone is.
///
/// **The nearest [AppConstants.maxScheduledTaskReminders] only.** iOS keeps
/// 64 pending notifications per app and silently drops the rest. Scheduling
/// the soonest ones and topping up on every change keeps the ones that
/// matter; the rest are scheduled as they come into range.
///
/// **Exact when allowed.** Android 14 makes exact alarms a permission the
/// person can refuse. A reminder that fires within Android's inexact window
/// is still a reminder, so a refusal falls back rather than failing.
class LocalTaskReminders implements TaskReminders {
  LocalTaskReminders._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _opened = StreamController<String>.broadcast();

  /// Android and iOS. Everywhere else a [NoTaskReminders] stands in.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<TaskReminders> create() async {
    if (!supported) return NoTaskReminders();
    final reminders = LocalTaskReminders._();
    try {
      await reminders._initialize();
    } catch (error) {
      debugPrint('Task reminders unavailable: $error');
      return NoTaskReminders();
    }
    return reminders;
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: _settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onTaskReminderBackground,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      // Delivered after the app has had a frame to subscribe.
      scheduleMicrotask(() => _onResponse(response));
    }
  }

  void _onResponse(NotificationResponse response) {
    if (response.actionId == _snoozeAction) {
      unawaited(_snooze(response));
      return;
    }
    final parsed = _parsePayload(response.payload);
    if (parsed != null) _opened.add(parsed.id);
  }

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        if (granted &&
            !(await android.canScheduleExactNotifications() ?? false)) {
          await android.requestExactAlarmsPermission();
        }
        return granted;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (error) {
      debugPrint('Notification permission not requested: $error');
      return false;
    }
  }

  @override
  Future<void> schedule(List<Task> tasks, {required bool snooze}) async {
    try {
      await _cancelTaskReminders();
      final now = DateTime.now();
      final due = <({Task task, DateTime at})>[
        for (final task in tasks)
          if (!task.isCompleted && !task.isDeleted && !task.isArchived)
            for (final at in task.reminders)
              if (at.isAfter(now)) (task: task, at: at),
      ]..sort((a, b) => a.at.compareTo(b.at));

      final mode = await _scheduleMode();
      for (final item in due.take(AppConstants.maxScheduledTaskReminders)) {
        await _plugin.zonedSchedule(
          id: _notificationId(item.task.id, item.at),
          title: item.task.title,
          body: _body(item.task),
          scheduledDate: tz.TZDateTime.from(item.at, tz.UTC),
          notificationDetails: _details(snooze: snooze),
          androidScheduleMode: mode,
          payload: _payload(
            _taskPrefix,
            item.task.id,
            item.task.title,
            _body(item.task),
          ),
        );
      }
    } catch (error) {
      debugPrint('Task reminders not scheduled: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Task reminders not cleared: $error');
    }
  }

  Future<void> _cancelTaskReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_taskPrefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await android.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _snooze(NotificationResponse response) =>
      snoozeTaskReminder(response);

  static String _body(Task task) {
    final open = task.subtasks.length - task.subtasksDone;
    if (open > 0) return '$open ${open == 1 ? 'step' : 'steps'} left';
    return task.description?.split('\n').first ?? 'Due now';
  }

  /// Stable per task and moment, so the same reminder always gets the same
  /// id and a reconcile replaces it rather than stacking a second copy.
  ///
  /// FNV-1a rather than `Object.hash`, whose values are allowed to change
  /// between runs — an id that changed across a restart could not replace
  /// the request it was meant to.
  static int _notificationId(String taskId, DateTime at) {
    var hash = 0x811c9dc5;
    for (final unit in '$taskId@${at.millisecondsSinceEpoch}'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// `<prefix><task id>\n<title>\n<body>`. The title and body travel in the
  /// payload because a snooze runs where the task list cannot be read, and
  /// by then the notification it came from has already been dismissed.
  static String _payload(String prefix, String id, String title, String body) =>
      '$prefix$id\n$title\n$body';

  static ({String id, String title, String body})? _parsePayload(
    String? payload,
  ) {
    if (payload == null) return null;
    for (final prefix in [_taskPrefix, _snoozedPrefix]) {
      if (!payload.startsWith(prefix)) continue;
      final parts = payload.substring(prefix.length).split('\n');
      return (
        id: parts.first,
        title: parts.length > 1 ? parts[1] : 'Reminder',
        body: parts.length > 2 ? parts.sublist(2).join('\n') : '',
      );
    }
    return null;
  }
}

InitializationSettings get _settings => InitializationSettings(
  android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    // Asked when somebody first sets a reminder, not at launch — a
    // permission prompt before the app has shown anything is the one most
    // people refuse.
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        _category,
        actions: [
          DarwinNotificationAction.plain(
            _snoozeAction,
            'Snooze ${AppConstants.taskSnoozeMinutes} min',
          ),
        ],
      ),
    ],
  ),
);

NotificationDetails _details({required bool snooze}) => NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Reminders you set on to-do items',
    importance: Importance.high,
    priority: Priority.high,
    actions: snooze
        ? const [
            AndroidNotificationAction(
              _snoozeAction,
              'Snooze ${AppConstants.taskSnoozeMinutes} min',
            ),
          ]
        : null,
  ),
  iOS: DarwinNotificationDetails(categoryIdentifier: snooze ? _category : null),
);

/// Shows the reminder again in [AppConstants.taskSnoozeMinutes] minutes.
///
/// Needs nothing from the app — no store, no account — because on Android it
/// runs in a background isolate while the app is not open.
Future<void> snoozeTaskReminder(
  NotificationResponse response, {
  bool initialize = false,
}) async {
  final parsed = LocalTaskReminders._parsePayload(response.payload);
  if (parsed == null) return;
  tz_data.initializeTimeZones();
  final plugin = FlutterLocalNotificationsPlugin();
  // A background isolate starts with a plugin nobody has set up. The app's
  // own isolate must not re-initialise: that would replace its tap handler.
  if (initialize) await plugin.initialize(settings: _settings);
  final at = DateTime.now().add(
    const Duration(minutes: AppConstants.taskSnoozeMinutes),
  );
  final details = _details(snooze: true);
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  final exact = await android?.canScheduleExactNotifications() ?? true;
  await plugin.zonedSchedule(
    id: LocalTaskReminders._notificationId('$_snoozedPrefix${parsed.id}', at),
    title: parsed.title,
    body: parsed.body,
    scheduledDate: tz.TZDateTime.from(at, tz.UTC),
    notificationDetails: details,
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    payload: LocalTaskReminders._payload(
      _snoozedPrefix,
      parsed.id,
      parsed.title,
      parsed.body,
    ),
  );
}

/// The action handler Android calls with the app closed. Top-level and kept
/// by the compiler so the background isolate can find it.
@pragma('vm:entry-point')
void onTaskReminderBackground(NotificationResponse response) {
  if (response.actionId == _snoozeAction) {
    unawaited(snoozeTaskReminder(response, initialize: true));
  }
}
