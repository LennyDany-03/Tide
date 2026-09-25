// Writes the four reminder tones into Android's res/raw.
//
//   flutter test tool/reminder_tones_test.dart
//
// Lives outside test/ for the same reason as brand_assets_test.dart: it
// writes files, and a plain `flutter test` must never do that. Rerun it after
// changing a tone here, and commit the .wav files it writes.
//
// The tones are synthesised rather than recorded, so there is nothing
// licensed in the app and every one of them can be tuned in code: bell-like
// partials with exponential decays, a few milliseconds of fade at each edge
// so nothing clicks, and a stretch of silence at the end so that looped by
// the ringing service they fall into a rhythm rather than a drone.
//
// Names and resources must match `ReminderTone` in
// lib/services/models/reminder_options.dart.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/models/reminder_options.dart';

const int _rate = 22050;
const String _raw = 'android/app/src/main/res/raw';

/// One sine partial: a frequency, a level, and how quickly it dies away.
class _Partial {
  const _Partial(this.frequency, this.level, this.decay);

  final double frequency;
  final double level;

  /// Seconds for the partial to fall to 1/e. Higher partials die faster, as
  /// they do in a real bell.
  final double decay;
}

/// A struck note: [partials] starting together at [start] seconds.
class _Strike {
  const _Strike(this.start, this.partials);

  final double start;
  final List<_Partial> partials;
}

/// A bell-ish note on [fundamental]: the ratios are close to a small bell's,
/// the upper ones slightly stretched so it rings rather than buzzes.
List<_Partial> _bell(
  double fundamental, {
  double length = 1.6,
  double level = 1,
}) => [
  _Partial(fundamental, 1.0 * level, length),
  _Partial(fundamental * 2.0, 0.34 * level, length * 0.55),
  _Partial(fundamental * 3.01, 0.14 * level, length * 0.35),
  _Partial(fundamental * 4.2, 0.07 * level, length * 0.22),
];

Float64List _render(double seconds, List<_Strike> strikes) {
  final samples = Float64List((seconds * _rate).round());
  for (final strike in strikes) {
    final from = (strike.start * _rate).round();
    for (var i = from; i < samples.length; i++) {
      final t = (i - from) / _rate;
      var value = 0.0;
      for (final p in strike.partials) {
        value +=
            p.level *
            math.exp(-t / p.decay) *
            math.sin(2 * math.pi * p.frequency * t);
      }
      // A 4ms attack on every strike, so it lands without a click.
      samples[i] += value * math.min(1, t / 0.004);
    }
  }
  return samples;
}

/// The Swell: a soft chord that rises and falls away, with a slow shimmer.
Float64List _swell() {
  const seconds = 2.8;
  final samples = Float64List((seconds * _rate).round());
  const notes = [220.0, 329.63, 440.0, 659.25];
  const levels = [1.0, 0.7, 0.55, 0.22];
  for (var i = 0; i < samples.length; i++) {
    final t = i / _rate;
    // Rises over the first 0.9 s, holds, and is gone by 2.2 s.
    final envelope = t < 0.9
        ? math.sin(t / 0.9 * math.pi / 2)
        : math.max(0.0, 1 - (t - 0.9) / 1.3);
    var value = 0.0;
    for (var n = 0; n < notes.length; n++) {
      final vibrato = 1 + 0.003 * math.sin(2 * math.pi * 4.5 * t + n);
      value += levels[n] * math.sin(2 * math.pi * notes[n] * vibrato * t);
    }
    samples[i] = value * envelope * envelope;
  }
  return samples;
}

Float64List _tone(ReminderTone tone) => switch (tone) {
  // Two notes, a fifth apart, the second answering the first.
  ReminderTone.lowTide => _render(2.4, [
    _Strike(0, _bell(392.0)),
    _Strike(0.32, _bell(587.33, level: 0.8)),
  ]),
  // Drops on water: five quick notes stepping down.
  ReminderTone.ripple => _render(1.9, [
    for (final (i, f) in const [1318.5, 1046.5, 880.0, 698.46, 587.33].indexed)
      _Strike(i * 0.11, _bell(f, length: 0.34, level: 0.8 - i * 0.08)),
  ]),
  ReminderTone.swell => _swell(),
  // One low bell and the hum under it, left to ring out.
  ReminderTone.deepBell => _render(3.4, [
    _Strike(0, [
      const _Partial(65.41, 0.45, 2.4),
      ..._bell(130.81, length: 2.2),
      const _Partial(130.81 * 1.19, 0.2, 1.1),
      const _Partial(130.81 * 2.74, 0.1, 0.6),
    ]),
  ]),
};

/// Peak-normalised to −3 dB with a fade at each end, as 16-bit PCM.
Uint8List _wav(Float64List samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  final gain = peak == 0 ? 0 : 0.708 / peak;
  final fade = (_rate * 0.012).round();
  final pcm = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    var edge = 1.0;
    if (i < fade) edge = i / fade;
    if (i > samples.length - fade) edge = (samples.length - i) / fade;
    final value = (samples[i] * gain * edge * 32767).round().clamp(
      -32768,
      32767,
    );
    pcm.setInt16(i * 2, value, Endian.little);
  }

  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, _rate, Endian.little);
  header.setUint32(28, _rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.lengthInBytes, Endian.little);

  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...pcm.buffer.asUint8List(),
  ]);
}

void main() {
  test('reminder tones', () {
    Directory(_raw).createSync(recursive: true);
    for (final tone in ReminderTone.values) {
      final bytes = _wav(_tone(tone));
      File('$_raw/${tone.resource}.wav').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(44));
    }
  });
}
