import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/app_constants.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/splash/splash_screen.dart';

/// The launch sequence plays once and gets out of the way.
///
/// Pumped in fixed steps: the mark's orbit and swell loop for as long as it
/// is on screen, so nothing here ever settles.
void main() {
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  /// The screen the splash hands off to staggers its own entrance in on
  /// delayed timers. A test that stops the moment that screen appears leaves
  /// them pending, which fails the test for a reason that has nothing to do
  /// with the splash — so every test lets the arrival finish.
  Future<void> letArrivalFinish(WidgetTester tester) =>
      pumpFor(tester, const Duration(milliseconds: 1200));

  testWidgets('the splash plays through and hands off to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const TideApp(showSplash: true));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Show me how'), findsNothing);

    await pumpFor(tester, const Duration(milliseconds: 1800));
    expect(find.text(AppConstants.tagline), findsOneWidget);

    // Intro, hold, exit and the route's fade, with room to spare.
    await pumpFor(tester, const Duration(milliseconds: 2400));
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Show me how'), findsOneWidget);

    await letArrivalFinish(tester);
  });

  testWidgets('a tap skips the rest of it', (tester) async {
    await tester.pumpWidget(const TideApp(showSplash: true));
    await pumpFor(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byType(SplashScreen));
    await pumpFor(tester, const Duration(milliseconds: 1200));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Show me how'), findsOneWidget);

    await letArrivalFinish(tester);
  });

  testWidgets('tests and deep links skip it entirely', (tester) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);

    await letArrivalFinish(tester);
  });
}
