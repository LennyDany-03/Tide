import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../config/milestone_catalog.dart';
import '../theme/tide_palette.dart';
import '../theme/tide_theme.dart';
import 'auth/auth_service.dart';
import 'auth/demo_auth_service.dart';
import 'device_flags.dart';
import 'habits/demo_habit_repository.dart';
import 'habits/habit_repository.dart';
import 'models/celebration_cue.dart';
import 'models/day_summary.dart';
import 'models/habit.dart';
import 'models/milestone.dart';
import 'streak_calculator.dart';
import 'tide_scope.dart';

/// The single source of truth for the running app.
///
/// Habits belong to the signed-in account. The store changes its own list
/// first, so a log lands under the finger rather than after a round trip,
/// then hands the change to [repository], which keeps a copy on the device,
/// gets the write to the server when it can, and reports what changed on the
/// account's other devices. Those reports come back through [_applyRemote]
/// and move the same streaks, stats and heatmaps a tap here does.
///
/// Who is signed in comes from [auth] and survives a restart until the
/// person logs out; whether this device has seen onboarding, whether an
/// account has had its tour, and whether a sign-up is waiting on its emailed
/// code come from [flags]. Preferences and the palette are still per session.
class TideStore extends ChangeNotifier {
  TideStore({
    AuthService? auth,
    DeviceFlags? flags,
    HabitRepository? repository,
  }) : auth = auth ?? DemoAuthService(),
       flags = flags ?? DeviceFlags.memory(),
       repository = repository ?? DemoHabitRepository() {
    _habits = this.repository.cached(this.auth.currentAccount?.id);
    _acknowledgedMilestones = _unlockedIds().toSet();
    firstRun = !this.flags.onboardingSeen;
    _remoteChanges = this.repository.changes.listen(_applyRemote);
    _restore(this.auth.currentAccount);
    _accountChanges = this.auth.accountChanges.listen(
      _onAccountChanged,
      onError: (Object error) => debugPrint('Auth state error: $error'),
    );
  }

  /// Who holds the accounts: Supabase in a real build, memory in tests.
  final AuthService auth;

  /// What this device remembers between launches.
  final DeviceFlags flags;

  /// Where habits are kept: Supabase in a real build, memory in tests.
  final HabitRepository repository;

  late final StreamSubscription<TideAccount?> _accountChanges;
  late final StreamSubscription<HabitChange> _remoteChanges;

  List<Habit> _habits = const [];
  late Set<String> _acknowledgedMilestones;

  /// Bumped on every cue so the overlay has a fresh widget identity.
  int _cueNonce = 0;

  // --- Account ----------------------------------------------------------

  TideAccount? _account;

  /// The signed-in account, or null.
  TideAccount? get account => _account;

  bool get signedIn => _account != null;

  String get accountName => _account?.displayName ?? 'You';
  String get accountEmail => _account?.email ?? '';

  /// Changes only when somebody signs in or out — never on a habit logged.
  /// The router listens to this rather than to the store, so it re-checks
  /// its guards twice a session instead of on every tap.
  Listenable get sessionChanges => _session;
  final ValueNotifier<String?> _session = ValueNotifier<String?>(null);

  /// The account that just arrived is a new one: the welcome says "Welcome"
  /// rather than "Welcome back", and Today opens empty.
  bool get welcomingNewAccount => _welcomingNew;
  bool _welcomingNew = false;

  /// Today should run the guided tour.
  ///
  /// Once per account, not once per sign-in: the account's profile remembers
  /// it on the server and [flags] remembers it on this device, so neither a
  /// second login nor a reinstall walks somebody round a screen twice.
  bool get tourPending => _tourPending;
  bool _tourPending = false;

  /// Onboarding had not been seen when this launch began.
  ///
  /// Decides whether the account form offers a way back to the explanation.
  /// It does on the launch that showed it; on every launch after, the form
  /// is the front door and an arrow back into a tutorial would be the
  /// tutorial repeating.
  late final bool firstRun;

  /// Onboarding has been read or skipped on this device, ever.
  bool get onboardingComplete => flags.onboardingSeen;

