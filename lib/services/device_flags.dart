import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// The few things this device remembers about itself between launches.
///
/// Habits still live only in memory — see `TideStore`. But once sign-in was
/// real, a few facts could no longer be forgotten on every launch without
/// the app visibly repeating itself or losing somebody's place: that the
/// explanation has been read, that an account has already been walked round
/// Today, and that a sign-up is waiting on the code emailed to it. All of
/// them are about this device and this person, not about a session.
class DeviceFlags {
  DeviceFlags._(
    this._prefs,
    this._onboardingSeen,
    this._toursDone,
    this._pendingVerification,
  );

  /// Remembers nothing past the process — tests, and a caller that has not
  /// loaded storage.
  DeviceFlags.memory({bool onboardingSeen = false, String? pendingVerification})
    : this._(null, onboardingSeen, {}, pendingVerification);

  static Future<DeviceFlags> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceFlags._(
      prefs,
      prefs.getBool(_onboardingKey) ?? false,
      {...?prefs.getStringList(_toursKey)},
      prefs.getString(_pendingKey),
    );
  }

  static const String _onboardingKey = 'tide.onboarding_seen';
  static const String _toursKey = 'tide.tours_done';
  static const String _pendingKey = 'tide.pending_verification';

  final SharedPreferences? _prefs;
  bool _onboardingSeen;
  final Set<String> _toursDone;
  String? _pendingVerification;

  bool get onboardingSeen => _onboardingSeen;

  void markOnboardingSeen() {
    if (_onboardingSeen) return;
    _onboardingSeen = true;
    unawaited(_prefs?.setBool(_onboardingKey, true));
  }

  /// Also recorded on the account's profile. Kept here as well so a tour
  /// finished while the profile could not be written does not come back on
  /// the next launch.
  bool tourDone(String accountId) => _toursDone.contains(accountId);

  void markTourDone(String accountId) {
    if (!_toursDone.add(accountId)) return;
    unawaited(_prefs?.setStringList(_toursKey, _toursDone.toList()));
  }

  /// The address of a sign-up waiting on its emailed code.
  ///
  /// Only the address — never the code, and never the password. It is what
  /// lets a launch between "code sent" and "code typed" reopen on the code
  /// screen instead of on a form that no longer knows the account exists.
  String? get pendingVerification => _pendingVerification;

  void setPendingVerification(String? email) {
    if (email == _pendingVerification) return;
    _pendingVerification = email;
    unawaited(
      email == null
          ? _prefs?.remove(_pendingKey)
          : _prefs?.setString(_pendingKey, email),
    );
  }
}
