# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Tide — a Flutter habit-tracker prototype. The repo directory is `Loopify`, but the Dart package is `tide` (imports are `package:tide/...`) and the Android app id is `com.example.tide`. Flutter 3.44 / Dart SDK ^3.12.2. Dependencies are just `go_router` and `cupertino_icons`; there is no state-management, persistence or networking package.

## Commands

```bash
flutter pub get
flutter run                       # -d chrome | windows | <device id>
flutter analyze                   # lints via flutter_lints (analysis_options.yaml)
flutter test
flutter test test/widget_test.dart
flutter test test/streak_calculator_test.dart --plain-name 'an unlogged today does not break the streak'
```

## Architecture

**Single in-memory store, no persistence.** `TideStore` (`lib/services/tide_store.dart`) is a `ChangeNotifier` holding every habit, preference and mutation. It boots from `SeedData.habits()` on each launch and never writes anything back — session actions are real (logging moves streaks, stats and heatmaps) but do not survive the process. Adding persistence means adding it here, not in screens.

**Store access.** `TideScope` (`InheritedNotifier`) is mounted in `main.dart` *above* the router so root-navigator sheets share it. Two accessors, and the difference matters:
- `context.tide` (extension on `BuildContext`, defined at the bottom of `tide_store.dart`) / `TideScope.of` — reads **and subscribes**; use in `build`.
- `TideScope.read(context)` — reads without subscribing; use in callbacks and one-shot actions.

**All arithmetic lives in `StreakCalculator`** (`lib/services/streak_calculator.dart`) — pure functions, no widgets or state. Streaks, completion rates, weekly series, weekday rates, heatmap intensities and clean streaks all resolve through it, so two screens can't disagree about the same figure. The store is a thin façade over it. New derived numbers belong here, not in a widget.

**Data model.** `Habit` (`lib/services/models/habit.dart`) is immutable; every mutation goes through `copyWith`, and the store mutates by rebuilding the list (`_mutate`). Logs are `Map<DateTime, num>` keyed by `DateUtils.dateOnly` — always normalise dates to midnight before keying. `frozenDays` are days where a freeze token was spent so a miss doesn't break the loop. `HabitType` decides the logging gesture: `binary` → swipe, `quantity`/`duration` → hold-to-fill.

**Routing** (`lib/config/app_routes.dart`). go_router with a `StatefulShellRoute` of four branches (Today / History / Insights / Settings) rendered by `TideShell`. All four branches set `preload: true` — tabs are swipeable, so a lazily-built branch would appear blank under the finger. Milestones, the add/edit sheet and the upgrade sheet are pushed on the root navigator (`_rootKey`); the sheets are non-opaque `CustomTransitionPage`s so the screen behind stays visible. Use the `Routes` constants, never literal path strings.

**Shell** (`lib/screens/shell/tide_shell.dart`). Owns the page ground, the tab bar and the FAB. `TideBackdrop` is mounted once here so all four tabs share one continuous background. Branch bodies stay alive in a stack. The FAB routes to `Routes.newHabit` or, when `store.canAddHabit` is false, to `Routes.upgrade` — the paywall is contextual, triggered by the free ceiling (`AppConstants.freeHabitLimit`), never a settings row.

**Screen layout.** Each screen is `lib/screens/<name>/<name>_screen.dart` plus a private `widgets/` folder; anything used by more than one screen graduates to `lib/widgets/`. `Scaffold.extendBody` is true, so scrolling screens must pad the bottom with `TideTabBar.reservedHeight(context)` for the frosted bar to have something to blur.

## Design system — the constraints that actually bind

The theme layer is prescriptive, not advisory. Read the doc comments in `lib/theme/` before adding visual code.

- **`TideColors` is the entire colour vocabulary**, and its tokens are *getters* reading the active `TidePalette` (`lib/theme/tide_palette.dart`: Midnight — the default, `TidePalettes.standard` — plus Deep water, Ink, Blossom, Paper). No file outside `lib/theme/` may introduce a hue. The fix for a flat-looking screen is motion, depth and consistency — never a new colour.
  - Because tokens are runtime values, never put them in a `const` expression or a default parameter value (make the parameter nullable and fall back inside `build`). `TideType` styles are getters for the same reason.
  - Ink on a solid accent fill is `TideColors.onLantern`, never `deepWater` — on light palettes the two differ.
  - Switch palettes only through `store.setPalette`, which calls `TideTheme.applyPalette` to rebuild and repaint the tree. A new palette must pass `test/palette_test.dart`'s contrast floors.
- **`TideGradients` holds every ramp**, all running top-left→bottom-right or top→bottom: one light source for the whole app. A gradient is depth, never decoration.
- **`TideMotion` holds every duration and curve.** Do not inline a `Duration` or `Curve` in a widget; add a named constant there so nine screens keep moving as one object.
- **`PressScale` is the only press affordance.** Material ink is disabled in `TideTheme` (transparent splash/highlight, `NoSplash`), so an unwrapped tappable feels dead.
- **`TideSurface` / `TideWell`** carry the elevation recipe (fill, radius, shadow set, 1px top inner highlight). Don't hand-roll a `Container` card.
- **`GaugeNumber` / `GaugeCountUp`** render every number on screen, in JetBrains Mono with tabular figures. One glyph per column per frame — no two-drum odometer, no crossfade between digits; the motion is in the tweened *value*. `test/gauge_number_test.dart` enforces this.
- **`TideType`**: Space Grotesk for display/headings, Manrope for body/UI, JetBrains Mono for numerics. Text scaling is clamped to 0.9–1.2 in `main.dart` because the gauges are fixed-width.
- **Glyphs are abstract geometry** (`TideGlyph`, drawn by the painter in `lib/widgets/habit_glyph.dart`), never pictographic icons.

## Testing

`TideApp(startOnboarded: true)` skips onboarding and boots straight into the shell — that flag exists for tests and deep links. Use fixed `tester.pump(Duration(...))` rather than `pumpAndSettle`: several screens run deliberate ambient loops (breathing empty state, sync pulse, CTA glow, onboarding drift) that never settle. Time-dependent logic tests pass an explicit `asOf` so they don't drift with the wall clock (see `test/streak_calculator_test.dart`). `test/failures/` holds checked-in golden diff PNGs, not test code.

## Conventions

- Config-as-data lives in `lib/config/`: `AppConstants` (limits, copy, the tab manifest), `HabitTemplate.all`, `MilestoneCatalog`, `SeedData`. Tune numbers there rather than in screens.
- Seed data is real log history, not hardcoded display strings — its patterns are tuned so the computed figures land on the design's numbers (12-day water streak, ~82% week, four milestones unlocked). Changing it changes what every screen reports.
- Prefer `abstract final class` for the token/constant holders, matching the existing files.
- Comments in this codebase explain *why* a non-obvious choice was made (why branches preload, why no odometer, why the radial falloff has seven stops). Match that when touching those areas.
