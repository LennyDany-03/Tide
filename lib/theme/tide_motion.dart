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

  /// The speed, in pixels per second, at which a horizontal drag stops being
  /// an action on a card and becomes a page thrown at the tab bar.
  ///
  /// One number with two owners, deliberately. A habit card's swipe sits
  /// below the shell's tab swipe in the tree and so wins the gesture arena
  /// by depth — a flick meant as "next tab" that happened to start on a card
  /// never reached the shell at all. Distance could not tell the two apart
  /// either: the flick crossed [swipeThreshold] on its way past and logged
  /// the habit. Speed can. A considered swipe is aimed and slows into the
  /// threshold; a page fling is already gone by the time it gets there.
  ///
  /// The shell commits a fling at this speed and the card refuses one at the
  /// same speed, so there is no band where a gesture is fast enough to have
  /// been a page swipe and still counts as a deliberate log.
  static const double swipeFlingVelocity = 380;

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

  /// One full burn of the streak fire.
  ///
  /// The exception to the rule above: this loop is deliberately *not* slow.
  /// Everything else ambient in the app is atmosphere and reads wrong if
  /// you can see it working, but a fire that idles at breathing pace does
  /// not read as fire — it reads as a flame-shaped logo being scaled. The
  /// flicker inside the painter runs at three, seven and eleven times this
  /// rate, which puts its fastest term around five per second, in the range
  /// a real flame actually moves at.
  static const Duration flameCycle = Duration(milliseconds: 2200);

  // --- The mark and the splash ------------------------------------------

  /// The mark drawing itself in: ring, then tide, then moon.
  static const Duration markDraw = Duration(milliseconds: 1600);

  /// One lap of the point round the mark. Slow enough to read as a loop
  /// going on, not a spinner waiting on something.
  static const Duration orbit = Duration(milliseconds: 5200);

  /// One cycle of the water surface drifting inside the mark.
  static const Duration swell = Duration(milliseconds: 9000);

  /// The splash's full entrance: glow, ring, tide, moon, name, tagline.
  ///
  /// Long enough for each part to be seen arriving in order, short enough
  /// that it is over before anyone wonders whether the app is loading. It
  /// can always be tapped through.
  static const Duration splashIntro = Duration(milliseconds: 2200);

  /// The finished mark held still before the app takes over, so the logo is
  /// seen *complete* at least once rather than only ever in motion.
  static const Duration splashHold = Duration(milliseconds: 520);

  /// The splash leaving: everything fades and the mark pushes gently toward
  /// you, in the direction it was already moving.
  static const Duration splashExit = Duration(milliseconds: 420);

  // --- Welcome ----------------------------------------------------------

  /// The greeting after sign-in: the portrait settling, then the greeting
  /// and the name rising in under it.
  static const Duration welcomeIn = Duration(milliseconds: 700);

  /// Long enough to read a first name and the line under it, short enough
  /// that nobody is kept from the app they just signed into. A tap skips it.
  static const Duration welcomeHold = Duration(milliseconds: 1300);

  // --- Email code -------------------------------------------------------

  /// The envelope drawing itself in on the code screen.
  static const Duration mailDraw = Duration(milliseconds: 1100);

  /// A digit landing in its cell. Quick: it answers a keystroke.
  static const Duration codeDigit = Duration(milliseconds: 180);

  /// The code accepted — the cells lighting left to right, the envelope
  /// folding away into a ring, the tick drawing through it.
  static const Duration codeAccepted = Duration(milliseconds: 1100);

  /// The finished tick held still before the welcome takes over, so it is
  /// seen complete rather than only ever in motion.
  static const Duration codeAcceptedHold = Duration(milliseconds: 650);
}
