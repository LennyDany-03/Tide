import 'package:flutter/foundation.dart';

/// The signed-in person, in the shape the app needs and nothing more.
///
/// No tokens and no provider objects: whatever the account service returned
/// is boiled down to this before a screen sees it, so nothing above the
/// service knows or cares which service it was.
@immutable
class TideAccount {
  const TideAccount({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.providers = const {},
  });

  final String id;
  final String email;

  /// The name the account was created with, or the one Google supplied.
  final String? name;

  /// The Google profile picture, when a Google identity is linked. Email
  /// accounts have none and are drawn as initials.
  final String? avatarUrl;

  /// How this account can sign in: `email`, `google`, or both.
  final Set<String> providers;

  bool get hasGoogle => providers.contains('google');
  bool get hasPassword => providers.contains('email');

  /// What to call the account when no name was ever given: the part of the
  /// address before the @, which is at least theirs.
  String get displayName {
    final given = name?.trim();
    if (given != null && given.isNotEmpty) return given;
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'You' : local;
  }

  /// The first word of [name], for greetings.
  ///
  /// Null when there is no name. "Welcome back, sam.reyes" reads like a log
  /// line, so a greeting drops the name rather than falling back to the
  /// address.
  String? get firstName {
    final given = name?.trim();
    if (given == null || given.isEmpty) return null;
    return given.split(RegExp(r'\s+')).first;
  }

  @override
  bool operator ==(Object other) =>
      other is TideAccount &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      setEquals(other.providers, providers);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    name,
    avatarUrl,
    Object.hashAllUnordered(providers),
  );
}

/// Why an account request was refused, as something a screen can say.
enum AuthProblem {
  /// Log in: nothing is registered under this address.
  noAccount,

  /// Create account: the address is already registered.
  accountExists,

  /// The address belongs to an account that only signs in with Google.
  googleAccount,

  /// The account exists and this is not its password.
  wrongPassword,

  /// Credentials were refused and the service could not say which half was
  /// wrong — the account lookup is unavailable.
  badCredentials,

  /// The account exists but its emailed code has not been entered yet.
  emailNotConfirmed,

  /// The emailed code is wrong, or has expired. Supabase does not say which.
  invalidCode,

  weakPassword,

  /// Too many requests. When the service says how long to wait, the number
  /// of seconds is the failure's detail.
  rateLimited,

  offline,

  /// The person closed the Google picker. Not worth a sentence.
  cancelled,

  googleUnavailable,

  /// Account deletion is not installed on the server: the `delete_account`
  /// function from `supabase/auth_setup.sql` has not been run.
  deletionUnavailable,

  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.problem, [this.detail]);

  final AuthProblem problem;

  /// Anything more specific the service had to add: the provider's own
  /// wording, the Google address that was picked, or seconds to wait.
  final String? detail;

  @override
  String toString() =>
      'AuthFailure(${problem.name}${detail == null ? '' : ': $detail'})';
}

enum SignUpOutcome {
  /// The account is open and signed in — a project with email confirmation
  /// turned off.
  signedIn,

  /// The account exists, and waits on the six-digit code emailed to it.
  needsCode,
}

/// The seam between Tide and whoever actually holds the accounts.
///
/// Two implementations: `SupabaseAuthService` for a real build, and
/// `DemoAuthService` for tests and for a build with no project configured.
/// Both keep the same rules — log in only reaches an account that exists,
/// create only makes one that does not, and a new email account opens only
/// once its code is in — so the screens have one set of outcomes to handle
/// whichever of them is behind it.
abstract class AuthService {
  /// The account a restored session belongs to, available synchronously at
  /// launch so the first screen can be chosen without a flash.
  TideAccount? get currentAccount;

  /// Every sign-in and sign-out, including the ones no screen started — a
  /// session that could not be refreshed, a sign-out on another device.
  Stream<TideAccount?> get accountChanges;

  /// True when accounts do not outlive the process.
  bool get isLocalOnly;

  bool get googleAvailable;

  /// Throws [AuthFailure].
  Future<TideAccount> logIn({required String email, required String password});

  /// Throws [AuthFailure].
  Future<SignUpOutcome> createAccount({
    required String name,
    required String email,
    required String password,
  });

  /// Confirms a new account with the code emailed to it, which also signs it
  /// in. Throws [AuthFailure].
  Future<TideAccount> verifyEmailCode({
    required String email,
    required String code,
  });

  /// Emails a fresh code to an account that has not been confirmed. Throws
  /// [AuthFailure].
  Future<void> resendEmailCode({required String email});

  /// [creating] is which half of the form the button was pressed from, and
  /// decides the rule: create refuses an address that already has an
  /// account, log in refuses one that does not. Throws [AuthFailure].
  Future<TideAccount> continueWithGoogle({required bool creating});

  /// Whether this account has already been shown the guided tour.
  Future<bool> tourCompleted(TideAccount account);

  Future<void> markTourCompleted(TideAccount account);

  Future<void> logOut();

  /// Deletes the signed-in account for good, then ends its session here.
  ///
  /// Throws [AuthFailure] when the server refuses or cannot be reached; the
  /// session is left signed in then, so the person can try again.
  Future<void> deleteAccount();
}
