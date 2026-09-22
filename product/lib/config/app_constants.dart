import 'package:flutter/material.dart';

/// Product-level constants: limits, copy and the tab manifest.
abstract final class AppConstants {
  static const String appName = 'Tide';

  /// The line under the name on the splash and in Settings.
  static const String tagline = 'Habits that move like water';

  /// Digits in the code emailed to confirm a new account. Must match
  /// Supabase → Sign In / Providers → Email → Email OTP Length.
  static const int emailCodeLength = 6;

  /// How long that code works, quoted on the code screen and in
  /// `supabase/email/confirm_signup.html`. Must match Email OTP Expiration
  /// (600 seconds).
  static const int emailCodeLifetimeMinutes = 10;

  /// Seconds before another code may be requested. Supabase refuses a second
  /// email to the same address inside about a minute anyway; waiting it out
  /// here means Resend never offers something that is about to fail.
  static const int emailCodeResendSeconds = 60;

  /// Freeze allowance a new habit starts with, and the most any habit may be
  /// given. The stepper runs the whole range for everybody.
  static const int defaultFreezeAllowance = 2;
  static const int maxFreezeAllowance = 7;

  // --- App updates -------------------------------------------------------

  /// The least time between two automatic update checks. Launch always
  /// checks; a resume only checks once this much has passed, so switching
  /// apps all afternoon does not fetch the manifest every time.
  static const int updateCheckIntervalHours = 6;

  /// How long the manifest request may take before the check gives up.
  static const int updateManifestTimeoutSeconds = 15;

  /// How long the APK download may go without a byte before it gives up.
  static const int updateDownloadStallSeconds = 30;

  // --- To-do ------------------------------------------------------------

  /// What a notification's snooze action puts the reminder off by.
  static const int taskSnoozeMinutes = 10;

  /// How many upcoming task reminders are handed to the OS at once. iOS
  /// keeps 64 per app and drops the rest silently; the margin leaves room
  /// for snoozes already counting down.
  static const int maxScheduledTaskReminders = 60;

  /// How often an open app syncs tasks with nothing else prompting it.
  static const int taskSyncIntervalMinutes = 15;

  /// The longest a failed task sync waits before trying again.
  static const int taskSyncMaxRetrySeconds = 300;

  /// Longest months a custom repeat may run between occurrences.
  static const int maxCustomRepeatMonths = 24;

  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

/// One destination in the bottom tab bar.
///
/// Named by a pair of icons rather than by one of the app's abstract marks.
/// The marks are good at what they are for — a vocabulary of shapes that
/// belongs to this product and to no other — but a navigation bar is the
/// one place in an app where being *recognisable* beats being distinctive.
/// A crescent does not say "insights" to anybody who has not already
/// learned that it does, and the four of them together read as decoration
/// with words underneath rather than as four places to go.
///
/// Two icons each, outline and filled, because that is how the selected
/// state is carried: the shape thickens rather than a block of furniture
/// sliding underneath it.
@immutable
class TideTab {
  const TideTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });

  final String label;

  /// Unselected: the outline.
  final IconData icon;

  /// Selected: the same shape, filled.
  final IconData activeIcon;

  final String path;

  /// Five tabs — Milestones and Upgrade are reached contextually rather
  /// than taking a slot here. To-do sits beside Today because it is used on
  /// the same errand, but it is the one tab that is not about habits.
  static const List<TideTab> all = [
    TideTab(
      label: 'Today',
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny_rounded,
      path: '/today',
    ),
    TideTab(
      label: 'To-do',
      icon: Icons.check_circle_outline_rounded,
      activeIcon: Icons.check_circle_rounded,
      path: '/tasks',
    ),
    TideTab(
      label: 'History',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      path: '/history',
    ),
    TideTab(
      label: 'Insights',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      path: '/insights',
    ),
    TideTab(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      path: '/settings',
    ),
  ];
}
