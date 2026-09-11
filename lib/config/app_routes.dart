import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/achievements/achievements_screen.dart';
import '../screens/add_edit_habit/add_edit_habit_screen.dart';
import '../screens/appearance/appearance_sheet.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/habit_detail/habit_detail_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/tide_shell.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/upgrade/upgrade_sheet.dart';
import '../screens/welcome/welcome_screen.dart';
import '../services/tide_store.dart';
import '../theme/tide_motion.dart';
import '../widgets/tide_sheet.dart';

/// Route names, so no screen has to hardcode a path string.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const welcome = '/welcome';
  static const today = '/today';
  static const history = '/history';
  static const insights = '/insights';
  static const settings = '/settings';
  static const milestones = '/milestones';
  static const newHabit = '/habit/new';
  static const upgrade = '/upgrade';
  static const appearance = '/appearance';

  static String habit(String id) => '/today/habit/$id';
  static String editHabit(String id) => '/habit/$id/edit';
}

abstract final class AppRoutes {
  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static GoRouter build({required TideStore store, bool showSplash = false}) {
    // Chosen from what is already on the device, so a launch never shows the
    // wrong screen first: a restored session opens Today, a device that has
    // been through onboarding opens the account form, and only a first
    // launch explains the app.
    final firstScreen = store.signedIn
        ? Routes.today
        : store.onboardingComplete
        ? Routes.auth
        : Routes.onboarding;

    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: showSplash ? Routes.splash : firstScreen,
      refreshListenable: store.sessionChanges,
      redirect: (context, state) => _guard(store, state.uri.path),
      routes: [
        // The launch sequence. A fade in and a fade out, and the same ground
        // colour as the native launch window before it and the screen after
        // it, so the only thing that visibly changes is the mark.
        GoRoute(
          path: Routes.splash,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: TideMotion.sheetIn,
            reverseTransitionDuration: TideMotion.sheetOut,
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
            child: SplashScreen(next: firstScreen),
          ),
        ),

        // A plain fade, explicitly.
        //
        // Left as a default page, this route wore the platform's own
        // transition — on Android a zoom — and onboarding's closing move is
        // a ring travelling to a specific point on the next screen. The
        // page zooming out from under it while it travelled is what made
        // the hand-off read as two animations fighting, and it is the
        // reason the mark appeared to jump size on its way across.
        GoRoute(
          path: Routes.onboarding,
          pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
        ),

        // Sign-up and log-in. A `go` rather than a push in both directions:
        // onboarding and the form are two halves of one entry sequence, and
        // leaving either on a stack means a back gesture inside the app can
        // land on the account screen of an account you already have.
        GoRoute(
          path: Routes.auth,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: TideMotion.sheetIn,
            reverseTransitionDuration: TideMotion.sheetOut,
            // Rises and settles, catching the ring the closing onboarding
            // step is shrinking toward. A plain fade here left the mark
            // materialising at the top of a still page.
            transitionsBuilder: (context, animation, secondary, child) {
              final eased = CurvedAnimation(
                parent: animation,
                curve: TideMotion.sheetCurve,
              );
              return FadeTransition(
                opacity: eased,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(eased),
                  child: child,
                ),
              );
            },
            child: const AuthScreen(),
          ),
        ),

        // Between the account form and Today. Reached only through the
        // guard below, never by a screen asking for it.
        GoRoute(
          path: Routes.welcome,
          pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
        ),

        // The four tabs. A branch keeps its own navigator, so pushing habit
        // detail from Today and then switching tabs and back returns to the
        // detail screen rather than resetting the tab.
        StatefulShellRoute(
          builder: (context, state, shell) => shell,
          navigatorContainerBuilder: (context, shell, children) =>
              TideShell(navigationShell: shell, branches: children),
          // Every branch is preloaded. Branches are lazy by default, which
          // is fine when the only way between them is a tab tap — the new
          // one is built before it is shown. It is not fine with a swipe:
          // the page arriving under your finger would be blank until you
          // let go of it. Four light screens is a cheap price for the
          // incoming page being there the moment it appears.
          branches: [
            StatefulShellBranch(
              preload: true,
              routes: [
                GoRoute(
                  path: Routes.today,
                  builder: (context, state) => const HomeScreen(),
                  routes: [
                    GoRoute(
                      path: 'habit/:id',
                      builder: (context, state) => HabitDetailScreen(
                        habitId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              routes: [
                GoRoute(
                  path: Routes.history,
                  builder: (context, state) => const CalendarScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              routes: [
                GoRoute(
                  path: Routes.insights,
                  builder: (context, state) => const InsightsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              routes: [
                GoRoute(
                  path: Routes.settings,
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),

        // Milestones covers the tab bar — it is a destination you arrive at,
        // not one you browse between.
        GoRoute(
          path: Routes.milestones,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const AchievementsScreen(),
        ),

        // The habit editor. A full page rather than a sheet: it is the
        // longest-lived screen in the app and it used to arrive by scaling
        // a nine-field form out of the FAB's corner over a live blurred
        // page, which is the single most expensive frame budget the app
        // could have spent, on the screen least able to afford it.
        GoRoute(
          path: Routes.newHabit,
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) =>
              _page(state, const AddEditHabitScreen()),
        ),
        GoRoute(
          path: '/habit/:id/edit',
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) => _page(
            state,
            AddEditHabitScreen(habitId: state.pathParameters['id']),
          ),
        ),

        // The paywall stays a sheet. It genuinely is contextual — it
        // interrupts an action and hands it back — and it is on screen for
        // a few seconds, not a few minutes.
        GoRoute(
          path: Routes.upgrade,
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) => _sheet(state, const UpgradeSheet()),
        ),

        // The palette picker. A sheet over Settings rather than a page, so
        // the screen behind it repaints in the palette you tap — the preview
        // is the app itself.
        GoRoute(
          path: Routes.appearance,
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) =>
              _sheet(state, const AppearanceSheet()),
        ),
      ],
    );
  }

  /// Who may be where.
  ///
  /// One rule set instead of a `go` at the end of every account call,
  /// because accounts arrive from places no screen is waiting on: the email
  /// confirmation link opening the app, a restored session, a refresh token
  /// revoked while the app was closed. Wherever the change comes from, the
  /// router hears it through [TideStore.sessionChanges] and puts the person
  /// on the right side of the door.
  static String? _guard(TideStore store, String path) {
    // The splash decides for itself when it is done.
    if (path == Routes.splash) return null;

    final atDoor = path == Routes.onboarding || path == Routes.auth;
    if (store.signedIn) return atDoor ? Routes.welcome : null;

    // Onboarding is once per device. The launch that showed it may still go
    // back to it from the form; no later launch can reach it at all.
    if (path == Routes.onboarding) {
      return store.onboardingComplete && !store.firstRun ? Routes.auth : null;
    }
    if (path == Routes.auth) return null;

    // Everything else is inside the app, and needs an account.
    return store.onboardingComplete ? Routes.auth : Routes.onboarding;
  }

  static CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: TideMotion.sheetIn,
      reverseTransitionDuration: TideMotion.sheetOut,
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: TideMotion.tabCurve,
            ),
            child: child,
          ),
      child: child,
    );
  }

  /// A full page arriving from the right.
  ///
  /// Opaque, so nothing underneath is composited while it is up, and no
  /// blur anywhere — a short slide over a fade is the cheapest transition
  /// that still reads as "forward", and it costs the same on a phone with
  /// four cores as it does on one with eight.
  static CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: TideMotion.tabSwitch,
      reverseTransitionDuration: TideMotion.tabSwitch,
      transitionsBuilder: (context, animation, secondary, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: TideMotion.tabCurve,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: eased,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(eased),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Sheets rise from the bottom edge over a dimmed page.
  static CustomTransitionPage<void> _sheet(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: TideMotion.sheetIn,
      reverseTransitionDuration: TideMotion.sheetOut,
      transitionsBuilder: tideSheetTransition,
      child: child,
    );
  }
}
