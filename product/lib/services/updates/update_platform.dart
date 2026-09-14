import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pub_semver/pub_semver.dart';

/// The native half of the updater: what is installed, where a download may
/// go, and the install intent itself.
///
/// Hand-rolled on a method channel rather than taken from a package. Firing
/// an install intent is a dozen lines of Kotlin (`MainActivity.kt`), and the
/// packages that wrap it are exactly the kind of unmaintained dependency a
/// sideloaded app cannot afford to be stuck on.
abstract interface class UpdatePlatform {
  /// The running build's `versionName`, or null when it cannot be read.
  Future<Version?> installedVersion();

  /// A private directory the install intent can be granted access to.
  Future<Directory> downloadDirectory();

  /// Android 8+ asks per app whether it may install packages.
  Future<bool> canInstallPackages();

  /// Opens the system page where that permission is granted.
  Future<void> openInstallPermission();

  /// Hands [apk] to the system installer.
  Future<void> install(File apk);
}

class AndroidUpdatePlatform implements UpdatePlatform {
  const AndroidUpdatePlatform();

  static const MethodChannel _channel = MethodChannel('tide/updates');

  @override
  Future<Version?> installedVersion() async {
    final name = await _channel.invokeMethod<String>('installedVersion');
    if (name == null) return null;
    try {
      return Version.parse(name);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Directory> downloadDirectory() async {
    final path = await _channel.invokeMethod<String>('downloadDirectory');
    return Directory(path!);
  }

  @override
  Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  @override
  Future<void> openInstallPermission() =>
      _channel.invokeMethod<void>('openInstallPermission');

  @override
  Future<void> install(File apk) =>
      _channel.invokeMethod<void>('install', {'path': apk.path});
}
