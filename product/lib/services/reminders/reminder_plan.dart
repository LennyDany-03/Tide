import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/foundation.dart';

import '../../config/app_constants.dart';
import '../../config/reminder_copy.dart';
import '../../config/task_copy.dart';
import '../habits/habit_rows.dart';
import '../models/habit.dart';
import '../models/reminder_options.dart';
import '../models/tide_glyph.dart';
import '../streak_calculator.dart';
import '../tasks/task.dart';
import 'reminder_settings.dart';

/// Which half of the app a reminder belongs to. Each is handed to the phone
/// as a whole and replaces what was there, so a habit edit can never cancel
/// a to-do reminder or the other way round.
enum ReminderGroup { habits, tasks }

/// What a reminder is.
enum ReminderKind {
  /// "Rising Tide": minutes before a habit, counting down to it.
  habitHeadsUp,

  /// "Tide Call": at the habit's time, full screen.
  habitCall,

  /// A habit reminder that is only a notification.
  habitGentle,

  /// "Beacon": minutes before a to-do reminder.
  taskHeadsUp,

  /// "Lighthouse": at a to-do's reminder time, full screen.
  taskCall,

  /// A to-do reminder that is only a notification.
  taskGentle;

  bool get isHabit =>
      this == habitHeadsUp || this == habitCall || this == habitGentle;

  bool get isHeadsUp => this == habitHeadsUp || this == taskHeadsUp;

  bool get isCall => this == habitCall || this == taskCall;

  ReminderGroup get group =>
      isHabit ? ReminderGroup.habits : ReminderGroup.tasks;

  /// The suffix a reminder's key ends in.
  String get tag => switch (this) {
    habitHeadsUp || taskHeadsUp => 'headsUp',
    habitCall || taskCall => 'call',
    habitGentle || taskGentle => 'gentle',
  };
}

/// One reminder, planned for one moment.
///
/// Everything the phone needs to show it is carried here — the words, the
/// figures, the look — because on Android it is shown by native code with no
/// Dart running, and on the lock screen by a separate isolate that has no
/// store. The words are written here, in Dart, once; nothing native composes
/// copy.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.key,
    required this.occurrence,
    required this.kind,
    required this.at,
    required this.dueAt,
    required this.subjectId,
    required this.title,
    required this.options,
    this.floating = false,
    this.quiet = false,
    this.test = false,
    this.accountId,
    this.details = const {},
    this.copy = const {},
  });

  /// Unique and stable: the same reminder always has the same key, so a
  /// rebuilt plan replaces rather than duplicates it.
  final String key;

  /// The habit-on-a-day or task-at-a-time this belongs to. A heads-up and
  /// its call share one, which is how "Done already" on the heads-up cancels
  /// the call behind it.
  final String occurrence;

  final ReminderKind kind;

  /// When it fires.
  final DateTime at;

  /// The time it is about: the habit's time, the to-do's reminder. Equal to
  /// [at] except on a heads-up, which counts down to this.
  final DateTime dueAt;

  final String subjectId;
  final String title;
  final ReminderOptions options;

  /// A wall-clock time rather than an instant. A habit at 07:30 stays at
  /// 07:30 when the phone crosses a time zone, so the phone recomputes the
  /// instant from [dueAt]'s local reading. A to-do reminder is an instant,
  /// as it always has been.
  final bool floating;

  /// Inside quiet hours: it arrives silently and does not take the screen.
  final bool quiet;

  /// Fired from Settings → Reminders. Answering it changes nothing.
  final bool test;

  /// Whose it is. An action taken on it is only applied to this account.
  final String? accountId;

  /// Figures for the screens: streak, week, freezes, steps.
  final Map<String, Object?> details;

  /// The sentences, already written.
  final Map<String, String> copy;

  Map<String, Object?> toJson() => {
    'key': key,
    'occurrence': occurrence,
    'kind': kind.name,
    'at': at.millisecondsSinceEpoch,
    'dueAt': dueAt.millisecondsSinceEpoch,
    'local': _localText(dueAt),
    'lead': dueAt.difference(at).inMilliseconds,
    'floating': floating,
    'quiet': quiet,
    'test': test,
    'subject': subjectId,
    'title': title,
    'account': accountId,
    'options': options.toJson(),
    'details': details,
    'copy': copy,
  };

  /// Reads a reminder back — from a notification payload, or from the phone.
  /// Null for anything that is not one.
  static PlannedReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final kind = ReminderKind.values.asNameMap()[json['kind']];
    final at = json['at'];
    final dueAt = json['dueAt'];
    final subject = json['subject'];
    if (key is! String || kind == null || subject is! String) return null;
    if (at is! int || dueAt is! int) return null;
    final title = json['title'];
    final details = json['details'];
    final copy = json['copy'];
    return PlannedReminder(
      key: key,
      occurrence: json['occurrence'] is String
          ? json['occurrence'] as String
          : key,
      kind: kind,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      dueAt: DateTime.fromMillisecondsSinceEpoch(dueAt),
      subjectId: subject,
      title: title is String ? title : '',
      options: ReminderOptions.fromJson(json['options']),
      floating: json['floating'] == true,
      quiet: json['quiet'] == true,
      test: json['test'] == true,
      accountId: json['account'] is String ? json['account'] as String : null,
      details: details is Map
          ? {for (final e in details.entries) '${e.key}': e.value}
          : const {},
      copy: copy is Map
          ? {
              for (final e in copy.entries)
                if (e.value is String) '${e.key}': e.value as String,
            }
          : const {},
    );
  }

  /// This reminder with its figures or words replaced — how a call brings
  /// its streak up to date from the device's copy before it is shown.
  PlannedReminder copyWith({
    Map<String, Object?>? details,
    Map<String, String>? copy,
  }) {
    return PlannedReminder(
      key: key,
      occurrence: occurrence,
      kind: kind,
      at: at,
      dueAt: dueAt,
      subjectId: subjectId,
      title: title,
      options: options,
      floating: floating,
      quiet: quiet,
      test: test,
      accountId: accountId,
      details: details ?? this.details,
      copy: copy ?? this.copy,
    );
  }

  /// `2026-09-25T07:30` — the wall-clock reading a floating reminder keeps.
  static String _localText(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${HabitRows.dayText(at)}T${two(at.hour)}:${two(at.minute)}';
  }

  @override
  String toString() => 'PlannedReminder($key at $at)';
}

