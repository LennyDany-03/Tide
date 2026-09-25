import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/reminder_copy.dart';
import '../../services/reminders/reminder_scope.dart';
import '../../services/reminders/reminder_settings.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/reminder_options_editor.dart';
import '../../widgets/settings_group.dart';
import '../../widgets/settings_row.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_dial.dart';
import '../../widgets/tide_switch.dart';
import 'widgets/permission_row.dart';

/// Settings → Reminders: how Tide reaches you, on this phone.
///
/// Three things, in the order somebody arrives looking for them: whether
/// anything rings at all and when it must keep quiet; whether the phone is
/// letting it ring, with a way to fix each thing it is refusing; and how
/// habits and to-dos arrive.
///
/// Every switch here is kept on this device, not the account — see
/// [ReminderSettings] for why.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _pickQuiet(BuildContext context, {required bool start}) async {
    final reminders = ReminderScope.read(context);
    final settings = reminders.settings;
    final picked = await showTideDial(
      context,
      initial: start ? settings.quietStart : settings.quietEnd,
      title: start ? 'Quiet from' : 'Quiet until',
    );
    if (picked == null) return;
    reminders.updateSettings(
      start
          ? settings.copyWith(quietStart: picked)
          : settings.copyWith(quietEnd: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ReminderScope.of(context);
    final settings = reminders.settings;
    final phone = reminders.permissionsAsked.isNotEmpty;
    final fullScreen = reminders.platform.fullScreenCalls;
    final preview = reminders.platform.canPreviewTones
        ? reminders.previewTone
        : null;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.viewPaddingOf(context).top + 16,
              20,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: PressScale(
                      onTap: () => context.pop(),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 21,
                          color: TideColors.bone,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Reminders', style: TideType.screenTitle),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'How Tide reaches you, on this phone.',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 24),
              StaggerColumn(
                spacing: 28,
                children: [
                  SettingsGroup(
                    title: 'Reminders',
                    rows: [
                      SettingsRow(
                        label: 'Reminders',
                        subtitle: settings.enabled
                            ? 'Habits and to-dos ring on this phone'
                            : 'Nothing rings. Each habit keeps its own '
                                  'setting for when this is back on',
                        icon: Icons.notifications_none_rounded,
                        trailing: TideSwitch(
                          value: settings.enabled,
                          onChanged: (value) => reminders.updateSettings(
                            settings.copyWith(enabled: value),
                          ),
                        ),
                      ),
                      SettingsRow(
                        label: 'Quiet hours',
                        subtitle: settings.quietHours
                            ? '${settings.quietLabel} · reminders arrive '
                                  'silently'
                            : 'Reminders ring at any hour',
                        icon: Icons.bedtime_outlined,
                        trailing: TideSwitch(
                          value: settings.quietHours,
                          onChanged: (value) => reminders.updateSettings(
                            settings.copyWith(quietHours: value),
                          ),
                        ),
                      ),
                      if (settings.quietHours) ...[
                        SettingsRow(
                          label: 'Quiet from',
                          subtitle: ReminderCopy.clock(settings.quietStart),
                          icon: Icons.nightlight_outlined,
                          showChevron: true,
                          onTap: () => _pickQuiet(context, start: true),
                        ),
                        SettingsRow(
                          label: 'Quiet until',
                          subtitle: ReminderCopy.clock(settings.quietEnd),
                          icon: Icons.wb_twilight_rounded,
                          showChevron: true,
                          onTap: () => _pickQuiet(context, start: false),
                        ),
                      ],
                    ],
                  ),
                  if (phone)
                    SettingsGroup(
                      title: 'What this phone allows',
                      rows: [
                        for (final permission in reminders.permissionsAsked)
                          PermissionRow(
                            permission: permission,
                            state: reminders.permission(permission),
                            onFix: () => reminders.request(permission),
                          ),
                      ],
                    ),
                  SettingsGroup(
                    title: 'Habits',
                    rows: [
                      _Defaults(
                        note:
                            'New habits start from these. Each habit can '
                            'change its own in its editor.',
                        child: ReminderOptionsEditor(
                          options: settings.habitDefaults,
                          fullScreenCalls: fullScreen,
                          onPreviewTone: preview,
                          onChanged: (options) => reminders.updateSettings(
                            settings.copyWith(habitDefaults: options),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'To-dos',
                    rows: [
                      _Defaults(
                        note: 'Every to-do reminder arrives this way.',
                        child: ReminderOptionsEditor(
                          options: settings.taskDefaults,
                          forTasks: true,
                          fullScreenCalls: fullScreen,
                          onPreviewTone: preview,
                          onChanged: (options) => reminders.updateSettings(
                            settings.copyWith(taskDefaults: options),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A set of defaults, with a line saying what they apply to.
class _Defaults extends StatelessWidget {
  const _Defaults({required this.note, required this.child});

  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(note, style: TideType.labelMuted),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
