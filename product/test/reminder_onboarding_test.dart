import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/reminders/reminder_platform.dart';

import 'support/flow.dart';

/// A phone that asks for all four, like Android 14.
NoReminderPlatform _phone({bool grant = true}) => NoReminderPlatform(
  permissionsAsked: ReminderPermission.values,
  grantOnRequest: grant,
);

/// Walks onboarding to "Let the tide find you".
Future<void> _reachPermissions(
  WidgetTester tester,
  NoReminderPlatform phone,
) async {
  await tester.pumpWidget(TideApp(reminders: phone));
  await settle(tester, 900);
  await tester.tap(find.text('Show me how'));
  await settle(tester);
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text('Next'));
    await settle(tester);
  }
}

void main() {
  testWidgets('one permission at a time, each with its reason', (tester) async {
    final phone = _phone();
    await _reachPermissions(tester, phone);

    expect(find.text('Let the tide find you'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('So we can nudge you before a habit.'), findsOneWidget);
    // Nothing is blocked: the footer skips until every card has an answer.
    expect(find.text('Skip for now'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(phone.requested, [ReminderPermission.notifications]);
    expect(find.text('Exact alarms'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('Full-screen alerts'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(find.text('3 of 4 · optional'), findsNothing);
    expect(find.text('4 of 4 · optional'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('everything granted is a full tide', (tester) async {
    await _reachPermissions(tester, _phone());

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Allow'));
      await settle(tester);
    }

    expect(find.text('Full tide'), findsOneWidget);
  });

  testWidgets('a refusal is answered kindly and never holds anything up', (
    tester,
  ) async {
    await _reachPermissions(tester, _phone(grant: false));

    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(
      find.text(
        'No problem. You can turn this on later in Settings → Reminders.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Exact alarms'), findsOneWidget);

    // The footer still goes on without another word.
    await tester.tap(find.text('Skip for now'));
    await settle(tester);
    expect(find.text('Get started'), findsOneWidget);
  });
}
