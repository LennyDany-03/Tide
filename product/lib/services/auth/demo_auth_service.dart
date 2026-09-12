import 'dart:async';

import 'auth_service.dart';

/// Accounts held in memory, for tests and for a build with no Supabase
/// project configured.
///
/// It keeps the real service's rules rather than waving everything through,
/// so the paths the screens take — no account, account exists, wrong
/// password, an account still waiting on its code — can be exercised without
/// a network. It knows one account from the start, the owner of the demo
/// history, so log in has somewhere to go.
class DemoAuthService implements AuthService {
  DemoAuthService({bool signedIn = false}) {
    if (signedIn) _current = _accounts[demoEmail]!.account;
  }

  static const String demoEmail = 'jules@tide.app';
  static const String demoPassword = 'tidewater';

  /// The only code this service accepts. There is no inbox to send a real
  /// one to, so every sign-up's code is this.
  static const String demoCode = '123456';

  final Map<String, _DemoAccount> _accounts = {
    demoEmail: _DemoAccount(
      const TideAccount(
        id: 'demo-jules',
        email: demoEmail,
        name: 'Jules Ramirez',
        providers: {'email'},
      ),
      password: demoPassword,
      confirmed: true,
      tourCompleted: true,
    ),
  };

  final StreamController<TideAccount?> _changes =
      StreamController<TideAccount?>.broadcast();

  TideAccount? _current;

  @override
  TideAccount? get currentAccount => _current;

  @override
  Stream<TideAccount?> get accountChanges => _changes.stream;

  @override
  bool get isLocalOnly => true;

  @override
  bool get googleAvailable => false;

  @override
  Future<TideAccount> logIn({
    required String email,
    required String password,
  }) async {
    final entry = _accounts[_key(email)];
    if (entry == null) throw const AuthFailure(AuthProblem.noAccount);
    if (entry.password != password) {
      throw const AuthFailure(AuthProblem.wrongPassword);
    }
    if (!entry.confirmed) {
      throw const AuthFailure(AuthProblem.emailNotConfirmed);
    }
    _set(entry.account);
    return entry.account;
  }

  @override
  Future<SignUpOutcome> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = _key(email);
    final existing = _accounts[key];
    if (existing != null && existing.confirmed) {
      throw const AuthFailure(AuthProblem.accountExists);
    }

    // Signing up again over an unconfirmed account starts it afresh, the
    // way Supabase sends a new code rather than refusing.
    final trimmed = name.trim();
    _accounts[key] = _DemoAccount(
      TideAccount(
        id: existing?.account.id ?? 'demo-${_accounts.length + 1}',
        email: key,
        name: trimmed.isEmpty ? null : trimmed,
        providers: const {'email'},
      ),
      password: password,
      confirmed: false,
      tourCompleted: false,
    );
    return SignUpOutcome.needsCode;
  }

  @override
  Future<TideAccount> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final entry = _accounts[_key(email)];
    if (entry == null || entry.confirmed || code != demoCode) {
      throw const AuthFailure(AuthProblem.invalidCode);
    }
    entry.confirmed = true;
    _set(entry.account);
    return entry.account;
  }

  @override
  Future<void> resendEmailCode({required String email}) async {}

  @override
  Future<TideAccount> continueWithGoogle({required bool creating}) async {
    throw const AuthFailure(
      AuthProblem.googleUnavailable,
      'Google sign-in needs Supabase, and this run started without its keys. '
      'Stop the app and launch it with --dart-define-from-file=.env.',
    );
  }

  @override
  Future<bool> tourCompleted(TideAccount account) async =>
      _accounts[account.email]?.tourCompleted ?? true;

  @override
  Future<void> markTourCompleted(TideAccount account) async {
    _accounts[account.email]?.tourCompleted = true;
  }

  @override
  Future<void> logOut() async => _set(null);

  /// Forgets the account entirely — including the demo owner, so a deleted
  /// demo account refuses log in afterwards the way a real one would.
  @override
  Future<void> deleteAccount() async {
    final current = _current;
    if (current == null) return;
    _accounts.remove(_key(current.email));
    _set(null);
  }

  void _set(TideAccount? account) {
    _current = account;
    _changes.add(account);
  }

  static String _key(String email) => email.trim().toLowerCase();
}

class _DemoAccount {
  _DemoAccount(
    this.account, {
    required this.password,
    required this.confirmed,
    required this.tourCompleted,
  });

  final TideAccount account;
  final String password;
  bool confirmed;
  bool tourCompleted;
}
