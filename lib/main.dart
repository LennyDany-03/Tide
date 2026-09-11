import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_constants.dart';
import 'config/app_routes.dart';
import 'config/supabase_config.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/demo_auth_service.dart';
import 'services/auth/supabase_auth_service.dart';
import 'services/device_flags.dart';
import 'services/habits/demo_habit_repository.dart';
import 'services/habits/habit_repository.dart';
import 'services/habits/supabase_habit_repository.dart';
import 'services/tide_scope.dart';
import 'services/tide_store.dart';
import 'theme/tide_colors.dart';
import 'theme/tide_palette.dart';
import 'theme/tide_theme.dart';
import 'widgets/celebration/celebration_host.dart';
import 'widgets/tour/tour_anchor.dart';
import 'widgets/tour/tour_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(TideTheme.overlayStyle);

  // All of this is read before the first frame, while the native launch
  // window is still up, so the app knows where it is going before it draws
  // anything: a restored session opens Today on the habits this device kept
  // for it, a device that has seen onboarding opens the account form.
  // Supabase restores its session from local storage here and keeps
  // refreshing it for as long as the refresh token is valid — which is until
  // the person logs out.
  final flags = await DeviceFlags.load();

  final AuthService auth;
  final HabitRepository habits;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    auth = SupabaseAuthService(Supabase.instance.client);
    habits = await SupabaseHabitRepository.load(Supabase.instance.client);
  } else {
    debugPrint(
      'Tide: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set — run with '
      '--dart-define-from-file=.env. Accounts and habits are kept in memory '
      'for this run.',
    );
    auth = DemoAuthService();
    habits = DemoHabitRepository();
  }

  runApp(TideApp(showSplash: true, auth: auth, flags: flags, habits: habits));
}

class TideApp extends StatefulWidget {
  const TideApp({
    super.key,
    this.startOnboarded = false,
    this.showSplash = false,
    this.auth,
    this.flags,
    this.habits,
  });

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

  @override
  State<TideApp> createState() => _TideAppState();
}

class _TideAppState extends State<TideApp> {
  late final TideStore _store = TideStore(
    auth: widget.auth ?? DemoAuthService(signedIn: widget.startOnboarded),
    flags:
        widget.flags ??
        DeviceFlags.memory(onboardingSeen: widget.startOnboarded),
    repository: widget.habits,
  );

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

  @override
  void initState() {
    super.initState();
    // Tokens are global, so a fresh app — every widget test builds one —
    // starts from its own store's palette rather than whatever the last
    // app left behind.
    _palette = _store.palette;
    TideColors.use(_palette);
    _store.addListener(_onStore);
    _router.routerDelegate.addListener(_trackRoute);
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
    _router.routerDelegate.removeListener(_trackRoute);
    _onToday.dispose();
    _store
      ..removeListener(_onStore)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits above the router so every route — including the sheets
    // pushed on the root navigator — reads the same store.
    return TideScope(
      store: _store,
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
            final scale = MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scale),
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
    );
  }
}
