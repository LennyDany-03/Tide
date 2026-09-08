import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/milestone_catalog.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/achievements/widgets/milestone_route.dart';

/// The route is a walked path rather than a ruled ladder, and "messy" is a
/// claim with three testable parts: the badges do not sit in two fixed
/// columns, they do not strictly alternate sides, and none of them wanders
/// so far in that it lands where its own caption has to go.
void main() {
  const width = 366.0;

  List<double> columns(int count) => [
    for (var i = 0; i < count; i++) MilestoneRoute.columnAt(i, width),
  ];

  group('the lanes wander', () {
    test('no two markers in a row stand in the same place', () {
      final xs = columns(MilestoneCatalog.all.length);
      for (var i = 1; i < xs.length; i++) {
        expect(
          (xs[i] - xs[i - 1]).abs(),
          greaterThan(1),
          reason: 'markers $i and ${i - 1} are stacked on each other',
        );
      }
    });

    test('the badges do not sit in two fixed columns', () {
      // The old route had exactly two distinct x positions all the way
      // down, which is the ladder this replaced.
      final distinct = columns(MilestoneCatalog.all.length)
          .map((x) => x.round())
          .toSet();
      expect(distinct, hasLength(greaterThan(8)));
    });

    test('the sides do not strictly alternate', () {
      // At least one pair has to run the same way twice, or the route is a
      // zigzag with a fixed period again — just a wobblier one.
      final sides = [
        for (var i = 0; i < MilestoneCatalog.all.length; i++)
          MilestoneRoute.onLeftAt(i),
      ];
      final runs = [
        for (var i = 1; i < sides.length; i++)
          if (sides[i] == sides[i - 1]) i,
      ];
      expect(runs, isNotEmpty);
    });

    test('no badge reaches the middle, where its caption has to go', () {
      const clear = MilestoneRoute.discSize / 2 + MilestoneRoute.labelGap;
      for (var i = 0; i < MilestoneCatalog.all.length; i++) {
        final x = MilestoneRoute.columnAt(i, width);
        // Whichever side it is on, the other side must still hold a caption
        // block of some usable width.
        final free = MilestoneRoute.onLeftAt(i)
            ? width - (x + clear) - MilestoneRoute.edge
            : (x - clear) - MilestoneRoute.edge;
        expect(
          free,
          greaterThan(100),
          reason: 'marker $i leaves only ${free.round()}px for its caption',
        );
      }
    });

    test('a badge always stays inside the page', () {
      for (var i = 0; i < MilestoneCatalog.all.length; i++) {
        final x = MilestoneRoute.columnAt(i, width);
        expect(x - MilestoneRoute.discSize / 2, greaterThanOrEqualTo(0));
        expect(x + MilestoneRoute.discSize / 2, lessThanOrEqualTo(width));
      }
    });
  });

  testWidgets('the whole catalogue lays out without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design — the streak
    // fire on the card being tapped here is one of them.
    await tester.pump(const Duration(milliseconds: 900));

    await tester.tap(find.text('day streak'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.byType(MilestoneRoute), findsOneWidget);
    // The first rung and one well down the list, so the assertion covers a
    // marker whose lane is deep rather than only the ones near an edge.
    expect(find.text('First tide'), findsOneWidget);
    expect(find.text('Full moon'), findsOneWidget);

    // A caption that has been squeezed to nothing does not throw — it
    // ellipsises silently — so measure one rather than trusting the layout
    // to complain.
    expect(tester.getSize(find.text('First tide')).width, greaterThan(40));
  });
}
