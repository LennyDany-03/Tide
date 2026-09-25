import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_constants.dart';
import 'config/app_routes.dart';
import 'config/supabase_config.dart';
import 'config/update_config.dart';
import 'screens/tide_call/call_deck.dart';
import 'screens/update/update_dialog.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/demo_auth_service.dart';
import 'services/auth/supabase_auth_service.dart';
import 'services/device_flags.dart';
import 'services/habits/demo_habit_repository.dart';
import 'services/habits/habit_repository.dart';
import 'services/habits/supabase_habit_repository.dart';
import 'services/home_widget/home_widget_bridge.dart';
import 'services/reminders/android_reminder_platform.dart';
import 'services/reminders/darwin_reminder_platform.dart';
import 'services/reminders/reminder_platform.dart';
import 'services/reminders/reminder_scope.dart';
import 'services/reminders/reminder_settings.dart';
import 'services/reminders/reminder_store.dart';
import 'services/tasks/reconnects.dart';
import 'services/tasks/task_local.dart';
import 'services/tasks/task_remote.dart';
import 'services/tasks/task_scope.dart';
import 'services/tasks/task_store.dart';
import 'services/tide_scope.dart';
import 'services/tide_store.dart';
import 'services/updates/update_platform.dart';
import 'services/updates/update_scope.dart';
import 'services/updates/update_store.dart';
import 'theme/tide_colors.dart';
import 'theme/tide_palette.dart';
import 'theme/tide_theme.dart';
import 'widgets/celebration/celebration_host.dart';
import 'widgets/tour/tour_anchor.dart';
import 'widgets/tour/tour_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All of this is read before the first frame, while the native launch
  // window is still up, so the app knows where it is going before it draws
  // anything: a restored session opens Today on the habits this device kept
  // for it, a device that has seen onboarding opens the account form.
  // Supabase restores its session from local storage here and keeps
  // refreshing it for as long as the refresh token is valid — which is until
  // the person logs out.
  final flags = await DeviceFlags.load();
  // The palette this device last chose, in place before the splash draws a
  // single pixel — otherwise the logo would play in Midnight and then snap.
  // The status bar is styled from it too, so light palettes get dark icons.
  TideColors.use(TidePalettes.byId(flags.paletteId ?? ''));
  SystemChrome.setSystemUIOverlayStyle(TideTheme.overlayStyle);
  await _forgetEntitlementCache();

  final AuthService auth;
  final HabitRepository habits;
  TaskRemote? taskRemote;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    auth = SupabaseAuthService(Supabase.instance.client);
    habits = await SupabaseHabitRepository.load(Supabase.instance.client);
    taskRemote = SupabaseTaskRemote(Supabase.instance.client);
  } else {
    if (SupabaseConfig.url.isNotEmpty && !SupabaseConfig.hasValidUrl) {
      debugPrint(
        'Tide: SUPABASE_URL is not a URL (it should be just '
        'https://<project>.supabase.co). Falling back to demo mode.',
      );
    }
    debugPrint(
      'Tide: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set — run with '
      '--dart-define-from-file=.env. Accounts and habits are kept in memory '
      'for this run.',
    );
    auth = DemoAuthService();
    habits = DemoHabitRepository();
  }

  // The to-do list lives on the device first and the server second, so it is
  // set up whether or not a project is configured.
  final taskLocal = await PrefsTaskLocal.open();
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final launchUri = mobile ? await _widgetLaunchUri() : null;

  // Reminders for habits and to-dos alike. Read before the first frame too,
  // for the same reason as a widget tap: a launch from a reminder skips the
  // splash and lands on what it was about.
  final reminderPrefs = await ReminderPrefs.load();
  final reminders = await _reminderPlatform(reminderPrefs);
  final reminderLaunch = await _reminderLaunch(reminders);

  // Only the sideloaded Android build updates itself; iOS and the web are
  // updated by their stores and hosts. A build compiled without a manifest
  // URL (every local run) has no updater at all.
  final updates =
      !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          UpdateConfig.isConfigured
      ? UpdateStore(
          manifestUrl: UpdateConfig.manifestUrl,
          platform: const AndroidUpdatePlatform(),
          prefs: await SharedPreferences.getInstance(),
        )
      : null;

  runApp(
    TideApp(
      // A widget tap is an errand — "choose this widget's habit", "open that
      // task" — and three seconds of logo in front of it reads as the tap
      // not having worked.
      showSplash: launchUri == null && reminderLaunch == null,
      launchUri: launchUri,
      reminderLaunch: reminderLaunch,
      auth: auth,
      flags: flags,
      habits: habits,
      taskLocal: taskLocal,
      taskRemote: taskRemote,
      reminders: reminders,
      reminderPrefs: reminderPrefs,
      reconnects: mobile ? connectionRestored() : null,
      homeShortcuts: mobile,
      widgetBridge: mobile ? HomeWidgetBridge() : null,
      updates: updates,
    ),
  );
}