/// How a day stands in the week row under a call's orb.
enum WeekMark {
  /// Not asked for: off-schedule or paused.
  rest,
  kept,
  frozen,
  missed,

  /// Today, or a day still to come.
  open,
}

/// Turns habits and to-dos into the reminders the phone should hold.
///
/// Pure, like `StreakCalculator`: no clock of its own, no state. Everything
/// time-dependent takes `now`, so the tests pin it.
abstract final class ReminderPlanner {
  // --- Habits ---------------------------------------------------------------

  /// Every habit reminder due in the next [days] days, soonest first, at most
  /// [limit] of them.
  ///
  /// A day gets a reminder when the habit is due on it — scheduled and not
  /// paused, the same test the streak uses — and, for today, when it has not
  /// already been kept or frozen. A time already gone gets nothing. The
  /// heads-up is left out when it would land in the past or in quiet hours.
  static List<PlannedReminder> habits(
    List<Habit> habits,
    ReminderSettings settings, {
    required DateTime now,
    String? accountId,
    int days = AppConstants.reminderHorizonDays,
    int limit = AppConstants.maxPlannedReminders,
  }) {
    if (!settings.enabled) return const [];
    final today = DateUtils.dateOnly(now);
    final planned = <PlannedReminder>[];

    for (final habit in habits) {
      if (!habit.reminderEnabled) continue;
      final streak = StreakCalculator.currentStreak(habit, asOf: now);
      final best = StreakCalculator.bestStreak(habit, asOf: now);

      for (var offset = 0; offset < days; offset++) {
        final day = DateUtils.addDaysToDate(today, offset);
        if (!habit.isDueOn(day)) continue;
        if (offset == 0 && habit.countsTowardStreak(day)) continue;
        final dueAt = DateTime(
          day.year,
          day.month,
          day.day,
          habit.reminderTime.hour,
          habit.reminderTime.minute,
        );
        if (!dueAt.isAfter(now)) continue;

        planned.addAll(
          _habitOccurrence(
            habit,
            settings,
            day: day,
            dueAt: dueAt,
            now: now,
            streak: streak,
            best: best,
            accountId: accountId,
          ),
        );
      }
    }
    planned.sort((a, b) => a.at.compareTo(b.at));
    return planned.take(limit).toList();
  }

