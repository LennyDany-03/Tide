import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_switch.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/account_card.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_row.dart';
import 'widgets/sync_pulse_dot.dart';

/// Account, notifications, sync, data.
///
/// The quiet screen. Rows settle in on arrival, toggles get a small spring,
/// sync keeps its slow pulse — and that is the entire animation budget.
/// Every other screen in Tide competes for attention; this one is where the
/// app stops performing, which is what makes the rest of it feel deliberate
/// rather than merely busy.
///
/// What it was: a bare name row, then three ungrouped columns of
/// left-aligned sentences on open ground. Every line the same size, the
/// same colour, the same shape, in the one screen people arrive at already
/// looking for a specific thing — so finding it meant reading all fourteen.
/// Groups are panels now and every row leads with its own mark, which turns
/// that read into a glance.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmingDelete = false;

  void _exportCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Export prepared — every log, as CSV.',
          style: TideType.label,
        ),
      ),
    );
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
        const Text('Settings', style: TideType.screenTitle),
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
              title: 'Sync and data',
              rows: [
                SettingsRow(
                  label: 'iCloud sync',
                  icon: Icons.cloud_done_rounded,
                  trailing: SyncPulseDot(lastSync: store.lastSync),
                  onTap: store.sync,
                ),
                SettingsRow(
                  label: 'Export CSV',
                  subtitle: 'Every log, as a spreadsheet',
                  icon: Icons.ios_share_rounded,
                  showChevron: true,
                  onTap: _exportCsv,
                ),
                SettingsRow(
                  label: 'Delete all data',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  showChevron: !_confirmingDelete,
                  onTap: () => setState(() => _confirmingDelete = true),
                ),
                // The destructive confirmation expands inline, using the
                // same coral hold as every other delete in the app.
                AnimatedSize(
                  duration: TideMotion.tabSwitch,
                  curve: TideMotion.tabCurve,
                  alignment: Alignment.topCenter,
                  child: _confirmingDelete
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'This removes every habit and every log. It '
                                'cannot be undone.',
                                style: TideType.labelMuted,
                              ),
                              const SizedBox(height: 12),
                              HoldToConfirmButton(
                                label: 'Hold to delete everything',
                                holdingLabel: 'Keep holding…',
                                onConfirm: () {
                                  store.deleteAllData();
                                  setState(() => _confirmingDelete = false);
                                },
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      setState(() => _confirmingDelete = false),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TideType.label.copyWith(
                                        color: TideColors.silt,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
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
                  subtitle: 'Deep water',
                  icon: Icons.palette_outlined,
                  showChevron: true,
                  onTap: () {},
                ),
                SettingsRow(
                  label: 'Help and feedback',
                  icon: Icons.help_outline_rounded,
                  showChevron: true,
                  onTap: () {},
                ),
                SettingsRow(
                  label: 'Restore demo data',
                  subtitle: 'Puts the sample history back',
                  icon: Icons.restore_rounded,
                  showChevron: true,
                  onTap: store.restoreSeed,
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
class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: TideColors.lantern.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TideColors.lantern,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('${AppConstants.appName} 1.0.0', style: TideType.labelMuted),
        const SizedBox(height: 4),
        Text(
          'Habits that move like water',
          style: TideType.labelMuted.copyWith(
            fontSize: 12,
            color: TideColors.silt.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