/// The lock screen's Tide Call. `TideCallActivity` starts a second engine on
/// this entry point rather than on [main], so the one thing reachable over
/// the lock screen is the call: no router, no store, no account.
@pragma('vm:entry-point')
Future<void> tideCallMain() => runTideCall();

/// Native scheduling and ringing on Android, `flutter_local_notifications`
/// on iOS, nothing anywhere else.
Future<ReminderPlatform> _reminderPlatform(ReminderPrefs prefs) async {
  if (kIsWeb) return NoReminderPlatform();
  try {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => await AndroidReminderPlatform.create(prefs),
      TargetPlatform.iOS => await DarwinReminderPlatform.create(),
      _ => NoReminderPlatform(),
    };
  } catch (error) {
    debugPrint('Reminders unavailable: $error');
    return NoReminderPlatform();
  }
}

Future<ReminderOpen?> _reminderLaunch(ReminderPlatform reminders) async {
  try {
    return await reminders.takeLaunch();
  } catch (error) {
    debugPrint('Could not read the reminder launch: $error');
    return null;
  }
}

/// Drops the Tide Pro entitlement `SharedPreferences` blobs left by an
/// earlier build.
///
/// Tide is free and nothing reads these any more, so they are dead bytes on
/// every device that ever ran a build with billing in it. Cheap, idempotent,
/// and silent on failure — a device that cannot clear them still launches.
Future<void> _forgetEntitlementCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('tide.entitlement.')) await prefs.remove(key);
    }
  } catch (error) {
    debugPrint('Could not clear the old entitlement cache: $error');
  }
}

/// The home-screen widget tap that started this process, if one did. Read
/// before `runApp` — the activity and its intent are already attached by the
/// time Dart's `main` runs — so the first frame already knows to skip the
/// splash.
Future<Uri?> _widgetLaunchUri() async {
  try {
    return await HomeWidget.initiallyLaunchedFromHomeWidget();
  } catch (error) {
    debugPrint('Could not read the widget launch: $error');
    return null;
  }
}

class TideApp extends StatefulWidget {
  const TideApp({
    super.key,
    this.startOnboarded = false,
    this.showSplash = false,
    this.auth,
    this.flags,
    this.habits,
    this.taskLocal,
    this.taskRemote,
    this.reminders,
    this.reminderPrefs,
    this.reminderLaunch,
    this.reconnects,
    this.homeShortcuts = false,
    this.widgetBridge,
    this.launchUri,
    this.updates,
  });

  /// Checks for and installs new releases of the sideloaded Android build.
  /// Left null, there is no updater — which is every test and every build
  /// compiled without `UPDATE_MANIFEST_URL`.
  final UpdateStore? updates;

  /// The widget tap that launched the app, handled once the first frame is
  /// up. Later taps, with the app already running, arrive on
  /// [HomeWidget.widgetClicked] instead.
  final Uri? launchUri;

  /// Tests and deep links can skip straight into the shell: onboarding
  /// counts as seen and the demo account is already signed in.
  final bool startOnboarded;

  /// Plays the animated splash before the first screen. On for a real
  /// launch, off by default so tests and deep links land where they asked
  /// to without sitting through three seconds of logo.
  final bool showSplash;

  /// Who holds the accounts. `main` passes Supabase; left null, accounts are
  /// kept in memory, which is what every widget test runs on.
  final AuthService? auth;

  /// What the device remembers between launches. Left null, nothing is.
  final DeviceFlags? flags;

