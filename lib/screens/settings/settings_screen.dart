import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/tide_switch.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/account_card.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_row.dart';
import 'widgets/sync_pulse_dot.dart';

/// Account, notifications, sync, data.
///
/// The quiet screen. Toggles get a small spring, rows get a background
/// fade, sync gets a slow pulse — and that is the entire animation budget.
/// Every other screen in Tide competes for attention; this one is where the
/// app stops performing, which is what makes the rest of it feel deliberate
/// rather than merely busy.
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
        MediaQuery.paddingOf(context).top + 16,
        20,
        TideTabBar.reservedHeight(context) + 28,
      ),
      children: [
        const Text('Settings', style: TideType.screenTitle),
        const SizedBox(height: 30),

        AccountCard(
          name: store.accountName,
          isPro: store.isPro,
          habitCount: store.activeHabitCount,
          onUpgrade: () => context.push(Routes.upgrade),
        ),
        const SizedBox(height: 40),

        SettingsGroup(
          title: 'Notifications',
          rows: [
            SettingsRow(
              label: 'Daily reminders',
              trailing: TideSwitch(
                value: store.dailyReminders,
                onChanged: (value) =>
                    store.setPreference(dailyReminders: value),
              ),
            ),
            SettingsRow(
              label: 'Quiet hours',
              subtitle: store.quietHours ? '22:00 – 07:00' : null,
              trailing: TideSwitch(
                value: store.quietHours,
                onChanged: (value) => store.setPreference(quietHours: value),
              ),
            ),
            SettingsRow(
              label: 'Weekly recap',
              trailing: TideSwitch(
                value: store.weeklyRecap,
                onChanged: (value) => store.setPreference(weeklyRecap: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),

        SettingsGroup(
          title: 'Sync and data',
          rows: [
            SettingsRow(
              label: 'iCloud sync',
              trailing: SyncPulseDot(lastSync: store.lastSync),
              onTap: store.sync,
            ),
            SettingsRow(
              label: 'Export CSV',
              showChevron: true,
              onTap: _exportCsv,
            ),
            SettingsRow(
              label: 'Delete all data',
              destructive: true,
              showChevron: !_confirmingDelete,
              onTap: () => setState(() => _confirmingDelete = true),
            ),
            // The destructive confirmation expands inline, using the same
            // coral hold as every other delete in the app.
            AnimatedSize(
              duration: TideMotion.tabSwitch,
              curve: TideMotion.tabCurve,
              alignment: Alignment.topCenter,
              child: _confirmingDelete
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
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
                          const SizedBox(height: 8),
                          SettingsRow(
                            label: 'Cancel',
                            onTap: () =>
                                setState(() => _confirmingDelete = false),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        const SizedBox(height: 34),

        SettingsGroup(
          title: 'App',
          rows: [
            SettingsRow(
              label: 'Haptics',
              trailing: TideSwitch(
                value: store.haptics,
                onChanged: (value) => store.setPreference(haptics: value),
              ),
            ),
            SettingsRow(
              label: 'Appearance',
              subtitle: 'Deep water',
              showChevron: true,
              onTap: () {},
            ),
            SettingsRow(
              label: 'Help & feedback',
              showChevron: true,
              onTap: () {},
            ),
            SettingsRow(
              label: 'Restore demo data',
              subtitle: 'Puts the sample history back',
              showChevron: true,
              onTap: store.restoreSeed,
            ),
          ],
        ),
        const SizedBox(height: 34),

        Center(child: Text('Tide 1.0.0', style: TideType.labelMuted)),
      ],
    );
  }
}
