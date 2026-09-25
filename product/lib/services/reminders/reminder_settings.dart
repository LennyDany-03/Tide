import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/reminder_copy.dart';
import '../models/reminder_options.dart';

/// Settings → Reminders: the switches that apply to every reminder.
///
/// Per device rather than per account. How loudly a phone may ring, and
/// when it must keep quiet, belongs to the phone on the nightstand — a
/// tablet on the kitchen counter wants a different answer from the same
/// person. What each *habit* asks for travels with the habit.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.quietHours = false,
    this.quietStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietEnd = const TimeOfDay(hour: 7, minute: 0),
    this.habitDefaults = const ReminderOptions(),
    this.taskDefaults = ReminderOptions.taskDefaults,
  });

  /// Every reminder, habits and to-dos. Off means nothing is scheduled at
  /// all; each habit keeps its own setting for when this comes back on.
  final bool enabled;

  /// Inside quiet hours a reminder still arrives, silently and without
  /// taking the screen, and a heads-up does not arrive at all. Dropping them
  /// altogether left a habit set for 22:30 with no reminder anybody could
  /// see, and no way to tell why.
  final bool quietHours;
  final TimeOfDay quietStart;
  final TimeOfDay quietEnd;

  /// What a new habit's reminder starts as.
  final ReminderOptions habitDefaults;

  /// How every to-do reminder arrives. To-dos do not carry their own: the
  /// new-task drawer is for writing a task down quickly, and five more
  /// controls there would cost every task to serve the rare one.
  final ReminderOptions taskDefaults;

  /// Whether [at] falls inside quiet hours. A window that crosses midnight
  /// (22:00 – 07:00) is the usual case; a window with no length is none.
  bool isQuietAt(DateTime at) {
    if (!quietHours) return false;
    final minute = at.hour * 60 + at.minute;
    final start = quietStart.hour * 60 + quietStart.minute;
    final end = quietEnd.hour * 60 + quietEnd.minute;
    if (start == end) return false;
    return start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }

  /// "22:00 – 07:00".
  String get quietLabel =>
      '${ReminderCopy.clock(quietStart)} – ${ReminderCopy.clock(quietEnd)}';

  ReminderSettings copyWith({
    bool? enabled,
    bool? quietHours,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
    ReminderOptions? habitDefaults,
    ReminderOptions? taskDefaults,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      quietHours: quietHours ?? this.quietHours,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      habitDefaults: habitDefaults ?? this.habitDefaults,
      taskDefaults: taskDefaults ?? this.taskDefaults,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'quiet': quietHours,
    'quietStart': _minutes(quietStart),
    'quietEnd': _minutes(quietEnd),
    'habit': habitDefaults.toJson(),
    'task': taskDefaults.toJson(),
  };

  static ReminderSettings fromJson(Object? json) {
    const fallback = ReminderSettings();
    if (json is! Map) return fallback;
    final enabled = json['enabled'];
    final quiet = json['quiet'];
    return ReminderSettings(
      enabled: enabled is bool ? enabled : fallback.enabled,
      quietHours: quiet is bool ? quiet : fallback.quietHours,
      quietStart: _time(json['quietStart']) ?? fallback.quietStart,
      quietEnd: _time(json['quietEnd']) ?? fallback.quietEnd,
      habitDefaults: ReminderOptions.fromJson(json['habit']),
      taskDefaults: ReminderOptions.fromJson(
        json['task'],
        fallback: ReminderOptions.taskDefaults,
      ),
    );
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay? _time(Object? value) {
    if (value is! int || value < 0 || value >= 24 * 60) return null;
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.quietHours == quietHours &&
      other.quietStart == quietStart &&
      other.quietEnd == quietEnd &&
      other.habitDefaults == habitDefaults &&
      other.taskDefaults == taskDefaults;

  @override
  int get hashCode => Object.hash(
    enabled,
    quietHours,
    quietStart,
    quietEnd,
    habitDefaults,
    taskDefaults,
  );
}

/// Where [ReminderSettings] are kept between launches.
class ReminderPrefs {
  ReminderPrefs._(this._prefs, this._settings, this._legacyCleared);

  /// Remembers nothing past the process — tests.
  ReminderPrefs.memory({ReminderSettings settings = const ReminderSettings()})
    : this._(null, settings, true);

  static Future<ReminderPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    ReminderSettings settings;
    try {
      final raw = prefs.getString(_settingsKey);
      settings = ReminderSettings.fromJson(
        raw == null ? null : jsonDecode(raw),
      );
    } on FormatException {
      settings = const ReminderSettings();
    }
    return ReminderPrefs._(prefs, settings, prefs.getBool(_legacyKey) ?? false);
  }

  static const String _settingsKey = 'tide.reminders.settings';
  static const String _legacyKey = 'tide.reminders.legacy_cleared';

  final SharedPreferences? _prefs;
  ReminderSettings _settings;
  bool _legacyCleared;

  ReminderSettings get settings => _settings;

  set settings(ReminderSettings next) {
    if (next == _settings) return;
    _settings = next;
    unawaited(_prefs?.setString(_settingsKey, jsonEncode(next.toJson())));
  }

  /// The to-do reminders an earlier build scheduled through
  /// `flutter_local_notifications` on Android have been cancelled, so they
  /// cannot fire beside the ones scheduled now.
  bool get legacyCleared => _legacyCleared;

  void markLegacyCleared() {
    if (_legacyCleared) return;
    _legacyCleared = true;
    unawaited(_prefs?.setBool(_legacyKey, true));
  }
}
