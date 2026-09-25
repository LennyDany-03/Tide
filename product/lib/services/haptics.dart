import 'package:flutter/services.dart';

/// The single gate every knock and shake in Tide goes through.
///
/// Widgets call `HapticFeedback` directly, which the Settings → Haptics
/// switch can never reach; here it can. [enabled] is mirrored from the
/// persisted device flag by the store and by the lock-screen call engine —
/// the two places the app boots from — so turning haptics off in Settings
/// shuts the whole layer down, and the choice survives a restart.
abstract final class TideHaptics {
  static bool enabled = true;

  static Future<void> selectionClick() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> lightImpact() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }
}