import 'package:flutter/foundation.dart';

/// A thing on Today the tour can put a light on.
enum TourStop {
  /// The screen title and date line.
  header,

  /// The day's figure and the water behind it.
  hero,

  /// Where habits will be listed — empty on a new account, which is the
  /// whole reason the tour exists.
  list,

  /// The four destinations.
  tabs,

  /// The add control in the header, and the last thing the tour points at.
  add,
}

/// The demo a step runs inside its caption, if any.
enum TourDemo {
  none,

  /// The swipe-to-log loop, the same one onboarding shows.
  swipe,
}

/// One step of the guided tour.
@immutable
class TourStep {
  const TourStep({
    required this.stop,
    required this.title,
    required this.body,
    this.demo = TourDemo.none,
    this.inset = 8,
    this.radius = 20,
  });

  final TourStop stop;
  final String title;
  final String body;
  final TourDemo demo;

  /// How far the light spreads past the target. Tuned per stop: a text
  /// block needs room around it to stop the hole reading as a highlighter
  /// pen, while a control that already has its own padding needs almost
  /// none.
  final double inset;

  /// Corner radius of the hole. Matches the shape of whatever is inside it,
  /// so the light looks like it is falling on the object rather than
  /// through a stencil. Plain numbers rather than the elevation tokens —
  /// config does not reach into the theme.
  final double radius;
}

/// What a new account is shown, in order.
///
/// Signing up empties the app on purpose, and an empty app explains
/// nothing about itself. This is what fills that silence: five stops that
/// name the parts of Today, ending on the add control — so the tour does
/// not finish by congratulating the user, it finishes by handing them the
/// one action there is.
///
/// The order is read-then-act. Everything before the last stop is
/// orientation and can be skipped without cost; the last stop is the thing
/// that turns an empty screen into a used one.
abstract final class TourCatalog {
  static const List<TourStep> steps = [
    TourStep(
      stop: TourStop.header,
      title: 'This is Today',
      body:
          'One screen, one day. Tide never asks you to look further ahead '
          'than the next few hours.',
      inset: 12,
      radius: 16,
    ),
    TourStep(
      stop: TourStop.hero,
      title: 'The day, as one figure',
      body:
          'How much of today is done, with the water standing at the level '
          'you have reached. It fills as you mark.',
      inset: 10,
      radius: 20,
    ),
    TourStep(
      stop: TourStop.list,
      title: 'Habits live here',
      body:
          'Each one is a card. Carry it right to mark the day — that is the '
          'whole gesture, and it is the only one you need.',
      demo: TourDemo.swipe,
      inset: 4,
      radius: 20,
    ),
    TourStep(
      stop: TourStop.tabs,
      title: 'Everything else is behind these',
      body:
          'History for the calendar, Insights for the pattern, Settings for '
          'the rest. Swipe between them, or tap.',
      inset: 6,
      radius: 22,
    ),
    TourStep(
      stop: TourStop.add,
      title: 'Add your first habit',
      body:
          'Pick something small and daily. The rhythm matters far more than '
          'the size of it.',
      inset: 8,
      radius: 14,
    ),
  ];
}
