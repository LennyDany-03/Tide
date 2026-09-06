import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'habit_glyph.dart';
import 'press_scale.dart';

/// The bottom bar: a frosted panel floating clear of the screen edge.
///
/// It is glass rather than a solid bar because the page keeps scrolling
/// underneath it — habit rows blur as they pass behind, which is what tells
/// you the list continues rather than ending at the bar. That only works if
/// the body extends behind it, so [TideShell] sets `extendBody: true` and
/// every scrolling tab pads its content by [reservedHeight].
///
/// The active tab is marked by ink, not by furniture. A travelling pill
/// with its own wash, border, glow and indicator capsule — the previous
/// design — put more decoration on the nav bar than on the content it
/// navigates. Weight and colour say the same thing and take no space, and
/// the weight shift means the selection is still readable without relying
/// on colour alone.
class TideTabBar extends StatelessWidget {
  const TideTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = TideTab.all,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TideTab> tabs;

  static const double barHeight = 60;
  static const double sideMargin = 20;

  /// Between the panel and the safe area below it.
  static const double bottomGap = 10;

  static const BorderRadius _radius = TideElevation.radius20;

  /// Everything the bar occupies at the bottom of the screen, including the
  /// system gesture inset.
  ///
  /// Read from `viewPadding` rather than `padding`, so it returns the same
  /// number in the bar's own slot and inside the body — where `extendBody`
  /// has already rewritten `padding.bottom` to mean something else.
  static double reservedHeight(BuildContext context) =>
      barHeight + bottomGap + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideMargin,
        0,
        sideMargin,
        bottomGap + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SizedBox(
        height: barHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: _radius,
            boxShadow: TideElevation.floating,
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TideGradients.glass,
                  // A floor under the blur. Without it the glass goes muddy
                  // over a card and unreadable over deep water.
                  color: TideColors.deepWater.withValues(alpha: 0.62),
                  borderRadius: _radius,
                  border: Border.all(color: TideColors.hairline),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: _Tab(
                          tab: tabs[i],
                          active: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final TideTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: SizedBox.expand(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: active ? 1 : 0),
          duration: TideMotion.tabSwitch,
          curve: TideMotion.tabCurve,
          builder: (context, t, _) {
            final tint = Color.lerp(TideColors.silt, TideColors.lantern, t)!;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  // The 2px lift that pairs with the crossfade on the page
                  // behind it, so the whole tab switch moves together.
                  offset: Offset(0, -TideMotion.tabSlide * 0.5 * t),
                  child: HabitGlyph(glyph: tab.glyph, size: 17, color: tint),
                ),
                const SizedBox(height: 6),
                Text(
                  tab.label,
                  style: TideType.labelMuted.copyWith(
                    fontSize: 11,
                    color: tint,
                    fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
