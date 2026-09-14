import 'package:flutter/widgets.dart';

import 'update_store.dart';

/// Hands the [UpdateStore] down the tree, above the router.
///
/// Absent in tests and in any build without an update manifest, which is
/// why the accessors are `maybe`: Settings simply has no update row there.
class UpdateScope extends InheritedNotifier<UpdateStore> {
  const UpdateScope({
    super.key,
    required UpdateStore store,
    required super.child,
  }) : super(notifier: store);

  /// Reads and subscribes. Use in `build`.
  static UpdateStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UpdateScope>()?.notifier;

  /// Reads without subscribing. Use in callbacks.
  static UpdateStore? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UpdateScope>()?.notifier;
}
