import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/reminders/reminder_platform.dart';
import '../../../services/reminders/reminder_scope.dart';
import '../../../services/reminders/reminder_store.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/ripple_burst.dart';
import '../../../widgets/stagger_list.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_level.dart';
import '../../../widgets/tide_surface.dart';
import 'permission_art.dart';

/// "Let the tide find you": what reminders need from the phone, asked one
/// thing at a time.
///
/// Not a list of switches. Each card says in one line why it is being asked
/// for, with a small drawing of it, and offers Allow or Not now — and "not
/// now" is always a full answer: nothing here holds onboarding up, and every
/// one of these can be fixed later from Settings → Reminders.
///
/// Along the bottom, the water rises as each is granted. All of them is a
/// full tide, and a ripple says so.
///
/// Several of these are granted on a system screen rather than in a dialog.
/// Allow opens it, the card waits, and when the app comes back to the
/// foreground the reminder store reads the phone again and the card moves on
/// by itself if the answer was yes.
class PermissionStep extends StatefulWidget {
  const PermissionStep({super.key, required this.done});

  /// Set once every card has had an answer, so the onboarding footer can go
  /// from "Skip for now" to "Next".
  final ValueNotifier<bool> done;

  @override
  State<PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<PermissionStep> {
  /// Answered "not now", or refused in the system's own dialog.
  final Set<ReminderPermission> _passed = {};

  /// Refused in the dialog: the card says so gently before moving on.
  final Set<ReminderPermission> _refused = {};

  /// Sent to the system's settings and not back with a yes yet.
  ReminderPermission? _waiting;

  int _ripple = 0;
  bool _wasFull = false;

  ReminderPermission? _current(ReminderStore reminders) {
    for (final p in reminders.permissionsAsked) {
      if (reminders.permission(p).ok) continue;
      if (_passed.contains(p)) continue;
      return p;
    }
    return null;
  }

  void _report(ReminderStore reminders) {
    final finished = _current(reminders) == null;
    if (widget.done.value != finished) {
      // Reported after the frame: this runs during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.done.value = finished;
      });
    }
    final full =
        reminders.permissionsAsked.isNotEmpty &&
        reminders.grantedCount == reminders.permissionsAsked.length;
    if (full && !_wasFull) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _ripple++);
      });
    }
    _wasFull = full;
  }

  Future<void> _allow(ReminderStore reminders, ReminderPermission p) async {
    setState(() => _waiting = p);
    final state = await reminders.request(p);
    if (!mounted) return;
    setState(() {
      if (state.ok) {
        _waiting = null;
      } else if (p == ReminderPermission.notifications) {
        // A dialog answered no: say so kindly, and move on from there.
        _waiting = null;
        _refused.add(p);
      }
    });
  }

  void _notNow(ReminderPermission p) {
    setState(() {
      _passed.add(p);
      _refused.remove(p);
      if (_waiting == p) _waiting = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ReminderScope.of(context);
    _report(reminders);
    final asked = reminders.permissionsAsked;
    final current = _current(reminders);
    final total = asked.length;
    final granted = reminders.grantedCount;

    return RippleBurst(
      trigger: _ripple,
      origin: Alignment.bottomCenter,
      intensity: 1.8,
      particles: true,
      child: Stack(
        children: [
          // The level along the foot of the page.
          Positioned(
            left: -24,
            right: -24,
            bottom: 0,
            height: 110,
            child: TideLevel(level: total == 0 ? 0 : granted / total),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggerColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Text(
                      'Stay in rhythm',
                      style: TideType.labelMuted.copyWith(
                        color: TideColors.lantern,
                      ),
                    ),
                    Text('Let the tide find you', style: TideType.hero),
                    Text(
                      'Tide can nudge you before a habit and ring when it is '
                      'time, even with the phone locked. Allow what you are '
                      'comfortable with — all of it can be changed later in '
                      'Settings → Reminders.',
                      style: TideType.bodyMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: TideMotion.sheetIn,
                  switchInCurve: TideMotion.sheetCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: current == null
                      ? _Summary(
                          key: const ValueKey('summary'),
                          supported: total > 0,
                          full: total > 0 && granted == total,
                        )
                      : _Card(
                          key: ValueKey(current),
                          permission: current,
                          index: asked.indexOf(current) + 1,
                          count: total,
                          waiting: _waiting == current,
                          refused: _refused.contains(current),
                          onAllow: () => _allow(reminders, current),
                          onNotNow: () => _notNow(current),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.permission,
    required this.index,
    required this.count,
    required this.waiting,
    required this.refused,
    required this.onAllow,
    required this.onNotNow,
  });

  final ReminderPermission permission;
  final int index;
  final int count;
  final bool waiting;
  final bool refused;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final status = refused
        ? 'No problem. You can turn this on later in Settings → Reminders.'
        : waiting
        ? 'Waiting for you in Settings — come back when it is on.'
        : null;
    return TideSurface(
      color: TideColors.shoal,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PermissionArt(permission: permission, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index of $count${permission.optional ? ' · optional' : ''}',
                      style: TideType.labelMuted.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(permission.title, style: TideType.heading),
                    const SizedBox(height: 4),
                    Text(permission.reason, style: TideType.labelMuted),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            alignment: Alignment.topLeft,
            child: status == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      status,
                      style: TideType.label.copyWith(
                        color: refused ? TideColors.silt : TideColors.lantern,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (refused)
            TideButton(
              label: 'Continue',
              variant: TideButtonVariant.secondary,
              onPressed: onNotNow,
            )
          else ...[
            TideButton(label: 'Allow', onPressed: onAllow),
            const SizedBox(height: 4),
            TideButton(
              label: 'Not now',
              variant: TideButtonVariant.ghost,
              onPressed: onNotNow,
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({super.key, required this.supported, required this.full});

  final bool supported;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final title = !supported
        ? 'Reminders ring on your phone'
        : full
        ? 'Full tide'
        : 'Ready when you are';
    final body = !supported
        ? 'Set a reminder on a habit and it arrives on Android and iPhone. '
              'Here, the app keeps them without ringing.'
        : full
        ? 'Every reminder can reach you, on the minute, even locked.'
        : 'Anything left off can be switched on in Settings → Reminders. '
              'Reminders still work — some may be late or quieter.';
    return TideSurface(
      color: TideColors.shoal,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          const PermissionArt(permission: null, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TideType.heading),
                const SizedBox(height: 4),
                Text(body, style: TideType.labelMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
