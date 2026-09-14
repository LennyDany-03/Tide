// Renders the screenshots the marketing site shows.
//
//   flutter test tool/site_screenshots_test.dart
//
// Lives outside test/ for the same reason as brand_assets_test.dart: it
// writes files (into ../public/screens/) and a plain `flutter test` must
// never do that. The shots are the real app on the demo account's seed
// history, so the site can never show a screen the app does not have.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';

/// A 390 x 844 logical phone at 3x, the size the site's frames are drawn for.
const _logical = Size(390, 844);
const _ratio = 3.0;

const _out = '../public/screens';

void main() {
  testWidgets('site screenshots', (tester) async {
    await _loadFonts();

    tester.view
      ..physicalSize = _logical * _ratio
      ..devicePixelRatio = _ratio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TideApp(startOnboarded: true));
    await _pumpFor(tester, const Duration(seconds: 3));
    await _shoot(tester, 'today');

    for (final (tab, name) in [
      ('History', 'history'),
      ('Insights', 'insights'),
    ]) {
      await tester.tap(find.text(tab).last, warnIfMissed: false);
      await _pumpFor(tester, const Duration(seconds: 2));
      await _shoot(tester, name);
    }

    // Leave nothing ticking for the harness to complain about.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// Real glyphs instead of the test font's boxes: the app's two families from
/// its own assets, and Material's icon font and Roboto from the SDK cache.
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
  final fonts = Directory('$sdk/bin/cache/artifacts/material_fonts');
  if (!fonts.existsSync()) return;
  Future<void> file(String name, String fileName) async {
    final f = File('${fonts.path}/$fileName');
    if (!f.existsSync()) return;
    final bytes = f.readAsBytesSync();
    final loader = FontLoader(name)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await file('MaterialIcons', 'MaterialIcons-Regular.otf');
  await file('Roboto', 'Roboto-Regular.ttf');
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    // The root layer is already in physical pixels: the render view applies
    // the device pixel ratio, so the capture is 1:1 over the physical size.
    final image = await layer.toImage(Offset.zero & (_logical * _ratio));
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
