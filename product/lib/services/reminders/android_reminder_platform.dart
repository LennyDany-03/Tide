import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../config/app_constants.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../widgets/habit_glyph.dart';
import '../models/reminder_options.dart';
import '../models/tide_glyph.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';
import 'reminder_settings.dart';

/// Reminders on Android, drawn and rung by native code
/// (`android/app/src/main/kotlin/com/example/tide/reminders/`).
///
/// **Why native.** A reminder has to be shown when no Dart is running: the
/// Rising Tide heads-up is a custom notification layout with a live
/// countdown; the Tide Call rings through a foreground service with its
/// volume swelling, takes the lock screen through an activity allowed there,
/// and gives up into a missed notification after two minutes; a reboot, a
/// time-zone change or an update has to re-arm all of it. None of that is
/// reachable from `flutter_local_notifications`, and all of it has to work
/// with the app closed.
///
/// **What crosses.** The plan, already worded — every sentence is written in
/// Dart, once — with the palette's colours as numbers and each habit's mark
/// as a small picture, because native code cannot read the theme and must
/// not invent a colour of its own.
class AndroidReminderPlatform implements ReminderPlatform {
  AndroidReminderPlatform._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _channel = MethodChannel('tide/reminders');

  /// Starts the platform, and — once per install — cancels the to-do
  /// reminders an earlier build scheduled through `flutter_local_notifications`,
  /// so they cannot ring beside the ones scheduled now.
  static Future<ReminderPlatform> create(ReminderPrefs prefs) async {
    final platform = AndroidReminderPlatform._();
    if (!prefs.legacyCleared) {
      try {
        final legacy = FlutterLocalNotificationsPlugin();
        await legacy.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        await legacy.cancelAll();
        prefs.markLegacyCleared();
      } catch (error) {
        debugPrint('Old task reminders not cleared: $error');
      }
    }
    return platform;
  }

