import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tide/main.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/widgets/tide_button.dart';
import 'package:tide/widgets/tide_tab_bar.dart';

import 'support/flow.dart';

/// A device that has been through onboarding before, so the launch opens on
/// the account form. The in-memory account service already knows the demo
/// account and nobody else.
Future<void> openAccountForm(WidgetTester tester) async {
  await tester.pumpWidget(
    TideApp(flags: DeviceFlags.memory(onboardingSeen: true)),
  );
  await settle(tester, 900);
}

Future<void> fill(WidgetTester tester, List<String> values) async {
  final fields = find.byType(TextField);
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
  await tester.pump();
}

void main() {
  group('log in only reaches accounts that exist', () {
    testWidgets('an address with no account is told to create one', (
      tester,
    ) async {
      await openAccountForm(tester);
      await fill(tester, ['nobody@example.com', 'whatever1']);
      await pressAuthButton(tester, 'Log in');

      expect(find.text('No Tide account uses this email'), findsOneWidget);
      expect(
        find.text('There is no account for nobody@example.com yet.'),
        findsOneWidget,
      );
      expect(find.text('Welcome back'), findsOneWidget, reason: 'still here');

      // The notice's own action, not the switch pinned under the form: it
      // crosses to the other half and keeps the address that was typed.
      await tester.tap(find.text('Create one').first);
      await settle(tester);

      expect(find.text('Start your first loop'), findsOneWidget);
      expect(find.text('nobody@example.com'), findsOneWidget);
    });

    testWidgets('a wrong password is blamed on the password', (tester) async {
      await openAccountForm(tester);
      await fill(tester, [DemoAuthService.demoEmail, 'not-the-one']);
      await pressAuthButton(tester, 'Log in');

      expect(find.text('That password is not right'), findsOneWidget);
      expect(find.text('No Tide account uses this email'), findsNothing);
    });

    testWidgets('a returning account is welcomed back by name', (
      tester,
    ) async {
      await openAccountForm(tester);
      await fill(tester, [
        DemoAuthService.demoEmail,
        DemoAuthService.demoPassword,
      ]);
      await pressAuthButton(tester, 'Log in');

      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Jules'), findsOneWidget);

      await crossWelcome(tester);

      expect(find.text('Morning water'), findsOneWidget);
      expect(
        find.text('This is Today'),
        findsNothing,
        reason: 'the tour belongs to the first sign-in only',
      );
    });
  });

  group('create only makes accounts that do not exist', () {
    testWidgets('an address that already has an account is sent to log in', (
      tester,
    ) async {
      await openAccountForm(tester);
      await tester.tap(find.text('Create one'));
      await settle(tester);

      await fill(tester, ['Jules', DemoAuthService.demoEmail, 'seawater88']);
      await pressAuthButton(tester, 'Create account');

      expect(find.text('This email already has an account'), findsOneWidget);
      expect(
        find.text('You already have a Tide account with jules@tide.app.'),
        findsOneWidget,
      );
    });

    testWidgets('a new account is greeted by its first name', (tester) async {
      await openAccountForm(tester);
      await tester.tap(find.text('Create one'));
      await settle(tester);

      await fill(tester, ['Sam Reyes', 'sam@example.com', 'seawater88']);
      await pressAuthButton(tester, 'Create account');

      expect(
        find.text('Check your email'),
        findsOneWidget,
        reason: 'nothing opens until the code is in',
      );
      await enterEmailCode(tester);

      expect(find.text('Welcome,'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);

      await crossWelcome(tester);
      expect(find.text('No habits yet'), findsOneWidget);
    });
  });

  group('onboarding happens once per device', () {
    testWidgets('a later launch opens on the form, with no way back into it', (
      tester,
    ) async {
      await openAccountForm(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Show me how'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    test('what the device remembers survives a restart', () async {
      SharedPreferences.setMockInitialValues({});

      final first = await DeviceFlags.load();
      expect(first.onboardingSeen, isFalse);
      first
        ..markOnboardingSeen()
        ..markTourDone('account-1');
      await Future<void>.delayed(Duration.zero);

      final second = await DeviceFlags.load();
      expect(second.onboardingSeen, isTrue);
      expect(second.tourDone('account-1'), isTrue);
      expect(second.tourDone('account-2'), isFalse);
    });
  });

  group('logging out', () {
    testWidgets('holding the button returns to the account form', (
      tester,
    ) async {
      await tester.pumpWidget(const TideApp(startOnboarded: true));
      await settle(tester, 900);

      final hold = find.text('Hold to log out');
      await scrollSettingsTo(tester, hold);

      // A tap does nothing; only a hold that fills the button commits.
      await tester.tap(hold);
      await settle(tester, 300);
      expect(find.text('Hold to log out'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(hold));
      await pumpFor(tester, const Duration(milliseconds: 1600));
      await gesture.up();
      await settle(tester, 900);

      expect(find.widgetWithText(TideButton, 'Log in'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('deleting the account', () {
    testWidgets('asks, needs a hold, and the account is gone after', (
      tester,
    ) async {
      await tester.pumpWidget(const TideApp(startOnboarded: true));
      await settle(tester, 900);

      final row = find.text('Delete account');
      await scrollSettingsTo(tester, row);

      // The row only asks; backing out of the panel keeps everything.
      await tester.tap(row);
      await settle(tester, 400);
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.text('Keep my account'));
      await settle(tester, 400);
      expect(find.text('Delete your account?'), findsNothing);

      await tester.tap(row);
      await settle(tester, 400);

      // A tap on the panel's button is not a hold.
      final hold = find.text('Hold to delete account');
      await tester.tap(hold);
      await settle(tester, 300);
      expect(find.text('Delete your account?'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(hold));
      await pumpFor(tester, const Duration(milliseconds: 1600));
      await gesture.up();
      await pumpFor(tester, const Duration(milliseconds: 2400));

      // The farewell, not the form — and it stays until Done.
      expect(find.text('Delete your account?'), findsNothing);
      expect(find.text('Account deleted'), findsOneWidget);
      expect(
        find.text(
          'The Tide account for ${DemoAuthService.demoEmail} has been '
          'deleted successfully.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await pumpFor(tester, const Duration(milliseconds: 2000));
      expect(find.widgetWithText(TideButton, 'Log in'), findsNothing);

      await tester.tap(find.widgetWithText(TideButton, 'Done'));
      await settle(tester, 900);

      expect(find.text('Account deleted'), findsNothing);
      expect(find.widgetWithText(TideButton, 'Log in'), findsOneWidget);

      // Deleted, not merely signed out: the address no longer logs in.
      await fill(tester, [
        DemoAuthService.demoEmail,
        DemoAuthService.demoPassword,
      ]);
      await pressAuthButton(tester, 'Log in');
      expect(find.text('No Tide account uses this email'), findsOneWidget);
    });
  });
}

/// Opens Settings from the tab bar and scrolls [target] into view.
Future<void> scrollSettingsTo(WidgetTester tester, Finder target) async {
  await tester.tap(
    find.descendant(
      of: find.byType(TideTabBar),
      matching: find.text('Settings'),
    ),
  );
  await settle(tester);

  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find
        .ancestor(
          of: find.text('Your account, and how Tide behaves.'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await settle(tester, 300);
}
