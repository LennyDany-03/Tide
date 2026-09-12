import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/widgets/tide_button.dart';

import 'support/flow.dart';

/// A device past onboarding, filling in sign-up and pressing Create account,
/// which lands on the code screen.
Future<void> startSignUp(WidgetTester tester) async {
  await tester.pumpWidget(
    TideApp(flags: DeviceFlags.memory(onboardingSeen: true)),
  );
  await settle(tester, 900);
  await tester.tap(find.text('Create one'));
  await settle(tester);

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Sam Reyes');
  await tester.enterText(fields.at(1), 'sam@example.com');
  await tester.enterText(fields.at(2), 'seawater88');
  await tester.pump();
  await pressAuthButton(tester, 'Create account');
}

String codeTyped(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('creating an account asks for the code sent to the address', (
    tester,
  ) async {
    await startSignUp(tester);

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('sam@example.com'), findsOneWidget);
    expect(find.text('Welcome,'), findsNothing, reason: 'not signed in yet');
  });

  testWidgets('a wrong code is refused, said so, and cleared', (tester) async {
    await startSignUp(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await settle(tester);

    expect(find.text('That code is wrong or has expired'), findsOneWidget);
    expect(codeTyped(tester), isEmpty, reason: 'ready for another try');
    expect(find.text('Check your email'), findsOneWidget);
  });

  testWidgets('the last digit submits, ticks, then welcomes the account', (
    tester,
  ) async {
    await startSignUp(tester);

    // No button: the sixth digit is the submit.
    expect(find.byType(TideButton), findsNothing);
    await tester.enterText(find.byType(TextField), DemoAuthService.demoCode);
    await pumpFor(tester, const Duration(milliseconds: 600));

    expect(find.text('Email confirmed'), findsOneWidget);
    expect(find.text('Welcome,'), findsNothing, reason: 'the tick plays first');

    await pumpFor(tester, const Duration(milliseconds: 1800));
    expect(find.text('Welcome,'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await crossWelcome(tester);
    expect(find.text('No habits yet'), findsOneWidget);
  });

  testWidgets('another code waits out the cooldown', (tester) async {
    await startSignUp(tester);

    expect(find.text('Resend code'), findsNothing);
    expect(find.text('Resend in '), findsOneWidget);

    for (var i = 0; i < 61; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('Resend code'));
    await settle(tester);

    expect(find.text('A new code is on its way.'), findsOneWidget);
    expect(find.text('Resend in '), findsOneWidget, reason: 'locked again');
  });

  testWidgets('going back returns to sign-up with the address kept', (
    tester,
  ) async {
    await startSignUp(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(tester, 900);

    expect(find.text('Start your first loop'), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);
  });

  testWidgets('logging in to an unconfirmed account offers the code screen', (
    tester,
  ) async {
    await startSignUp(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(tester, 900);

    await tester.tap(find.text('Log in'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), 'seawater88');
    await tester.pump();
    await pressAuthButton(tester, 'Log in');

    expect(find.text('Enter code'), findsOneWidget);

    await tester.tap(find.text('Enter code'));
    await settle(tester, 900);

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('A new code is on its way.'), findsOneWidget);
  });

  testWidgets('closing the app mid-sign-up reopens on the code screen', (
    tester,
  ) async {
    final auth = DemoAuthService();
    await auth.createAccount(
      name: 'Sam Reyes',
      email: 'sam@example.com',
      password: 'seawater88',
    );

    await tester.pumpWidget(
      TideApp(
        auth: auth,
        flags: DeviceFlags.memory(
          onboardingSeen: true,
          pendingVerification: 'sam@example.com',
        ),
      ),
    );
    await settle(tester, 900);

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text('Resend code'),
      findsOneWidget,
      reason: 'nothing was sent on this launch, so there is nothing to wait out',
    );

    await enterEmailCode(tester);
    expect(find.text('Welcome,'), findsOneWidget);
    await crossWelcome(tester);
  });
}
