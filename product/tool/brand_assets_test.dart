// Regenerates every platform app icon from the logo painter.
//
//   flutter test tool/brand_assets_test.dart
//
// Lives outside test/ on purpose: it writes into android/, ios/ and web/,
// and a plain `flutter test` must never do that. Run it after changing
// `TideLogoPainter` or the Midnight palette, then commit the images.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/theme/tide_gradients.dart';
import 'package:tide/theme/tide_palette.dart';
import 'package:tide/widgets/tide_logo.dart';

/// The icon is always Midnight, whatever palette the app is showing: an
/// icon cannot change with an in-app setting.
const _palette = TidePalettes.midnight;

/// The logo's size as a fraction of a full-bleed icon — iOS, legacy
/// Android, web.
const _full = 0.62;

/// The logo's size inside a maskable canvas — Android adaptive foregrounds
/// and web maskable icons — which a launcher may crop to a circle two
/// thirds the width of the canvas.
const _safe = 0.5;

void main() {
  testWidgets('platform icons', (tester) async {
    await tester.runAsync(() async {
      const android = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final entry in android.entries) {
        final dir = 'android/app/src/main/res/mipmap-${entry.key}';
        await _writeIcon(
          '$dir/ic_launcher.png',
          (48 * entry.value).round(),
          mark: _full,
        );
        await _writeIcon(
          '$dir/ic_launcher_foreground.png',
          (108 * entry.value).round(),
          mark: _safe,
          ground: false,
        );
      }

      const ios = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final entry in ios.entries) {
        await _writeIcon(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
          entry.value,
          mark: _full,
        );
      }

      await _writeIcon('web/favicon.png', 32, mark: 0.8);
      await _writeIcon('web/icons/Icon-192.png', 192, mark: _full);
      await _writeIcon('web/icons/Icon-512.png', 512, mark: _full);
      await _writeIcon('web/icons/Icon-maskable-192.png', 192, mark: _safe);
      await _writeIcon('web/icons/Icon-maskable-512.png', 512, mark: _safe);
    });
  });
}

/// The ground, the glow, and the finished mark. [ground] false leaves the
/// background transparent, for adaptive-icon foregrounds whose ground is a
/// separate layer.
void _paintIcon(
  Canvas canvas,
  double extent, {
  required double mark,
  bool ground = true,
}) {
  final centre = Offset(extent / 2, extent / 2);
  if (ground) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, extent, extent),
      Paint()..color = _palette.deepWater,
    );
  }

  final glow = extent * mark * 0.95;
  canvas.drawCircle(
    centre,
    glow,
    Paint()
      ..shader = TideGradients.bloom(
        color: _palette.lantern,
        alpha: 0.2,
        center: Alignment.center,
        radius: 0.5,
      ).createShader(Rect.fromCircle(center: centre, radius: glow)),
  );

  final size = extent * mark;
  // A heavier ring as the icon shrinks: at 29px a 3% ring is a hairline and
  // the mark reads as a dot on a blue smear.
  final weight = extent <= 48 ? 0.065 : (extent <= 120 ? 0.05 : 0.04);
  canvas
    ..save()
    ..translate((extent - size) / 2, (extent - size) / 2);
  TideLogoPainter(
    palette: _palette,
    strokeWidth: size * weight,
  ).paint(canvas, Size.square(size));
  canvas.restore();
}

Future<void> _writeIcon(
  String path,
  int px, {
  required double mark,
  bool ground = true,
}) async {
  final recorder = ui.PictureRecorder();
  _paintIcon(Canvas(recorder), px.toDouble(), mark: mark, ground: ground);
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  File(path)
    ..parent.createSync(recursive: true)
    // Opaque icons are written with no alpha channel at all: the App Store
    // rejects a marketing icon that has one, even if every pixel is solid.
    ..writeAsBytesSync(
      _encodePng(data!.buffer.asUint8List(), px, px, alpha: !ground),
    );
}

// --- A minimal PNG encoder --------------------------------------------------
//
// dart:ui can only encode RGBA PNGs, and there is no image package in this
// project. An 8-bit RGB or RGBA PNG is four chunks and a zlib stream.

Uint8List _encodePng(Uint8List rgba, int w, int h, {required bool alpha}) {
  final channels = alpha ? 4 : 3;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    final row = Uint8List(1 + w * channels); // leading 0: no filter
    var o = 1;
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      row[o++] = rgba[i];
      row[o++] = rgba[i + 1];
      row[o++] = rgba[i + 2];
      if (alpha) row[o++] = rgba[i + 3];
    }
    raw.add(row);
  }

  final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final tag = ascii.encode(type);
    out
      ..add(_u32(data.length))
      ..add(tag)
      ..add(data)
      ..add(_u32(_crc32([...tag, ...data])));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, alpha ? 6 : 2, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder(level: 9).convert(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
