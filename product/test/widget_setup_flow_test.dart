import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/device_flags.dart';

/// Launches the app the way a cold widget tap does — the URI comes in on
/// [TideApp.launchUri] — and verifies the whole errand: the picker opens,
/// lists every habit, and choosing one ties that widget to the habit.
void main() {
  Future<void> openPicker(WidgetTester tester, DeviceFlags flags) async {
    await tester.pumpWidget(
      TideApp(
        startOnboarded: true,
        flags: flags,
        launchUri: Uri.parse('tide://widget/setup?id=7&kind=streak'),
      ),
    );
    // The launch is handled in a post-frame callback, and the picker is
    // pushed in a second one — three frames for go() + push + page build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a widget setup tap opens the picker listing every habit', (
    tester,
  ) async {
    await openPicker(tester, DeviceFlags.memory(onboardingSeen: true));

    expect(find.text('Choose a habit'), findsOneWidget);
    expect(find.text('Morning water'), findsOneWidget);
    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('Move 30 min'), findsOneWidget);
    expect(find.text('No screens after 10'), findsOneWidget);
  });

  testWidgets('choosing a habit assigns that widget and closes the picker', (
    tester,
  ) async {
    final flags = DeviceFlags.memory(onboardingSeen: true);
    await openPicker(tester, flags);

    await tester.tap(find.text('Morning water'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(flags.widgetHabits[7], 'morning-water');
    expect(find.text('Choose a habit'), findsNothing);
  });
}