  /// The address of a sign-up waiting on its emailed code, if there is one.
  /// Kept on the device, so closing the app between the code being sent and
  /// being typed reopens on the code screen.
  String? get pendingVerificationEmail => flags.pendingVerification;

  /// Which half of the form the in-flight request came from. Consulted when
  /// the profile cannot say whether an account is new, and cleared once the
  /// account has arrived.
  bool? _creating;

  /// Arrivals in flight, by account id. An account can be announced twice —
  /// by the call that signed it in and by the service's change stream — and
  /// both must resolve to one arrival.
  final Map<String, Future<void>> _arrivals = {};

  static const Duration _profileTimeout = Duration(seconds: 6);

  /// How long log out waits for queued habit writes before letting them go.
  static const Duration _flushTimeout = Duration(seconds: 4);

  // --- Preferences --------------------------------------------------------

  /// The splash has drawn the mark this session, so the welcome step shows
  /// it already whole instead of drawing it a second time.
  bool splashPlayed = false;

  bool isPro = false;

  /// The palette the whole app is drawn in.
  ///
  /// Session-only: the app opens on [TidePalettes.standard] (Midnight) every
  /// launch.
  TidePalette palette = TidePalettes.standard;

  bool dailyReminders = true;
  bool quietHours = false;
  bool weeklyRecap = false;
  bool haptics = true;

  /// Added to the computed best streak by the milestones screen's
  /// "simulate next unlock" control, so the celebration can be seen without
  /// waiting sixty days for it.
  int _simulatedBonus = 0;

  // --- Reads ------------------------------------------------------------

  /// Active habits, unfinished ones first.
  ///
  /// Home relies on this ordering: a completed habit sinks toward the
  /// bottom, which is what the FLIP-style reorder animates between.
  List<Habit> get habits {
    final active = _habits.where((h) => !h.paused).toList();
    final today = DateUtils.dateOnly(DateTime.now());
    active.sort((a, b) {
      final aDone = a.isCompleteOn(today) || a.isFrozenOn(today);
      final bDone = b.isCompleteOn(today) || b.isFrozenOn(today);
      if (aDone == bDone) return 0;
      return aDone ? 1 : -1;
    });
    return List.unmodifiable(active);
  }

  /// Everything, including paused habits — used by history and settings.
  List<Habit> get allHabits => List.unmodifiable(_habits);

  Habit? habitById(String id) {
    for (final habit in _habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  bool get canAddHabit =>
      isPro ||
      _habits.where((h) => !h.paused).length < AppConstants.freeHabitLimit;

  int get activeHabitCount => _habits.where((h) => !h.paused).length;

  DaySummary summaryFor(DateTime date) =>
      StreakCalculator.daySummary(_habits, date);

  DaySummary get today => summaryFor(DateTime.now());

  List<HabitDayEntry> breakdownFor(DateTime date) =>
      StreakCalculator.dayBreakdown(_habits, date);

  double get weeklyRate => StreakCalculator.weeklyRate(_habits);

  double get lastWeeklyRate {
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));
    return StreakCalculator.weeklyRate(_habits, asOf: lastWeek);
  }

  List<double> weeklySeries({int weeks = 8}) =>
      StreakCalculator.weeklySeries(_habits, weeks: weeks);

  List<double> get weekdayRates => StreakCalculator.weekdayRates(_habits);

  int freezesSpent({int days = 30}) =>
      StreakCalculator.freezesSpent(_habits, days: days);

  int get freezesRemaining =>
      _habits.fold(0, (sum, h) => sum + h.freezesRemaining);

  /// The longest streak currently running — the figure Home reports beside
  /// the weekly rate. Distinct from [allTimeBestStreak], which is what
  /// milestones are measured against.
  int get bestActiveStreak {
    var best = 0;
    for (final habit in _habits) {
      if (habit.paused) continue;
      final streak = StreakCalculator.currentStreak(habit);
      if (streak > best) best = streak;
    }
    return best;
  }

  int get allTimeBestStreak =>
      StreakCalculator.bestStreakAcross(_habits) + _simulatedBonus;

  int get cleanStreak => StreakCalculator.cleanStreak(_habits);

  int currentStreakOf(Habit habit) => StreakCalculator.currentStreak(habit);

