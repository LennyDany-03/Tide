import 'package:flutter/material.dart' show TimeOfDay;

import 'app_constants.dart';

/// Every sentence a reminder says, for habits and for to-dos.
///
/// The tone is the whole design brief: calm, encouraging, never nagging. A
/// reminder that scolds gets its notifications turned off, and then it cannot
/// say anything at all.
///
/// Where there are several ways to say a thing, one is picked by [pick] from
/// a stable hash of the reminder, so the same occurrence always reads the same
/// — a heads-up redrawn a minute later does not change its mind — while the
/// days vary from each other.
abstract final class ReminderCopy {
  /// One of [options], the same one every time for [seed].
  ///
  /// FNV-1a rather than `String.hashCode`, which may differ between runs: the
  /// copy is chosen when the plan is built and must not change on a rebuild.
  static String pick(String seed, List<String> options) {
    var hash = 0x811c9dc5;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return options[hash % options.length];
  }

  /// "10 min", "1 min".
  static String minutes(int minutes) => '$minutes min';

  // --- Habits: the heads-up ("Rising Tide") -------------------------------

  /// The collapsed line under the habit's name.
  static String risingTide(int lead) => 'Tide rises in ${minutes(lead)}';

  /// The longer line in the expanded card.
  static String risingTideLine(String seed, String name, int lead) =>
      pick(seed, [
        'The tide rises in ${minutes(lead)} — $name is up next.',
        '${minutes(lead)} till $name. Ride the wave.',
        '$name in ${minutes(lead)}. The water is already moving.',
        'A little swell before $name — ${minutes(lead)} to go.',
      ]);

  /// The streak line on the heads-up and under the call's orb.
  static String streakLine(int streak) => streak > 0
      ? '$streak-day streak — keep the tide high'
      : 'A new loop starts today';

  // --- Habits: the call ("Tide Call") -------------------------------------

  /// The line under the habit name on the call. [day] is the day this one
  /// would make — the running streak plus one — and it is "at its highest"
  /// when that would match or pass the best the habit has ever had.
  static String callSubtitle({
    required int day,
    required int streak,
    required int best,
  }) {
    if (streak <= 0) return 'Day 1 · The first wave of a new loop';
    if (day >= best) return 'Day $day · Your tide is at its highest';
    return 'Day $day · The tide is coming back in';
  }

  static String callBody(String seed, String name) => pick(seed, [
    "It's time for $name.",
    '$name, right on the tide.',
    'The water is up. Time for $name.',
  ]);

  /// Said once the call is answered with done.
  static String doneLine(int streak) =>
      streak == 1 ? 'Streak: 1 day' : 'Streak: $streak days';

  static String snoozedLine(int minutes) =>
      'Back in ${ReminderCopy.minutes(minutes)}';

  static String skippedLine(int freezesLeft) => freezesLeft == 1
      ? 'Frozen for today · 1 freeze left'
      : 'Frozen for today · $freezesLeft freezes left';

  /// The notification left behind when a call rings out unanswered.
  static String habitMissed(String name) =>
      'The tide went out on $name — still time today.';

  // --- To-dos: the heads-up ("Beacon") ------------------------------------

  static String beacon(int lead) => 'Due in ${minutes(lead)}';

  static String beaconLine(String seed, String title, int lead) => pick(seed, [
    'The light is on — $title in ${minutes(lead)}.',
    '${minutes(lead)} till $title. The harbour is in sight.',
    'Coming up in ${minutes(lead)}: $title.',
  ]);

  /// "2 of 5 steps done", or '' for a task with no steps.
  static String steps(int done, int total) =>
      total == 0 ? '' : '$done of $total steps done';

  // --- To-dos: the call ("Lighthouse") ------------------------------------

  static String lighthouseBody(String seed, String title) => pick(seed, [
    'The beam is on $title.',
    '$title, now.',
    'Bring $title in.',
  ]);

  static String docked() => 'Docked';

  static String tomorrowLine() => 'Moved to tomorrow';

  static String stepsLeftLine(int left) => left == 1
      ? '1 step left — tick it to dock'
      : '$left steps left — tick them to dock';

  static String taskMissed(String title) =>
      'The beam passed $title — it is still on your list.';

  // --- Shared -------------------------------------------------------------

  /// "07:30".
  static String clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// "Thursday · 24 September", said in small capitals on the call.
  static String date(DateTime date) =>
      '${AppConstants.weekdayNames[date.weekday - 1]} · '
      '${date.day} ${AppConstants.monthNames[date.month - 1]}';
}
