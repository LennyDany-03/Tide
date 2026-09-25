import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The few things this device remembers about itself between launches.
///
/// Habits are the account's and are kept by `HabitRepository`. But once
/// sign-in was real, a few facts could no longer be forgotten on every launch without
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
    this._widgetHabits,
    this._paletteId,
    this._haptics,
    this._weeklyRecap,
  );

  /// Remembers nothing past the process — tests, and a caller that has not
  /// loaded storage.
  DeviceFlags.memory({
    bool onboardingSeen = false,
    String? pendingVerification,
    String? paletteId,
    bool haptics = true,
    bool weeklyRecap = false,
  }) : this._(null, onboardingSeen, {}, pendingVerification, {}, paletteId, haptics, weeklyRecap);

  static Future<DeviceFlags> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceFlags._(
      prefs,
      prefs.getBool(_onboardingKey) ?? false,
      {...?prefs.getStringList(_toursKey)},
      prefs.getString(_pendingKey),
      _decodeWidgetHabits(prefs.getString(_widgetHabitsKey)),
      prefs.getString(_paletteKey),
      prefs.getBool(_hapticsKey) ?? true,
      prefs.getBool(_weeklyRecapKey) ?? false,
    );
  }

  static const String _onboardingKey = 'tide.onboarding_seen';
  static const String _toursKey = 'tide.tours_done';
  static const String _pendingKey = 'tide.pending_verification';
  static const String _widgetHabitsKey = 'tide.widget_habits';
  static const String _paletteKey = 'tide.palette';
  static const String _hapticsKey = 'tide.haptics';
  static const String _weeklyRecapKey = 'tide.weekly_recap';

  final SharedPreferences? _prefs;
  bool _onboardingSeen;
  final Set<String> _toursDone;
  String? _pendingVerification;
  final Map<int, String> _widgetHabits;
  String? _paletteId;
  bool _haptics;
  bool _weeklyRecap;

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

  /// The id of the palette picked on this device, or null for the default.
  ///
  /// Per device rather than per account: it is chosen during onboarding,
  /// before there is an account, and the app has to be drawn in it from the
  /// very first frame of the next launch — before any session is restored.
  String? get paletteId => _paletteId;

  void setPaletteId(String id) {
    if (id == _paletteId) return;
    _paletteId = id;
    unawaited(_prefs?.setString(_paletteKey, id));
  }

  /// Whether the app should knock when something lands (Settings → Haptics).
  ///
  /// A device choice, like the palette — no account should conjure a
  /// different feel on the same phone. Defaults on, because that is the
  /// app as it was written.
  bool get haptics => _haptics;

  void setHaptics(bool value) {
    if (value == _haptics) return;
    _haptics = value;
    unawaited(_prefs?.setBool(_hapticsKey, value));
  }

  /// Whether the weekly recap is delivered on this device (Settings →
  /// Notifications). Defaults off, so nobody is followed home by a recap
  /// they never asked for.
  bool get weeklyRecap => _weeklyRecap;

  void setWeeklyRecap(bool value) {
    if (value == _weeklyRecap) return;
    _weeklyRecap = value;
    unawaited(_prefs?.setBool(_weeklyRecapKey, value));
  }

  /// Which habit each placed Streak or Heatmap widget shows, by the
  /// launcher's widget id.
  ///
  /// Per placed widget, not one pin for all of them: two Heatmap widgets side
  /// by side are two habits. Kept on the device because a widget that forgot
  /// its habit on every restart would ask again every morning. Not scoped to
  /// an account — after switching accounts an id resolves to no habit, and
  /// the widget simply asks again.
  Map<int, String> get widgetHabits => Map.unmodifiable(_widgetHabits);

  void setWidgetHabit(int widgetId, String habitId) {
    if (_widgetHabits[widgetId] == habitId) return;
    _widgetHabits[widgetId] = habitId;
    unawaited(
      _prefs?.setString(
        _widgetHabitsKey,
        jsonEncode({
          for (final entry in _widgetHabits.entries)
            '${entry.key}': entry.value,
        }),
      ),
    );
  }

  static Map<int, String> _decodeWidgetHabits(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (int.tryParse(entry.key) != null && entry.value is String)
            int.parse(entry.key): entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }
}
