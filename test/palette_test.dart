import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/screens/settings/settings_screen.dart';
import 'package:tide/theme/tide_colors.dart';
import 'package:tide/theme/tide_palette.dart';
import 'package:tide/widgets/tide_tab_bar.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every palette fills the same roles, so every palette is held to the same
/// floors. A new palette that looks right on the swatch but puts muted text
/// below legibility on its own page fails here rather than on a phone.
void main() {
  for (final palette in TidePalettes.all) {
    group(palette.name, () {
      test('primary ink reads on the page and on a card', () {
        expect(contrast(palette.bone, palette.deepWater), greaterThan(7));
        expect(contrast(palette.bone, palette.shelf), greaterThan(7));
      });

      test('muted ink reads on the page', () {
        expect(contrast(palette.silt, palette.deepWater), greaterThan(4));
      });

      test('the accent stands off the page', () {
        expect(contrast(palette.lantern, palette.deepWater), greaterThan(3));
      });

      test('ink on the accent is legible', () {
        expect(contrast(palette.onLantern, palette.lantern), greaterThan(4.5));
      });

      test('a recess is darker than the page it is cut into', () {
        expect(
          palette.trench.computeLuminance(),
          lessThan(palette.deepWater.computeLuminance()),
        );
      });
    });
  }

  test('a fresh app opens in Midnight', () {
    expect(TidePalettes.standard, same(TidePalettes.midnight));
    expect(TidePalettes.all.first, same(TidePalettes.standard));
    expect(TidePalettes.byId('no-such-palette'), same(TidePalettes.standard));
  });

  testWidgets('the app boots with the default palette applied', (tester) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    await tester.pump(const Duration(milliseconds: 900));

    expect(TideColors.palette, same(TidePalettes.standard));
    expect(TideColors.lantern, TidePalettes.midnight.lantern);
  });

  test('palette ids are unique', () {
    final ids = TidePalettes.all.map((p) => p.id).toSet();
    expect(ids.length, TidePalettes.all.length);
  });

  testWidgets('choosing a palette in Settings switches the app to it', (
    tester,
  ) async {
    // Wider than the other shell tests. The test font draws every glyph as a
    // full-width square, which pushes the account card's upgrade label past
    // a phone-width row; real type fits, so the viewport makes room rather
    // than the card being bent around a test artefact.
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(() => TideColors.use(TidePalettes.standard));

    // Signed in as somebody who has paid. Midnight is the only palette on the
    // free plan, so a free account tapping Paper opens the paywall instead of
    // repainting the app — and this test is about the repaint.
    await tester.pumpWidget(
      TideApp(startOnboarded: true, billing: DemoBillingService.pro()),
    );
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));

    await tester.tap(
      find.descendant(
        of: find.byType(TideTabBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Clear of the frosted tab bar before tapping the row.
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Appearance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final paper = find.text('White paper, black ink');
    expect(paper, findsOneWidget);
    await tester.ensureVisible(paper);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(paper);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(TideColors.palette, same(TidePalettes.paper));
    expect(TideColors.deepWater, TidePalettes.paper.deepWater);
  });
}