  int bestStreakOf(Habit habit) => StreakCalculator.bestStreak(habit);

  double rateOf(Habit habit, {int days = 30}) =>
      StreakCalculator.completionRate(habit, days: days);

  // --- Celebration cues -------------------------------------------------

  CelebrationCue? _pendingHabitCue;

  /// A habit that has just been finished and not yet been celebrated.
  ///
  /// Read by the celebration overlay mounted above the router, so the
  /// reward plays wherever the log was made from.
  CelebrationCue? get pendingHabitCue => _pendingHabitCue;

  void clearHabitCue() {
    if (_pendingHabitCue == null) return;
    _pendingHabitCue = null;
    notifyListeners();
  }

  // --- Milestones -------------------------------------------------------

  List<MilestoneStatus> get milestones {
    final best = allTimeBestStreak;
    final clean = cleanStreak;

    return MilestoneCatalog.all.map((milestone) {
      final value = milestone.kind == MilestoneKind.streak ? best : clean;
      return MilestoneStatus(
        milestone: milestone,
        unlocked: value >= milestone.threshold,
        progress: (value / milestone.threshold).clamp(0.0, 1.0),
      );
    }).toList();
  }

  int get unlockedMilestoneCount => milestones.where((m) => m.unlocked).length;

  Iterable<String> _unlockedIds() =>
      milestones.where((m) => m.unlocked).map((m) => m.milestone.id);

  /// A milestone that has become unlocked but has not yet been celebrated.
  /// The achievements screen reads this, plays the burst, then acknowledges.
  Milestone? get pendingCelebration {
    for (final status in milestones) {
      if (status.unlocked &&
          !_acknowledgedMilestones.contains(status.milestone.id)) {
        return status.milestone;
      }
    }
    return null;
  }

  void acknowledgeCelebration(Milestone milestone) {
    _acknowledgedMilestones.add(milestone.id);
    notifyListeners();
  }

  /// Pushes the best streak far enough to cross the next locked threshold.
  /// A demo affordance, kept because the unlock burst is the biggest moment
  /// in the app and otherwise unreachable.
  void simulateNextUnlock() {
    final locked = milestones.where(
      (m) => !m.unlocked && m.milestone.kind == MilestoneKind.streak,
    );
    if (locked.isEmpty) return;
    final next = locked.first.milestone;
    _simulatedBonus += next.threshold - allTimeBestStreak;
    notifyListeners();
  }

  // --- Mutations --------------------------------------------------------
  //
  // Each one changes the list, then hands [repository] the rows it touched.
  // The repository ignores writes while nobody is signed in, so none of these
  // need to check.

  /// Logs [amount] against [habitId] for [date], replacing whatever was
  /// there. Passing null logs the habit's full target.
  void log(String habitId, {num? amount, DateTime? date}) {
    final day = DateUtils.dateOnly(date ?? DateTime.now());
    final before = habitById(habitId);
    final wasComplete = before?.isCompleteOn(day) ?? false;

    _mutate(habitId, (habit) {
      final logs = Map<DateTime, num>.from(habit.logs);
      logs[day] = amount ?? habit.target;
      final frozen = Set<DateTime>.from(habit.frozenDays)..remove(day);
      return habit.copyWith(logs: logs, frozenDays: frozen);
    });
    _saveEntry(habitId, day);

    _raiseCue(habitId, day: day, wasComplete: wasComplete);
  }

  /// Raises a celebration cue if this log is the one that finished the
  /// habit.
  ///
  /// Two guards, both of them deliberate. It fires on the *transition* into
  /// complete, so topping a quantity habit up from 8 to 9 is silent — the
  /// reward belongs to the glass that finished the target, not to every one
  /// after it. And it fires only for today: backfilling a missed Tuesday
  /// from the calendar is bookkeeping, and throwing a full-screen party
  /// over tidying up last week's history would cheapen the one that happens
  /// when you actually do the thing.
  void _raiseCue(
    String habitId, {
    required DateTime day,
    required bool wasComplete,
  }) {
    if (wasComplete) return;
    if (day != DateUtils.dateOnly(DateTime.now())) return;

    final habit = habitById(habitId);
    if (habit == null || !habit.isCompleteOn(day)) return;

    _pendingHabitCue = CelebrationCue(
      habitId: habit.id,
      habitName: habit.name,
      glyph: habit.glyph,
      type: CelebrationCueType.completion,
      streak: StreakCalculator.currentStreak(habit),
      dayComplete: summaryFor(day).isFullyLogged,
      nonce: _cueNonce++,
    );
    notifyListeners();
  }

