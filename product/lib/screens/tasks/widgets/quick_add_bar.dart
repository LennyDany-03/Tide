import 'package:flutter/material.dart';

import '../../../config/task_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import 'due_date_sheet.dart';

/// Type, pick a day if it has one, press return.
///
/// The due date used to hide behind a calendar icon at the end of the field,
/// which nobody reads as "this task can have a date". Now, the moment the
/// field is in use, the common answers are laid out under it as chips —
/// Today, Tomorrow, a date — and one tap sets them. The field keeps focus
/// after adding, so a list goes in as fast as it can be typed.
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({
    super.key,
    required this.onAdd,
    required this.focusRequests,
  });

  final void Function(String title, DateTime? due) onAdd;

  /// Bumped from outside — the launcher shortcut — to focus the field.
  final ValueNotifier<int> focusRequests;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  DateTime? _due;

  bool get _ready => _text.text.trim().isNotEmpty;

  /// Chips show while the composer is in use, and stay while a date is set.
  bool get _expanded => _focus.hasFocus || _ready || _due != null;

  @override
  void initState() {
    super.initState();
    _text.addListener(_refresh);
    _focus.addListener(_refresh);
    widget.focusRequests.addListener(_onFocusRequest);
  }

  @override
  void dispose() {
    widget.focusRequests.removeListener(_onFocusRequest);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onFocusRequest() {
    if (mounted) _focus.requestFocus();
  }

  void _submit() {
    if (!_ready) return;
    widget.onAdd(_text.text, _due);
    _text.clear();
    setState(() => _due = null);
    _focus.requestFocus();
  }

  void _setDue(DateTime? day) {
    setState(() => _due = _due == day ? null : day);
    _focus.requestFocus();
  }

  Future<void> _pickDate() async {
    final choice = await showDueDateSheet(context, current: _due);
    if (!mounted) return;
    if (choice != null) setState(() => _due = choice.date);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final custom = _due != null && _due != today && _due != tomorrow;

    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      decoration: BoxDecoration(
        color: TideColors.shelf,
        borderRadius: TideElevation.radius20,
        border: Border.all(
          color: _focus.hasFocus
              ? TideColors.lantern.withValues(alpha: 0.45)
              : TideColors.hairline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: TideMotion.tabSwitch,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _focus.hasFocus
                          ? TideColors.lantern.withValues(alpha: 0.7)
                          : TideColors.bone.withValues(alpha: 0.24),
                      width: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    style: TideType.body,
                    cursorColor: TideColors.lantern,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    // Return adds; it must not also drop the keyboard.
                    onEditingComplete: () {},
                    decoration: InputDecoration(
                      hintText: 'Add a task',
                      hintStyle: TideType.bodyMuted,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedScale(
                  duration: TideMotion.tabSwitch,
                  curve: TideMotion.overshoot,
                  scale: _ready ? 1 : 0.8,
                  child: Semantics(
                    button: true,
                    label: 'Add task',
                    child: PressScale(
                      onTap: _ready ? _submit : null,
                      child: AnimatedContainer(
                        duration: TideMotion.tabSwitch,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ready
                              ? TideColors.lantern
                              : TideColors.bone.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: _ready
                              ? TideColors.onLantern
                              : TideColors.silt.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: TideColors.hairline),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _DayChip(
                            icon: Icons.today_rounded,
                            label: 'Today',
                            selected: _due == today,
                            onTap: () => _setDue(today),
                          ),
                          const SizedBox(width: 8),
                          _DayChip(
                            icon: Icons.wb_twilight_rounded,
                            label: 'Tomorrow',
                            selected: _due == tomorrow,
                            onTap: () => _setDue(tomorrow),
                          ),
                          const SizedBox(width: 8),
                          _DayChip(
                            icon: Icons.calendar_month_rounded,
                            label: custom
                                ? TaskCopy.dayAndDate(_due!)
                                : 'Pick date',
                            selected: custom,
                            onTap: _pickDate,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TideColors.lantern : TideColors.bone;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? TideColors.lantern.withValues(alpha: 0.14)
              : TideColors.bone.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? TideColors.lantern.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TideType.label.copyWith(fontSize: 13, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
