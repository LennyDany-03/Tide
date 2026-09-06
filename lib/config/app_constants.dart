import 'package:flutter/material.dart';

import '../services/models/tide_glyph.dart';

/// Product-level constants: limits, copy and the tab manifest.
abstract final class AppConstants {
  static const String appName = 'Tide';

  /// Free plan ceiling. Hitting it is what triggers the contextual paywall —
  /// the upgrade sheet is never a buried settings row.
  static const int freeHabitLimit = 5;

  /// Free-plan history window, quoted on the paywall.
  static const int freeHistoryDays = 30;

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
@immutable
class TideTab {
  const TideTab({required this.label, required this.glyph, required this.path});

  final String label;
  final TideGlyph glyph;
  final String path;

  /// Four tabs and a floating add action — Milestones and Upgrade are
  /// reached contextually rather than taking a slot here.
  static const List<TideTab> all = [
    TideTab(label: 'Today', glyph: TideGlyph.diamondOutline, path: '/today'),
    TideTab(label: 'History', glyph: TideGlyph.striped, path: '/history'),
    TideTab(label: 'Insights', glyph: TideGlyph.crescent, path: '/insights'),
    TideTab(label: 'Settings', glyph: TideGlyph.diamond, path: '/settings'),
  ];
}
