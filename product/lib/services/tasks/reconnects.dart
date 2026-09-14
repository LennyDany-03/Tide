import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// An event each time the device goes from no connection to some connection.
///
/// Only the transition, not every change: moving from Wi-Fi to mobile data is
/// not a reason to sync again, coming out of a tunnel is.
Stream<void> connectionRestored([Connectivity? connectivity]) {
  final source = connectivity ?? Connectivity();
  var offline = false;
  return source.onConnectivityChanged
      .handleError((Object error) => debugPrint('Connectivity: $error'))
      .where((results) {
        final nowOffline =
            results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
        final restored = offline && !nowOffline;
        offline = nowOffline;
        return restored;
      })
      .map((_) {});
}
