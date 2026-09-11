import 'package:flutter_test/flutter_test.dart';
import 'package:tide/widgets/tide_button.dart';

/// Fixed pumps throughout rather than `pumpAndSettle`: onboarding runs a
/// drifting backdrop, an orbiting mark and three looping demos, and the
/// tour breathes a ring around its spotlight. None of them ever settle, by
/// design.
Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  // A timed pump advances the clock in one jump, so anything built during
  // that frame — a page arriving under the scroll, a step's staggered copy —
  // schedules its entrance timer relative to the clock *after* the jump. One
  // more pump flushes those, which is also what stops them being reported as
  // pending timers when the tree is torn down. Long enough to clear the
  // slowest of them: the welcome copy, which waits out the ring at 760ms.
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Pumps in small steps, for sequences that chain an animation into a timer
/// into a route change — the welcome — where one long jump would land on
/// the first link and leave the rest unstarted.
Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// Presses one of the account form's buttons, scrolling it into view first.
/// The form is longer than a short window, and the mode switch is pinned
/// across the bottom of it.
Future<void> pressAuthButton(WidgetTester tester, String label) async {
  final target = find.widgetWithText(TideButton, label);
  await tester.ensureVisible(target);
  await settle(tester, 200);
  await tester.tap(target);
  await settle(tester);
}

/// Waits out the welcome — its entrance, its hold and the fade to Today —
/// and lets Today's own entrance finish.
Future<void> crossWelcome(WidgetTester tester) async {
  await pumpFor(tester, const Duration(milliseconds: 3200));
  await settle(tester, 500);
}
