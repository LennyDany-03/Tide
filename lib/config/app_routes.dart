import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/account_deleted/account_deleted_screen.dart';
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
import '../screens/verify_email/verify_email_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../services/tide_store.dart';
import '../theme/tide_motion.dart';
import '../widgets/tide_sheet.dart';

/// Route names, so no screen has to hardcode a path string.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const verifyEmail = '/verify';
  static const welcome = '/welcome';
  static const accountDeleted = '/account-deleted';
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
    // wrong screen first: a restored session opens Today, a sign-up waiting
    // on its code opens the code screen, a device that has been through
    // onboarding opens the account form, and only a first launch explains
    // the app.
    final firstScreen = store.signedIn
        ? Routes.today
        : store.pendingVerificationEmail != null
        ? Routes.verifyEmail
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
        // land on the account screen of an account you already have. The
        // code screen sends people back here with what they had typed.
        GoRoute(
          path: Routes.auth,
          pageBuilder: (context, state) {
            final draft = state.extra;
            return _rise(
              state,
              AuthScreen(draft: draft is AuthDraft ? draft : null),
            );
          },
        ),

        // The emailed code: the second half of creating an account. It
        // rises the same way the form did, because it is the same errand
        // continuing rather than somewhere new.
        GoRoute(
          path: Routes.verifyEmail,
          pageBuilder: (context, state) {
            final delivery = state.extra;
            return _rise(
              state,
              VerifyEmailScreen(
                delivery: delivery is CodeDelivery
                    ? delivery
                    : CodeDelivery.unknown,
              ),
            );
          },
        ),

        // Between the account form and Today. Reached only through the
        // guard below or the code screen's tick, never by a screen asking
        // for it on a whim.
        GoRoute(
          path: Routes.welcome,
          pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
        ),

        // The other end of the same door: after the account is deleted. A
        // fade, like the welcome it mirrors, and likewise reached only
        // through the guard.
        GoRoute(
          path: Routes.accountDeleted,
          pageBuilder: (context, state) =>
              _fade(state, const AccountDeletedScreen()),
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
  /// because accounts arrive from places no screen is waiting on: a restored
  /// session, a refresh token revoked while the app was closed, a sign-out on
  /// another device. Wherever the change comes from, the router hears it
  /// through [TideStore.sessionChanges] and puts the person on the right
  /// side of the door.
  static String? _guard(TideStore store, String path) {
    // The splash decides for itself when it is done.
    if (path == Routes.splash) return null;

    // The code screen. Signed in *here* means the code was just accepted:
    // the screen is playing its tick and hands over to the welcome itself
    // when that is done. Bouncing it the instant the account arrived would
    // cut the confirmation off before anyone saw it.
    if (path == Routes.verifyEmail) {
      if (store.signedIn) return null;
      return store.pendingVerificationEmail == null ? Routes.auth : null;
    }

    // The farewell after deleting the account. It exists only in the moments
    // after a deletion, and hands over to the account form itself on Done.
    if (path == Routes.accountDeleted) {
      if (store.signedIn) return Routes.today;
      if (store.deletedAccountEmail != null) return null;
      return store.onboardingComplete ? Routes.auth : Routes.onboarding;
    }

    final atDoor = path == Routes.onboarding || path == Routes.auth;
    if (store.signedIn) return atDoor ? Routes.welcome : null;

    // Onboarding is once per device. The launch that showed it may still go
    // back to it from the form; no later launch can reach it at all.
    if (path == Routes.onboarding) {
      return store.onboardingComplete && !store.firstRun ? Routes.auth : null;
    }
    if (path == Routes.auth) return null;

    // Everything else is inside the app, and needs an account. An account
    // that was just deleted from in here is seen off before the form.
    if (store.deletedAccountEmail != null) return Routes.accountDeleted;
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

  /// Rises and settles. The account form uses it to catch the ring the
  /// closing onboarding step is shrinking toward — a plain fade there left
  /// the mark materialising at the top of a still page — and the code
  /// screen uses it because it continues the form.
  static CustomTransitionPage<void> _rise(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: TideMotion.sheetIn,
      reverseTransitionDuration: TideMotion.sheetOut,
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
