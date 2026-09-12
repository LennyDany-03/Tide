import 'package:flutter/material.dart';

import 'tide_store.dart';

/// Puts the [TideStore] in the tree and rebuilds dependents when it changes.
///
/// `InheritedNotifier` is doing the whole job here — there is no state
/// package in this project, and for one store shared by nine screens there
/// does not need to be.
class TideScope extends InheritedNotifier<TideStore> {
  const TideScope({super.key, required TideStore store, required super.child})
    : super(notifier: store);

  /// Reads the store *and* subscribes the calling widget to its changes.
  static TideStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TideScope>();
    assert(scope != null, 'No TideScope found above this widget.');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing — for callbacks and one-shot
  /// actions, where rebuilding the caller would be pointless churn.
  static TideStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TideScope>();
    assert(scope != null, 'No TideScope found above this widget.');
    return scope!.notifier!;
  }
}
