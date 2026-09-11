import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// The few things this device remembers about itself between launches.
///
/// Habits still live only in memory — see `TideStore`. But once sign-in was
/// real, two facts could no longer be forgotten on every launch without the
/// app visibly repeating itself: that the explanation has been read, and
/// that an account has already been walked round Today. Both are about this
/// device and this person, not about a session, so they are kept here.
class DeviceFlags {
  DeviceFlags._(this._prefs, this._onboardingSeen, this._toursDone);

  /// Remembers nothing past the process — tests, and a caller that has not
  /// loaded storage.
  DeviceFlags.memory({bool onboardingSeen = false})
    : this._(null, onboardingSeen, {});

  static Future<DeviceFlags> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceFlags._(
      prefs,
      prefs.getBool(_onboardingKey) ?? false,
      {...?prefs.getStringList(_toursKey)},
    );
  }

  static const String _onboardingKey = 'tide.onboarding_seen';
  static const String _toursKey = 'tide.tours_done';

  final SharedPreferences? _prefs;
  bool _onboardingSeen;
  final Set<String> _toursDone;

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
}