  /// Clears a day's log — used by the context menu and by tapping an
  /// already-logged day.
  void unlog(String habitId, {DateTime? date}) {
    final day = DateUtils.dateOnly(date ?? DateTime.now());
    _mutate(habitId, (habit) {
      final logs = Map<DateTime, num>.from(habit.logs)..remove(day);
      return habit.copyWith(logs: logs);
    });
    _saveEntry(habitId, day);
  }

  /// Spends one freeze token so a missed day does not break the loop.
  /// Returns false when the habit has no freezes left.
  bool freeze(String habitId, {DateTime? date}) {
    final habit = habitById(habitId);
    if (habit == null || habit.freezesRemaining <= 0) return false;
    final day = DateUtils.dateOnly(date ?? DateTime.now());
    if (habit.isFrozenOn(day)) return false;

    _mutate(habitId, (h) {
      return h.copyWith(
        frozenDays: Set<DateTime>.from(h.frozenDays)..add(day),
        freezesRemaining: h.freezesRemaining - 1,
      );
    });
    _saveHabit(habitId);
    _saveEntry(habitId, day);
    _pendingHabitCue = CelebrationCue(
      habitId: habit.id,
      habitName: habit.name,
      glyph: habit.glyph,
      type: CelebrationCueType.freeze,
      streak: StreakCalculator.currentStreak(habit),
      dayComplete: false,
      nonce: _cueNonce++,
    );
    notifyListeners();
    return true;
  }

  /// Reverses a freeze for a day and returns its token to this habit.
  bool unfreeze(String habitId, {DateTime? date}) {
    final habit = habitById(habitId);
    final day = DateUtils.dateOnly(date ?? DateTime.now());
    if (habit == null || !habit.isFrozenOn(day)) return false;

    _mutate(habitId, (h) {
      final frozen = Set<DateTime>.from(h.frozenDays)..remove(day);
      return h.copyWith(
        frozenDays: frozen,
        freezesRemaining:
            (h.freezesRemaining + 1).clamp(0, h.freezeAllowance).toInt(),
      );
    });
    _saveHabit(habitId);
    _saveEntry(habitId, day);
    return true;
  }

  void addHabit(Habit habit) {
    _habits = [..._habits, habit];
    repository.saveHabit(habit);
    for (final day in {...habit.logs.keys, ...habit.frozenDays}) {
      repository.saveEntry(habit, day);
    }
    _changed();
  }

  void updateHabit(Habit habit) {
    _habits = [
      for (final existing in _habits)
        if (existing.id == habit.id) habit else existing,
    ];
    repository.saveHabit(habit);
    _changed();
  }

  void deleteHabit(String habitId) {
    _habits = _habits.where((h) => h.id != habitId).toList();
    repository.removeHabit(habitId);
    _changed();
  }

  void togglePause(String habitId) {
    _mutate(habitId, (habit) => habit.copyWith(paused: !habit.paused));
    _saveHabit(habitId);
  }

  /// The intro has been read, or skipped. Distinct from [signedIn]: this
  /// only decides whether a launch replays the explanation, and it is kept
  /// on the device so no launch ever does twice.
  void completeOnboarding() {
    if (flags.onboardingSeen) return;
    flags.markOnboardingSeen();
    notifyListeners();
  }

  // --- Changes from elsewhere ---------------------------------------------

