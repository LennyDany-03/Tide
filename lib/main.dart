import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'config/app_constants.dart';
import 'config/app_routes.dart';
import 'services/tide_scope.dart';
import 'services/tide_store.dart';
import 'theme/tide_theme.dart';
import 'widgets/celebration/celebration_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(TideTheme.overlayStyle);
  runApp(const TideApp());
}

class TideApp extends StatefulWidget {
  const TideApp({super.key, this.startOnboarded = false});

  /// Tests and deep links can skip straight into the shell.
  final bool startOnboarded;

  @override
  State<TideApp> createState() => _TideAppState();
}

class _TideAppState extends State<TideApp> {
  late final TideStore _store = TideStore();
  late final GoRouter _router = AppRoutes.build(
    startOnboarded: widget.startOnboarded,
  );

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits above the router so every route — including the sheets
    // pushed on the root navigator — reads the same store.
    return TideScope(
      store: _store,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: TideTheme.dark,
        routerConfig: _router,
        builder: (context, child) {
          // Lock text scaling to a sane band: the gauge readouts are a
          // fixed-width instrument panel and fall apart past this.
          final scale = MediaQuery.textScalerOf(
            context,
          ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            // Completion may be logged from Today, the calendar, a detail
            // screen or a sheet. Keeping this above the router gives all of
            // them the same reward without duplicating UI glue in four
            // interaction paths.
            child: CelebrationHost(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