  static List<PlannedReminder> _habitOccurrence(
    Habit habit,
    ReminderSettings settings, {
    required DateTime day,
    required DateTime dueAt,
    required DateTime now,
    required int streak,
    required int best,
    String? accountId,
    bool test = false,
  }) {
    final options = habit.reminderOptions;
    final occurrence = 'h:${habit.id}:${_dayKey(day)}';
    final quiet = !test && settings.isQuietAt(dueAt);
    final details = habitDetails(habit, day: day, now: now);
    final copy = habitCopy(
      habit,
      seed: occurrence,
      streak: streak,
      best: best,
      lead: test ? 0 : options.leadMinutes,
    );
    final callKind = options.style == AlarmStyle.call
        ? ReminderKind.habitCall
        : ReminderKind.habitGentle;

    PlannedReminder make(ReminderKind kind, DateTime at) => PlannedReminder(
      key: '$occurrence:${kind.tag}',
      occurrence: occurrence,
      kind: kind,
      at: at,
      dueAt: dueAt,
      subjectId: habit.id,
      title: habit.name,
      options: options,
      floating: !test,
      quiet: quiet,
      test: test,
      accountId: accountId,
      details: details,
      copy: copy,
    );

    final lead = Duration(minutes: options.leadMinutes);
    final headsUpAt = test ? null : dueAt.subtract(lead);
    return [
      if (headsUpAt != null &&
          options.leadMinutes > 0 &&
          headsUpAt.isAfter(now) &&
          !quiet &&
          !settings.isQuietAt(headsUpAt))
        make(ReminderKind.habitHeadsUp, headsUpAt),
      make(callKind, dueAt),
    ];
  }

  /// The figures a habit's reminder shows: its mark, its streak, the seven
  /// days ending on [day], and the freezes it has left for "Skip today".
  static Map<String, Object?> habitDetails(
    Habit habit, {
    required DateTime day,
    required DateTime now,
  }) {
    final today = DateUtils.dateOnly(now);
    return {
      'glyph': habit.glyph.name,
      'type': habit.type.name,
      'target': habit.targetLabel,
      'streak': StreakCalculator.currentStreak(habit, asOf: now),
      'best': StreakCalculator.bestStreak(habit, asOf: now),
      'freezes': habit.freezesRemaining,
      'day': HabitRows.dayText(day),
      'week': [
        for (var back = 6; back >= 0; back--)
          weekMark(
            habit,
            DateUtils.addDaysToDate(DateUtils.dateOnly(day), -back),
            today: today,
          ).index,
      ],
    };
  }

  /// How [date] stands for [habit], seen from [today].
  static WeekMark weekMark(
    Habit habit,
    DateTime date, {
    required DateTime today,
  }) {
    final day = DateUtils.dateOnly(date);
    if (habit.isCompleteOn(day)) return WeekMark.kept;
    if (habit.isFrozenOn(day)) return WeekMark.frozen;
    if (!day.isBefore(today)) return WeekMark.open;
    if (!habit.isDueOn(day)) return WeekMark.rest;
    if (day.isBefore(DateUtils.dateOnly(habit.createdAt))) return WeekMark.rest;
    return WeekMark.missed;
  }

  static Map<String, String> habitCopy(
    Habit habit, {
    required String seed,
    required int streak,
    required int best,
    required int lead,
  }) {
    final name = habit.name.trim().isEmpty ? 'Your habit' : habit.name.trim();
    final next = streak + 1;
    return {
      'headsUp': lead > 0
          ? ReminderCopy.risingTide(lead)
          : 'Tide rises in a moment · a test',
      'headsUpLine': ReminderCopy.risingTideLine(seed, name, lead),
      'streakLine': ReminderCopy.streakLine(streak),
      'callBody': ReminderCopy.callBody(seed, name),
      'subtitle': ReminderCopy.callSubtitle(
        day: next,
        streak: streak,
        best: best,
      ),
      'missed': ReminderCopy.habitMissed(name),
      'done': ReminderCopy.doneLine(next),
      'snoozed': ReminderCopy.snoozedLine(habit.reminderOptions.snoozeMinutes),
      'skipped': ReminderCopy.skippedLine(
        (habit.freezesRemaining - 1).clamp(0, 99),
      ),
    };
  }

