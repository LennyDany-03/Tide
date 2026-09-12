import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../widgets/tide_wave.dart';

/// Pull-to-refresh, drawn as water instead of a spinner.
///
/// The wave's amplitude is tied directly to how far the list has been
/// pulled, so the gesture has a physical readout the whole way down rather
/// than a spinner that appears once a threshold is crossed. Past the commit
/// point the wave goes tide blue and the crest keeps travelling.
class WaveRefreshIndicator extends StatefulWidget {
  const WaveRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 74,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerDistance;

  @override
  State<WaveRefreshIndicator> createState() => _WaveRefreshIndicatorState();
}

class _WaveRefreshIndicatorState extends State<WaveRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _crest;

  double _pull = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Eager for the same reason as HabitCard's settle controller: nothing
    // reads _crest until a pull begins, so a lazy field would be created
    // inside dispose() on a screen that was never pulled.
    _crest = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  /// The crest only travels while the wave is actually on screen. Leaving
  /// it repeating would keep a ticker alive behind every idle Home screen —
  /// and would stop `pumpAndSettle` ever settling in tests.
  void _setCresting(bool active) {
    if (active && !_crest.isAnimating) {
      _crest.repeat();
    } else if (!active && _crest.isAnimating) {
      _crest.stop();
    }
  }

  double get _fraction => (_pull / widget.triggerDistance).clamp(0.0, 1.4);
  bool get _armed => _pull >= widget.triggerDistance;

  @override
  void dispose() {
    _crest.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      final metrics = notification.metrics;
      final over = metrics.minScrollExtent - metrics.pixels;
      final next = over > 0 ? over : 0.0;
      if ((next - _pull).abs() > 0.5) {
        setState(() => _pull = next);
        _setCresting(next > 1);
      }
    }

    if (notification is ScrollEndNotification) {
      if (_armed && !_refreshing) {
        _run();
      }
      setState(() => _pull = 0);
      _setCresting(_refreshing);
    }
    return false;
  }

  Future<void> _run() async {
    setState(() => _refreshing = true);
    _setCresting(true);
    HapticFeedback.mediumImpact();
    await widget.onRefresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    _setCresting(false);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Stack(
        children: [
          widget.child,
          if (_pull > 1 || _refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: (_pull.clamp(0.0, 110.0)) + (_refreshing ? 34 : 0),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _crest,
                  builder: (context, _) {
                    return TideWave(
                      amplitude: _refreshing ? 1 : _fraction,
                      phase: _crest.value * 6.28,
                      color: _armed || _refreshing
                          ? TideColors.lantern
                          : TideColors.silt,
                      strokeWidth: 2,
                      waves: 1.4,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The physics the wave needs: overscroll has to exist on every platform,
/// not just iOS, or the gesture simply would not register on Android.
const ScrollPhysics tidePullPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

/// Kept here so Home and the refresh indicator agree on how long a refresh
/// takes to settle.
const Duration tideRefreshSettle = TideMotion.dayComplete;
