import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/home/widgets/habit_card.dart';
import 'package:tide/theme/tide_colors.dart';
import 'package:tide/widgets/swipe_log_background.dart';
import 'package:tide/widgets/tide_surface.dart';

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
}
