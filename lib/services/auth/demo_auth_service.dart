import 'dart:async';

import 'auth_service.dart';

/// Accounts held in memory, for tests and for a build with no Supabase
/// project configured.
///
/// It keeps the real service's rules rather than waving everything through,
/// so the paths the auth screen takes — no account, account exists, wrong
/// password — can be exercised without a network. It knows one account from
/// the start, the owner of the demo history, so log in has somewhere to go.
class DemoAuthService implements AuthService {
  DemoAuthService({bool signedIn = false}) {
    if (signedIn) _current = _accounts[demoEmail]!.account;
  }

  static const String demoEmail = 'jules@tide.app';
  static const String demoPassword = 'tidewater';

  final Map<String, _DemoAccount> _accounts = {
    demoEmail: _DemoAccount(
      const TideAccount(
        id: 'demo-jules',
        email: demoEmail,
        name: 'Jules Ramirez',
        providers: {'email'},
      ),
      password: demoPassword,
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
    if (_accounts.containsKey(key)) {
      throw const AuthFailure(AuthProblem.accountExists);
    }
    final trimmed = name.trim();
    final account = TideAccount(
      id: 'demo-${_accounts.length + 1}',
      email: key,
      name: trimmed.isEmpty ? null : trimmed,
      providers: const {'email'},
    );
    _accounts[key] = _DemoAccount(
      account,
      password: password,
      tourCompleted: false,
    );
    _set(account);
    return SignUpOutcome.signedIn;
  }

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
    required this.tourCompleted,
  });

  final TideAccount account;
  final String password;
  bool tourCompleted;
}
