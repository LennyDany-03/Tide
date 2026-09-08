import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
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
/// with its own wash, border, glow and indicator capsule — an earlier
/// design — put more decoration on the nav bar than on the content it
/// navigates. Colour, weight and a filled icon say the same thing and take
/// no space, and the two shifts that are not colour mean the selection is
/// still readable without relying on colour alone.
///
/// One piece of furniture came back, deliberately: a soft tinted capsule
/// that travels to sit behind the selected tab's icon. That is not the old
/// pill. The pill was a container the whole tab sat inside — icon, label
/// and all — which is why it needed a fill *and* a border *and* a glow to
/// hold itself together against the glass. This is one flat tint behind one
/// glyph, and its whole job is that it *moves*: a switch you can see travel
/// is a switch you understand you caused.
///
/// It went on the panel's top edge first, as a three-pixel lit line. Two
/// things were wrong with that and both were the same thing — it was not
/// attached to anything. Drawn at the very top it sat over the panel's own
/// hairline border and read as a separate object floating above the bar,
/// and on the first and last tabs it ran into the corner radius and came
/// out visibly cut. An indicator has to belong to the thing it indicates,
/// and the only place inside this panel that is unambiguously *the tab* is
/// directly behind its icon.
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

  static const double barHeight = 62;
  static const double sideMargin = 20;

  /// The tab's own layout, named once so the indicator can be placed
  /// against the same numbers rather than against a guess.
  static const double _iconSize = 22;
  static const double _iconGap = 5;

  /// Fixed rather than measured. The app clamps text scaling to 1.2, and a
  /// label box that grows moves the icon — which moves it off the indicator
  /// that is supposed to be sitting behind it.
  static const double _labelHeight = 18;

  static const double _indicatorHeight = 30;
  static const double _indicatorWidth = 52;

  static const double _contentHeight = _iconSize + _iconGap + _labelHeight;
  static const double _contentTop = (barHeight - _contentHeight) / 2;

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Measured rather than aligned. `Alignment` positions a
                    // child by its *edges* — at -1 it goes flush left, not
                    // "centred on the left edge" — so an alignment derived
                    // from the tab's centre fraction lands the capsule half
                    // its own width off the icon, outward on the first tab
                    // and inward on the last. It looked like a rounding
                    // error and was a twenty-pixel one.
                    //
                    // A tab is exactly `width / n` across; the indicator is
                    // centred in that. No fudge factor, and it stays right
                    // whatever the panel width or the number of tabs.
                    final tabWidth = constraints.maxWidth / tabs.length;

                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: TideMotion.pillSlide,
                          curve: TideMotion.pillCurve,
                          top:
                              _contentTop +
                              _iconSize / 2 -
                              _indicatorHeight / 2,
                          left:
                              tabWidth * currentIndex +
                              (tabWidth - _indicatorWidth) / 2,
                          width: _indicatorWidth,
                          height: _indicatorHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: TideColors.lantern.withValues(
                                alpha: 0.13,
                              ),
                              borderRadius: BorderRadius.circular(
                                _indicatorHeight / 2,
                              ),
                            ),
                          ),
                        ),
                        Row(
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
                      ],
                    );
                  },
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
                // Crossfaded rather than swapped: at 21px the outline and
                // the filled shape share most of their geometry, so a hard
                // swap reads as the icon flickering while a crossfade reads
                // as it thickening.
                //
                // No lift any more. The icon used to rise two pixels on
                // selection, which was fine when there was nothing behind
                // it and is not now — it would climb out of the indicator
                // that has just arrived to sit under it.
                SizedBox(
                  width: TideTabBar._iconSize,
                  height: TideTabBar._iconSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - t,
                        child: Icon(tab.icon, size: 21, color: tint),
                      ),
                      Opacity(
                        opacity: t,
                        child: Icon(tab.activeIcon, size: 21, color: tint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TideTabBar._iconGap),
                SizedBox(
                  height: TideTabBar._labelHeight,
                  child: Center(
                    child: Text(
                      tab.label,
                      style: TideType.labelMuted.copyWith(
                        fontSize: 11,
                        color: tint,
                        fontWeight: t > 0.5
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
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
