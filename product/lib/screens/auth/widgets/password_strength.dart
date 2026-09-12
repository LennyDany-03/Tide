import 'package:flutter/material.dart';

import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_line_gauge.dart';

/// How far along a new password is, as a rising level.
///
/// The same gauge onboarding uses for its own progress, at the same height
/// and on the same curve — a password filling up and a flow filling up are
/// the same idea, so they get the same instrument rather than a red-amber-
/// green meter borrowed from somewhere else. There is no second hue here
/// for "weak": the level *is* the reading, and colouring it would need a
/// hue the palette does not have.
///
/// It scores length first because length is the only factor that reliably
/// matters, then gives credit for mixing character classes. The word beside
/// it is deliberately plain — a bar with no label is a decoration.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({
    super.key,
    required this.password,
    required this.visible,
  });

  final String password;
  final bool visible;

  /// 0..1.
  double get _score {
    if (password.isEmpty) return 0;

    // Length carries most of the weight, and saturates at sixteen.
    final length = (password.length / 16).clamp(0.0, 1.0);

    var classes = 0;
    if (password.contains(RegExp(r'[a-z]'))) classes++;
    if (password.contains(RegExp(r'[A-Z]'))) classes++;
    if (password.contains(RegExp(r'\d'))) classes++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) classes++;

    final variety = (classes - 1).clamp(0, 3) / 3;
    return (length * 0.7 + variety * 0.3).clamp(0.0, 1.0);
  }

  String get _word {
    if (password.length < 8) return 'Too short';
    if (_score < 0.5) return 'Workable';
    if (_score < 0.78) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(child: TideLineGauge(progress: _score)),
                  const SizedBox(width: 12),
                  SizedBox(
                    // Fixed, so the gauge does not change length as the
                    // word beside it changes.
                    width: 66,
                    child: Text(
                      _word,
                      style: TideType.labelMuted,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
