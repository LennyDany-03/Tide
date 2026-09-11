/// Where the account service lives, and the Google client it trusts.
///
/// Everything here is public by design and safe to ship inside the app: the
/// publishable key only names the project, and every table behind it is
/// closed by row level security (see `supabase/auth_setup.sql`). The two
/// things that must never appear here are the `service_role` / secret key
/// and the Google client *secret* — both belong in the Supabase dashboard
/// and nowhere else.
///
/// The values come from `.env` at the repo root (git-ignored; copy
/// `.env.example`), compiled in with `flutter run --dart-define-from-file=.env`
/// — `.vscode/launch.json` passes that for you. They are compile-time
/// constants, so a changed `.env` needs a full restart, not a hot reload.
/// Run without the file and every value is empty: the app notices and keeps
/// accounts in memory instead, which is also what the tests run on.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Project Settings → API Keys: the publishable key (`sb_publishable_…`)
  /// or the legacy `anon` key. Never the secret or `service_role` key.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// The **Web application** OAuth client from Google Cloud — not the
  /// Android one.
  ///
  /// Android's Credential Manager mints the ID token *for* this client, and
  /// Supabase checks the token's audience against the Client IDs listed on
  /// its Google provider, so this ID has to be in that list too. The Android
  /// client (package name + SHA-1) never appears in code; it exists so Google
  /// will agree to hand a token to this particular signed build.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Only for an iOS build, which also needs the reversed client ID
  /// registered as a URL scheme in `ios/Runner/Info.plist`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Where the email confirmation link hands back to the app. Listed under
  /// Authentication → URL Configuration → Redirect URLs in Supabase, and
  /// matched by the intent filter in `android/app/src/main/AndroidManifest.xml`.
  static const String authRedirect = 'com.example.tide://login-callback';

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
