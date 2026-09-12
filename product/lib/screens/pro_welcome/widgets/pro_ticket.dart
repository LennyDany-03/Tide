import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/plan_catalog.dart';
import '../../../services/billing/entitlement.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_mark.dart';

/// The Pro pass — a ticket, drawn rather than decorated.
///
/// **Why a ticket and not a receipt.** A receipt is a record of money
/// leaving; a ticket is a record of being let in. The second is the true
/// thing here, and it is the one worth keeping on a screen somebody can come
/// back to.
///
/// The shape does the work. Two notches bitten out of the sides with a
/// perforation running between them is a form nothing else in the app has,
/// so the object reads as a different *kind* of thing from a habit card or a
/// settings row without a single new colour being introduced. The stub below
/// the perforation carries the figures — dates, plan, serial — in the same
/// JetBrains Mono the gauges use, because a pass is an instrument readout
/// and not a piece of marketing.
///
/// **The sheen is not a loop.** It sweeps once, when the ticket arrives or
/// when it is tapped. A foil that keeps glinting at you turns into an
/// idling animation on a screen that is supposed to hold still, and the rare
/// thing loses its rarity by repeating every two seconds.
class ProTicket extends StatelessWidget {
  const ProTicket({
    super.key,
    required this.entitlement,
    required this.holderName,
    this.reveal = 1,
    this.sheen = 0,
  });

  final Entitlement entitlement;
  final String holderName;

  /// 0..1 — the ticket assembling. Drives the stub separating from the body
  /// and the whole thing settling, so the parent can run it on one clock
  /// alongside everything else on the screen.
  final double reveal;

  /// 0..1 — where the light is across the face. Outside that range nothing
  /// is drawn at all.
  final double sheen;

  /// The pass number.
  ///
  /// Derived from the payment that bought the period, so it is stable across
  /// launches and actually refers to something — support can find the order
  /// from it. Formatted in two groups because a sixteen-character run of hex
  /// is unreadable and a pass number is meant to be read aloud.
  String get _serial {
    final source =
        entitlement.lastPaymentId ??
        entitlement.periodStart?.millisecondsSinceEpoch.toRadixString(16) ??
        'tide';
    final cleaned = source
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final tail = cleaned.length <= 8
        ? cleaned.padLeft(8, '0')
        : cleaned.substring(cleaned.length - 8);
    return '${tail.substring(0, 4)} ${tail.substring(4)}';
  }

  static String _date(DateTime? when) {
    if (when == null) return '—';
    return '${when.day} ${AppConstants.monthNames[when.month - 1].substring(0, 3)} '
        '${when.year}';
  }

