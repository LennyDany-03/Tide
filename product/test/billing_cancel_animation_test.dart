import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/screens/billing/billing_screen.dart';
import 'package:tide/screens/billing/widgets/cancelled_notice.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/tide_scope.dart';
import 'package:tide/services/tide_store.dart';
import 'package:tide/theme/tide_motion.dart';
import 'package:tide/theme/tide_theme.dart';

/// The billing card's one pass: cancelling opens the note, resuming closes it.
///
/// Two properties, and the second one is the reason this file exists.
///
/// The pass only plays on a *change* — the card's controller starts settled,
/// so arriving on a plan cancelled last month draws it as a fact rather than
/// as news.
///
/// And **not one frame of it moves while the dialog is still up.** The first
/// version of this animation was, by the numbers, perfect: it ran, it eased,
/// it finished — entirely behind the cancel dialog's scrim, 100ms before that
/// scrim cleared. Nobody could ever have seen it. An animation is only real
/// if it is on screen while it happens, so the last group here holds the pass
/// against the thing that covers it.
void main() {
  TideStore pro() => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
    billing: DemoBillingService.pro(),
  );

  /// The screen alone, not the whole app: it is reached from Settings, which
  /// is not what any of this is about.
  Future<void> show(WidgetTester tester, TideStore store) async {
    await tester.pumpWidget(
      TideScope(
        store: store,
        child: MaterialApp(
          theme: TideTheme.current,
          home: const BillingScreen(),
        ),
      ),
    );
    // Fixed pumps, never pumpAndSettle: the backdrop behind this screen
    // drifts on an ambient loop that by design never settles.
    await tester.pump(const Duration(milliseconds: 400));
  }

  double noticeHeight(WidgetTester tester) {
    final notice = find.byType(CancelledNotice);
    if (notice.evaluate().isEmpty) return 0;
    return tester.getSize(notice).height;
  }

  group('the pass', () {
    testWidgets('opens the note over time, not in one frame', (tester) async {
      final store = pro();
      await show(tester, store);

      expect(find.text('Cancel Pro'), findsOneWidget);
      expect(noticeHeight(tester), 0);

      await store.cancelPlan();
      await tester.pump();

      // Still nothing: this is the lead-in, where the dialog is leaving.
      await tester.pump(TideMotion.planChangeLeadIn - _aFrame);
      expect(
        noticeHeight(tester),
        0,
        reason: 'the note must not start before the lead-in is over',
      );

      await tester.pump(const Duration(milliseconds: 80));
      final early = noticeHeight(tester);
      expect(early, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 100));
      final later = noticeHeight(tester);
      expect(later, greaterThan(early));

      await tester.pump(TideMotion.planChange);
      expect(noticeHeight(tester), greaterThan(later));

      // And it ends with the action swapped, in the slot Cancel held.
      expect(find.text('Cancel Pro'), findsNothing);
      expect(find.text('Resume Pro'), findsOneWidget);
    });

    testWidgets('resuming runs it backwards, with no lead-in', (tester) async {
      final store = pro();
      await store.cancelPlan();
      await show(tester, store);

      // Arrived on a cancelled plan: settled, with nothing to watch.
      final settled = noticeHeight(tester);
      expect(settled, greaterThan(0));
      await tester.pump(TideMotion.planChange);
      expect(noticeHeight(tester), settled);

      // Nothing is covering the card here — the tap was on the card itself —
      // so the close starts immediately, and in the reverse order: the words
      // fade out first, then the block collapses under them. Sampled past
      // that first beat, where the height has actually begun to move.
      await store.resumePlan();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(noticeHeight(tester), lessThan(settled));

      await tester.pump(TideMotion.planChangeBack);
      expect(noticeHeight(tester), 0);
      expect(find.text('Cancel Pro'), findsOneWidget);
    });
  });

  group('through the dialog that asks', () {
    testWidgets('the note stays still until the scrim has gone', (
      tester,
    ) async {
      final store = pro();
      await show(tester, store);

      await tester.tap(find.text('Cancel Pro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hold to cancel'), findsOneWidget);

      final hold = await tester.startGesture(
        tester.getCenter(find.text('Hold to cancel')),
      );

      // Sampled every frame from the hold to well past the end of the pass,
      // watching for the one thing that must never happen: the note moving
      // while the dialog is on top of it.
      var movedUnderTheDialog = false;
      var movedInTheOpen = false;
      var sawTheDialogGo = false;

      for (var i = 0; i < 60; i++) {
        final before = noticeHeight(tester);
        await tester.pump(const Duration(milliseconds: 50));
        final after = noticeHeight(tester);
        final dialogUp = find.byType(PopScope).evaluate().isNotEmpty;
        sawTheDialogGo |= !dialogUp;

        if (after != before) {
          if (dialogUp) {
            movedUnderTheDialog = true;
          } else {
            movedInTheOpen = true;
          }
        }
      }
      await hold.up();
      await tester.pump(const Duration(milliseconds: 400));

      expect(sawTheDialogGo, isTrue, reason: 'the hold never committed');
      expect(
        movedUnderTheDialog,
        isFalse,
        reason: 'the pass played behind the scrim, where nobody can see it',
      );
      expect(
        movedInTheOpen,
        isTrue,
        reason: 'the note never animated on a clear screen',
      );
      expect(noticeHeight(tester), greaterThan(0));
      expect(find.text('Resume Pro'), findsOneWidget);
    });
  });
}

/// One 60fps frame, give or take. Used to sample *just* inside the lead-in
/// rather than exactly on its boundary, where a rounding difference would
/// decide the assertion.
const _aFrame = Duration(milliseconds: 20);