  /// [call] with its streak, week and words worked out again from [habit]
  /// as it stands [now] — for a call planned days ago, shown today.
  static PlannedReminder refreshed(
    PlannedReminder call,
    Habit habit, {
    required DateTime now,
  }) {
    final day =
        HabitRows.parseDay(call.details['day']) ??
        DateUtils.dateOnly(call.dueAt);
    return call.copyWith(
      details: habitDetails(habit, day: day, now: now),
      copy: {
        ...call.copy,
        ...habitCopy(
          habit,
          seed: call.occurrence,
          streak: StreakCalculator.currentStreak(habit, asOf: now),
          best: StreakCalculator.bestStreak(habit, asOf: now),
          lead: call.options.leadMinutes,
        ),
      },
    );
  }

  /// Habits that still want reminding today. A snoozed call for anything
  /// else — kept since, frozen, paused, switched off — is dropped by the
  /// phone rather than coming back to ask about something already settled.
  static Set<String> openHabitSubjects(List<Habit> habits, DateTime now) {
    final today = DateUtils.dateOnly(now);
    return {
      for (final habit in habits)
        if (habit.reminderEnabled &&
            habit.isDueOn(today) &&
            !habit.countsTowardStreak(today))
          habit.id,
    };
  }

  // --- To-dos ---------------------------------------------------------------

  /// Every to-do reminder still to come on an open task, soonest first.
  ///
  /// Each reminder moment the person chose becomes one call — or a gentle
  /// notification — with a heads-up before it when the to-do defaults ask
  /// for one.
  static List<PlannedReminder> tasks(
    List<Task> tasks,
    ReminderSettings settings, {
    required DateTime now,
    String? accountId,
    int limit = AppConstants.maxPlannedReminders,
  }) {
    if (!settings.enabled) return const [];
    final planned = <PlannedReminder>[];
    for (final task in tasks) {
      if (task.isCompleted || task.isDeleted || task.isArchived) continue;
      for (final at in task.reminders) {
        if (!at.isAfter(now)) continue;
        planned.addAll(
          _taskOccurrence(
            task,
            settings,
            dueAt: at,
            now: now,
            accountId: accountId,
          ),
        );
      }
    }
    planned.sort((a, b) => a.at.compareTo(b.at));
    return planned.take(limit).toList();
  }

  static List<PlannedReminder> _taskOccurrence(
    Task task,
    ReminderSettings settings, {
    required DateTime dueAt,
    required DateTime now,
    String? accountId,
    bool test = false,
  }) {
    final options = settings.taskDefaults;
    final occurrence = 't:${task.id}:${dueAt.millisecondsSinceEpoch}';
    final quiet = !test && settings.isQuietAt(dueAt);
    final title = task.title.trim().isEmpty ? 'Your to-do' : task.title.trim();
    final details = taskDetails(task, now: now);
    final lead = test ? 0 : options.leadMinutes;
    final copy = {
      'headsUp': lead > 0
          ? ReminderCopy.beacon(lead)
          : 'Due in a moment · a test',
      'headsUpLine': ReminderCopy.beaconLine(occurrence, title, lead),
      'steps': ReminderCopy.steps(task.subtasksDone, task.subtasks.length),
      'callBody': ReminderCopy.lighthouseBody(occurrence, title),
      'missed': ReminderCopy.taskMissed(title),
      'snoozed': ReminderCopy.snoozedLine(options.snoozeMinutes),
      'done': ReminderCopy.docked(),
      'tomorrow': ReminderCopy.tomorrowLine(),
    };
    final callKind = options.style == AlarmStyle.call
        ? ReminderKind.taskCall
        : ReminderKind.taskGentle;

    PlannedReminder make(ReminderKind kind, DateTime at) => PlannedReminder(
      key: '$occurrence:${kind.tag}',
      occurrence: occurrence,
      kind: kind,
      at: at,
      dueAt: dueAt,
      subjectId: task.id,
      title: title,
      options: options,
      quiet: quiet,
      test: test,
      accountId: accountId,
      details: details,
      copy: copy,
    );

    final headsUpAt = dueAt.subtract(Duration(minutes: options.leadMinutes));
    return [
      if (!test &&
          options.leadMinutes > 0 &&
          headsUpAt.isAfter(now) &&
          !quiet &&
          !settings.isQuietAt(headsUpAt))
        make(ReminderKind.taskHeadsUp, headsUpAt),
      make(callKind, dueAt),
    ];
  }

