import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// Flutter mocks of the native widget layouts in
/// `android/app/src/main/res/layout/widget_*.xml`, with sample content —
/// not a live preview of the account. Kept visually in step with those by
/// hand: same card, same rows, same flame, same heatmap tiers.
///
/// Home-screen widgets always draw in Midnight (see `values/colors.xml`),
/// so the widget-only colours below are fixed rather than palette tokens.
abstract final class _W {
  static const shelf = Color(0xFF0C1217);
  static const tile = Color(0xFF141E25);
  static const lanternSoft = Color(0x2645D0FF);
  static const coralSoft = Color(0x2EE0675E);
  static const edge = Color(0x14E8F1F6);
  static const flare = Color(0xFFC8F3FF);
  static const ember = Color(0xFF1A9BF0);
  static const outBody = Color(0xFF17272D);
  static const outCore = Color(0xFF2A3B44);

  static const cellRest = Color(0xFF121A20);
  static const cellEmpty = Color(0xFF18222A);
  static const cells = [
    Color(0xFF174A5E),
    Color(0xFF1F7899),
    Color(0xFF30A9D6),
    Color(0xFF45D0FF),
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.width, this.height, this.padding});

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _W.shelf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _W.edge),
        ),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.meta, this.metaColor, this.trailing});

  final String title;
  final String? meta;
  final Color? metaColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TideType.label.copyWith(color: TideColors.bone, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
          if (trailing != null) const SizedBox(width: 5),
          if (meta != null)
            Text(meta!, style: TideType.gauge(13, color: metaColor ?? TideColors.silt)),
        ],
      ),
    );
  }
}

/// The widget flame: `res/drawable/ic_widget_flame.xml`, path for path.
class _Flame extends StatelessWidget {
  const _Flame({this.height = 14, this.lit = true});

  final double height;
  final bool lit;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: height * 24 / 28,
    height: height,
    child: CustomPaint(painter: _FlamePainter(lit: lit)),
  );
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter({required this.lit});

  final bool lit;

  static Path _body() => Path()
    ..moveTo(12.6, 0.8)
    ..cubicTo(13.4, 5, 16.2, 7.4, 18.6, 10.4)
    ..cubicTo(20.6, 12.9, 21.8, 15.6, 21.8, 18.4)
    ..cubicTo(21.8, 23.6, 17.6, 27.4, 12, 27.4)
    ..cubicTo(6.4, 27.4, 2.2, 23.6, 2.2, 18.4)
    ..cubicTo(2.2, 14.8, 3.9, 12.1, 5.9, 10)
    ..cubicTo(6, 12.3, 6.9, 14, 8.4, 15)
    ..cubicTo(8, 9.6, 10, 4.6, 12.6, 0.8)
    ..close();

  static Path _core() => Path()
    ..moveTo(12.4, 12.2)
    ..cubicTo(13, 15, 15.6, 16.6, 16.2, 19.6)
    ..cubicTo(16.8, 22.6, 14.8, 25, 12, 25)
    ..cubicTo(9.2, 25, 7.4, 23, 7.6, 20.4)
    ..cubicTo(7.8, 18.4, 9, 17.2, 10, 16.4)
    ..cubicTo(10.2, 17.6, 10.7, 18.4, 11.4, 18.8)
    ..cubicTo(11, 16.4, 11.4, 14, 12.4, 12.2)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 28);
    final body = Paint();
    if (lit) {
      body.shader = const LinearGradient(
        colors: [_W.flare, Color(0xFF45D0FF), _W.ember],
        stops: [0, 0.4, 1],
      ).createShader(Rect.fromPoints(const Offset(4, 2), const Offset(20, 27)));
    } else {
      body.color = _W.outBody;
    }
    canvas
      ..drawPath(_body(), body)
      ..drawPath(_core(), Paint()..color = lit ? _W.flare : _W.outCore);
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.lit != lit;
}

class _Check extends StatelessWidget {
  const _Check({required this.done, this.overdue = false, this.size = 18});

  final bool done;
  final bool overdue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? TideColors.lantern : Colors.transparent,
        border: done
            ? null
            : Border.all(
                color: overdue ? TideColors.coral : TideColors.silt,
                width: 1.6,
              ),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: size * 0.72, color: TideColors.onLantern)
          : null,
    );
  }
}

