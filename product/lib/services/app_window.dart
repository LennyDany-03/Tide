import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's own window, as the OS sees it.
abstract final class AppWindow {
  static const _channel = MethodChannel('tide/app');

  /// Sends Tide to the background without closing it — the widget habit
  /// picker's last step, so choosing a habit lands back on the home screen
  /// where the widget is. Android only (see MainActivity.kt); a no-op
  /// everywhere else.
  static Future<void> moveToBack() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('moveToBack');
    } on MissingPluginException {
      // Tests and hosts without the native half.
    }
  }

  /// Asks for the launcher icon drawn in [paletteId]. Android switches it
  /// the next time the app leaves the screen (see LauncherIcon.kt); a no-op
  /// everywhere else.
  static Future<void> setLauncherIcon(String paletteId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setLauncherIcon', {
        'palette': paletteId,
      });
    } on MissingPluginException {
      // Tests and hosts without the native half.
    }
  }
}
