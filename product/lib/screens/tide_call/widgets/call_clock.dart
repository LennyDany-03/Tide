import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/reminder_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// The time, large and set wide, with the date under it in small capitals:
/// the face of an alarm clock, because on the lock screen that is what this
/// is.
///
/// Keeps itself current — a call can ring for two minutes and stay open for
/// longer — by waking on each minute boundary rather than polling.
class CallClock extends StatefulWidget {
  const CallClock({
    super.key,
    this.alignment = CrossAxisAlignment.center,
    this.size = 76,
  });

  final CrossAxisAlignment alignment;
  final double size;

  @override
  State<CallClock> createState() => _CallClockState();
}

class _CallClockState extends State<CallClock> {
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _tick = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = ReminderCopy.clock(TimeOfDay.fromDateTime(_now));
    return Semantics(
      label: 'It is $time',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: widget.alignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time,
              style: TideType.gauge(
                widget.size,
                letterSpacing: widget.size * 0.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ReminderCopy.date(_now).toUpperCase(),
              style: TideType.sectionHeader.copyWith(
                fontSize: 11.5,
                letterSpacing: 2.2,
                color: TideColors.silt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
