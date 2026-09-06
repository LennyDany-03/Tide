import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import 'press_scale.dart';

/// The one object in the app that reads as genuinely floating.
///
/// A solid lantern disc — the only saturated block on Home — and the visual
/// origin of the add-habit sheet. It used to carry a wide blurred glow; on
/// a near-black ground a warm disc is already unmissable, and the glow only
/// softened its edge and cost it the crispness that made it look solid.
///
/// The morph is *not* a Flutter `Hero`. Sheets here are non-opaque routes,
/// so the FAB stays mounted underneath them — two heroes sharing a tag on
/// screen at once would assert. Instead the sheet scales up out of the FAB's
/// corner (see `tideMorphSheetTransition`), which keeps origin and result
/// visually connected without the tag collision.
class TideFab extends StatelessWidget {
  const TideFab({
    super.key,
    required this.onPressed,
    this.size = 58,
    this.icon = Icons.add_rounded,
  });

  final VoidCallback onPressed;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      scale: 0.92,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: TideColors.lantern,
          shape: BoxShape.circle,
          boxShadow: TideElevation.floating,
        ),
        child: Icon(icon, color: TideColors.deepWater, size: size * 0.42),
      ),
    );
  }
}

/// The disc in a sheet header that the FAB appears to have become — same
/// lantern, same circle, at the far end of the morph.
class TideFabMorphTarget extends StatelessWidget {
  const TideFabMorphTarget({super.key, required this.child, this.size = 40});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      // Solid, because the FAB it grew out of is solid. A translucent
      // wash here meant the disc visibly changed material half way through
      // the morph, which is the one thing the morph exists to avoid.
      decoration: const BoxDecoration(
        color: TideColors.lantern,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

/// The FAB's entrance and exit as tabs change — it retracts on screens with
/// no add action rather than jumping out of existence.
class TideFabSlot extends StatelessWidget {
  const TideFabSlot({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: TideMotion.morph,
      curve: TideMotion.overshoot,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: TideMotion.tabSwitch,
        child: child,
      ),
    );
  }
}
