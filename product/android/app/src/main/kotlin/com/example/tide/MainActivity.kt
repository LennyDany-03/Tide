package com.example.tide

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /**
     * A home-screen widget tap sets Intent.data to a `tide://widget/...`
     * URI so the home_widget plugin's own channel can read it (see
     * _openFromWidget in lib/main.dart). Flutter's default deep-linking
     * also treats any non-null Intent.data as a route to push straight
     * into go_router, both on cold start and on the onNewIntent path for a
     * warm one — and go_router has no route registered for that scheme, so
     * every widget tap opened the app onto a "Page Not Found" screen before
     * _openFromWidget ever ran. Nothing else in this app declares a `data`
     * scheme to receive via Flutter's own deep linking, so it is off
     * entirely and widget taps are handled only in Dart.
     */
    override fun shouldHandleDeeplinking(): Boolean = false
}
