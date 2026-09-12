import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/rise.dart';

/// One beat of the billing card's pass, eased inside its own window.
///
/// The easing is applied *here* rather than to the controller, and that is the
/// whole point of the function. Windowing one already-eased value looks
/// equivalent and is not: `easeOutCubic` has covered 73% of its travel by a
/// quarter of the way through, so a beat declared as "the first 62%" actually
/// finishes in the first 150ms of a 560ms pass — which is how the note used to
/// finish opening while the cancel dialog was still on top of it.
///
/// Windows are fractions of [TideMotion.planChange], and everything before
/// [TideMotion.planChangeLeadIn] is dead air on purpose: see that constant.
double planBeat(double t, double from, double to) => TideMotion.planChangeCurve
    .transform(((t - from) / (to - from)).clamp(0, 1));

/// Where the lead-in ends, as a fraction of the pass.
final double planLeadIn =
    TideMotion.planChangeLeadIn.inMilliseconds /
    TideMotion.planChange.inMilliseconds;

/// The note the billing card keeps under a plan that has been cancelled.
///
/// Driven by a [progress] the card owns rather than by a controller of its
/// own, because the same pass turns Cancel into Resume directly below it. One
/// clock means the note cannot finish explaining a button that has not
/// arrived yet.
///
/// Three beats after the lead-in, in the order they are read: the block opens,
/// a margin mark draws down its left edge with it, and the words rise into it
/// last — by which time the dialog that asked the question has gone, and the
/// sentence lands on a screen somebody can actually see.
///
/// The top gap is inside the clip, so a closed note takes no height at all
/// and the card does not carry a stray 14px when nothing is cancelled.
class CancelledNotice extends StatelessWidget {
  const CancelledNotice({
    super.key,
    required this.progress,
    required this.until,
  });

  /// The card's raw pass, 0 = no note, 1 = fully open. Uneased: every beat
  /// below eases its own window out of it.
  final double progress;

  /// The last day already paid for, named so nobody has to take it on trust.
  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final open = planBeat(progress, planLeadIn, 0.68);
    final mark = planBeat(progress, 0.32, 0.75);
    final words = planBeat(progress, 0.58, 1);
    final end = until;

    // Nothing to draw yet: the dialog is still leaving.
    if (open <= 0) return const SizedBox.shrink();

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: open,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                decoration: BoxDecoration(
                  color: TideColors.lantern.withValues(alpha: 0.08 * open),
                  borderRadius: TideElevation.radius12,
                ),
                child: Rise(
                  progress: words,
                  lift: 6,
                  child: Text(
                    'Cancelled. You keep Pro until '
                    '${end == null ? 'the end of your period' : _date(end)}, '
                    'and nothing will be charged.',
                    style: TideType.label.copyWith(
                      color: TideColors.lantern,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              // The mark, drawn downward as the block opens — inset past the
              // corner radius so it stays inside the fill at both ends.
              Positioned(
                left: 2,
                top: 10,
                bottom: 10,
                width: 2,
                child: FractionallySizedBox(
                  alignment: Alignment.topCenter,
                  heightFactor: mark,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TideColors.lantern.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
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

  static String _date(DateTime when) =>
      '${when.day} ${AppConstants.monthNames[when.month - 1]} ${when.year}';
}
