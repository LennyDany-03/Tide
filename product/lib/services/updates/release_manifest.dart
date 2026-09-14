import 'package:flutter/foundation.dart';
import 'package:pub_semver/pub_semver.dart';

/// One published release, as described by the website's `version.json`.
///
/// The same file the site reads to print its version number, so the site and
/// the app can never disagree about what "latest" is. Parsing is forgiving in
/// the way `HabitRows` is: an unknown field is ignored and a malformed one
/// makes the whole manifest unreadable rather than half-trusted, because a
/// half-read manifest is how an app installs something it should not.
@immutable
class ReleaseManifest {
  const ReleaseManifest({
    required this.version,
    required this.build,
    required this.notes,
    this.minSupportedVersion,
    this.apkUrl,
    this.sha256 = '',
    this.sizeBytes = 0,
    this.releasedAt,
  });

  final Version version;
  final int build;

  /// Installs older than this are asked to update before carrying on.
  final Version? minSupportedVersion;

  /// Null until the release workflow has published an APK. The site ships a
  /// manifest before the first release exists, and that manifest must not
  /// make the app offer a download it cannot perform.
  final Uri? apkUrl;

  /// Lower-case hex. The download is refused unless it matches.
  final String sha256;
  final int sizeBytes;
  final DateTime? releasedAt;

  /// The changelog lines for this version, in order.
  final List<String> notes;

  bool get hasDownload =>
      apkUrl != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256);

  bool isNewerThan(Version installed) => version > installed;

  bool isRequiredFor(Version installed) {
    final floor = minSupportedVersion;
    return floor != null && installed < floor;
  }

  /// Null when [json] is not a manifest this build can trust.
  static ReleaseManifest? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      final version = Version.parse(json['version']! as String);
      final floor = json['minSupportedVersion'];
      final android = json['android'];
      final notes = json['notes'];

      Uri? apkUrl;
      var sha = '';
      var size = 0;
      if (android is Map<String, Object?>) {
        final url = android['url'];
        if (url is String && url.isNotEmpty) {
          final parsed = Uri.parse(url);
          // Only ever https: the checksum guards the bytes, but a manifest
          // pointing at plain http is a manifest somebody got wrong.
          if (parsed.scheme == 'https') apkUrl = parsed;
        }
        sha = (android['sha256'] as String? ?? '').toLowerCase();
        size = (android['size'] as num? ?? 0).toInt();
      }

      return ReleaseManifest(
        version: version,
        build: (json['build'] as num? ?? 0).toInt(),
        minSupportedVersion: floor is String && floor.isNotEmpty
            ? Version.parse(floor)
            : null,
        apkUrl: apkUrl,
        sha256: sha,
        sizeBytes: size,
        releasedAt: DateTime.tryParse(json['releasedAt'] as String? ?? ''),
        notes: notes is List ? notes.whereType<String>().toList() : const [],
      );
    } on Object {
      return null;
    }
  }
}