/// A list widget's header: title over a muted subtitle, an accent right.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TideType.label.copyWith(color: TideColors.bone, fontSize: 16)),
              const SizedBox(height: 3),
              Text(subtitle, style: TideType.labelMuted.copyWith(fontSize: 12)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

/// One row of a scrolling list widget (`res/drawable/widget_tile.xml`).
class _Tile extends StatelessWidget {
  const _Tile({required this.children, this.height = 44});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _W.tile, borderRadius: BorderRadius.circular(14)),
      child: Row(children: children),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children, this.color = _W.tile, this.height = 22});

  final List<Widget> children;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height > 22 ? 10 : 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.label, required this.size, required this.fontSize});

  final double value;
  final String label;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: size / 11,
              backgroundColor: TideColors.shoal,
              color: TideColors.lantern,
            ),
          ),
          Text(label, style: TideType.gauge(fontSize, color: TideColors.bone)),
        ],
      ),
    );
  }
}

class TodayHabitsPreview extends StatelessWidget {
  const TodayHabitsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [('Morning water', true, 12), ('Read 20 pages', false, 5), ('Evening walk', true, 3)];
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          const _TitleBlock(
            title: 'Today',
            subtitle: '2 of 3 done',
            trailing: _Ring(value: 0.67, label: '67%', size: 42, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final (name, done, streak) in rows)
            _Tile(
              children: [
                _Check(done: done, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TideType.label.copyWith(
                      color: done ? TideColors.silt : TideColors.bone,
                    ),
                  ),
                ),
                _Pill(
                  color: _W.shelf,
                  children: [
                    _Flame(height: 12, lit: streak > 0),
                    const SizedBox(width: 4),
                    Text('$streak', style: TideType.gauge(12, color: TideColors.bone)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class SingleHabitStreakPreview extends StatelessWidget {
  const SingleHabitStreakPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return _Card(
      width: 156,
      height: 156,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Flame(height: 44),
                const SizedBox(height: 6),
                Text('12', style: TideType.gauge(32, color: TideColors.bone)),
                Text('day streak', style: TideType.labelMuted.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  'Morning water',
                  style: TideType.label.copyWith(color: TideColors.lantern, fontSize: 12),
                ),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.topRight,
            child: _Check(done: true, size: 16),
          ),
        ],
      ),
    );
  }
}

class TodayTasksPreview extends StatelessWidget {
  const TodayTasksPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [('Pay rent', 'Yesterday', true), ('Call dentist', 'Today', false), ('Buy groceries', 'Today', false)];
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          _TitleBlock(
            title: 'Tasks',
            subtitle: '3 due',
            trailing: _Pill(
              color: _W.coralSoft,
              height: 26,
              children: [
                Text('1 overdue', style: TideType.labelMuted.copyWith(color: TideColors.coral, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (title, due, overdue) in rows)
            _Tile(
              children: [
                _Check(done: false, overdue: overdue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: TideType.label.copyWith(color: TideColors.bone)),
                ),
                _Pill(
                  color: overdue ? _W.coralSoft : _W.shelf,
                  children: [
                    Text(
                      due,
                      style: TideType.labelMuted.copyWith(
                        fontSize: 11,
                        color: overdue ? TideColors.coral : TideColors.silt,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class QuickAddPreview extends StatelessWidget {
  const QuickAddPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return _Card(
      width: 180,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: TideColors.lantern,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_rounded, size: 26, color: TideColors.onLantern),
          ),
          const SizedBox(width: 10),
          Text('New habit', style: TideType.label.copyWith(color: TideColors.bone)),
        ],
      ),
    );
  }
}

/// The heatmap grid as `WidgetHeatmap.kt` draws it: Monday-to-Sunday
/// columns, newest on the right, five tiers, today ringed while still open.
class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.series, required this.weeks});

  /// One value per day ending today: -1 rest, 0..1 kept.
  final List<double> series;
  final int weeks;

  static const double _cell = 12;
  static const double _gap = _cell * 0.22;

  Color _tier(double t) => switch (t) {
    < 0 => _W.cellRest,
    <= 0 => _W.cellEmpty,
    < 0.34 => _W.cells[0],
    < 0.67 => _W.cells[1],
    < 1 => _W.cells[2],
    _ => _W.cells[3],
  };

  @override
  Widget build(BuildContext context) {
    final today = series.length - 1;
    final firstWeek = (series.length + 6) ~/ 7 - weeks;
    return SizedBox(
      width: weeks * (_cell + _gap) - _gap,
      height: 7 * (_cell + _gap) - _gap,
      child: Row(
        children: [
          for (var col = 0; col < weeks; col++) ...[
            if (col > 0) const SizedBox(width: _gap),
            Column(
              children: [
                for (var row = 0; row < 7; row++) ...[
                  if (row > 0) const SizedBox(height: _gap),
                  () {
                    final index = (firstWeek + col) * 7 + row;
                    final future = index > today;
                    final t = future ? -1.0 : series[index];
                    return Container(
                      width: _cell,
                      height: _cell,
                      decoration: BoxDecoration(
                        color: future ? _W.cellRest.withValues(alpha: 0.43) : _tier(t),
                        borderRadius: BorderRadius.circular(_cell * 0.26),
                        border: index == today && t >= 0 && t < 1
                            ? Border.all(color: TideColors.lantern, width: 1.4)
                            : null,
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HeatmapPreview extends StatelessWidget {
  const HeatmapPreview({super.key});

  static const _weeks = 18;

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday;
    final days = _weeks * 7 - (7 - weekday);
    final random = math.Random(11);
    final series = [
      for (var i = 0; i < days; i++)
        switch (random.nextDouble() + i / days * 0.35) {
          < 0.32 => 0.0,
          < 0.5 => 0.25,
          < 0.72 => 0.5,
          < 0.95 => 0.8,
          _ => 1.0,
        },
    ];
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          _Header(
            title: 'Morning water',
            meta: '12',
            metaColor: TideColors.lantern,
            trailing: const _Flame(height: 14),
          ),
          const SizedBox(height: 8),
          FittedBox(child: _HeatmapGrid(series: series, weeks: _weeks)),
        ],
      ),
    );
  }
}

class HabitDashboardPreview extends StatelessWidget {
  const HabitDashboardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Morning water', 12, [2, 2, 2, 2, 2, 2, 2]),
      ('Read 20 pages', 5, [1, 2, 2, 0, 2, 2, 3]),
      ('Evening walk', 3, [2, 1, 1, 2, 2, 2, 2]),
    ];
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          _TitleBlock(
            title: 'Streaks',
            subtitle: '3 on a streak',
            trailing: _Pill(
              color: _W.lanternSoft,
              height: 26,
              children: [
                const _Flame(height: 13),
                const SizedBox(width: 5),
                Text('12', style: TideType.gauge(13, color: TideColors.lantern)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (name, streak, week) in rows)
            _Tile(
              height: 56,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TideType.label.copyWith(color: TideColors.bone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          for (final (i, code) in week.indexed) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: switch (code) {
                                  2 => _W.cells[3],
                                  0 => _W.cellRest,
                                  _ => _W.cellEmpty,
                                },
                                border: code == 3
                                    ? Border.all(color: TideColors.lantern, width: 1.4)
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _Flame(height: 18, lit: streak > 0),
                const SizedBox(width: 5),
                Text(
                  '$streak',
                  style: TideType.gauge(
                    20,
                    color: streak > 0 ? TideColors.bone : TideColors.silt,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class WeeklyRecapPreview extends StatelessWidget {
  const WeeklyRecapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    Widget stat(Widget lead, String value, String label) => Row(
      children: [
        SizedBox(width: 16, child: Center(child: lead)),
        const SizedBox(width: 8),
        Text(value, style: TideType.gauge(20, color: TideColors.bone)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TideType.labelMuted.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    // Monday to Sunday: a Friday that is still open, a weekend to come.
    const days = [1.0, 0.8, 1.0, 0.5, 0.0, null, null];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          _TitleBlock(
            title: 'This week',
            subtitle: 'Sep 8 – 14',
            trailing: _Pill(
              color: _W.lanternSoft,
              height: 26,
              children: [
                Icon(Icons.trending_up_rounded, size: 14, color: TideColors.lantern),
                const SizedBox(width: 5),
                Text('+6%', style: TideType.gauge(13, color: TideColors.lantern)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const _Ring(value: 0.82, label: '82%', size: 66, fontSize: 17),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    stat(const _Flame(height: 16), '12', 'best streak'),
                    const SizedBox(height: 8),
                    stat(
                      Icon(Icons.check_rounded, size: 16, color: TideColors.silt),
                      '18/22',
                      'check-ins',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, value) in days.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: switch (value) {
                              null => _W.cellRest.withValues(alpha: 0.44),
                              >= 1 => _W.cells[3],
                              <= 0 => _W.cellEmpty,
                              < 0.67 => _W.cells[1],
                              _ => _W.cells[2],
                            },
                            border: i == 4
                                ? Border.all(color: TideColors.lantern, width: 1.5)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(letters[i], style: TideType.labelMuted.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
