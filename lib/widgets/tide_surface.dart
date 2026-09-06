import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';

/// A card, sheet or raised row — anything sitting above the page.
///
/// Flat. The fill is a solid step up from the page, and the only modelling
/// is a one-pixel lit line along the top edge. That is the whole recipe.
///
/// This used to paint a diagonal ramp on every surface in the app. A ramp
/// on one card reads as light falling across it; a ramp on all of them
/// reads as texture, and texture everywhere is the thing that makes an
/// interface look busy rather than expensive. Luminance separation does the
/// same job silently, which is why the palette was rebuilt to give it
/// enough room to work.
class TideSurface extends StatelessWidget {
  const TideSurface({
    super.key,
    required this.child,
    this.radius = TideElevation.radius20,
    this.color,
    this.gradient,
    this.floating = false,
    this.padding,
    this.margin,
    this.border,
    this.highlight = true,
    this.shadows,
    this.width,
    this.height,
  });

  final Widget child;
  final BorderRadius radius;

  /// Defaults to [TideColors.shelf]. Pass [TideColors.shoal] for something
  /// sitting one step further forward.
  final Color? color;

  /// Escape hatch for the two surfaces that genuinely carry a ramp — the
  /// tide curve and the tab bar's glass. Everything else stays flat.
  final Gradient? gradient;

  /// Floating surfaces (sheets, context menus) take the deep shadow. Cards
  /// take none.
  final bool floating;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;

  /// The lit top edge. Off for recessed wells, which should read as carved
  /// into a surface rather than raised off it.
  final bool highlight;

  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? TideColors.shelf) : null,
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow:
            shadows ??
            (floating ? TideElevation.floating : TideElevation.resting),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          // Hand the surface's own constraints to the content rather than
          // loosening them, so a card never shrinks to fit its text.
          fit: StackFit.passthrough,
          children: [
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
            if (highlight)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: TideElevation.innerHighlightWidth,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: TideElevation.innerHighlightGradient,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A recess cut into a surface: inputs, empty grid cells, the inactive
/// track behind a sliding pill.
///
/// Flat [TideColors.trench], and no lit edge — a hole does not catch the
/// light that a raised face does. That single omission is what separates it
/// from [TideSurface]; it needs no gradient to read as carved.
class TideWell extends StatelessWidget {
  const TideWell({
    super.key,
    required this.child,
    this.radius = TideElevation.radius12,
    this.padding,
    this.color,
    this.border,
  });

  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? TideColors.trench,
        borderRadius: radius,
        border: border,
      ),
      child: child,
    );
  }
}
