import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../config/milestone_catalog.dart';
import '../config/plan_catalog.dart';
import '../config/pro_features.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_palette.dart';
import '../theme/tide_theme.dart';
import 'auth/auth_service.dart';
import 'auth/demo_auth_service.dart';
import 'billing/billing_service.dart';
import 'billing/demo_billing_service.dart';
import 'billing/entitlement.dart';
import 'billing/payment_record.dart';
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
    BillingService? billing,
  }) : auth = auth ?? DemoAuthService(),
       flags = flags ?? DeviceFlags.memory(),
       repository = repository ?? DemoHabitRepository(),
       billing = billing ?? DemoBillingService() {
    final openAccount = this.auth.currentAccount?.id;
    _habits = this.repository.cached(openAccount);
    // Read before the first frame for the same reason the habits are: an
    // account that paid for Pro must not spend the first second of every
    // launch being told it has five habits and one palette.
    _entitlement = this.billing.cached(openAccount);
    _acknowledgedMilestones = _unlockedIds().toSet();
    firstRun = !this.flags.onboardingSeen;
    _remoteChanges = this.repository.changes.listen(_applyRemote);
    _planChanges = this.billing.changes.listen(_applyEntitlement);
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

  /// Who says whether this account is Pro. Never this class: [billing] relays
  /// the server's answer and nothing here can overrule it.
  final BillingService billing;

  late final StreamSubscription<TideAccount?> _accountChanges;
  late final StreamSubscription<HabitChange> _remoteChanges;
  late final StreamSubscription<Entitlement> _planChanges;

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

  // --- Tide Pro -----------------------------------------------------------
  //
  // `isPro` used to be a bool anybody could set, and the upgrade sheet set it
  // after a fake 700ms wait. It is a read of the server's answer now, and
  // there is deliberately no setter: every gate below asks the same question,
  // so there is exactly one thing to get right and exactly one thing that can
  // be wrong.

  late Entitlement _entitlement;

  /// Which plan this account is on, until when, and whether that is still
  /// running. Drawn by Settings and the paywall.
  Entitlement get entitlement => _entitlement;

  /// The whole question, asked the same way everywhere.
  ///
  /// Computed from the period against the clock rather than stored, so a plan
  /// that ran out while the app was closed is not Pro on the next launch even
  /// if nothing has reached the network yet.
  bool get isPro => _entitlement.isPro;

  /// Whether [feature] is out of reach on this plan.
  ///
  /// The one call every gate makes. A screen that wants to know whether to
  /// draw a lock asks this; it does not ask `isPro` and decide for itself,
  /// because that is how a paywall and an app come to disagree.
  bool locked(ProFeature feature) => !isPro;

  bool allows(ProFeature feature) => !locked(feature);

  /// What a locked control says when it is tapped.
  String lockedBlurb(ProFeature feature) => ProFeatures.of(feature).blurb;

  /// The earliest day a free account may look at, or null on Pro.
  ///
  /// History is not deleted and it is not stopped from syncing — the days are
  /// all there, and they all come back the moment somebody upgrades. What the
  /// free plan gets is a window onto them.
  DateTime? get historyHorizon {
    if (allows(ProFeature.fullHistory)) return null;
    return DateUtils.dateOnly(
      DateTime.now().subtract(
        const Duration(days: AppConstants.freeHistoryDays - 1),
      ),
    );
  }

  /// Whether [date] is inside the window this plan can see. Days in the future
  /// are nobody's to see, on any plan.
  bool canSee(DateTime date) {
    final day = DateUtils.dateOnly(date);
    if (day.isAfter(DateUtils.dateOnly(DateTime.now()))) return false;
    final horizon = historyHorizon;
    return horizon == null || !day.isBefore(horizon);
  }

  /// The most freezes a habit may be given on this plan.
  int get freezeCeiling => allows(ProFeature.carryOverFreezes)
      ? AppConstants.maxFreezeAllowance
      : AppConstants.freeFreezeAllowance;

  // --- Receipts -----------------------------------------------------------
  //
  // Read on demand, kept in memory, never written to the device. There is no
  // FutureBuilder anywhere in this app and there is not one here: the billing
  // screen reads [payments] and [receiptsStatus] synchronously in `build` and
  // draws whatever is true this frame, exactly the way Today reads [habits]
  // and [syncStatus]. The asynchrony is in the action, not in the widget tree.

  List<PaymentRecord> _payments = const [];
  ReceiptsStatus _receiptsStatus = ReceiptsStatus.unread;
  Future<void>? _receiptsLoad;

  /// The account's payment history, newest first. Empty until something has
  /// asked for it.
  List<PaymentRecord> get payments => _payments;

  ReceiptsStatus get receiptsStatus => _receiptsStatus;

  /// Reads the account's receipts. Never throws — the screen draws
  /// [receiptsStatus] instead.
  ///
  /// The list is deliberately *not* cleared while a read is in flight, and not
  /// cleared when one fails. A refresh that emptied the list would flash it
  /// away on every pull, and a failed refresh would take away the receipts
  /// somebody was in the middle of reading.
  ///
  /// Concurrent callers share the one request: the screen's first read and a
  /// pull to refresh land together often enough to matter.
  Future<void> refreshReceipts() {
    final account = _account;
    if (account == null) {
      _forgetReceipts();
      return Future<void>.value();
    }
    return _receiptsLoad ??= _readReceipts(
      account.id,
    ).whenComplete(() => _receiptsLoad = null);
  }

  Future<void> _readReceipts(String accountId) async {
    _receiptsStatus = ReceiptsStatus.loading;
    notifyListeners();
    try {
      final answer = await billing.snapshot();
      // Signed out, or somebody else signed in, while it was on its way. Those
      // receipts belong to an account that is no longer open.
      if (_account?.id != accountId) return;
      _payments = answer.payments;
      _receiptsStatus = ReceiptsStatus.loaded;
    } catch (error) {
      debugPrint('Receipts not read: $error');
      if (_account?.id != accountId) return;
      _receiptsStatus = ReceiptsStatus.failed;
    }
    notifyListeners();
  }

  /// The receipt list belongs to whoever is signed in and to nobody else.
  ///
  /// Nothing is written to the device, so there is nothing to erase — but it
  /// is dropped from memory the instant the account is, on both paths: the one
  /// that signs somebody out and the one that swaps somebody in. Does not
  /// notify; both callers already do.
  void _forgetReceipts() {
    _payments = const [];
    _receiptsStatus = ReceiptsStatus.unread;
  }

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
      allows(ProFeature.unlimitedHabits) ||
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
      // The Pro badge is not counted toward, so it has no partial state:
      // the plan is running or it is not. Giving it a fraction would draw a
      // progress bar toward a purchase, which is the one thing on this
      // screen that must not look like something you are nearly at.
      final value = switch (milestone.kind) {
        MilestoneKind.streak => best,
        MilestoneKind.cleanDays => clean,
        MilestoneKind.pro => isPro ? 1 : 0,
      };
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

  // --- Buying Pro ---------------------------------------------------------

  /// Buys [plan]. Resolves once the server has confirmed the payment and the
  /// gates have opened.
  ///
  /// Throws [BillingFailure]. Two of its problems are not failures and the
  /// sheet draws them differently: [BillingProblem.cancelled] is somebody
  /// closing the payment sheet, and [BillingProblem.pending] means the money
  /// moved and the webhook has not landed — in which case the plan arrives on
  /// its own through [billing]'s change stream, possibly a minute later,
  /// possibly on the next launch.
  ///
  /// Nothing here decides anybody is Pro. The entitlement it returns came back
  /// from the server, past a signature check.
  Future<Entitlement> purchase(BillingPlan plan) async {
    final next = await billing.purchase(
      plan,
      title: AppConstants.appName,
      description: '${plan.title} · ${AppConstants.appName} Pro',
      // The checkout is drawn in the palette the app is in, so the one screen
      // Tide does not draw itself still belongs to it.
      themeColor: TideColors.lantern.toARGB32(),
    );
    _applyEntitlement(next);
    // Only if somebody has already opened the billing screen. The receipt is
    // read back from the server rather than invented from the payment that
    // just succeeded: a store that wrote its own rows of payment history would
    // be the one thing this whole layer is built not to be.
    if (_receiptsStatus != ReceiptsStatus.unread) {
      unawaited(refreshReceipts());
    }
    return next;
  }

  /// Asks the server what this account is entitled to. Never throws.
  Future<void> refreshEntitlement() async =>
      _applyEntitlement(await billing.refresh());

  /// Stops the plan renewing, and on a mandate stops the charge with it.
  /// Every day already paid for stays: Pro runs to the end of the period
  /// either way, which is what the screen has to say before the tap as well
  /// as after it.
  ///
  /// Throws [BillingFailure] — the screen draws it. Nothing here decides
  /// anything; the entitlement applied came back from the server.
  Future<void> cancelPlan() async =>
      _applyEntitlement(await billing.cancelSubscription());

  /// Undo of [cancelPlan], and only on a prepaid period. A cancelled mandate
  /// throws [BillingProblem.resubscribeNeeded]: there is nothing at Razorpay
  /// left to resume, so the screen offers a fresh checkout instead.
  Future<void> resumePlan() async =>
      _applyEntitlement(await billing.resumeSubscription());

  /// A plan arriving: the server's answer, a webhook granting a period while
  /// the app was in somebody's pocket, or a refund taking one back.
  void _applyEntitlement(Entitlement next) {
    if (next == _entitlement) return;
    final was = _entitlement.isPro;
    _entitlement = next;

    // A plan that lapsed does not take a preference with it silently — the
    // recap switch turns itself off rather than staying on and doing nothing,
    // which is the version of this that generates support mail.
    if (was && !next.isPro && weeklyRecap) weeklyRecap = false;

    notifyListeners();
  }

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
    billing.open(account.id);
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
    // Not conditional on [isNew] the way the habits are. A brand-new account
    // genuinely has no history, but it can perfectly well have a plan — the
    // same person reinstalling, or signing in on a second phone — and opening
    // that account on the free plan would take away something they paid for.
    billing.open(next.id);
    _entitlement = billing.cached(next.id);
    _forgetReceipts();
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
    // The plan goes immediately, list and all: the next person to pick up this
    // phone must not find somebody else's Pro.
    _entitlement = Entitlement.free;
    _forgetReceipts();
    unawaited(billing.close(forget: true));
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

  /// Pull to refresh: sends whatever is still queued, reads the account back,
  /// and re-reads the plan. Resolves once all of it is done or has failed;
  /// never throws.
  ///
  /// The plan is in here because pull to refresh is what somebody does when
  /// the app disagrees with what they believe they paid for.
  Future<void> sync() async {
    await Future.wait([
      repository.refresh(),
      // Receipts only once somebody has actually looked at them — pull to
      // refresh on Today is not a reason to fetch an account's payment
      // history. The snapshot carries the entitlement too, so this is not a
      // second round trip.
      if (_receiptsStatus == ReceiptsStatus.unread)
        refreshEntitlement()
      else
        refreshReceipts(),
    ]);
  }

  // --- Settings -----------------------------------------------------------

  /// There is no `isPro` here any more, and that is the point: the one thing
  /// on this screen that costs money is not a preference, and a setter for it
  /// would be a way to become Pro without paying.
  void setPreference({
    bool? dailyReminders,
    bool? quietHours,
    bool? weeklyRecap,
    bool? haptics,
  }) {
    this.dailyReminders = dailyReminders ?? this.dailyReminders;
    this.quietHours = quietHours ?? this.quietHours;
    // Turning the recap *off* is always allowed; turning it on is the Pro
    // half. A gate that also refused to let somebody out would be a trap.
    if (weeklyRecap != null &&
        (!weeklyRecap || allows(ProFeature.weeklyRecap))) {
      this.weeklyRecap = weeklyRecap;
    }
    this.haptics = haptics ?? this.haptics;
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
    unawaited(_planChanges.cancel());
    unawaited(repository.close());
    unawaited(billing.close());
    _session.dispose();
    super.dispose();
  }
}

/// Convenience so screens can read `context.tide` rather than spelling out
/// the scope lookup on every line.
extension TideStoreContext on BuildContext {
  TideStore get tide => TideScope.of(this);
}
