import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where a milestone card can be sent from the share sheet.
enum ShareTarget {
  /// WhatsApp's own picker, which opens on "My status" as well as chats.
  whatsapp,

  /// Instagram's story composer when this Instagram exposes one, otherwise
  /// Instagram's own choice of story, feed or message.
  instagram,

  /// The phone's default messaging app.
  messages,

  /// The phone's gallery, under Pictures/Tide.
  save,

  /// The system share sheet: everything else installed.
  more,
}

/// Hands a rendered card to another app.
///
/// The seam between the share sheet and the platform: [AndroidCardShare]
/// on the sideloaded Android build, [NoCardShare] anywhere this has not
/// been built for, and a fake in tests.
abstract class CardShare {
  const CardShare();

  /// The platform's own, or [debugOverride] when a test has set one.
  static CardShare platform() {
    final override = debugOverride;
    if (override != null) return override;
    if (!kIsWeb && Platform.isAndroid) return AndroidCardShare();
    return const NoCardShare();
  }

  /// Set by tests so the sheet reaches a fake rather than the platform.
  @visibleForTesting
  static CardShare? debugOverride;

  /// The targets that will work on this device right now: an app that is
  /// not installed does not get a button.
  Future<Set<ShareTarget>> targets();

  /// A directory the other app will be allowed to read an image from.
  Future<Directory> directory();

  /// Sends [image] to [target], with [caption] where the target takes text.
  /// False when the target could not be reached.
  Future<bool> send(ShareTarget target, File image, {String? caption});
}

/// The Android half is `CardShare.kt`, on the `tide/share` channel.
class AndroidCardShare extends CardShare {
  AndroidCardShare();

  static const _channel = MethodChannel('tide/share');

  @override
  Future<Set<ShareTarget>> targets() async {
    try {
      final names = await _channel.invokeListMethod<String>('targets') ?? [];
      return {
        for (final target in ShareTarget.values)
          if (names.contains(target.name)) target,
        ShareTarget.more,
      };
    } on PlatformException {
      return {ShareTarget.more};
    } on MissingPluginException {
      return const {};
    }
  }

  @override
  Future<Directory> directory() async {
    final path = await _channel.invokeMethod<String>('directory');
    return Directory(path!);
  }

  @override
  Future<bool> send(ShareTarget target, File image, {String? caption}) async {
    try {
      return await _channel.invokeMethod<bool>(
            target == ShareTarget.save ? 'save' : 'send',
            {'path': image.path, 'target': target.name, 'caption': caption},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}

/// No way out of the app on this platform yet.
class NoCardShare extends CardShare {
  const NoCardShare();

  @override
  Future<Set<ShareTarget>> targets() async => const {};

  @override
  Future<Directory> directory() async => Directory.systemTemp;

  @override
  Future<bool> send(ShareTarget target, File image, {String? caption}) async =>
      false;
}
