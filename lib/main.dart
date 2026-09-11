import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'config/app_constants.dart';
import 'config/app_routes.dart';
import 'services/tide_scope.dart';
import 'services/tide_store.dart';
import 'theme/tide_colors.dart';
import 'theme/tide_palette.dart';
import 'theme/tide_theme.dart';
import 'widgets/celebration/celebration_host.dart';
import 'widgets/tour/tour_anchor.dart';
import 'widgets/tour/tour_host.dart';

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

  /// Where the guided tour finds the things it points at. Lives up here
  /// with the store because its two ends — the anchors on Today and in the
  /// tab bar, and the overlay above the router — are in different subtrees.
  final TourAnchorRegistry _anchors = TourAnchorRegistry();

  /// The palette Material's theme was last built for.
  late TidePalette _palette;

  @override
  void initState() {
    super.initState();
    // Tokens are global, so a fresh app — every widget test builds one —
    // starts from its own store's palette rather than whatever the last
    // app left behind.
    _palette = _store.palette;
    TideColors.use(_palette);
    _store.addListener(_onStore);
  }

  /// Rebuilds the MaterialApp only when the palette actually changed, not on
  /// every habit logged.
  void _onStore() {
    if (identical(_store.palette, _palette)) return;
    setState(() => _palette = _store.palette);
  }

  @override
  void dispose() {
    _store
      ..removeListener(_onStore)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits above the router so every route — including the sheets
    // pushed on the root navigator — reads the same store.
    return TideScope(
      store: _store,
      child: TourAnchorScope(
        registry: _anchors,
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: TideTheme.current,
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
              // screen or a sheet. Keeping this above the router gives all
              // of them the same reward without duplicating UI glue in four
              // interaction paths.
              //
              // The tour sits under the celebration rather than over it:
              // the tour's last step opens the add sheet and ends itself, so
              // the only way the two could overlap is a reward earned while
              // a scrim is up, and a reward must never be dimmed.
              child: CelebrationHost(
                child: TourHost(
                  // The router is not reachable from this builder's own
                  // context — it lives below the app — so the one action the
                  // tour can take is handed in from out here.
                  onAddHabit: () => _router.push(Routes.newHabit),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