  final StreamController<void> _queued = StreamController<void>.broadcast();
  final StreamController<ReminderOpen> _opened =
      StreamController<ReminderOpen>.broadcast();

  Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'actionsQueued':
        _queued.add(null);
      case 'open':
        final open = _parseOpen(call.arguments);
        if (open != null) _opened.add(open);
    }
  }

  @override
  List<ReminderPermission> get permissionsAsked => ReminderPermission.values;

  @override
  bool get fullScreenCalls => true;

  @override
  bool get canPreviewTones => true;

  @override
  Future<Map<ReminderPermission, PermissionState>> permissions() async {
    final raw = await _channel.invokeMapMethod<String, String>('permissions');
    return {for (final p in ReminderPermission.values) p: _state(raw?[p.name])};
  }

  @override
  Future<PermissionState> request(ReminderPermission permission) async {
    final raw = await _channel.invokeMethod<String>('request', {
      'permission': permission.name,
    });
    return _state(raw);
  }

  static PermissionState _state(String? raw) =>
      PermissionState.values.asNameMap()[raw] ?? PermissionState.denied;

  @override
  Future<void> schedule(
    ReminderGroup group,
    List<PlannedReminder> items, {
    required Set<String> open,
  }) async {
    await _channel.invokeMethod<void>('schedule', {
      'group': group.name,
      'items': jsonEncode([for (final item in items) item.toJson()]),
      'open': open.toList(),
      'look': _look(),
      'timing': _timing,
      'glyphs': await _glyphs(items),
    });
  }

  @override
  Future<void> test(List<PlannedReminder> items) async {
    await _channel.invokeMethod<void>('test', {
      'items': jsonEncode([for (final item in items) item.toJson()]),
      'look': _look(),
      'timing': _timing,
      'glyphs': await _glyphs(items),
    });
  }

  @override
  Future<void> snooze(PlannedReminder item, Duration after, int snoozes) async {
    await _channel.invokeMethod<void>('snooze', {
      'item': jsonEncode(item.toJson()),
      'after': after.inMilliseconds,
      'snoozes': snoozes,
    });
  }

  @override
  Future<List<ReminderAction>> takeActions() async {
    final raw = await _channel.invokeMethod<String>('takeActions');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [for (final item in decoded) ?ReminderAction.fromJson(item)];
  }

  @override
  Stream<void> get actionsQueued => _queued.stream;

  @override
  Stream<ReminderOpen> get opened => _opened.stream;

  @override
  Future<ReminderOpen?> takeLaunch() async =>
      _parseOpen(await _channel.invokeMethod<Object?>('takeLaunch'));

  @override
  Future<void> previewTone(ReminderTone tone) async {
    try {
      await _channel.invokeMethod<void>('previewTone', {'tone': tone.resource});
    } catch (error) {
      debugPrint('Tone not played: $error');
    }
  }

  static ReminderOpen? _parseOpen(Object? raw) {
    if (raw is! Map) return null;
    final target = ReminderOpenTarget.values.asNameMap()[raw['target']];
    final id = raw['id'];
    if (target == null || id is! String) return null;
    return ReminderOpen(target, id);
  }

  // --- The look -----------------------------------------------------------------

  /// The numbers native code rings by, from the one place they are set, so
  /// the phone and the app cannot disagree about how long a call rings.
  static final Map<String, int> _timing = {
    'ringMinutes': AppConstants.reminderRingMinutes,
    'swellSeconds': AppConstants.reminderSwellSeconds,
    'staleMinutes': AppConstants.reminderStaleMinutes,
    'maxSnoozes': AppConstants.maxReminderSnoozes,
    // The vibration pulses on the orb's bob, so hand and screen keep time.
    'pulseMillis': TideMotion.callBob.inMilliseconds,
  };

  /// The active palette, as ARGB numbers native code can paint with.
  static Map<String, Object> _look() {
    final palette = TideColors.palette;
    int argb(Color color) => color.toARGB32();
    return {
      'palette': palette.id,
      'light': palette.isLight,
      'ground': argb(TideColors.deepWater),
      'surface': argb(TideColors.shelf),
      'raised': argb(TideColors.shoal),
      'recess': argb(TideColors.trench),
      'ink': argb(TideColors.bone),
      'muted': argb(TideColors.silt),
      'accent': argb(TideColors.lantern),
      'onAccent': argb(TideColors.onLantern),
      'frost': argb(TideColors.frost),
      'flare': argb(TideColors.flare),
      'ember': argb(TideColors.ember),
    };
  }

  /// Rendered badges, by palette and glyph, so a plan rebuilt on every log
  /// does not redraw marks it has already drawn.
  final Map<String, Uint8List> _badges = {};

  /// A picture of each habit mark the plan uses — the mark in the accent,
  /// in a ring of it — for the notification's large icon and its card.
  Future<Map<String, Uint8List>> _glyphs(List<PlannedReminder> items) async {
    final names = {
      for (final item in items)
        if (item.details['glyph'] is String) item.details['glyph'] as String,
    };
    final out = <String, Uint8List>{};
    for (final name in names) {
      final glyph = TideGlyph.values.asNameMap()[name];
      if (glyph == null) continue;
      final key = '${TideColors.palette.id}:$name';
      final cached = _badges[key] ?? await _badge(glyph);
      if (cached == null) continue;
      _badges[key] = cached;
      out[name] = cached;
    }
    return out;
  }

  static const double _badgeSize = 144;

  static Future<Uint8List?> _badge(TideGlyph glyph) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size.square(_badgeSize);
      final center = size.center(Offset.zero);
      canvas.drawCircle(
        center,
        _badgeSize / 2,
        Paint()..color = TideColors.lantern.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        center,
        _badgeSize / 2 - 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = TideColors.lantern.withValues(alpha: 0.55),
      );
      canvas.save();
      canvas.translate(_badgeSize * 0.27, _badgeSize * 0.27);
      HabitGlyph.paintOn(
        canvas,
        const Size.square(_badgeSize * 0.46),
        glyph,
        color: TideColors.lantern,
        strokeWidth: 6,
      );
      canvas.restore();
      final image = await recorder.endRecording().toImage(
        _badgeSize.toInt(),
        _badgeSize.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (error) {
      debugPrint('Glyph badge not drawn: $error');
      return null;
    }
  }
}