  /// A change that did not start in this app: the server's copy arriving, or
  /// a tap on another of the account's devices.
  ///
  /// Nothing is written back — it is already on the server — and nothing is
  /// celebrated. The reward belongs to the moment somebody finishes a habit,
  /// and that moment happened on the other phone.
  void _applyRemote(HabitChange change) {
    if (change.accountId != _account?.id) return;

    switch (change) {
      case HabitsReplaced(:final habits):
        _habits = habits;
        // Badges this history already earned were earned some other day,
        // perhaps somewhere else. Opening Milestones should not burst each
        // of them open as though it had just happened.
        _acknowledgedMilestones.addAll(_unlockedIds());
      case HabitSaved(:final habit):
        final existing = habitById(habit.id);
        _habits = existing == null
            ? [..._habits, habit]
            : [
                for (final other in _habits)
                  if (other.id == habit.id)
                    habit.copyWith(
                      logs: existing.logs,
                      frozenDays: existing.frozenDays,
                    )
                  else
                    other,
              ];
      case HabitRemoved(:final habitId):
        if (habitById(habitId) == null) return;
        _habits = _habits.where((h) => h.id != habitId).toList();
        if (_pendingHabitCue?.habitId == habitId) _pendingHabitCue = null;
      case HabitEntrySaved(:final entry):
        // An entry for a habit this list does not have yet means the habit's
        // own announcement was missed; the next snapshot brings both.
        if (habitById(entry.habitId) == null) return;
        _habits = [
          for (final habit in _habits)
            if (habit.id == entry.habitId) entry.applyTo(habit) else habit,
        ];
    }
    _changed();
  }

  // --- Account actions ----------------------------------------------------
  //
  // None of these navigate. Each resolves once the account has *arrived* —
  // history chosen, tour decided — and the router's guard, listening to
  // [sessionChanges], moves the app on from wherever it is.

  /// Throws [AuthFailure].
  Future<void> logIn({required String email, required String password}) =>
      _signingIn(
        creating: false,
        request: () => auth.logIn(email: email, password: password),
      );

