import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_constants.dart';
import 'release_manifest.dart';
import 'update_platform.dart';

/// Where the updater is. Screens read this and nothing else.
enum UpdatePhase {
  /// Not checked yet this launch.
  idle,
  checking,
  upToDate,

  /// A newer release with a download is published.
  available,
  downloading,

  /// Downloaded and verified; waiting on the system installer.
  readyToInstall,

  /// Android has not been told this app may install packages.
  needsPermission,

  /// The check or the download failed. [UpdateStore.problem] says why.
  failed,
}

/// Checks the release manifest, downloads the APK and hands it to Android.
///
/// A store of its own rather than part of `TideStore`, for the same reason
/// the to-do list has one: nothing a habit screen draws depends on it, so an
/// update ticking through its download never rebuilds one.
class UpdateStore extends ChangeNotifier {
  UpdateStore({
    required this.manifestUrl,
    required this.platform,
    http.Client? client,
    this.prefs,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final String manifestUrl;
  final UpdatePlatform platform;
  final http.Client _client;

  /// Remembers which release has been announced. Null in tests.
  final SharedPreferences? prefs;
  final DateTime Function() _clock;

  static const String _announcedKey = 'tide.updates.announced';

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  Version? _installed;
  Version? get installed => _installed;

  ReleaseManifest? _latest;
  ReleaseManifest? get latest => _latest;

  /// 0..1 while [UpdatePhase.downloading].
  double _progress = 0;
  double get progress => _progress;

  String? _problem;
  String? get problem => _problem;

  File? _download;
  DateTime? _checkedAt;
  bool _disposed = false;

  /// A newer release exists and this build can actually fetch it.
  bool get updateAvailable {
    final latest = _latest;
    final installed = _installed;
    return latest != null &&
        installed != null &&
        latest.hasDownload &&
        latest.isNewerThan(installed);
  }

  /// The installed build is below the manifest's supported floor.
  bool get updateRequired {
    final installed = _installed;
    return updateAvailable && _latest!.isRequiredFor(installed!);
  }

  /// Whether the launch prompt for the current release has not been shown
  /// yet. Each version is announced once; after that it waits in Settings.
  bool get shouldAnnounce {
    if (!updateAvailable) return false;
    if (updateRequired) return true;
    return prefs?.getString(_announcedKey) != _latest!.version.toString();
  }

  void markAnnounced() {
    final latest = _latest;
    if (latest == null) return;
    unawaited(prefs?.setString(_announcedKey, latest.version.toString()));
  }

  /// Checks now, unless [ifStale] and the last check was recent.
  Future<void> check({bool ifStale = false}) async {
    if (_phase == UpdatePhase.checking || _phase == UpdatePhase.downloading) {
      return;
    }
    final last = _checkedAt;
    if (ifStale &&
        last != null &&
        _clock().difference(last) <
            const Duration(hours: AppConstants.updateCheckIntervalHours)) {
      return;
    }

    _set(UpdatePhase.checking);
    try {
      _installed ??= await platform.installedVersion();
      final response = await _client
          .get(Uri.parse(manifestUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(
            const Duration(seconds: AppConstants.updateManifestTimeoutSeconds),
          );
      if (response.statusCode != 200) {
        throw UpdateFailure(
          'The update server answered ${response.statusCode}.',
        );
      }
      final manifest = ReleaseManifest.tryParse(jsonDecode(response.body));
      if (manifest == null) {
        throw const UpdateFailure('The release manifest could not be read.');
      }
      _latest = manifest;
      _checkedAt = _clock();
      // A download already verified for this exact version is kept, so
      // coming back from the permission screen does not fetch it twice.
      if (_download != null && !updateAvailable) _download = null;
      _set(
        _download != null
            ? UpdatePhase.readyToInstall
            : updateAvailable
            ? UpdatePhase.available
            : UpdatePhase.upToDate,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// Downloads, verifies and installs the latest release.
  Future<void> downloadAndInstall() async {
    final latest = _latest;
    if (latest == null || !updateAvailable) return;
    if (_phase == UpdatePhase.downloading) return;

    try {
      final file = _download ?? await _fetch(latest);
      _download = file;
      await install();
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// Fires the install intent for a verified download, asking for the
  /// install permission first when Android has not granted it.
  Future<void> install() async {
    final file = _download;
    if (file == null) return;
    if (!await platform.canInstallPackages()) {
      _set(UpdatePhase.needsPermission);
      await platform.openInstallPermission();
      return;
    }
    _set(UpdatePhase.readyToInstall);
    await platform.install(file);
  }

  Future<File> _fetch(ReleaseManifest release) async {
    _progress = 0;
    _set(UpdatePhase.downloading);

    final dir = await platform.downloadDirectory();
    await dir.create(recursive: true);
    // Clear older downloads first: an APK is tens of megabytes and nothing
    // else ever deletes them.
    for (final old in dir.listSync().whereType<File>()) {
      if (old.path.endsWith('.apk')) old.deleteSync();
    }
    final file = File('${dir.path}/tide-${release.version}.apk');

    final response = await _client.send(http.Request('GET', release.apkUrl!));
    if (response.statusCode != 200) {
      throw UpdateFailure('The download answered ${response.statusCode}.');
    }
    final total = response.contentLength ?? release.sizeBytes;

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final sink = file.openWrite();
    var received = 0;
    var lastNotified = 0.0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: AppConstants.updateDownloadStallSeconds),
      )) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _progress = (received / total).clamp(0, 1);
          // A notify per chunk is hundreds of rebuilds a second; a percent
          // is all the bar can show anyway.
          if (_progress - lastNotified >= 0.01) {
            lastNotified = _progress;
            _notify();
          }
        }
      }
    } finally {
      await sink.close();
      hasher.close();
    }

    if (digest.value.toString() != release.sha256) {
      await file.delete();
      throw const UpdateFailure(
        'The download did not match the published checksum, so it was '
        'deleted rather than installed.',
      );
    }
    _progress = 1;
    return file;
  }

  void _fail(Object error) {
    _problem = switch (error) {
      UpdateFailure(:final message) => message,
      TimeoutException() => 'The update server took too long to answer.',
      SocketException() ||
      http.ClientException() => 'Tide could not reach the update server.',
      _ => 'Something went wrong while updating.',
    };
    debugPrint('Tide update: $error');
    _set(UpdatePhase.failed);
  }

  void _set(UpdatePhase phase) {
    _phase = phase;
    if (phase != UpdatePhase.failed) _problem = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