  static Map<String, Object?> taskDetails(Task task, {required DateTime now}) {
    final note = task.description?.split('\n').first.trim() ?? '';
    final due = task.dueDate;
    return {
      'note': note,
      'due': due == null ? '' : TaskCopy.due(due, now: now),
      'repeats': task.repeats,
      'steps': [
        for (final step in task.subtasks)
          {'id': step.id, 'title': step.title, 'done': step.isCompleted},
      ],
    };
  }

  /// Open to-dos. A snoozed reminder for one that has been finished or
  /// deleted since is dropped.
  static Set<String> openTaskSubjects(List<Task> tasks) => {
    for (final task in tasks)
      if (!task.isCompleted && !task.isDeleted && !task.isArchived) task.id,
  };

  // --- The test button --------------------------------------------------------

  /// A heads-up in [AppConstants.reminderTestDelaySeconds] and a call the same
  /// again after it, for [habit] — or for a stand-in when there are no
  /// habits yet, so the button always has something to show.
  static List<PlannedReminder> habitTest(
    Habit? habit,
    ReminderSettings settings, {
    required DateTime now,
  }) {
    final subject =
        habit ??
        Habit(
          id: 'test',
          name: 'Go for a swim',
          glyph: TideGlyph.water,
          type: HabitType.binary,
          createdAt: now,
          reminderOptions: settings.habitDefaults,
        );
    const delay = Duration(seconds: AppConstants.reminderTestDelaySeconds);
    final dueAt = now.add(delay * 2);
    final day = DateUtils.dateOnly(now);
    final occurrence = _habitOccurrence(
      subject,
      settings,
      day: day,
      dueAt: dueAt,
      now: now,
      streak: StreakCalculator.currentStreak(subject, asOf: now),
      best: StreakCalculator.bestStreak(subject, asOf: now),
      test: true,
    );
    final call = occurrence.last;
    return [
      _retime(call, kind: ReminderKind.habitHeadsUp, at: now.add(delay)),
      _retime(call, kind: ReminderKind.habitCall, at: dueAt),
    ];
  }

  static List<PlannedReminder> taskTest(
    Task? task,
    ReminderSettings settings, {
    required DateTime now,
  }) {
    final subject =
        task ??
        Task(
          id: 'test',
          title: 'Post the parcel',
          description: 'Before the counter closes',
          dueDate: DateUtils.dateOnly(now),
          subtasks: const [
            Subtask(id: 'a', title: 'Find the address', isCompleted: true),
            Subtask(id: 'b', title: 'Print the label', isCompleted: true),
          ],
          createdAt: now,
          updatedAt: now,
        );
    const delay = Duration(seconds: AppConstants.reminderTestDelaySeconds);
    final dueAt = now.add(delay * 2);
    final call = _taskOccurrence(
      subject,
      settings,
      dueAt: dueAt,
      now: now,
      test: true,
    ).last;
    return [
      _retime(call, kind: ReminderKind.taskHeadsUp, at: now.add(delay)),
      _retime(call, kind: ReminderKind.taskCall, at: dueAt),
    ];
  }

  static PlannedReminder _retime(
    PlannedReminder base, {
    required ReminderKind kind,
    required DateTime at,
  }) {
    return PlannedReminder(
      key: '${base.occurrence}:test:${kind.tag}',
      occurrence: '${base.occurrence}:test',
      kind: kind,
      at: at,
      dueAt: base.dueAt,
      subjectId: base.subjectId,
      title: base.title,
      options: base.options,
      test: true,
      details: base.details,
      copy: base.copy,
    );
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';
}
