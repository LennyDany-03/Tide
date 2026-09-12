import 'package:flutter/material.dart';

import '../../config/tour_catalog.dart';

/// The things the guided tour can point at.
///
/// A screen marks a target by wrapping it, and the overlay asks the
/// registry where that target ended up. Nothing else couples the two: the
/// tour does not know Home's widget tree and Home does not know the tour
/// exists beyond one wrapper per target, so moving the hero figure or
/// re-laying out the header cannot leave the spotlight pointing at empty
/// water.
///
/// Keys rather than rects, because a rect measured at register time is
/// wrong the moment anything scrolls. The registry hands back a live
/// measurement each time it is asked.
class TourAnchorRegistry {
  final Map<TourStop, GlobalKey> _keys = {};

  void register(TourStop stop, GlobalKey key) => _keys[stop] = key;

  /// Only clears the slot if this key is still the one in it. Two anchors
  /// for the same stop can briefly overlap while a screen rebuilds, and the
  /// outgoing one must not delete the incoming one's registration.
  void unregister(TourStop stop, GlobalKey key) {
    if (_keys[stop] == key) _keys.remove(stop);
  }

  /// Where [stop] currently sits in global coordinates, or null if it is
  /// not mounted or has not been laid out yet.
  Rect? rectOf(TourStop stop) {
    final render = _keys[stop]?.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    return render.localToGlobal(Offset.zero) & render.size;
  }
}

/// Puts a [TourAnchorRegistry] in the tree.
///
/// Mounted above the router, alongside the store, so the overlay and the
/// anchors can find each other across route and branch boundaries — the
/// tab bar and the Today header live in different subtrees, and the tour
/// points at both.
class TourAnchorScope extends InheritedWidget {
  const TourAnchorScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final TourAnchorRegistry registry;

  static TourAnchorRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TourAnchorScope>()
      ?.registry;

  @override
  bool updateShouldNotify(TourAnchorScope old) => old.registry != registry;
}

/// Marks its child as the target for one tour stop.
///
/// Costs nothing when no tour is running: it adds a keyed subtree and one
/// map entry, and never rebuilds on its own.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.stop, required this.child});

  final TourStop stop;
  final Widget child;

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  final GlobalKey _key = GlobalKey();
  TourAnchorRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = TourAnchorScope.maybeOf(context);
    if (registry == _registry) return;
    _registry?.unregister(widget.stop, _key);
    _registry = registry?..register(widget.stop, _key);
  }

  @override
  void didUpdateWidget(TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.stop == widget.stop) return;
    _registry?.unregister(old.stop, _key);
    _registry?.register(widget.stop, _key);
  }

  @override
  void dispose() {
    _registry?.unregister(widget.stop, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
