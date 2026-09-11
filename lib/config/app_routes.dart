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
import '../screens/upgrade/upgrade_sheet.dart';
import '../theme/tide_motion.dart';
import '../widgets/tide_sheet.dart';

/// Route names, so no screen has to hardcode a path string.
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const auth = '/auth';
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

  static GoRouter build({required bool startOnboarded}) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: startOnboarded ? Routes.today : Routes.onboarding,
      routes: [
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
          pageBuilder: (context, state) => CustomTransitionPage<void>(
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
            child: const OnboardingScreen(),
          ),
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
