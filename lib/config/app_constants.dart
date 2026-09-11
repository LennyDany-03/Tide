import 'package:flutter/material.dart';

/// Product-level constants: limits, copy and the tab manifest.
abstract final class AppConstants {
  static const String appName = 'Tide';

  /// The line under the name on the splash and in Settings.
  static const String tagline = 'Habits that move like water';

  /// Free plan ceiling. Hitting it is what triggers the contextual paywall —
  /// the upgrade sheet is never a buried settings row.
  static const int freeHabitLimit = 5;

  /// Free-plan history window, quoted on the paywall.
  static const int freeHistoryDays = 30;

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

  /// Default freeze allowance on a new habit.
  static const int defaultFreezeAllowance = 2;
  static const int maxFreezeAllowance = 7;

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

  /// Four tabs — Milestones and Upgrade are reached contextually rather
  /// than taking a slot here.
  static const List<TideTab> all = [
    TideTab(
      label: 'Today',
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny_rounded,
      path: '/today',
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