  /// Where habits are kept. `main` passes Supabase; left null, they are kept
  /// in memory and a returning account opens on the demo history.
  final HabitRepository? habits;

  /// Where the to-do list is kept on the device. Left null, in memory.
  final TaskLocal? taskLocal;

  /// The server behind the to-do list. Left null, tasks never leave the
  /// device — which is what every widget test runs on.
  final TaskRemote? taskRemote;

  /// Where habit and to-do reminders are scheduled and rung. Left null,
  /// nothing rings: every test, the web and desktop.
  final ReminderPlatform? reminders;

  /// Settings → Reminders, kept on the device. Left null, in memory.
  final ReminderPrefs? reminderPrefs;

  /// The reminder tap that launched the app, handled once the first frame is
  /// up. Later taps arrive on the reminder store's `opened` stream.
  final ReminderOpen? reminderLaunch;

  /// One event each time the connection comes back, to sync the list.
  final Stream<void>? reconnects;

  /// Registers the launcher's "New task" shortcut. Off in tests, which have
  /// no launcher to register with.
  final bool homeShortcuts;

  /// Pushes habits to the Android home-screen widgets. Left null, nothing is
  /// — which is every non-mobile build and every test.
  final HomeWidgetBridge? widgetBridge;

  @override
  State<TideApp> createState() => _TideAppState();
}

class _TideAppState extends State<TideApp> with WidgetsBindingObserver {
  late final TideStore _store = TideStore(
    auth: widget.auth ?? DemoAuthService(signedIn: widget.startOnboarded),
    flags:
        widget.flags ??
        DeviceFlags.memory(onboardingSeen: widget.startOnboarded),
    repository: widget.habits,
    widgetBridge: widget.widgetBridge,
  );

  late final ReminderStore _reminders = ReminderStore(
    tide: _store,
    platform: widget.reminders,
    prefs: widget.reminderPrefs,
  );

  late final TaskStore _tasks = TaskStore(
    tide: _store,
    local: widget.taskLocal,
    remote: widget.taskRemote,
    reminders: _reminders.taskReminders,
    reconnects: widget.reconnects,
  );

  StreamSubscription<ReminderOpen>? _openedReminders;
  StreamSubscription<Uri?>? _widgetTaps;

  late final GoRouter _router = AppRoutes.build(
    store: _store,
    showSplash: widget.showSplash,
  );

  /// Where the guided tour finds the things it points at. Lives up here
  /// with the store because its two ends — the anchors on Today and in the
  /// tab bar, and the overlay above the router — are in different subtrees.
  final TourAnchorRegistry _anchors = TourAnchorRegistry();

  /// Whether Today is the page on screen.
  ///
  /// The tour lives above the router and points at Today's widgets. Now that
  /// a tour can be owed by an account restored at launch, "a tour is
  /// pending" is no longer the same as "Today is showing" — the splash or
  /// the welcome can be up — so the overlay waits on both.
  final ValueNotifier<bool> _onToday = ValueNotifier<bool>(false);

  /// The palette Material's theme was last built for.
  late TidePalette _palette;

  /// A widget tap that arrived before the session was restored. Opened on
  /// the next [TideStore.sessionChanges] once somebody is signed in.
  Uri? _pendingWidgetLaunch;

  /// The same, for a reminder tap.
  ReminderOpen? _pendingReminder;

  @override
  void initState() {
    super.initState();
    // Tokens are global, so a fresh app — every widget test builds one —
    // starts from its own store's palette rather than whatever the last
    // app left behind.
    _palette = _store.palette;
    TideColors.use(_palette);
    _store.addListener(_onStore);
    _store.sessionChanges.addListener(_openPendingWidgetLaunch);
    _router.routerDelegate.addListener(_trackRoute);
    _reminders.attachTasks(_tasks);
    _openedReminders = _reminders.opened.listen(_openReminder);
    final reminderLaunch = widget.reminderLaunch;
    if (reminderLaunch != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openReminder(reminderLaunch),
      );
    }
    if (widget.homeShortcuts) {
      _registerShortcuts();
      _registerHomeWidgetTaps();
    }
    final updates = widget.updates;
    if (updates != null) {
      updates.addListener(_announceUpdate);
      _onToday.addListener(_announceUpdate);
      unawaited(updates.check());
    }
    if (_observesLifecycle) WidgetsBinding.instance.addObserver(this);
    final launch = widget.launchUri;
    if (launch != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromWidget(launch),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The day may have rolled over, or a widget tap may have changed
    // something, while the app sat backgrounded — push a fresh payload
    // rather than waiting on the next habit mutation.
    if (state != AppLifecycleState.resumed) return;
    if (widget.homeShortcuts) _store.refreshWidgets();
    unawaited(widget.updates?.check(ifStale: true));
  }

