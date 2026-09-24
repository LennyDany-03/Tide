// TEMPORARY — renders the share sheet for review. Delete after.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/milestone_catalog.dart';
import 'package:tide/screens/achievements/widgets/share_card_view.dart';
import 'package:tide/services/share/card_share.dart';
import 'package:tide/theme/tide_colors.dart';
import 'package:tide/theme/tide_theme.dart';

const _out =
    r'C:\Users\lenny\AppData\Local\Temp\claude\C--Users-lenny-Documents-Code-Github-pre-prod-Tide-product\d1dfe99a-deef-4a7f-b669-2393a0dce027\scratchpad\cards';

class _Fake extends CardShare {
  @override
  Future<Set<ShareTarget>> targets() async => ShareTarget.values.toSet();
  @override
  Future<Directory> directory() async => Directory.systemTemp;
  @override
  Future<bool> send(ShareTarget target, File image, {String? caption}) async =>
      true;
}

void main() {
  testWidgets('share sheet preview', (tester) async {
    await _loadFonts();
    const logical = Size(390, 844);
    tester.view
      ..physicalSize = logical * 3
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(bottom: 72, top: 120)
      ..viewPadding = const FakeViewPadding(bottom: 72, top: 120);
    addTearDown(tester.view.reset);

    final milestone = MilestoneCatalog.all.firstWhere((m) => m.id == 'hundred');
    await tester.pumpWidget(
      MaterialApp(
        theme: TideTheme.current,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: TideColors.deepWater,
            body: Center(
              child: TextButton(
                onPressed: () => showShareCard(
                  context,
                  milestone: milestone,
                  accountName: 'Lenny Dany . D',
                  bestRun: 104,
                  share: _Fake(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shoot(tester, 'sheet_story', logical);
    await tester.tap(find.text('Post'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shoot(tester, 'sheet_post', logical);
  });
}

Future<void> _shoot(WidgetTester tester, String name, Size logical) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & (logical * 3));
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family('Space Grotesk', [
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-Bold.ttf',
  ]);
  await family('Manrope', [
    'assets/fonts/Manrope-Regular.ttf',
    'assets/fonts/Manrope-Medium.ttf',
    'assets/fonts/Manrope-Bold.ttf',
  ]);
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) return;
  final f = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!f.existsSync()) return;
  final bytes = f.readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}
