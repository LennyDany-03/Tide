import 'package:flutter/material.dart';

/// The global motion system. Every animation in the app pulls its duration
/// and curve from here, which is what makes nine separately-built screens
/// feel like one object.
abstract final class TideMotion {
  // --- Press feedback ---------------------------------------------------

  /// Every tappable element scales to this on press. No exceptions.
  static const double pressScale = 0.97;
  static const Duration press = Duration(milliseconds: 130);
  static const Curve pressCurve = Curves.easeOut;

  /// Springing back on release overshoots very slightly past resting size.
  ///
  /// This is applied as a `reverseCurve`, where the controller runs 1 -> 0.
  /// `easeInBack` dips below zero near that end, which drives the scale
  /// tween just past 1.0 — the small bounce you feel on release.
  static const Curve pressReleaseCurve = Curves.easeInBack;

  // --- Ring fill --------------------------------------------------------

  /// Overshoot, then settle — the signature Tide curve.
  static const Curve overshoot = Cubic(0.34, 1.56, 0.64, 1);
  static const Duration ringFill = Duration(milliseconds: 600);

  /// The onboarding ring drawing itself in from empty.
  static const Duration ringDraw = Duration(milliseconds: 1100);

  // --- Numbers ----------------------------------------------------------

  /// Odometer digit-roll. Numbers never plain-swap.
  static const Duration digitRoll = Duration(milliseconds: 300);
  static const Curve digitRollCurve = Curves.easeOutCubic;

  /// Stat chips counting up from zero on entrance.
  static const Duration countUp = Duration(milliseconds: 900);

  // --- Entrances --------------------------------------------------------

  /// List items fade in and rise by [staggerRise], [staggerStep] apart.
  static const Duration staggerItem = Duration(milliseconds: 380);
  static const Duration staggerStep = Duration(milliseconds: 60);
  static const double staggerRise = 8;
  static const Curve staggerCurve = Curves.easeOutCubic;

  /// Heatmap and calendar cells rippling in across a grid.
  static const Duration cellFill = Duration(milliseconds: 420);
  static const Duration cellStep = Duration(milliseconds: 14);

  // --- Navigation -------------------------------------------------------

  /// Tab switches and month paging share this family.
  static const Duration tabSwitch = Duration(milliseconds: 200);
  static const double tabSlide = 4;
  static const Curve tabCurve = Curves.easeOutCubic;

  /// The sliding pill under the active tab / inside a segmented control.
  static const Duration pillSlide = Duration(milliseconds: 280);
  static const Curve pillCurve = Curves.easeOutCubic;

  /// Sheets rising from the bottom with floating elevation.
  static const Duration sheetIn = Duration(milliseconds: 380);
  static const Duration sheetOut = Duration(milliseconds: 260);
  static const Curve sheetCurve = Curves.easeOutCubic;

  /// The FAB morphing into a sheet header, and the onboarding ring morphing
  /// into Home's ring.
  static const Duration morph = Duration(milliseconds: 460);
  static const Curve morphCurve = Curves.easeOutCubic;

  // --- Gestures ---------------------------------------------------------

  /// Fraction of card width a swipe must cross to commit.
  static const double swipeThreshold = 0.4;

  /// Snapping into place after crossing the threshold.
  static const Duration swipeSettle = Duration(milliseconds: 260);

  /// Springing back when released early — a soft bounce, nothing logged.
  static const Duration swipeCancel = Duration(milliseconds: 340);
  static const Curve swipeCancelCurve = Curves.elasticOut;

  /// Hold-to-fill: how long a hold must be sustained to commit.
  static const Duration holdToCommit = Duration(milliseconds: 1200);

  /// How long the log sheet's control must be held to bank a single unit.
  ///
  /// One hold, one unit. The control used to fire on touch-down and then
  /// repeat on a 260ms metronome for as long as it was held, which meant a
  /// resting thumb ran an eight-glass target from empty to full in under
  /// two seconds. Nothing about that was addressable: you could not stop on
  /// six, because six went past before you had finished reacting to five.
  ///
  /// Long enough to read as deliberate rather than as a tap, short enough
  /// that it is not a chore. The nudge buttons beside it are there for the
  /// targets where holding this out unit by unit would be.
  static const Duration holdUnit = Duration(milliseconds: 520);

  /// The log sheet's ring catching up to a unit that has just landed.
  ///
  /// Shorter than [holdUnit] on purpose — the ring should have finished
  /// moving by the time a second hold could bank anything.
  static const Duration holdStep = Duration(milliseconds: 260);

  // --- Feedback ---------------------------------------------------------

  /// A single habit's completion ripple.
  static const Duration ripple = Duration(milliseconds: 620);

  /// The rarer, bigger celebration when a milestone unlocks.
  static const Duration celebration = Duration(milliseconds: 1400);

  /// The whole-day-complete moment on Home — distinct from a single ripple.
  static const Duration dayComplete = Duration(milliseconds: 1600);

  // --- Celebration ------------------------------------------------------

  /// The themed completion panel arriving, standing, and leaving.
  ///
  /// The hold is the number that matters. Under about a second and a half
  /// the line cannot be read before it starts to go, which turns a reward
  /// into a flicker; much past two and a half and you are waiting on the
  /// app to finish congratulating you, every single day. Anything on screen
  /// this often has to be shorter than it wants to be.
  static const Duration celebrateIn = Duration(milliseconds: 440);
  static const Duration celebrateHold = Duration(milliseconds: 1750);
  static const Duration celebrateOut = Duration(milliseconds: 280);

  /// How long the arcade panel spends filling its XP bar, and the kawaii
  /// panel spends bobbing once. Both are decoration inside the hold, so
  /// they have to finish well inside [celebrateHold].
  static const Duration celebrateFlourish = Duration(milliseconds: 900);

  /// Arcade quantises its motion to this many frames, so the panel arrives
  /// in visible steps instead of sliding.
  static const int arcadeSteps = 6;

  // --- Milestone route --------------------------------------------------

  /// The route drawing itself down the screen on arrival, and the lantern
  /// travelling to where the streak actually stands.
  ///
  /// The traveller is slower than the line on purpose: the route is context
  /// and arrives first, then the eye follows the one moving thing to the
  /// only part of the screen that is about *you*.
  static const Duration routeDraw = Duration(milliseconds: 1000);
  static const Duration routeTravel = Duration(milliseconds: 1400);
  static const Curve routeCurve = Curves.easeOutCubic;
  static const Curve routeTravelCurve = Curves.easeOutCubic;

  /// Pausing or archiving a habit "drains" its colour away.
  static const Duration drain = Duration(milliseconds: 400);

  /// Trend charts draw left-to-right rather than snapping in.
  static const Duration chartDraw = Duration(milliseconds: 720);

  /// Validation errors pulse the field border and shake it gently.
  static const Duration errorShake = Duration(milliseconds: 420);

  /// Ambient loops — the breathing empty state, the sync dot, the CTA glow.
  /// Deliberately slow enough to read as atmosphere, not as animation.
  static const Duration breathe = Duration(milliseconds: 3200);
  static const Duration syncPulse = Duration(milliseconds: 2400);
  static const Duration ctaGlow = Duration(milliseconds: 3600);

  /// The onboarding background drift — the only screen allowed it.
  static const Duration ambientDrift = Duration(seconds: 24);
}
