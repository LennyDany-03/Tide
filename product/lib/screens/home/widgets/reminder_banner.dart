import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_routes.dart';
import '../../../services/reminders/reminder_scope.dart';
import '../../../services/tide_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// A quiet line on Today when reminders are switched on but the phone is
/// refusing something they need — notifications turned off in the system
/// settings since, say. Without it the only symptom is a reminder that never
/// comes, which reads as the app forgetting rather than the phone refusing.
///
/// It is checked again every time the app comes back to the foreground, so
/// fixing it in Settings and coming back makes it go. It can be waved away
/// for the session.
class ReminderBanner extends StatelessWidget {
  const ReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribed to the habit store as well: switching a habit's reminder on
    // is what can make this true.
    TideScope.of(context);
    final reminders = ReminderScope.maybeOf(context);
    final show = reminders != null && reminders.needsAttention;
    final missing = reminders?.missing ?? const [];

    return AnimatedSize(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TideSurface(
                color: TideColors.shelf,
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_paused_outlined,
                      size: 20,
                      color: TideColors.silt,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminders cannot reach you',
                            style: TideType.label,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${missing.map((p) => p.title).join(', ')} '
                            '${missing.length == 1 ? 'is' : 'are'} off on '
                            'this phone',
                            style: TideType.labelMuted.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Fix reminders',
                      child: ExcludeSemantics(
                        child: PressScale(
                          onTap: () => context.push(Routes.reminders),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TideColors.lantern.withValues(alpha: 0.12),
                              borderRadius: TideElevation.radius12,
                            ),
                            child: Text(
                              'Fix',
                              style: TideType.label.copyWith(
                                color: TideColors.lantern,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Hide for now',
                      child: ExcludeSemantics(
                        child: PressScale(
                          onTap: () =>
                              ReminderScope.read(context).dismissBanner(),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: TideColors.silt,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
