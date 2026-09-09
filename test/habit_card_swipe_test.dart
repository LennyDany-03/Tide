import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/home/widgets/habit_card.dart';
import 'package:tide/services/tide_scope.dart';
import 'package:tide/theme/tide_colors.dart';
import 'package:tide/widgets/swipe_log_background.dart';
import 'package:tide/widgets/tide_surface.dart';

/// Seeded binary habits, one either side of today's line: [openHabit] is the
/// card the design shows waiting for a swipe, [loggedHabit] is already done.
const openHabit = 'No screens after 10';
const loggedHabit = 'Read 20 pages';

/// The shape a card slides out of.
///
/// A swipe is the one moment a habit row is not a rectangle sitting still,
/// and it used to come apart there: the stack clipped with `Clip.hardEdge`,
/// which is square, so the travelling card was cut off with a right angle
/// at whichever end it was leaving while the socket behind it kept its 20px
/// radius. And the socket's tint was painted straight onto the page, so a
/// freeze swipe — frost is a near-white — left a band *lighter* than the
/// card that had just moved off it.
void main() {
  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// Whether [name] counts as done today, read off the store rather than
  /// off the card: the card shows the same muted title for a habit that is
  /// frozen as for one that is logged.
  bool loggedToday(WidgetTester tester, String name) {
    final store = TideScope.read(
      tester.element(find.byType(HabitCard).first),
    );
    return store.habits
        .firstWhere((habit) => habit.name == name)
        .isCompleteOn(DateTime.now());
  }

  /// Drags a card horizontally at a fixed, unhurried speed and lets go.
  ///
  /// Hand-rolled rather than `tester.drag`, because the entire point of
  /// these gestures is how fast the finger was moving when it came up — the
  /// card reads the release velocity to tell a deliberate log from a page
  /// thrown at the tab bar. `drag` reports no velocity at all, and
  /// `moveBy` stamps every event at zero unless it is told otherwise, so
  /// the timestamps have to be carried by hand for the velocity tracker to
  /// have anything to estimate from.
  Future<void> dragSlowly(
    WidgetTester tester,
    String name,
    double dx, {
    double pixelsPerSecond = 200,
  }) async {
    const step = Duration(milliseconds: 40);
    final perStep = pixelsPerSecond * step.inMilliseconds / 1000;
    final steps = (dx.abs() / perStep).ceil();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(name)),
    );
    var elapsed = Duration.zero;
    for (var i = 0; i < steps; i++) {
      elapsed += step;
      await gesture.moveBy(Offset(perStep * dx.sign, 0), timeStamp: elapsed);
      await tester.pump(step);
    }
    await gesture.up(timeStamp: elapsed);
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The clip wrapping one card's stack.
  ClipRRect rowClip(WidgetTester tester) {
    return tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(HabitCard).first,
            matching: find.byType(ClipRRect),
          )
          .first,
    );
  }

  testWidgets('a row is clipped to its own radius, not to a rectangle', (
    tester,
  ) async {
    await openHome(tester);

    expect(
      rowClip(tester).borderRadius,
      HabitCard.radius,
      reason: 'the socket, the card and the card leaving it are one shape',
    );
  });

  testWidgets('the socket behind a swipe is a recess, not a pale slab', (
    tester,
  ) async {
    await openHome(tester);

    // Held part way rather than dragged and released: a completed gesture
    // springs the card back before the frame can be read.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Morning water')),
    );
    // Leftward, which is the freeze side — and the side the pale-slab
    // problem belonged to, because frost is a near-white. Rightward would
    // read as zero anyway: a counted habit clamps its log swipe shut, since
    // its exact amount belongs in the drawer rather than in a check.
    //
    // Several steps: the first few pixels are the gesture arena's slop, and
    // the row's recogniser has to win it before any of the travel is real.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-14, 0));
      await tester.pump();
    }

    final background = tester.widget<SwipeLogBackground>(
      find
          .descendant(
            of: find.byType(HabitCard).first,
            matching: find.byType(SwipeLogBackground),
          )
          .first,
    );
    expect(background.offset, lessThan(0));
    expect(background.radius, HabitCard.radius);

    // The first thing painted inside the backdrop is the trench, which is
    // darker than the page. Without it the tint went straight onto
    // deepWater and the exposed socket read as a panel sitting on top of
    // the list rather than a cut into it.
    final ground = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(SwipeLogBackground).first,
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(ground.color, TideColors.trench);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a card keeps all four corners while it slides', (
    tester,
  ) async {
    await openHome(tester);

    TideSurface body() => tester.widget<TideSurface>(
      find
          .descendant(
            of: find.byType(HabitCard).first,
            matching: find.byType(TideSurface),
          )
          .first,
    );

    expect(body().radius, HabitCard.radius);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Morning water')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-14, 0));
      await tester.pump();
    }

    expect(
      body().radius,
      HabitCard.radius,
      reason:
          'a card lifting away from its socket is still a card; squaring '
          'off the edge that moved inside the row reads as a slice',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
  });

  /// Distance alone used to decide whether a swipe had committed, and
  /// distance alone cannot tell a habit being logged from a page being
  /// thrown at the tab bar. The card's recogniser sits below the shell's
  /// and wins the arena by depth, so a flick meant as "next tab" that
  /// started on a card never reached the shell — it crossed the threshold
  /// on the way past and logged the habit instead.
  group('a page fling is not a log', () {
    testWidgets('flinging a card at page speed leaves the day alone', (
      tester,
    ) async {
      await openHome(tester);
      expect(loggedToday(tester, openHabit), isFalse);

      // Well past the distance threshold, and far too fast to be aimed.
      await tester.fling(find.text(openHabit), const Offset(220, 0), 1200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        loggedToday(tester, openHabit),
        isFalse,
        reason: 'a gesture quick enough to have been a page swipe must '
            'spring back rather than guess',
      );
    });

    testWidgets('a deliberate drag past the threshold still logs', (
      tester,
    ) async {
      await openHome(tester);
      expect(loggedToday(tester, openHabit), isFalse);

      await dragSlowly(tester, openHabit, 200);

      expect(
        loggedToday(tester, openHabit),
        isTrue,
        reason: 'the guard is on speed, not on distance — an aimed swipe '
            'that slows into the threshold is exactly the gesture that '
            'should commit',
      );
    });
  });

  /// The trailing side of a card reads the day rather than offering one
  /// fixed action. On an open day it freezes; on a day already logged it
  /// takes the log back, which is where an accidental swipe goes to die.
  group('the trailing side of a finished card undoes it', () {
    testWidgets('swiping a logged habit back clears the day', (tester) async {
      await openHome(tester);
      expect(loggedToday(tester, loggedHabit), isTrue);

      await dragSlowly(tester, loggedHabit, -200);

      expect(loggedToday(tester, loggedHabit), isFalse);
    });

    testWidgets('and it is neutral ink, not the freeze', (tester) async {
      await openHome(tester);

      // Held part way rather than released: a committed gesture springs the
      // card home before the frame can be read.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(loggedHabit)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(-14, 0));
        await tester.pump();
      }

      final background = tester.widget<SwipeLogBackground>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(loggedHabit),
                matching: find.byType(HabitCard),
              ),
              matching: find.byType(SwipeLogBackground),
            )
            .first,
      );
      expect(background.offset, lessThan(0));
      expect(
        background.undoing,
        isTrue,
        reason: 'frost means frozen and coral means destroyed; taking back '
            'a log today is neither, so it gets neutral ink',
      );

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