  @override
  Widget build(BuildContext context) {
    final plan = PlanCatalog.byId(entitlement.planId);
    final eased = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));

    return AspectRatio(
      aspectRatio: 1.62,
      child: CustomPaint(
        painter: _TicketPainter(reveal: eased, sheen: sheen),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TIDE PRO',
                          style: TideType.gauge(
                            11,
                            color: TideColors.lantern,
                          ).copyWith(letterSpacing: 2.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          plan?.title ?? 'Pro',
                          style: TideType.hero.copyWith(fontSize: 30),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Already whole. The mark draws itself in on the splash and
                  // in the welcome; here it is a seal, and a seal does not
                  // assemble in front of you.
                  const TideMark(size: 40, strokeWidth: 2.4, drawIn: false),
                ],
              ),

              const Spacer(),

              Text(
                holderName.toUpperCase(),
                style: TideType.gauge(
                  13,
                  color: TideColors.bone,
                ).copyWith(letterSpacing: 1.6),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text('Holder', style: TideType.labelMuted.copyWith(fontSize: 10.5)),

              // The perforation sits here in the layout; the painter draws it.
              const SizedBox(height: 26),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Stub(label: 'Valid until', value: _date(entitlement.periodEnd)),
                  const SizedBox(width: 22),
                  _Stub(label: 'Pass no.', value: _serial),
                  const Spacer(),
                  _Stub(
                    label: 'Days',
                    value: '${entitlement.daysRemaining}',
                    align: CrossAxisAlignment.end,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One figure on the stub: a small muted label over a gauge readout.
class _Stub extends StatelessWidget {
  const _Stub({
    required this.label,
    required this.value,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        Text(
          label.toUpperCase(),
          style: TideType.labelMuted.copyWith(fontSize: 9, letterSpacing: 1.2),
        ),
        const SizedBox(height: 5),
        Text(value, style: TideType.gauge(13, color: TideColors.bone)),
      ],
    );
  }
}

/// The ticket's body: the notched outline, the perforation, and the sheep of
/// light that crosses it once.
///
/// Everything here is geometry and the palette's own tokens. There is no
/// gold, no second accent and no gradient doing the work of a colour — the
/// premium reading comes from the shape being unlike anything else in the
/// app and from the light behaving like light.
class _TicketPainter extends CustomPainter {
  const _TicketPainter({required this.reveal, required this.sheen});

  final double reveal;
  final double sheen;

  /// Where the perforation crosses, as a fraction of height. Below the
  /// golden-ish two thirds, so the stub reads as a stub rather than as half
  /// a card.
  static const double _tear = 0.68;

  /// Radius of the notch bitten out of each side.
  static const double _notch = 13;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tearY = size.height * _tear;
    final path = _outline(rect, tearY);

    canvas.save();
    canvas.clipPath(path);

    // The face. Shoal — one step above a card, because this is the thing you
    // just opened.
    canvas.drawRect(rect, Paint()..color = TideColors.shoal);

    // A wash of the accent pooling in the top-left, which is where the app's
    // single light source is. Radial rather than linear so it reads as light
    // falling on the card rather than as a gradient applied to it.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.75, -0.95),
          radius: 1.35,
          colors: [
            TideColors.lantern.withValues(alpha: 0.20 * reveal),
            TideColors.lantern.withValues(alpha: 0.05 * reveal),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );

    // The stub, a shade deeper, so the tear reads as a real edge even before
    // the perforation is drawn over it.
    canvas.drawRect(
      Rect.fromLTRB(0, tearY, size.width, size.height),
      Paint()..color = TideColors.deepWater.withValues(alpha: 0.35),
    );

    _perforation(canvas, size, tearY);
    if (sheen > 0 && sheen < 1) _sheen(canvas, size);

    canvas.restore();

    // The lit top edge every raised surface in Tide carries, and a hairline
    // around the rest of the outline so the notches have a drawn edge.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TideColors.bone.withValues(alpha: 0.14),
    );
  }

  /// A rounded rectangle with a semicircle bitten out of each side at the
  /// tear line. Built by walking the outline rather than by subtracting two
  /// circles, so the notch edge joins the border cleanly instead of leaving
  /// a seam where two paths meet.
  Path _outline(Rect rect, double tearY) {
    const r = TideElevation.r20;
    final w = rect.width;
    final h = rect.height;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, tearY - _notch)
      // Right notch, cut inward.
      ..arcToPoint(
        Offset(w, tearY + _notch),
        radius: const Radius.circular(_notch),
        clockwise: false,
      )
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, tearY + _notch)
      // Left notch.
      ..arcToPoint(
        Offset(0, tearY - _notch),
        radius: const Radius.circular(_notch),
        clockwise: false,
      )
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
      ..close();

    return path;
  }

  /// The dashed tear line. It draws itself outward from both notches as
  /// [reveal] runs, so the stub looks torn from the body rather than printed
  /// with a line already on it.
  void _perforation(Canvas canvas, Size size, double tearY) {
    const dash = 5.0;
    const gap = 5.0;
    final paint = Paint()
      ..color = TideColors.bone.withValues(alpha: 0.20)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final inset = _notch + 5;
    final span = (size.width - inset * 2) * reveal;
    final mid = size.width / 2;

    for (var offset = 0.0; offset < span / 2; offset += dash + gap) {
      for (final direction in const [-1, 1]) {
        final start = mid + direction * offset;
        final end = mid + direction * (offset + dash);
        canvas.drawLine(Offset(start, tearY), Offset(end, tearY), paint);
      }
    }
  }

  /// One pass of light across the face, angled the way the app's light
  /// falls. Narrow, and nowhere near opaque — a highlight, not a flash.
  void _sheen(Canvas canvas, Size size) {
    final travel = size.width * 2.2;
    final x = -size.width * 0.6 + travel * sheen;

    canvas.save();
    canvas.translate(x, 0);
    canvas.transform(
      Matrix4.skewX(-math.pi / 9).storage,
    );

    final band = Rect.fromLTWH(0, -size.height, size.width * 0.30, size.height * 3);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            TideColors.glint.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.reveal != reveal || old.sheen != sheen;
}
