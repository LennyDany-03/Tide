import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/task_copy.dart';
import '../../../services/tasks/task.dart';
import '../../../services/tasks/task_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_button.dart';
import 'due_date_sheet.dart';
import 'reminder_sheet.dart';
import 'repeat_sheet.dart';

/// The new-task drawer: everything a task can carry, gathered before it is
/// written.
///
/// It replaced a field inlined at the head of the list. That field was fast
/// for a bare title and nothing else — notes, a repeat, a reminder or steps
/// all meant adding the task, finding it again and opening the editor. And
/// it kept a live text field inside a tab that stays mounted, which is what
/// kept the keyboard hanging around the rest of the app.
///
/// The title is focused as the drawer rises, so the fast path is still
/// "tap, type, add". Everything else is one row of chips and a list of
/// steps under it, all optional, and the task is written once — with all of
/// it — when Add is pressed.
///
/// Returns the new task, or null if the drawer was dismissed.
Future<Task?> showNewTaskSheet(BuildContext context) {
  return showGeneralDialog<Task>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.drawerIn,
    pageBuilder: (context, _, _) => const Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        type: MaterialType.transparency,
        child: _KeyboardFrame(child: _NewTaskSheet()),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: TideMotion.drawerCurve,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      // The drawer slides as one rasterised layer. Without the boundary its
      // soft shadow and every chip were repainted on each frame of the rise.
      child: RepaintBoundary(child: child),
    ),
  );
}

class _NewTaskSheet extends StatefulWidget {
  const _NewTaskSheet();

  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _stepInput = TextEditingController();
  final FocusNode _stepFocus = FocusNode();

  DateTime? _due;
  TaskRecurrence _recurrence = TaskRecurrence.none;
  int? _months;
  List<DateTime> _reminders = [];
  List<Subtask> _steps = [];
  int _stepIds = 0;

