import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/home/widgets/habit_card.dart';
import 'package:tide/widgets/tide_tab_bar.dart';

/// The tab bar is the shell's own readout of which branch is selected, so
/// reading it is the same as asking the shell.
int selectedTab(WidgetTester tester) =>
    tester.widget<TideTabBar>(find.byType(TideTabBar)).currentIndex;

/// Every tab body, in branch order: how visible it is, and how far across
/// the screen it sits.
///
/// The shell's `_Branch` is the only thing in the app that uses
/// `AnimatedSlide`, so there is exactly one per branch — with its own
/// `Transform` and the `FadeTransition` that `AnimatedOpacity` builds
/// sitting directly above it.
List<({double opacity, double dx})> branchStates(WidgetTester tester) {
  final slides = find.byType(AnimatedSlide);

  double nearest<T extends Widget>(int i, double Function(T) read) {
    final finder = find
        .ancestor(of: slides.at(i), matching: find.byType(T))
        .first;
    return read(tester.widget<T>(finder));
  }

  return [
    for (var i = 0; i < slides.evaluate().length; i++)
      (
        opacity: nearest<FadeTransition>(i, (w) => w.opacity.value),
        dx: nearest<Transform>(i, (w) => w.transform.getTranslation().x),
      ),
  ];
}

/// Starts the drag high on the page, clear of the habit rows — those carry
/// their own horizontal gesture, which the conflict test below covers
/// deliberately rather than by accident.
Future<void> swipePage(WidgetTester tester, double dx) async {
  await tester.flingFrom(const Offset(400, 120), Offset(dx, 0), 900);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  Future<void> openShell(WidgetTester tester) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('swiping left walks forward through the tabs', (tester) async {
    await openShell(tester);
    expect(selectedTab(tester), 0);

    for (final expected in [1, 2, 3]) {
      await swipePage(tester, -320);
      expect(selectedTab(tester), expected);
    }

    // Landing on a tab arms its entrance staggers; let them run out so the
    // test does not end with timers still pending.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('swiping right walks back through the tabs', (tester) async {
    await openShell(tester);
    for (var i = 0; i < 3; i++) {
      await swipePage(tester, -320);
    }
    expect(selectedTab(tester), 3);

    for (final expected in [2, 1, 0]) {
      await swipePage(tester, 320);
      expect(selectedTab(tester), expected);
    }
  });

  testWidgets('the ends of the row hold', (tester) async {
    await openShell(tester);

    // Nothing sits before Today...
    await swipePage(tester, 320);
    expect(selectedTab(tester), 0);

    for (var i = 0; i < 3; i++) {
      await swipePage(tester, -320);
    }
    // ...or after Settings.
    await swipePage(tester, -320);
    expect(selectedTab(tester), 3);
  });

  testWidgets('a short drag springs back instead of changing tab', (
    tester,
  ) async {
    await openShell(tester);

    // Well under the commit threshold, and slow enough not to read as a
    // fling — the page should give and come back.
    await tester.dragFrom(const Offset(400, 120), const Offset(-40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedTab(tester), 0);
  });

  testWidgets('the tab left behind never lands on top of the one you reach', (
    tester,
  ) async {
    await openShell(tester);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    await tester.flingFrom(const Offset(400, 120), const Offset(-320, 0), 900);

    // Frame by frame through the settle and well past the point the page
    // comes to rest. Two tabs painted at once is normal mid-swipe — they are
    // side by side — but the moment they are painted at the same offset, one
    // is sitting on top of the other, which is the ghost of the tab you just
    // left showing through the one you arrived at.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));

      final lit = branchStates(tester).where((b) => b.opacity > 0).toList();
      expect(lit, hasLength(lessThanOrEqualTo(2)));

      if (lit.length == 2) {
        expect(
          (lit.first.dx - lit.last.dx).abs(),
          moreOrLessEquals(width, epsilon: 0.5),
          reason: 'two tabs are painted at once but not side by side',
        );
      }
    }

    expect(selectedTab(tester), 1);
    expect(
      branchStates(tester).where((b) => b.opacity > 0).length,
      1,
      reason: 'the page came to rest with more than one tab painted',
    );
  });

  testWidgets('a habit row keeps its own swipe', (tester) async {
    await openShell(tester);

    // The first row rather than the last. On a short viewport the bottom
    // card sits under the frosted tab bar, so this flung the bar itself and
    // passed for the wrong reason: the tab was never going to move because
    // nothing ever reached the shell *or* the card.
    //
    // The row's swipe recogniser sits deeper than the shell's, so it wins
    // the arena and the tab does not move underneath it.
    await tester.fling(find.text('Morning water'), const Offset(-320, 0), 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedTab(tester), 0);
  });

  testWidgets('the edge lane pages even with a habit row under it', (
    tester,
  ) async {
    await openShell(tester);

    // Six pixels inside the card's own right edge, so the gesture starts on
    // a habit rather than in the page margin either side of the list — that
    // margin was always clear, and starting there would prove nothing.
    //
    // The lane is last in the shell's stack, and a stack is hit-tested
    // topmost-first, so its recogniser is entered into the arena before the
    // card's and takes the gesture instead of losing it on depth.
    final card = tester.getRect(find.byType(HabitCard).first);
    await tester.flingFrom(
      Offset(card.right - 6, card.center.dy),
      const Offset(-320, 0),
      900,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedTab(tester), 1);
  });
}
