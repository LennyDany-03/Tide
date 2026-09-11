// Redraws the logo the confirmation email shows.
//
//   flutter test tool/email_assets_test.dart
//
// Lives outside test/ for the same reason as brand_assets_test.dart: it
// writes a file, and a plain `flutter test` must never do that. Upload the
// result to the `email-assets` bucket afterwards — see supabase/email/README.md.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/theme/tide_gradients.dart';
import 'package:tide/theme/tide_palette.dart';
import 'package:tide/widgets/tide_logo.dart';

/// Always Midnight: the email is Midnight whatever palette the app is in.
const _palette = TidePalettes.midnight;

/// Three times the 64px it is shown at, for dense screens.
const int _px = 192;

void main() {
  testWidgets('email logo', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const centre = Offset(_px / 2, _px / 2);

      // Transparent ground, so it sits on the email's card; the glow fades
      // out before the edge so there is no square around it.
      final glow = _px * 0.48;
      canvas.drawCircle(
        centre,
        glow,
        Paint()
          ..shader = TideGradients.bloom(
            color: _palette.lantern,
            alpha: 0.22,
            center: Alignment.center,
            radius: 0.5,
          ).createShader(Rect.fromCircle(center: centre, radius: glow)),
      );

      const mark = _px * 0.72;
      canvas
        ..save()
        ..translate((_px - mark) / 2, (_px - mark) / 2);
      TideLogoPainter(
        palette: _palette,
        strokeWidth: mark * 0.045,
      ).paint(canvas, const Size.square(mark));
      canvas.restore();

      final image = await recorder.endRecording().toImage(_px, _px);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('supabase/email/tide-mark.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