  /// Whether the title holds anything — the one thing the Add button hangs
  /// on. Kept as its own notifier so a keystroke rebuilds the button only:
  /// a `setState` per change rebuilt the whole drawer several times a key
  /// (the controller also fires on selection and IME composing changes).
  final ValueNotifier<bool> _ready = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => _ready.value = _title.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _ready.dispose();
    _title.dispose();
    _notes.dispose();
    _stepInput.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_ready.value) return;
    final store = TaskScope.read(context);
    // A step typed but not yet entered is still meant.
    _addStep(_stepInput.text);
    final task = store.add(
      title: _title.text,
      description: _notes.text,
      dueDate: _due,
      recurrence: _recurrence,
      customRecurrenceMonths: _months,
      reminders: _reminders,
      subtasks: _steps,
    );
    if (_reminders.isNotEmpty) store.requestReminderPermission();
    Navigator.of(context).pop(task);
  }

  void _setDue(DateTime? day) =>
      setState(() => _due = _due == day ? null : day);

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final choice = await showDueDateSheet(context, current: _due);
    if (choice != null && mounted) setState(() => _due = choice.date);
  }

  Future<void> _pickRepeat() async {
    FocusScope.of(context).unfocus();
    final choice = await showRepeatSheet(
      context,
      current: _recurrence,
      months: _months,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _recurrence = choice.recurrence;
      _months = choice.months ?? _months;
    });
  }

  Future<void> _pickReminder() async {
    FocusScope.of(context).unfocus();
    final at = await showReminderSheet(context, due: _due);
    if (at == null || !mounted) return;
    setState(() {
      if (!_reminders.contains(at)) _reminders = [..._reminders, at]..sort();
    });
  }

  void _addStep(String raw) {
    final title = raw.trim();
    _stepInput.clear();
    if (title.isEmpty) return;
    setState(() {
      _steps = [
        ..._steps,
        Subtask(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_stepIds++}',
          title: title,
        ),
      ];
    });
    // Steps come in runs; the field stays open for the next one.
    _stepFocus.requestFocus();
  }

  String get _repeatLabel {
    if (_recurrence == TaskRecurrence.none) return 'Repeat';
    final now = DateTime.now();
    return TaskCopy.repeat(
      Task(
        id: '',
        title: '',
        createdAt: now,
        updatedAt: now,
        recurrence: _recurrence,
        customRecurrenceMonths: _months,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing in here reads MediaQuery — the keyboard is [_KeyboardFrame]'s
    // business, so its slide never rebuilds these fields and chips.
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final custom = _due != null && _due != today && _due != tomorrow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: TideElevation.innerHighlightWidth,
          decoration: BoxDecoration(
            gradient: TideElevation.innerHighlightGradient,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: TideColors.bone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'New task',
                  style: TideType.hero.copyWith(fontSize: 19),
                ),
              ),
              Semantics(
                button: true,
                label: 'Close',
                child: PressScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TideColors.bone.withValues(alpha: 0.06),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: TideColors.silt,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  autofocus: true,
                  style: TideType.heading.copyWith(fontSize: 18),
                  cursorColor: TideColors.lantern,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'What needs doing?',
                    hintStyle: TideType.heading.copyWith(
                      fontSize: 18,
                      color: TideColors.silt,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                TextField(
                  controller: _notes,
                  style: TideType.body,
                  cursorColor: TideColors.lantern,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Add details',
                    hintStyle: TideType.bodyMuted,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
                const SizedBox(height: 16),
                const _Label('When'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SheetChip(
                      icon: Icons.today_rounded,
                      label: 'Today',
                      selected: _due == today,
                      onTap: () => _setDue(today),
                    ),
                    SheetChip(
                      icon: Icons.wb_twilight_rounded,
                      label: 'Tomorrow',
                      selected: _due == tomorrow,
                      onTap: () => _setDue(tomorrow),
                    ),
                    SheetChip(
                      icon: Icons.calendar_month_rounded,
                      label: custom ? TaskCopy.dayAndDate(_due!) : 'Pick date',
                      selected: custom,
                      onTap: _pickDate,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('Options'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SheetChip(
                      icon: Icons.repeat_rounded,
                      label: _repeatLabel,
                      selected: _recurrence != TaskRecurrence.none,
                      onTap: _pickRepeat,
                      onClear: _recurrence == TaskRecurrence.none
                          ? null
                          : () => setState(
                              () => _recurrence = TaskRecurrence.none,
                            ),
                    ),
                    for (final at in _reminders)
                      SheetChip(
                        icon: Icons.notifications_active_outlined,
                        label: TaskCopy.reminder(at),
                        selected: true,
                        onTap: _pickReminder,
                        onClear: () => setState(
                          () => _reminders = [..._reminders]..remove(at),
                        ),
                      ),
                    SheetChip(
                      icon: Icons.add_alarm_rounded,
                      label: _reminders.isEmpty
                          ? 'Remind me'
                          : 'Another reminder',
                      selected: false,
                      onTap: _pickReminder,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Label(
                  'Steps',
                  trailing: _steps.isEmpty ? 'Optional' : '${_steps.length}',
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: TideColors.trench,
                    borderRadius: TideElevation.radius12,
                  ),
                  child: Column(
                    children: [
                      for (final step in _steps)
                        _StepRow(
                          title: step.title,
                          onRemove: () => setState(
                            () => _steps = [
                              for (final s in _steps)
                                if (s.id != step.id) s,
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: TideColors.silt,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _stepInput,
                                focusNode: _stepFocus,
                                style: TideType.body,
                                cursorColor: TideColors.lantern,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                onSubmitted: _addStep,
                                // Enter adds the step; it must not
                                // also move focus or drop the keyboard.
                                onEditingComplete: () {},
                                decoration: InputDecoration(
                                  hintText: 'Add a step',
                                  hintStyle: TideType.bodyMuted,
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: TideColors.hairline)),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _ready,
            builder: (context, ready, _) => TideButton(
              label: 'Add task',
              enabled: ready,
              onPressed: _submit,
              icon: Icon(
                Icons.add_rounded,
                size: 20,
                color: ready ? TideColors.onLantern : TideColors.silt,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The drawer's chrome, and the only part of it that reads the keyboard.
///
/// The keyboard's inset changes on every frame of its slide. When the drawer
/// read it in its own build, each of those frames rebuilt every chip and all
/// three text fields while the drawer was also sliding in — the stutter on
/// opening. Here a frame of the slide rebuilds a padding, a constraint and
/// the chrome; [child] is handed through untouched.
class _KeyboardFrame extends StatelessWidget {
  const _KeyboardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;
    // Clear of the gesture bar while the drawer sits on the screen's edge,
    // shrinking to nothing as the keyboard covers the bar — continuously,
    // rather than jumping when the keyboard first reports in.
    final gestureBar = math.max(
      0.0,
      MediaQuery.viewPaddingOf(context).bottom - keyboard,
    );

    return Padding(
      // The drawer rides up on the keyboard, so the Add button is never
      // under it.
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: (height - keyboard) * 0.92,
        ),
        decoration: BoxDecoration(
          color: TideColors.shoal,
          borderRadius: TideElevation.sheetRadius,
          boxShadow: TideElevation.floating,
        ),
        child: ClipRRect(
          borderRadius: TideElevation.sheetRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(child: child),
              SizedBox(height: gestureBar),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          Text(text, style: TideType.sectionHeader),
          const SizedBox(width: 12),
          if (trailing != null)
            Expanded(
              child: Text(
                trailing!,
                style: TideType.labelMuted.copyWith(fontSize: 12),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.title, required this.onRemove});

  final String title;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TideColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TideColors.bone.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TideType.body)),
          Semantics(
            button: true,
            label: 'Remove step',
            child: PressScale(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: TideColors.silt,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A choice in the drawer: a pill that lights when set, with an optional
/// clear mark for the ones that can be taken off again.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TideColors.lantern : TideColors.bone;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        height: 36,
        padding: EdgeInsets.only(left: 12, right: onClear == null ? 14 : 4),
        decoration: BoxDecoration(
          color: selected
              ? TideColors.lantern.withValues(alpha: 0.14)
              : TideColors.bone.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? TideColors.lantern.withValues(alpha: 0.45)
                : TideColors.hairline,
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
            if (onClear != null)
              Semantics(
                button: true,
                label: 'Clear $label',
                child: PressScale(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 14, color: color),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
