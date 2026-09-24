import 'package:flutter/foundation.dart';

import '../../config/app_constants.dart';

/// How a reminder arrives at its time.
enum AlarmStyle {
  /// Full screen, over the lock screen, ringing on the alarm stream until it
  /// is answered — "Tide Call" for a habit, "Lighthouse" for a to-do.
  call,

  /// A notification and nothing more.
  gentle;

  String habitLabel() => switch (this) {
    AlarmStyle.call => 'Tide Call',
    AlarmStyle.gentle => 'Gentle',
  };

  String taskLabel() => switch (this) {
    AlarmStyle.call => 'Lighthouse',
    AlarmStyle.gentle => 'Gentle',
  };
}

/// The four sounds a reminder can make. Generated, not recorded, by
/// `tool/reminder_tones_test.dart`, which writes them into Android's
/// `res/raw` under [resource].
enum ReminderTone {
  lowTide('Low Tide chime', 'tone_low_tide'),
  ripple('Ripple', 'tone_ripple'),
  swell('Swell', 'tone_swell'),
  deepBell('Deep Bell', 'tone_deep_bell');

  const ReminderTone(this.label, this.resource);

  final String label;

  /// The raw resource name on Android, without an extension.
  final String resource;
}

/// How one habit's reminder behaves, beyond whether it is on and when.
///
/// Also the shape of the defaults in Settings → Reminders: new habits start
/// from the habit defaults, and every to-do reminder follows the to-do ones.
///
/// Parsing is forgiving for the same reason `HabitRows` is. A value this
/// build does not know — a lead of 20, a tone added later — falls back to the
/// default rather than dropping the reminder.
@immutable
class ReminderOptions {
  const ReminderOptions({
    this.leadMinutes = 10,
    this.style = AlarmStyle.call,
    this.tone = ReminderTone.lowTide,
    this.snoozeMinutes = 10,
    this.vibrate = true,
    this.throughDnd = false,
  });

  /// Minutes of heads-up before the reminder itself. Zero for none.
  final int leadMinutes;

  final AlarmStyle style;
  final ReminderTone tone;

  /// What one snooze puts the call off by.
  final int snoozeMinutes;

  final bool vibrate;

  /// Rings through Do Not Disturb. Off by default: somebody who silenced the
  /// phone meant it, and a habit is rarely the exception they had in mind.
  final bool throughDnd;

  /// The to-do defaults a fresh install starts with. A to-do reminder is a
  /// time somebody chose, so it keeps the heads-up but sounds a lighter tone.
  static const ReminderOptions taskDefaults = ReminderOptions(
    tone: ReminderTone.ripple,
  );

  ReminderOptions copyWith({
    int? leadMinutes,
    AlarmStyle? style,
    ReminderTone? tone,
    int? snoozeMinutes,
    bool? vibrate,
    bool? throughDnd,
  }) {
    return ReminderOptions(
      leadMinutes: leadMinutes ?? this.leadMinutes,
      style: style ?? this.style,
      tone: tone ?? this.tone,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      vibrate: vibrate ?? this.vibrate,
      throughDnd: throughDnd ?? this.throughDnd,
    );
  }

  Map<String, Object?> toJson() => {
    'lead': leadMinutes,
    'style': style.name,
    'tone': tone.name,
    'snooze': snoozeMinutes,
    'vibrate': vibrate,
    'dnd': throughDnd,
  };

  /// Reads [json], falling back to [fallback] for anything missing or
  /// unknown. Never throws.
  static ReminderOptions fromJson(
    Object? json, {
    ReminderOptions fallback = const ReminderOptions(),
  }) {
    if (json is! Map) return fallback;
    final lead = json['lead'];
    final snooze = json['snooze'];
    final vibrate = json['vibrate'];
    final dnd = json['dnd'];
    return ReminderOptions(
      leadMinutes:
          lead is int && AppConstants.reminderLeadChoices.contains(lead)
          ? lead
          : fallback.leadMinutes,
      style: AlarmStyle.values.asNameMap()[json['style']] ?? fallback.style,
      tone: ReminderTone.values.asNameMap()[json['tone']] ?? fallback.tone,
      snoozeMinutes:
          snooze is int && AppConstants.reminderSnoozeChoices.contains(snooze)
          ? snooze
          : fallback.snoozeMinutes,
      vibrate: vibrate is bool ? vibrate : fallback.vibrate,
      throughDnd: dnd is bool ? dnd : fallback.throughDnd,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderOptions &&
      other.leadMinutes == leadMinutes &&
      other.style == style &&
      other.tone == tone &&
      other.snoozeMinutes == snoozeMinutes &&
      other.vibrate == vibrate &&
      other.throughDnd == throughDnd;

  @override
  int get hashCode =>
      Object.hash(leadMinutes, style, tone, snoozeMinutes, vibrate, throughDnd);
}
