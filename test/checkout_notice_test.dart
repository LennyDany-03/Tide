import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/screens/upgrade/widgets/checkout_notice.dart';
import 'package:tide/services/billing/billing_service.dart';
import 'package:tide/theme/tide_theme.dart';

/// Every outcome a payment can have gets a sentence somebody wrote.
///
/// This exists because of a bug that shipped, twice over. Auto-pay added two
/// [BillingProblem] values — [BillingProblem.alreadySubscribed] and
/// [BillingProblem.resubscribeNeeded] — and nothing made the notice grow a case
/// for either: a `switch` used as an expression with a `_` fallback compiles
/// perfectly happily, and the two new outcomes silently fell through to "The
/// payment did not go through. Nothing was charged," which is wrong about both.
/// One of them means the person *already has* what they are buying.
///
/// The related half of the same bug is in `SupabaseBillingService._translate`,
/// which used to pass `error.reasonPhrase` through as the failure's detail —
/// so a function that was not deployed put the bare words "Not Found" under a
/// dialog about cancelling a subscription. That one is fixed at the source,
/// where the detail is written, rather than here where it is drawn: the notice
/// *should* pass a detail through when there is one, because Razorpay's own
/// wording for a declined card is better than anything this app would write.
void main() {
  /// The two that legitimately use the fallback, and the reason each does.
  ///
  ///   - [BillingProblem.declined] is where a real gateway description lands,
  ///     and the fallback covers the case where one did not arrive.
  ///   - [BillingProblem.unknown] is the bucket for everything unforeseen; a
  ///     specific sentence for it would be a lie.
  const usesFallback = {BillingProblem.declined, BillingProblem.unknown};

  /// Never drawn at all: closing a payment sheet is a decision, not an error.
  const neverDrawn = {BillingProblem.cancelled};

  const fallback = 'The payment did not go through. Nothing was charged.';

  Future<String> render(WidgetTester tester, BillingFailure failure) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TideTheme.current,
        home: Scaffold(body: CheckoutNotice(failure: failure)),
      ),
    );
    // The notice rises in over sheetIn rather than appearing between two
    // frames, so it needs pumping before its text is laid out.
    await tester.pump(const Duration(milliseconds: 500));
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('every outcome has words of its own', (tester) async {
    for (final problem in BillingProblem.values) {
      if (neverDrawn.contains(problem) || usesFallback.contains(problem)) {
        continue;
      }
      // No detail, so nothing can stand in for a missing case.
      final drawn = await render(tester, BillingFailure(problem));
      expect(
        drawn,
        isNot(fallback),
        reason:
            '${problem.name} has no case in CheckoutNotice and fell through to '
            'the generic line. Add one: a switch with a default cannot fail to '
            'compile when the enum grows, which is exactly why this test is '
            'here.',
      );
      expect(drawn.trim(), isNotEmpty, reason: problem.name);
    }
  });

  testWidgets('a gateway description is preferred where there is one', (
    tester,
  ) async {
    // The other half of the contract. Razorpay's sentence for a declined card
    // is better than anything written here, so a declined payment must still
    // show it rather than a house line.
    const detail = 'Your card was declined because of insufficient funds.';
    expect(
      await render(
        tester,
        const BillingFailure(BillingProblem.declined, detail),
      ),
      detail,
    );
  });

  testWidgets('waiting is never drawn as a failure', (tester) async {
    // The one outcome where the money *has* moved. Anything that reads as a
    // decline here teaches people that paying twice is how you fix it.
    final drawn = await render(
      tester,
      const BillingFailure(BillingProblem.pending),
    );
    expect(drawn, contains('do not need to pay again'));
  });
}
