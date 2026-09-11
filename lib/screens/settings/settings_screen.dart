import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/auth/auth_service.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_mark.dart';
import '../../widgets/tide_switch.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/account_card.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_row.dart';

/// Account, notifications, app.
///
/// The quiet screen. Rows settle in on arrival and toggles get a small
/// spring — and that is the entire animation budget. Every other screen in
/// Tide competes for attention; this one is where the app stops performing,
/// which is what makes the rest of it feel deliberate rather than merely
/// busy.
///
/// What it was: a bare name row, then three ungrouped columns of
/// left-aligned sentences on open ground. Every line the same size, the
/// same colour, the same shape, in the one screen people arrive at already
/// looking for a specific thing — so finding it meant reading all fourteen.
/// Groups are panels now and every row leads with its own mark, which turns
/// that read into a glance.
///
/// The sync-and-data group is gone, and so is the demo-data restore. All
/// four of those rows described machinery that does not exist: there is no
/// service behind iCloud sync, no file behind the CSV export, and the
/// delete and restore controls both operated on an in-memory store that
/// resets itself on every launch anyway. A settings screen that offers
/// four controls over nothing is worse than a shorter one — it is the part
/// of the app that is supposed to tell the truth about how it behaves.
///
/// Log out is last, and held rather than tapped. The session is kept until
/// somebody asks for it to end, so ending it should never be something a
/// thumb scrolling to the colophon does by accident.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// How this account can get back in, which is the useful thing to know
  /// just before leaving it.
  static String _waysIn(TideAccount? account) {
    if (account == null) return '';
    if (account.hasGoogle && account.hasPassword) return 'Google and email';
    if (account.hasGoogle) return 'Google';
    return 'Email and password';
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        TideTabBar.reservedHeight(context) + 28,
      ),
      children: [
        Text('Settings', style: TideType.screenTitle),
        const SizedBox(height: 6),
        Text(
          'Your account, and how Tide behaves.',
          style: TideType.labelMuted,
        ),
        const SizedBox(height: 24),

        StaggerColumn(
          spacing: 28,
          children: [
            AccountCard(
              name: store.accountName,
              email: store.accountEmail,
              avatarUrl: store.account?.avatarUrl,
              isPro: store.isPro,
              habitCount: store.activeHabitCount,
              onUpgrade: () => context.push(Routes.upgrade),
            ),

            SettingsGroup(
              title: 'Notifications',
              rows: [
                SettingsRow(
                  label: 'Daily reminders',
                  subtitle: 'One nudge per habit, at its own time',
                  icon: Icons.notifications_none_rounded,
                  trailing: TideSwitch(
                    value: store.dailyReminders,
                    onChanged: (value) =>
                        store.setPreference(dailyReminders: value),
                  ),
                ),
                SettingsRow(
                  label: 'Quiet hours',
                  subtitle: store.quietHours
                      ? '22:00 – 07:00'
                      : 'Nothing arrives overnight',
                  icon: Icons.bedtime_outlined,
                  trailing: TideSwitch(
                    value: store.quietHours,
                    onChanged: (value) =>
                        store.setPreference(quietHours: value),
                  ),
                ),
                SettingsRow(
                  label: 'Weekly recap',
                  subtitle: 'Sunday evening, the week in one line',
                  icon: Icons.summarize_outlined,
                  trailing: TideSwitch(
                    value: store.weeklyRecap,
                    onChanged: (value) =>
                        store.setPreference(weeklyRecap: value),
                  ),
                ),
              ],
            ),

            SettingsGroup(
              title: 'App',
              rows: [
                SettingsRow(
                  label: 'Haptics',
                  subtitle: 'The small knock when something lands',
                  icon: Icons.vibration_rounded,
                  trailing: TideSwitch(
                    value: store.haptics,
                    onChanged: (value) => store.setPreference(haptics: value),
                  ),
                ),
                SettingsRow(
                  label: 'Appearance',
                  subtitle: store.palette.name,
                  icon: Icons.palette_outlined,
                  showChevron: true,
                  onTap: () => context.push(Routes.appearance),
                ),
                SettingsRow(
                  label: 'Help and feedback',
                  icon: Icons.help_outline_rounded,
                  showChevron: true,
                  onTap: () {},
                ),
              ],
            ),

            SettingsGroup(
              title: 'Account',
              rows: [
                SettingsRow(
                  label: 'Signed in with',
                  subtitle: _waysIn(store.account),
                  icon: Icons.verified_user_outlined,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  // The hold-to-confirm every destructive control in Tide
                  // uses, in its coral. Leaving is destructive here in a
                  // plain sense: habits are not stored, so whatever this
                  // session logged does not come back with the account.
                  child: HoldToConfirmButton(
                    label: 'Hold to log out',
                    holdingLabel: 'Keep holding to log out',
                    onConfirm: () => TideScope.read(context).logOut(),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 34),

        const _Colophon(),
      ],
    );
  }
}

/// The version, and the mark it belongs to.
///
/// A bare "Tide 1.0.0" centred under a settings screen is a string. The
/// mark makes it a sign-off, which is what the end of the last screen in an
/// app should be.
///
/// It is the real logo, not a sketch of it. This used to be a hand-drawn
/// ring and dot standing in for the mark — which, once the logo gained its
/// tide and moon, made the last screen of the app sign off with a different
/// logo from the one on the splash and the icon.
class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Already whole: this is a signature, not an entrance.
        const TideMark(size: 52, strokeWidth: 2.8, drawIn: false),
        const SizedBox(height: 14),
        Text('${AppConstants.appName} 1.0.0', style: TideType.labelMuted),
        const SizedBox(height: 4),
        Text(
          AppConstants.tagline,
          style: TideType.labelMuted.copyWith(
            fontSize: 12,
            color: TideColors.silt.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
