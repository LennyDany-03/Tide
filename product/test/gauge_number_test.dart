import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/theme/tide_typography.dart';
import 'package:tide/widgets/gauge_number.dart';

/// Guards the two ways a gauge has previously disturbed the card it sits in.
///
/// Both were animation faults rather than layout faults, so they only showed
/// up on the frames between the start and the settled value — which is
/// exactly what these tests sample.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 160, child: child)),
    ),
  );

  testWidgets('a counting gauge never stacks two glyphs in one column', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(GaugeCountUp(value: 87, style: TideType.gaugeStat(), suffix: '%')),
    );

    for (var frame = 0; frame < 14; frame++) {
      await tester.pump(const Duration(milliseconds: 80));
      // The readout plus the suffix, and nothing else. A second copy of the
      // digits — a wheel's outgoing drum sliding or fading against the
      // incoming one — renders as a doubled glyph at gauge sizes.
      expect(
        find.byType(Text),
        findsNWidgets(2),
        reason: 'frame $frame drew more than the readout and its suffix',
      );
    }
  });

  testWidgets('a counting gauge holds one width for the whole climb', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(GaugeCountUp(value: 100, style: TideType.gaugeStat(), suffix: '%')),
    );
    await tester.pump(const Duration(milliseconds: 40));

    final first = tester
        .renderObject<RenderBox>(find.byType(GaugeCountUp))
        .size
        .width;

    for (var frame = 0; frame < 14; frame++) {
      await tester.pump(const Duration(milliseconds: 80));
      final width = tester
          .renderObject<RenderBox>(find.byType(GaugeCountUp))
          .size
          .width;
      // A readout that grows a column part-way through re-lays-out its row,
      // which moves the caption under it and re-fits any parent scaler.
      expect(width, first, reason: 'frame $frame reflowed the row mid-count');
    }
  });

  testWidgets('a place the climb has not reached holds a blank, not a zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(GaugeCountUp(value: 100, style: TideType.gaugeStat())),
    );

    final seen = <String>[];
    for (var frame = 0; frame < 16; frame++) {
      await tester.pump(const Duration(milliseconds: 70));
      seen.add(tester.widget<Text>(find.byType(Text)).data!);
    }

    for (final text in seen) {
      final trimmed = text.trimLeft();
      // "0" on its own is the honest reading at the start of the climb.
      // "084" is not — that is a padded column pretending to be a figure.
      expect(
        trimmed.length > 1 && trimmed.startsWith('0'),
        isFalse,
        reason: 'a rate climbing to 100 read "$trimmed" on the way',
      );
    }

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Text>(find.byType(Text)).data, '100');
  });

  testWidgets('a gauge lays its suffix out like a plain baseline Row does', (
    tester,
  ) async {
    // A Row using CrossAxisAlignment.baseline silently falls back to
    // top-aligning any child that reports no baseline. When the readout was
    // a stack of clipped boxes it reported none, which floated the % up by
    // the cap height instead of sitting it on the digits' baseline.
    //
    // Checked against a hand-built Row of two real text runs rather than
    // against numbers, so the expectation holds whatever font metrics the
    // host happens to have.
    final numberStyle = TideType.gaugeStat();
    final suffixStyle = TideType.gauge(
      numberStyle.fontSize! * 0.45,
      color: numberStyle.color!,
    );

    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GaugeCountUp(value: 42, style: numberStyle, suffix: '%'),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('42', style: numberStyle),
                Text('%', style: suffixStyle),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gaugeDrop =
        tester.getRect(find.text('%').first).top -
        tester.getRect(find.text('42').first).top;
    final referenceDrop =
        tester.getRect(find.text('%').last).top -
        tester.getRect(find.text('42').last).top;

    expect(gaugeDrop, greaterThan(1), reason: 'the suffix was top-aligned');
    expect(gaugeDrop, closeTo(referenceDrop, 0.5));
  });
}
