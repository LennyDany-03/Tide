import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tide/services/updates/release_manifest.dart';
import 'package:tide/services/updates/update_platform.dart';
import 'package:tide/services/updates/update_store.dart';

/// Records what the native side was asked to do, with no Android behind it.
class _FakePlatform implements UpdatePlatform {
  _FakePlatform({required this.installed, this.canInstall = true});

  final String installed;
  bool canInstall;
  final Directory dir = Directory.systemTemp.createTempSync('tide_update_');
  final List<String> installs = [];
  int permissionRequests = 0;

  @override
  Future<Version?> installedVersion() async => Version.parse(installed);

  @override
  Future<Directory> downloadDirectory() async => dir;

  @override
  Future<bool> canInstallPackages() async => canInstall;

  @override
  Future<void> openInstallPermission() async => permissionRequests++;

  @override
  Future<void> install(File apk) async => installs.add(apk.path);
}

const _manifestUrl = 'https://tide.test/version.json';
const _apkUrl = 'https://tide.test/tide-1.2.0.apk';
final _apkBytes = utf8.encode('not really an apk');

Map<String, Object?> _manifest({
  String version = '1.2.0',
  String? minSupported,
  String url = _apkUrl,
  String? sha,
}) => {
  'version': version,
  'build': 7,
  'releasedAt': '2026-09-15',
  'minSupportedVersion': ?minSupported,
  'android': {
    'url': url,
    'sha256': sha ?? sha256.convert(_apkBytes).toString(),
    'size': _apkBytes.length,
  },
  'notes': ['Faster sync', 'A new widget'],
};

UpdateStore _store(
  _FakePlatform platform,
  Map<String, Object?> manifest, {
  List<int>? apk,
}) {
  final client = MockClient((request) async {
    if (request.url.toString() == _manifestUrl) {
      return http.Response(jsonEncode(manifest), 200);
    }
    if (request.url.toString() == _apkUrl) {
      return http.Response.bytes(apk ?? _apkBytes, 200);
    }
    return http.Response('', 404);
  });
  return UpdateStore(
    manifestUrl: _manifestUrl,
    platform: platform,
    client: client,
  );
}

void main() {
  group('ReleaseManifest', () {
    test('reads a published release', () {
      final manifest = ReleaseManifest.tryParse(_manifest())!;
      expect(manifest.version, Version(1, 2, 0));
      expect(manifest.hasDownload, isTrue);
      expect(manifest.notes, ['Faster sync', 'A new widget']);
    });

    test('a manifest without an APK offers no download', () {
      final manifest = ReleaseManifest.tryParse(_manifest(url: '', sha: ''))!;
      expect(manifest.hasDownload, isFalse);
    });

    test('refuses a plain-http download', () {
      final manifest = ReleaseManifest.tryParse(
        _manifest(url: 'http://tide.test/tide.apk'),
      )!;
      expect(manifest.hasDownload, isFalse);
    });

    test('a malformed version makes the whole manifest unreadable', () {
      expect(ReleaseManifest.tryParse(_manifest(version: 'soon')), isNull);
      expect(ReleaseManifest.tryParse('nope'), isNull);
    });

    test('compares by semantic version, not by string', () {
      final manifest = ReleaseManifest.tryParse(_manifest(version: '1.10.0'))!;
      expect(manifest.isNewerThan(Version.parse('1.9.3')), isTrue);
      expect(manifest.isNewerThan(Version.parse('1.10.0')), isFalse);
    });
  });

  group('UpdateStore', () {
    test('finds a newer release', () async {
      final store = _store(_FakePlatform(installed: '1.0.0'), _manifest());
      await store.check();
      expect(store.phase, UpdatePhase.available);
      expect(store.updateAvailable, isTrue);
      expect(store.updateRequired, isFalse);
    });

    test('is up to date on the published version', () async {
      final store = _store(_FakePlatform(installed: '1.2.0'), _manifest());
      await store.check();
      expect(store.phase, UpdatePhase.upToDate);
      expect(store.shouldAnnounce, isFalse);
    });

    test('an install below the supported floor must update', () async {
      final store = _store(
        _FakePlatform(installed: '1.0.0'),
        _manifest(minSupported: '1.1.0'),
      );
      await store.check();
      expect(store.updateRequired, isTrue);
    });

    test('downloads, verifies and fires the install intent', () async {
      final platform = _FakePlatform(installed: '1.0.0');
      final store = _store(platform, _manifest());
      await store.check();
      await store.downloadAndInstall();

      expect(platform.installs, hasLength(1));
      expect(File(platform.installs.single).readAsBytesSync(), _apkBytes);
      expect(store.phase, UpdatePhase.readyToInstall);
    });

    test(
      'a download that fails its checksum is deleted, not installed',
      () async {
        final platform = _FakePlatform(installed: '1.0.0');
        final store = _store(
          platform,
          _manifest(),
          apk: utf8.encode('tampered'),
        );
        await store.check();
        await store.downloadAndInstall();

        expect(platform.installs, isEmpty);
        expect(store.phase, UpdatePhase.failed);
        expect(platform.dir.listSync(), isEmpty);
      },
    );

    test('asks for the install permission, then installs without '
        'downloading again', () async {
      final platform = _FakePlatform(installed: '1.0.0', canInstall: false);
      final store = _store(platform, _manifest());
      await store.check();
      await store.downloadAndInstall();

      expect(store.phase, UpdatePhase.needsPermission);
      expect(platform.permissionRequests, 1);
      expect(platform.installs, isEmpty);

      platform.canInstall = true;
      await store.install();
      expect(platform.installs, hasLength(1));
    });
  });
}
