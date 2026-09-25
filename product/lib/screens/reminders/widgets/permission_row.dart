import 'package:flutter/material.dart';

import '../../../services/reminders/reminder_platform.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/settings_row.dart';

/// One thing the phone has to allow, whether it does, and a Fix button when
/// it does not.
///
/// "Fix" rather than "Allow", because by the time somebody is here it was
/// refused once already, and what the button does next is send them to the
/// system screen where it can be changed.
class PermissionRow extends StatelessWidget {
  const PermissionRow({
    super.key,
    required this.permission,
    required this.state,
    required this.onFix,
  });

  final ReminderPermission permission;
  final PermissionState state;
  final VoidCallback onFix;

  static IconData iconFor(ReminderPermission permission) =>
      switch (permission) {
        ReminderPermission.notifications => Icons.notifications_active_outlined,
        ReminderPermission.exactAlarms => Icons.alarm_rounded,
        ReminderPermission.fullScreen => Icons.fullscreen_rounded,
        ReminderPermission.battery => Icons.battery_charging_full_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final granted = state.ok;
    return SettingsRow(
      label: permission.title,
      subtitle: granted
          ? 'Allowed'
          : permission.optional
          ? 'Optional. ${permission.reason}'
          : permission.reason,
      icon: iconFor(permission),
      onTap: granted ? null : onFix,
      trailing: granted
          ? Icon(Icons.check_rounded, size: 20, color: TideColors.lantern)
          : Semantics(
              button: true,
              label: 'Fix ${permission.title}',
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: onFix,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TideColors.lantern.withValues(alpha: 0.12),
                      borderRadius: TideElevation.radius12,
                      border: Border.all(
                        color: TideColors.lantern.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'Fix',
                      style: TideType.label.copyWith(color: TideColors.lantern),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