  /// Resolves to [SignUpOutcome.needsCode] when the account is waiting on its
  /// emailed code — nothing has signed in then, and the address is kept as
  /// [pendingVerificationEmail]. Throws [AuthFailure].
  Future<SignUpOutcome> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    _creating = true;
    try {
      final outcome = await auth.createAccount(
        name: name,
        email: email,
        password: password,
      );
      switch (outcome) {
        case SignUpOutcome.needsCode:
          flags.setPendingVerification(email.trim());
          notifyListeners();
        case SignUpOutcome.signedIn:
          final account = auth.currentAccount;
          if (account != null) await _adopt(account);
      }
      return outcome;
    } finally {
      _creating = null;
    }
  }

  /// Confirms the pending sign-up with its emailed code, which also signs
  /// the account in. Throws [AuthFailure]; the sign-up stays pending.
  Future<void> verifyEmailCode(String code) async {
    final email = pendingVerificationEmail;
    if (email == null) {
      throw const AuthFailure(
        AuthProblem.unknown,
        'No sign-up is waiting on a code.',
      );
    }
    await _signingIn(
      creating: true,
      request: () => auth.verifyEmailCode(email: email, code: code),
    );
  }

  /// Emails the pending sign-up a fresh code. Throws [AuthFailure].
  Future<void> resendEmailCode() async {
    final email = pendingVerificationEmail;
    if (email == null) {
      throw const AuthFailure(
        AuthProblem.unknown,
        'No sign-up is waiting on a code.',
      );
    }
    await auth.resendEmailCode(email: email);
  }

  /// Log in found [email] unconfirmed: its sign-up is picked back up.
  void beginVerification(String email) {
    flags.setPendingVerification(email.trim());
    notifyListeners();
  }

  /// "Use a different email" — the pending sign-up is let go.
  void abandonVerification() {
    if (flags.pendingVerification == null) return;
    flags.setPendingVerification(null);
    notifyListeners();
  }

  /// Throws [AuthFailure].
  Future<void> continueWithGoogle({required bool creating}) => _signingIn(
    creating: creating,
    request: () => auth.continueWithGoogle(creating: creating),
  );

  Future<void> _signingIn({
    required bool creating,
    required Future<TideAccount> Function() request,
  }) async {
    _creating = creating;
    try {
      await _adopt(await request());
    } finally {
      _creating = null;
    }
  }

  /// Ends the session here whether or not the server hears about it: the
  /// session is removed from the device before the network call is made,
  /// so an offline log-out still logs out.
  ///
  /// Habit writes still queued get a few seconds to reach the server first,
  /// while there is still a session allowed to make them. Whatever has not
  /// gone by then is let go with the rest of the account's copy on this
  /// device.
  Future<void> logOut() async {
    if (repository.hasPendingWrites) {
      await repository.flush().timeout(_flushTimeout, onTimeout: () {});
    }
    try {
      await auth.logOut();
    } catch (error) {
      debugPrint('Log out did not reach the server: $error');
    }
    _release();
  }

  /// Deletes the account on the server for good, then leaves it the way
  /// [logOut] does.
  ///
  /// Unlike log out, this does not go ahead offline. An account that looked
  /// deleted on this device while it still existed on the server would be
  /// worse than a refusal, so a failure throws [AuthFailure] and the account
  /// stays signed in to try again.
  Future<void> deleteAccount() async {
    final account = _account;
    if (account == null) return;
    // Recorded before the request, not after it: the service's own sign-out
    // can reach [_release] through the change stream before this call
    // returns, and by then the router must already know that a signed-out
    // app is owed a farewell rather than the account form.
    _deletedEmail = account.email;
    try {
      await auth.deleteAccount();
    } catch (_) {
      _deletedEmail = null;
      rethrow;
    }
    _release();
  }

  /// The address of the account deleted this session, while its farewell is
  /// still owed. Not kept on the device: a relaunch has nobody to see off.
  String? get deletedAccountEmail => _deletedEmail;
  String? _deletedEmail;

  /// The farewell has been read. Does not notify: the screen leaving is what
  /// moves the app on, and nothing on screen is drawn from this.
  void acknowledgeDeletion() => _deletedEmail = null;

  void finishTour() {
    if (!_tourPending) return;
    _tourPending = false;
    notifyListeners();

    final account = _account;
    if (account == null) return;
    flags.markTourDone(account.id);
    unawaited(_saveTour(account));
  }

  // --- Account arrival ----------------------------------------------------

  /// A session that was already on the device at launch. Adopted at once,
  /// so the first screen is chosen without waiting on the network; whether
  /// a tour is still owed is checked behind it.
  ///
  /// Its habits were read from the device's copy in the constructor, so
  /// Today draws them on the first frame; the server's copy replaces them
  /// once it arrives.
  void _restore(TideAccount? account) {
    if (account == null) return;
    _account = account;
    _session.value = account.id;
    flags
      ..markOnboardingSeen()
      ..setPendingVerification(null);
    repository.open(account.id);
    unawaited(_armTourIfOwed(account));
  }

  void _onAccountChanged(TideAccount? next) {
    if (next == null) {
      _release();
    } else {
      unawaited(_adopt(next));
    }
  }

  Future<void> _adopt(TideAccount next) {
    final current = _account;
    if (current != null && current.id == next.id) {
      // The same person with fresher details — a linked Google identity, a
      // refreshed token. No arrival, no welcome.
      if (current != next) {
        _account = next;
        notifyListeners();
      }
      return Future<void>.value();
    }
    // A block body on purpose: `remove` returns the future being completed,
    // and `whenComplete` waits on whatever its callback returns — an arrow
    // here makes the arrival wait on itself forever.
    return _arrivals[next.id] ??= _arrive(next).whenComplete(() {
      _arrivals.remove(next.id);
    });
  }

  Future<void> _arrive(TideAccount next) async {
    final creating = _creating;

    bool? toured;
    try {
      toured = await auth.tourCompleted(next).timeout(_profileTimeout);
    } catch (error) {
      debugPrint('Could not read the profile for ${next.id}: $error');
    }
    // Signed out again, or replaced, while the profile was on its way.
    if (auth.currentAccount?.id != next.id) return;

    // The profile is the authority on whether an account is new. Without
    // it, the button that was pressed is the best remaining evidence — and
    // an account that arrived on its own is treated as returning rather
    // than having its history cleared on a guess.
    final seenHere = flags.tourDone(next.id);
    final isNew = !(toured ?? !(creating ?? false)) && !seenHere;
    if (seenHere && toured == false) unawaited(_saveTour(next));

    _account = next;
    _welcomingNew = isNew;
    _tourPending = isNew;
    flags
      ..markOnboardingSeen()
      ..setPendingVerification(null);

    // A new account opens genuinely empty — the one moment an empty app is
    // the honest thing to show, and the tour is what keeps it from reading
    // as broken. A returning one opens on whatever this device kept of it,
    // and the server's copy replaces that as soon as it arrives.
    repository.open(next.id);
    _habits = isNew ? const [] : repository.cached(next.id);
    _simulatedBonus = 0;
    _pendingHabitCue = null;
    _acknowledgedMilestones = isNew ? {} : _unlockedIds().toSet();
    repository.remember(_habits);

    _session.value = next.id;
    notifyListeners();
  }

  Future<void> _armTourIfOwed(TideAccount account) async {
    if (flags.tourDone(account.id)) return;
    try {
      final toured = await auth.tourCompleted(account).timeout(_profileTimeout);
      if (toured || _tourPending || _account?.id != account.id) return;
      _tourPending = true;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not check the tour for ${account.id}: $error');
    }
  }

  void _release() {
    if (_account == null) return;
    _account = null;
    _tourPending = false;
    _welcomingNew = false;
    _pendingHabitCue = null;
    // The list itself stays until the next account arrives, so the screen on
    // its way out does not flash empty. The device's copy goes now.
    unawaited(repository.close(forget: true));
    _session.value = null;
    notifyListeners();
  }

  Future<void> _saveTour(TideAccount account) async {
    try {
      await auth.markTourCompleted(account);
    } catch (error) {
      debugPrint('Tour not saved to the profile yet: $error');
    }
  }

  // --- Sync ---------------------------------------------------------------

  /// Where the account's habits stand with the server.
  SyncStatus get syncStatus => repository.status.value;

  /// When the server last confirmed this device's habits. Null until it has,
  /// and always null with no project behind the app.
  DateTime? get lastSynced => repository.lastSynced;

  /// Pull to refresh: sends whatever is still queued and reads the account
  /// back. Resolves once both are done or have failed; never throws.
  Future<void> sync() => repository.refresh();

  // --- Settings -----------------------------------------------------------

  void setPreference({
    bool? dailyReminders,
    bool? quietHours,
    bool? weeklyRecap,
    bool? haptics,
    bool? isPro,
  }) {
    this.dailyReminders = dailyReminders ?? this.dailyReminders;
    this.quietHours = quietHours ?? this.quietHours;
    this.weeklyRecap = weeklyRecap ?? this.weeklyRecap;
    this.haptics = haptics ?? this.haptics;
    this.isPro = isPro ?? this.isPro;
    notifyListeners();
  }

  /// Switches the app to [next] and repaints what is on screen in it.
  void setPalette(TidePalette next) {
    if (identical(next, palette)) return;
    palette = next;
    TideTheme.applyPalette(next);
    notifyListeners();
  }

  /// A fresh habit id: a version 4 UUID, because `habits.id` on the server is
  /// a uuid the app chooses. A habit made offline needs its id before the
  /// server has seen it, so its first logged day can be queued against it.
  ///
  /// Ids are only ever generated here, so no two habits can collide.
  String newHabitId() {
    final bytes = List<int>.generate(16, (_) => _ids.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static final Random _ids = Random.secure();

  void _mutate(String habitId, Habit Function(Habit) transform) {
    _habits = [
      for (final habit in _habits)
        if (habit.id == habitId) transform(habit) else habit,
    ];
    _changed();
  }

  /// The list has changed: the device's copy is refreshed and the screens
  /// redrawn.
  void _changed() {
    repository.remember(_habits);
    notifyListeners();
  }

  void _saveHabit(String habitId) {
    final habit = habitById(habitId);
    if (habit != null) repository.saveHabit(habit);
  }

  void _saveEntry(String habitId, DateTime day) {
    final habit = habitById(habitId);
    if (habit != null) repository.saveEntry(habit, day);
  }

  @override
  void dispose() {
    unawaited(_accountChanges.cancel());
    unawaited(_remoteChanges.cancel());
    unawaited(repository.close());
    _session.dispose();
    super.dispose();
  }
}

/// Convenience so screens can read `context.tide` rather than spelling out
/// the scope lookup on every line.
extension TideStoreContext on BuildContext {
  TideStore get tide => TideScope.of(this);
}
