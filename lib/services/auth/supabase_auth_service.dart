import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'auth_service.dart';

/// Accounts held by Supabase Auth, with Google through the native picker.
///
/// **Why a code rather than a link.** A confirmation link only signs in the
/// device that opens it — PKCE keeps half of the exchange inside the app —
/// so a link tapped in Gmail on a laptop confirmed the address and signed
/// nobody in. A six-digit code typed into the app works wherever the email
/// was read, and nobody leaves the app to use it. The email that carries it
/// is `supabase/email/confirm_signup.html`.
///
/// **Why there is an account lookup.** Supabase answers a wrong password and
/// an address it has never seen with the same `invalid_credentials` error —
/// deliberately, so its login endpoint cannot be used to find out who has an
/// account. Tide wants to say "there is no account, create one" instead,
/// which needs exactly that fact, so it asks for it through the
/// `account_status` function in `supabase/auth_setup.sql`. That is a real
/// trade: anyone holding the publishable key can ask whether an address is
/// registered. It is only asked after a refused login or before a sign-up,
/// and it never answers more than none / unconfirmed / password / google.
///
/// If the function has not been installed the lookup returns null, and
/// every path falls back to Supabase's own vaguer answers instead of failing.
///
/// **Why Google goes through `signInWithIdToken`.** The browser redirect
/// flow signs in first and only then reveals whether the account was new —
/// too late to refuse a "log in" that should have been a "create". The
/// native picker hands back the address before Supabase is involved, so the
/// rule the email form follows can be applied to Google too.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Future<void>? _googleReady;

  @override
  TideAccount? get currentAccount => _toAccount(_auth.currentUser);

  @override
  Stream<TideAccount?> get accountChanges =>
      _auth.onAuthStateChange.map((state) => _toAccount(state.session?.user));

  @override
  bool get isLocalOnly => false;

  @override
  bool get googleAvailable {
    if (kIsWeb || SupabaseConfig.googleWebClientId.isEmpty) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => SupabaseConfig.googleIosClientId.isNotEmpty,
      _ => false,
    };
  }

  @override
  Future<TideAccount> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _require(response.user);
    } on AuthException catch (error) {
      if (!_isInvalidCredentials(error)) throw _translate(error);
      throw AuthFailure(switch (await _statusOf(email)) {
        _AccountStatus.none => AuthProblem.noAccount,
        _AccountStatus.google => AuthProblem.googleAccount,
        _AccountStatus.password ||
        _AccountStatus.unconfirmed => AuthProblem.wrongPassword,
        null => AuthProblem.badCredentials,
      });
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw _unexpected(error);
    }
  }

  @override
  Future<SignUpOutcome> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final status = await _statusOf(email);
    if (status == _AccountStatus.password) {
      throw const AuthFailure(AuthProblem.accountExists);
    }
    if (status == _AccountStatus.google) {
      throw const AuthFailure(AuthProblem.googleAccount);
    }
    // An address that signed up and never entered its code falls through:
    // signing up again is how Supabase sends it a fresh code.

    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // Picked up by the profile trigger, and by the app as the name.
        data: {'full_name': name.trim()},
      );
      if (response.session != null) return SignUpOutcome.signedIn;
      // With "Confirm email" on, Supabase answers an address that is already
      // confirmed with an identity-less user rather than an error, so that
      // sign-up cannot be used to probe for accounts either. The lookup above
      // normally catches this first; this is for when it is not installed.
      if (response.user?.identities?.isEmpty ?? false) {
        throw const AuthFailure(AuthProblem.accountExists);
      }
      return SignUpOutcome.needsCode;
    } on AuthException catch (error) {
      throw _translate(error);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw _unexpected(error);
    }
  }

  @override
  Future<TideAccount> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: code,
      );
      return _require(response.user);
    } on AuthException catch (error) {
      throw _translate(error);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw _unexpected(error);
    }
  }

  @override
  Future<void> resendEmailCode({required String email}) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException catch (error) {
      throw _translate(error);
    } catch (error) {
      throw _unexpected(error);
    }
  }

  @override
  Future<TideAccount> continueWithGoogle({required bool creating}) async {
    if (!googleAvailable) {
      throw AuthFailure(
        AuthProblem.googleUnavailable,
        SupabaseConfig.googleWebClientId.isEmpty
            ? 'Google sign-in needs GOOGLE_WEB_CLIENT_ID in .env.'
            : 'Google sign-in is available in the Android app.',
      );
    }

    try {
      await _prepareGoogle();
      final picked = await GoogleSignIn.instance.authenticate();

      // A sign-up that never entered its code is not an account as far as
      // Google is concerned: it was never confirmed, and Google has just
      // verified the address.
      final status = await _statusOf(picked.email);
      final exists =
          status == _AccountStatus.password || status == _AccountStatus.google;
      if (!creating && status != null && !exists) {
        await _forgetGoogle();
        throw AuthFailure(AuthProblem.noAccount, picked.email);
      }
      if (creating && exists) {
        await _forgetGoogle();
        throw AuthFailure(AuthProblem.accountExists, picked.email);
      }

      final idToken = picked.authentication.idToken;
      if (idToken == null) {
        await _forgetGoogle();
        throw const AuthFailure(
          AuthProblem.unknown,
          'Google did not return an ID token.',
        );
      }

      // An address that already has a confirmed password account is linked
      // to it here by Supabase, since Google's addresses arrive verified —
      // which is how one account ends up with both ways in.
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return _require(response.user);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthFailure(AuthProblem.cancelled);
      }
      debugPrint(
        'Google sign-in failed: ${error.code.name} ${error.description}',
      );
      throw AuthFailure(AuthProblem.googleUnavailable, error.description);
    } on AuthException catch (error) {
      await _forgetGoogle();
      throw _translate(error);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw _unexpected(error);
    }
  }

  @override
  Future<bool> tourCompleted(TideAccount account) async {
    final row = await _client
        .from('profiles')
        .select('tour_completed')
        .eq('id', account.id)
        .maybeSingle();
    // No row means the profile trigger has not run for this user, which only
    // happens to an account that has never been through the app.
    return row?['tour_completed'] == true;
  }

  @override
  Future<void> markTourCompleted(TideAccount account) async {
    await _client
        .from('profiles')
        .update({'tour_completed': true})
        .eq('id', account.id);
  }

  @override
  Future<void> logOut() async {
    try {
      await _auth.signOut();
    } finally {
      // Otherwise the picker's next appearance can quietly reuse the Google
      // account that just left.
      if (googleAvailable) await _forgetGoogle();
    }
  }

  /// **Why an RPC rather than the Admin API.** Deleting a user through
  /// `auth.admin` needs the service-role key, which must never ship in the
  /// app. The `delete_account` function in `supabase/auth_setup.sql` runs
  /// with the database's rights but only ever deletes the caller — the user
  /// named by the JWT the request carries — and everything hanging off that
  /// user (identities, sessions, the profile) goes with it by cascade.
  @override
  Future<void> deleteAccount() async {
    if (_auth.currentUser == null) return;
    try {
      await _client.rpc<dynamic>('delete_account');
    } on PostgrestException catch (error) {
      // PGRST202: PostgREST has no function by that name to call.
      if (error.code == 'PGRST202') {
        throw const AuthFailure(
          AuthProblem.deletionUnavailable,
          'Account deletion is not set up on the server yet. Run '
          'supabase/auth_setup.sql in the SQL editor.',
        );
      }
      debugPrint('delete_account refused: ${error.code} ${error.message}');
      throw AuthFailure(AuthProblem.unknown, error.message);
    } catch (error) {
      throw _unexpected(error);
    }

    // The user is gone, so there is no server session left to end: the local
    // one is dropped, and the server's 403 for a missing user is expected.
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('Local sign-out after deletion: $error');
    }
    if (googleAvailable) await _forgetGoogle();
  }

  /// `initialize` may only succeed once per process, so it is kept — but a
  /// failed attempt must not be kept as if it had worked.
  Future<void> _prepareGoogle() {
    return _googleReady ??= GoogleSignIn.instance
        .initialize(
          serverClientId: SupabaseConfig.googleWebClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? SupabaseConfig.googleIosClientId
              : null,
        )
        .catchError((Object error, StackTrace stack) {
          _googleReady = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  Future<void> _forgetGoogle() async {
    try {
      await _prepareGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      // Nothing to undo: there was no Google session to end.
      debugPrint('Google sign-out skipped: $error');
    }
  }

  Future<_AccountStatus?> _statusOf(String email) async {
    try {
      final result = await _client.rpc<dynamic>(
        'account_status',
        params: {'p_email': email.trim()},
      );
      return switch (result) {
        'none' => _AccountStatus.none,
        'unconfirmed' => _AccountStatus.unconfirmed,
        'password' => _AccountStatus.password,
        'google' => _AccountStatus.google,
        _ => null,
      };
    } catch (error) {
      debugPrint('account_status lookup unavailable: $error');
      return null;
    }
  }

  static TideAccount? _toAccount(User? user) {
    if (user == null) return null;

    final identities = user.identities ?? const <UserIdentity>[];
    final meta = user.userMetadata ?? const <String, dynamic>{};

    Map<String, dynamic>? google;
    final providers = <String>{};
    for (final identity in identities) {
      providers.add(identity.provider);
      if (identity.provider == 'google') google = identity.identityData;
    }
    // Kept by Supabase on the user even when a payload omits identities.
    final listed = user.appMetadata['providers'];
    if (listed is List) providers.addAll(listed.whereType<String>());

    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    final hasGoogle = providers.contains('google');

    return TideAccount(
      id: user.id,
      email: user.email ?? '',
      name:
          text(meta['full_name']) ??
          text(meta['name']) ??
          text(google?['full_name']) ??
          text(google?['name']),
      // Only a Google identity supplies a picture. Reading the identity first
      // means an email account that later linked Google shows the photo even
      // if its metadata still describes the original sign-up.
      avatarUrl:
          text(google?['avatar_url']) ??
          text(google?['picture']) ??
          (hasGoogle ? text(meta['avatar_url']) ?? text(meta['picture']) : null),
      providers: providers,
    );
  }

  static TideAccount _require(User? user) {
    final account = _toAccount(user);
    if (account == null) {
      throw const AuthFailure(AuthProblem.unknown, 'No account came back.');
    }
    return account;
  }

  static bool _isInvalidCredentials(AuthException error) =>
      error.code == 'invalid_credentials' ||
      error.message == 'Invalid login credentials';

  static final RegExp _waitSeconds = RegExp(r'after (\d+) seconds?');

  static AuthFailure _translate(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return const AuthFailure(AuthProblem.offline);
    }
    final message = error.message;
    return switch (error.code) {
      'email_not_confirmed' => const AuthFailure(AuthProblem.emailNotConfirmed),
      // Supabase uses the one code for a wrong token and an expired one.
      'otp_expired' => const AuthFailure(AuthProblem.invalidCode),
      'weak_password' => AuthFailure(AuthProblem.weakPassword, message),
      'user_already_exists' ||
      'email_exists' => const AuthFailure(AuthProblem.accountExists),
      'over_email_send_rate_limit' || 'over_request_rate_limit' => AuthFailure(
        AuthProblem.rateLimited,
        _waitSeconds.firstMatch(message)?.group(1),
      ),
      _ when message.contains('Token has expired or is invalid') =>
        const AuthFailure(AuthProblem.invalidCode),
      _ => AuthFailure(AuthProblem.unknown, message),
    };
  }

  static AuthFailure _unexpected(Object error) {
    debugPrint('Auth request failed: $error');
    final described = error.toString();
    final offline =
        described.contains('SocketException') ||
        described.contains('ClientException') ||
        described.contains('TimeoutException');
    return AuthFailure(offline ? AuthProblem.offline : AuthProblem.unknown);
  }
}

enum _AccountStatus { none, unconfirmed, password, google }
