import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/milestone_art.dart';
import 'package:tide/config/milestone_catalog.dart';
import 'package:tide/screens/achievements/widgets/milestone_card.dart';
import 'package:tide/screens/achievements/widgets/share_card_view.dart';
import 'package:tide/services/share/card_share.dart';
import 'package:tide/theme/tide_colors.dart';
import 'package:tide/theme/tide_palette.dart';

/// Records what the sheet hands over instead of opening another app.
class _FakeShare extends CardShare {
  _FakeShare(this.available) : folder = Directory.systemTemp.createTempSync();

  final Set<ShareTarget> available;
  final Directory folder;
  final sent = <(ShareTarget, File, String?)>[];

  @override
  Future<Set<ShareTarget>> targets() async => available;

  @override
  Future<Directory> directory() async => folder;

  @override
  Future<bool> send(ShareTarget target, File image, {String? caption}) async {
    sent.add((target, image, caption));
    return true;
  }
}

void main() {
  final oneWeek = MilestoneCatalog.all.firstWhere((m) => m.id == 'one-week');

  test('every milestone has a scene of its own', () {
    final ids = {for (final m in MilestoneCatalog.all) m.id};
    // No badge falls back to the default picture...
    expect(MilestoneArtCatalog.byId.keys.toSet(), ids);
    // ...and no two badges share one.
    final scenes = {
      for (final m in MilestoneCatalog.all) MilestoneArtCatalog.of(m).scene,
    };
    expect(scenes, hasLength(MilestoneCatalog.all.length));
  });

  testWidgets('every card draws, in both formats, dark and light', (
    tester,
  ) async {
    addTearDown(() => TideColors.use(TidePalettes.standard));
    for (final palette in [TidePalettes.midnight, TidePalettes.paper]) {
      TideColors.use(palette);
      for (final format in CardFormat.values) {
        for (final milestone in MilestoneCatalog.all) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: MilestoneCard(
                  milestone: milestone,
                  format: format,
                  accountName: 'Jules',
                  bestRun: milestone.threshold,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: milestone.id);
          expect(find.text(milestone.name), findsOneWidget);
        }
      }
    }
  });

  Future<void> openSheet(WidgetTester tester, CardShare share) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showShareCard(
                  context,
                  milestone: oneWeek,
                  accountName: 'Jules',
                  bestRun: 9,
                  share: share,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('offers only the apps that are there', (tester) async {
    await openSheet(
      tester,
      _FakeShare({ShareTarget.whatsapp, ShareTarget.save, ShareTarget.more}),
    );

    expect(find.bySemanticsLabel('Share to WhatsApp'), findsOneWidget);
    expect(find.bySemanticsLabel('Save card'), findsOneWidget);
    expect(find.bySemanticsLabel('Share to Instagram'), findsNothing);
    expect(find.bySemanticsLabel('Share to Messages'), findsNothing);
    expect(find.text('More ways to share'), findsOneWidget);
  });

  testWidgets('sends the card as a 1080-wide story image', (tester) async {
    final share = _FakeShare({ShareTarget.whatsapp, ShareTarget.more});
    await openSheet(tester, share);

    await tester.tap(find.bySemanticsLabel('Share to WhatsApp'));
    // The render waits for a frame, then encodes and writes for real: each
    // real step resumes on the test's clock, so take turns until it lands.
    for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump();

    expect(share.sent, hasLength(1));
    final (target, image, caption) = share.sent.single;
    expect(target, ShareTarget.whatsapp);
    expect(caption, contains('One week'));

    final bytes = await tester.runAsync(image.readAsBytes);
    final header = ByteData.sublistView(bytes!);
    // PNG signature, then the IHDR chunk's width and height.
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    expect(header.getUint32(16), 1080);
    expect(header.getUint32(20), 1920);
  });

  testWidgets('says so where sharing is not built', (tester) async {
    await openSheet(tester, const NoCardShare());

    expect(find.text('Sharing works in the Android app.'), findsOneWidget);
    expect(find.text('More ways to share'), findsNothing);
  });
}
