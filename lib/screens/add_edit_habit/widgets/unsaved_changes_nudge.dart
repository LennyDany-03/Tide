import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// The inline "you have unsaved changes" nudge.
///
/// It appears in the sheet, not as a modal on top of it. Backing out of an
/// edit is a small mistake and deserves a small correction — a dialog would
/// treat a half-typed habit name as an emergency.
class UnsavedChangesNudge extends StatelessWidget {
  const UnsavedChangesNudge({
    super.key,
    required this.visible,
    required this.onDiscard,
    required this.onKeepEditing,
  });

  final bool visible;
  final VoidCallback onDiscard;
  final VoidCallback onKeepEditing;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: TideMotion.tabSwitch,
        child: visible
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: TideColors.coral.withValues(alpha: 0.10),
                    borderRadius: TideElevation.radius12,
                    border: Border.all(
                      color: TideColors.coral.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'You have unsaved changes.',
                          style: TideType.label.copyWith(
                            color: TideColors.coral,
                          ),
                        ),
                      ),
                      PressScale(
                        onTap: onKeepEditing,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'Keep editing',
                            style: TideType.label.copyWith(
                              color: TideColors.bone,
                            ),
                          ),
                        ),
                      ),
                      PressScale(
                        onTap: onDiscard,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'Discard',
                            style: TideType.label.copyWith(
                              color: TideColors.coral,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
