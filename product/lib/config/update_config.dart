/// Where the app learns that a newer build exists.
///
/// The manifest is the `version.json` the release workflow
/// (`.github/workflows/release.yml`) attaches to every GitHub Release; the
/// default URL is `.../releases/latest/download/version.json`, which GitHub
/// always points at the newest release. Release builds are compiled with
/// `--dart-define=UPDATE_MANIFEST_URL=...`; a local run without it leaves the
/// value empty, and the updater stays switched off rather than pointing a
/// development build at production releases.
abstract final class UpdateConfig {
  static const String manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: '',
  );

  static bool get isConfigured => manifestUrl.isNotEmpty;
}