  bool get _observesLifecycle => widget.homeShortcuts || widget.updates != null;

  /// Whether the update panel is on screen, so a second notification while
  /// it is up does not stack another one on top.
  bool _announcingUpdate = false;

  /// Shows a newly found release once, on Today.
  ///
  /// Today rather than wherever the app happens to be: a panel arriving over
  /// the habit editor interrupts an errand, and Today is where every launch
  /// lands anyway. After the first showing a release waits in
  /// Settings; only a required update is raised again.
  void _announceUpdate() {
    final updates = widget.updates;
    if (updates == null || _announcingUpdate) return;
    if (!_onToday.value || !updates.shouldAnnounce) return;
    // Listeners can fire mid-build (the route listener does), and a dialog
    // cannot be pushed from there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _router.routerDelegate.navigatorKey.currentContext;
      if (!mounted || context == null || _announcingUpdate) return;
      if (!_onToday.value || !updates.shouldAnnounce) return;
      _announcingUpdate = true;
      updates.markAnnounced();
      showUpdateDialog(
        context,
        updates,
      ).whenComplete(() => _announcingUpdate = false);
    });
  }

  /// A reminder was tapped: open its task, if it is still on this account.
  void _openTask(String taskId) {
    if (!_store.signedIn || _tasks.byId(taskId) == null) return;
    _router.go(Routes.tasks);
    unawaited(_router.push(Routes.task(taskId)));
  }

  static const String _newTaskShortcut = 'new_task';

  /// The launcher's long-press menu: "New task", straight into the field.
  void _registerShortcuts() {
    const actions = QuickActions();
    unawaited(
      actions.initialize((type) {
        if (type != _newTaskShortcut || !_store.signedIn) return;
        _router.go(Routes.tasks);
        _tasks.requestQuickAdd();
      }),
    );
    unawaited(
      actions.setShortcutItems(const [
        ShortcutItem(type: _newTaskShortcut, localizedTitle: 'New task'),
      ]),
    );
  }

  /// Every Android home-screen widget is deep-link only for now: a tap
  /// opens the app rather than acting natively, so there is no in-widget
  /// business logic to keep in sync with [TideStore]/[TaskStore]. See
  /// `android/app/src/main/kotlin/com/example/tide/*WidgetProvider.kt` for
  /// the other half — each tap target's `PendingIntent` carries one of
  /// these URIs.
  void _registerHomeWidgetTaps() {
    _widgetTaps = HomeWidget.widgetClicked.listen(_openFromWidget);
  }

  void _openPendingWidgetLaunch() {
    final pending = _pendingWidgetLaunch;
    if (pending != null && _store.signedIn) _openFromWidget(pending);
    final reminder = _pendingReminder;
    if (reminder != null && _store.signedIn) _openReminder(reminder);
  }

  /// A reminder was tapped. A heads-up or a missed reminder opens what it
  /// was about; a call tapped inside the app (iOS) opens the call itself.
  void _openReminder(ReminderOpen open) {
    if (!_store.signedIn) {
      _pendingReminder = open;
      return;
    }
    _pendingReminder = null;
    switch (open.target) {
      case ReminderOpenTarget.habit:
        if (_store.habitById(open.id) == null) return;
        _router.go(Routes.today);
        unawaited(_router.push(Routes.habit(open.id)));
      case ReminderOpenTarget.task:
        _openTask(open.id);
      case ReminderOpenTarget.call:
        if (open.calls.isEmpty) return;
        unawaited(_router.push(Routes.call, extra: CallRequest(open.calls)));
    }
  }

  void _openFromWidget(Uri? uri) {
    if (uri == null) return;
    if (!_store.signedIn) {
      _pendingWidgetLaunch = uri;
      return;
    }
    _pendingWidgetLaunch = null;
    switch (WidgetLaunch.action(uri)) {
      case 'habit':
        final id = uri.queryParameters['id'];
        if (id == null || _store.habitById(id) == null) return;
        _router.go(Routes.today);
        _store.log(id);
      case 'habit-detail':
        final id = uri.queryParameters['id'];
        if (id == null || _store.habitById(id) == null) return;
        _router.go(Routes.today);
        unawaited(_router.push(Routes.habit(id)));
      case 'today':
        _router.go(Routes.today);
      case 'tasks':
        _router.go(Routes.tasks);
      case 'dashboard':
      case 'insights':
        _router.go(Routes.insights);
      case 'settings':
        _router.go(Routes.settings);
      case 'task':
        final id = uri.queryParameters['id'];
        if (id != null) _openTask(id);
      case 'quick-add':
        _router.go(Routes.today);
        unawaited(_router.push(Routes.newHabit));
      case 'heatmap':
        final id = uri.queryParameters['id'];
        if (id == null || _store.habitById(id) == null) return;
        _router.go(Routes.today);
        unawaited(_router.push(Routes.habit(id)));
      // Tide is free, so nothing is locked and there is no paywall to open.
      // A widget placed by a build that still had one can go on firing these
      // until the launcher redraws it, so they land on Today rather than
      // falling through to nothing.
      case 'upgrade':
      case 'dashboard-locked':
      case 'heatmap-locked':
      case 'recap-locked':
        _router.go(Routes.today);
      case 'setup':
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        final kind = HabitWidgetKind.byName(uri.queryParameters['kind']);
        if (id == null || kind == null) return;
        _router.go(Routes.today);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_router.push(Routes.widgetSetup(id, kind.name)));
        });
    }
  }

  /// Rebuilds the MaterialApp only when the palette actually changed, not on
  /// every habit logged.
  void _onStore() {
    if (identical(_store.palette, _palette)) return;
    setState(() => _palette = _store.palette);
  }

  void _trackRoute() {
    _onToday.value =
        _router.routerDelegate.currentConfiguration.uri.path == Routes.today;
  }

  @override
  void dispose() {
    if (_observesLifecycle) WidgetsBinding.instance.removeObserver(this);
    widget.updates?.removeListener(_announceUpdate);
    _onToday.removeListener(_announceUpdate);
    _router.routerDelegate.removeListener(_trackRoute);
    unawaited(_openedReminders?.cancel());
    unawaited(_widgetTaps?.cancel());
    _tasks.dispose();
    _reminders.dispose();
    _onToday.dispose();
    _store.sessionChanges.removeListener(_openPendingWidgetLaunch);
    _store
      ..removeListener(_onStore)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits above the router so every route — including the sheets
    // pushed on the root navigator — reads the same store.
    final app = TideScope(
      store: _store,
      child: TaskScope(
        store: _tasks,
        child: ReminderScope(
          store: _reminders,
          child: TourAnchorScope(
            registry: _anchors,
            child: MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: TideTheme.current,
              routerConfig: _router,
              builder: (context, child) {
                // Lock text scaling to a sane band: the gauge readouts are a
                // fixed-width instrument panel and fall apart past this.
                // Clamped through the text-scaler aspect alone. Copying the whole
                // `MediaQuery.of` here rebuilt this builder — and the hosts below
                // it — on every frame of the keyboard's slide.
                return MediaQuery.withClampedTextScaling(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.2,
                  // Completion may be logged from Today, the calendar, a detail
                  // screen or a sheet. Keeping this above the router gives all
                  // of them the same reward without duplicating UI glue in four
                  // interaction paths.
                  //
                  // The tour sits under the celebration rather than over it:
                  // the tour's last step opens the add sheet and ends itself, so
                  // the only way the two could overlap is a reward earned while
                  // a scrim is up, and a reward must never be dimmed.
                  child: CelebrationHost(
                    child: TourHost(
                      // The router is not reachable from this builder's own
                      // context — it lives below the app — so the one action the
                      // tour can take is handed in from out here.
                      onAddHabit: () => _router.push(Routes.newHabit),
                      onToday: _onToday,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final updates = widget.updates;
    return updates == null ? app : UpdateScope(store: updates, child: app);
  }
}
