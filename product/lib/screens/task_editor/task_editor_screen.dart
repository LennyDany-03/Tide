import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/task_copy.dart';
import '../../services/models/reminder_options.dart';
import '../../services/reminders/reminder_scope.dart';
import '../../services/tasks/task.dart';
import '../../services/tasks/task_scope.dart';
import '../../services/tasks/task_store.dart' show TaskCompletion;
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_button.dart';
import '../tasks/widgets/due_date_sheet.dart';
import '../tasks/widgets/list_options_sheet.dart' show TagChip;
import '../tasks/widgets/reminder_sheet.dart';
import '../tasks/widgets/repeat_sheet.dart';

/// One task, opened.
///
/// **It saves itself.** The first version had a Save button that sat greyed
/// out until something changed, and a "discard changes?" dialog on the way
/// out — two chances to lose an edit on a screen whose whole purpose is to
/// be quick. Edits are kept the moment you leave, however you leave: back,
/// the system gesture, or Done.
///
/// **Rows, not a form.** Due, repeat and reminders are rows in one card, each
/// showing its current answer and opening a sheet of sensible choices — the
/// shape of every settings list, so nothing has to be learned. A five-way
/// segmented control and a date-then-time picker pair are gone.
///
/// **Finishing is a button.** "Mark as complete" sits at the foot where the
/// thumb is. Delete is in the header: one tap, with Undo on the list behind —
/// a hold-to-confirm is for things that cannot be taken back, and a deleted
/// task can.
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  Task? _original;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _tagInput = TextEditingController();
  final TextEditingController _stepInput = TextEditingController();

  DateTime? _due;
  TaskRecurrence _recurrence = TaskRecurrence.none;
  int? _months;
  List<DateTime> _reminders = [];
  List<String> _tags = [];
  List<Subtask> _subtasks = [];
  int _stepIds = 0;

  /// Set once the task has been saved, completed or deleted by an explicit
  /// action, so leaving afterwards does not write the draft over it.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    final task = TaskScope.read(context).byId(widget.taskId);
    _original = task;
    if (task == null) return;
    _title.text = task.title;
    _notes.text = task.description ?? '';
    _due = task.dueDate;
    _recurrence = task.recurrence;
    _months = task.customRecurrenceMonths;
    _reminders = [...task.reminders];
    _tags = [...task.tags];
    _subtasks = [...task.subtasks];
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tagInput.dispose();
    _stepInput.dispose();
    super.dispose();
  }

  Task? get _draft {
    final original = _original;
    if (original == null) return null;
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    return original.copyWith(
      title: title.isEmpty ? original.title : title,
      description: notes.isEmpty ? null : notes,
      dueDate: _due,
      recurrence: _recurrence,
      customRecurrenceMonths: _recurrence == TaskRecurrence.custom
          ? _months
          : null,
      reminders: _reminders,
      tags: _tags,
      subtasks: _subtasks,
    );
  }

  /// Writes the draft, once. Every way out of the screen comes through here.
  void _save() {
    if (_settled) return;
    _settled = true;
    final draft = _draft;
    if (draft != null) TaskScope.read(context).update(draft);
  }

  void _done() => context.pop();

  /// Completes the task, or reopens a finished one.
  ///
  /// [lastStep] is set when ticking that step is what finished the task.
  /// Undo then takes the tick back as well — otherwise it would return a
  /// task with every step done and nothing left to finish it with.
  void _complete({String? lastStep}) {
    final store = TaskScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final wasDone = _original!.isCompleted;
    _save();
    // Unticking a step on a finished task already reopened it on save;
    // toggling again would try to finish it straight back.
    final saved = store.byId(widget.taskId);
    final completion = saved != null && saved.isCompleted == wasDone
        ? store.toggleComplete(widget.taskId)
        : null;
    final undo = completion == null
        ? null
        : lastStep == null
        ? completion
        : TaskCompletion(
            before: completion.before.copyWith(
              subtasks: [
                for (final s in completion.before.subtasks)
                  s.id == lastStep ? s.copyWith(isCompleted: false) : s,
              ],
            ),
            spawnedId: completion.spawnedId,
          );
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: TideMotion.snackHold,
          content: Text(
            wasDone
                ? 'Moved back to your list.'
                : lastStep != null
                ? 'Last step done. Task complete.'
                : completion?.spawnedId != null
                ? 'Completed. The next one is on your list.'
                : 'Completed.',
            style: TideType.label,
          ),
          action: undo == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => store.undoCompletion(undo),
                ),
        ),
      );
  }

  /// Ticks a step, or unticks it. Ticking the last open step finishes the
  /// task — the steps are what the task is made of, so once they are all
  /// done there is nothing left to finish.
  void _toggleStep(Subtask step) {
    setState(() {
      _subtasks = [
        for (final s in _subtasks)
          s.id == step.id ? s.copyWith(isCompleted: !s.isCompleted) : s,
      ];
    });
    final finished =
        !step.isCompleted &&
        !_original!.isCompleted &&
        _subtasks.every((s) => s.isCompleted);
    if (finished) _complete(lastStep: step.id);
  }

  void _delete() {
    final store = TaskScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    _settled = true;
    final removed = store.delete(widget.taskId);
    context.pop();
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: TideMotion.snackHold,
          content: Text('Task deleted.', style: TideType.label),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.restore(removed),
          ),
        ),
      );
  }

  // --- Pickers ---------------------------------------------------------------

  Future<void> _chooseDue() async {
    FocusScope.of(context).unfocus();
    final choice = await showDueDateSheet(context, current: _due);
    if (choice != null && mounted) setState(() => _due = choice.date);
  }

  Future<void> _chooseRepeat() async {
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

  Future<void> _addReminder() async {
    FocusScope.of(context).unfocus();
    final store = TaskScope.read(context);
    final at = await showReminderSheet(context, due: _due);
    if (at == null || !mounted) return;
    setState(() {
      if (!_reminders.contains(at)) _reminders = [..._reminders, at]..sort();
    });
    await store.requestReminderPermission();
  }

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll(RegExp(r'^#+'), '').replaceAll(' ', '-');
    _tagInput.clear();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags = [..._tags, tag]);
  }

  void _addStep(String raw) {
    final title = raw.trim();
    _stepInput.clear();
    if (title.isEmpty) return;
    setState(() {
      _subtasks = [
        ..._subtasks,
        Subtask(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_stepIds++}',
          title: title,
        ),
      ];
    });
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final original = _original;
    if (original == null) {
      return Scaffold(
        backgroundColor: TideColors.deepWater,
        body: Column(
          children: [
            _Header(onBack: _done),
            const Expanded(
              child: TideEmptyNote(message: 'This task is no longer here.'),
            ),
          ],
        ),
      );
    }

    final done = original.isCompleted;
    final stepsLeft = _subtasks.where((s) => !s.isCompleted).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        body: Column(
          children: [
            _Header(onBack: _done, onDelete: _delete, onDone: _done),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _TitleBlock(
                    title: _title,
                    notes: _notes,
                    completedAt: done ? original.completedAt : null,
                  ),
                  const SizedBox(height: 22),

                  _Group(
                    children: [
                      _Row(
                        icon: Icons.event_rounded,
                        label: 'Due',
                        value: _due == null ? 'None' : TaskCopy.dueLong(_due!),
                        active: _due != null,
                        onTap: _chooseDue,
                        onClear: _due == null
                            ? null
                            : () => setState(() => _due = null),
                      ),
                      _Row(
                        icon: Icons.repeat_rounded,
                        label: 'Repeat',
                        value: TaskCopy.repeat(
                          original.copyWith(
                            recurrence: _recurrence,
                            customRecurrenceMonths: _months,
                          ),
                        ),
                        active: _recurrence != TaskRecurrence.none,
                        onTap: _chooseRepeat,
                      ),
                    ],
                  ),
                  if (_recurrence != TaskRecurrence.none)
                    _Footnote(
                      _due == null
                          ? 'Counted from the day you complete it.'
                          : 'The next one appears when you complete this one.',
                    ),
                  const SizedBox(height: 22),

                  _GroupLabel('Reminders'),
                  _Group(
                    children: [
                      for (final at in _reminders)
                        _Row(
                          icon: Icons.notifications_active_outlined,
                          label: TaskCopy.reminder(at),
                          active: at.isAfter(DateTime.now()),
                          onClear: () => setState(
                            () => _reminders = [..._reminders]..remove(at),
                          ),
                        ),
                      _Row(
                        icon: Icons.add_alarm_rounded,
                        label: _reminders.isEmpty
                            ? 'Add a reminder'
                            : 'Add another',
                        muted: true,
                        onTap: _addReminder,
                      ),
                    ],
                  ),
                  if (_reminders.isNotEmpty) _Footnote(_reminderNote(context)),
                  const SizedBox(height: 22),

                  _GroupLabel(
                    'Steps',
                    trailing: _subtasks.isEmpty
                        ? null
                        : '${_subtasks.where((s) => s.isCompleted).length}'
                              ' of ${_subtasks.length}',
                  ),
                  _Group(
                    children: [
                      for (final step in _subtasks) _stepRow(step),
                      _InputRow(
                        controller: _stepInput,
                        icon: Icons.add_rounded,
                        hint: 'Add a step',
                        onSubmitted: _addStep,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _GroupLabel('Tags'),
                  _tagsBlock(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: TideColors.deepWater,
                border: Border(top: BorderSide(color: TideColors.hairline)),
              ),
              // Clear of the gesture bar, which the keyboard covers when it
              // is up. Only this reads the inset: the whole editor reading
              // `MediaQuery.of` rebuilt on every frame of the keyboard's slide.
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: TideButton(
                  label: done
                      ? 'Mark as not done'
                      : stepsLeft > 0
                      ? 'Finish ${TaskCopy.steps(stepsLeft)} first'
                      : 'Mark as complete',
                  variant: done || stepsLeft > 0
                      ? TideButtonVariant.secondary
                      : TideButtonVariant.primary,
                  icon: Icon(
                    done
                        ? Icons.undo_rounded
                        : stepsLeft > 0
                        ? Icons.checklist_rounded
                        : Icons.check_rounded,
                    size: 19,
                    color: done || stepsLeft > 0
                        ? TideColors.bone
                        : TideColors.onLantern,
                  ),
                  // The task finishes with its last step, not before it.
                  onPressed: !done && stepsLeft > 0 ? null : _complete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(Subtask step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        children: [
          Semantics(
            checked: step.isCompleted,
            button: true,
            label: step.title,
            child: PressScale(
              onTap: () => _toggleStep(step),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.isCompleted
                        ? TideColors.lantern
                        : Colors.transparent,
                    border: Border.all(
                      color: step.isCompleted
                          ? TideColors.lantern
                          : TideColors.bone.withValues(alpha: 0.28),
                      width: 1.6,
                    ),
                  ),
                  child: step.isCompleted
                      ? Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: TideColors.onLantern,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.title,
              style: TideType.body.copyWith(
                color: step.isCompleted ? TideColors.silt : TideColors.bone,
                decoration: step.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: TideColors.silt,
              ),
            ),
          ),
          _ClearButton(
            onTap: () => setState(
              () => _subtasks = [
                for (final s in _subtasks)
                  if (s.id != step.id) s,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                TagChip(
                  label: '#$tag',
                  selected: true,
                  onTap: null,
                  onRemove: () =>
                      setState(() => _tags = [..._tags]..remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _Group(
          children: [
            _InputRow(
              controller: _tagInput,
              icon: Icons.sell_outlined,
              hint: 'Add a tag',
              onSubmitted: _addTag,
            ),
          ],
        ),
      ],
    );
  }
}

// --- Pieces ----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.onBack, this.onDelete, this.onDone});

  final VoidCallback onBack;
  final VoidCallback? onDelete;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.viewPaddingOf(context).top + 8,
        16,
        8,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: PressScale(
              onTap: onBack,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: TideColors.bone,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (onDelete != null)
            Semantics(
              button: true,
              label: 'Delete task',
              child: PressScale(
                onTap: onDelete,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: TideColors.hairline),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: TideColors.coral,
                  ),
                ),
              ),
            ),
          if (onDone != null) ...[
            const SizedBox(width: 10),
            PressScale(
              onTap: onDone,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TideColors.lantern.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Text(
                  'Done',
                  style: TideType.label.copyWith(
                    color: TideColors.lantern,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The title at display size and the notes straight under it, both plain
/// text on the page — edited in place, the way they read.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.notes,
    required this.completedAt,
  });

  final TextEditingController title;
  final TextEditingController notes;
  final DateTime? completedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (completedAt != null) ...[
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: TideColors.lantern,
              ),
              const SizedBox(width: 6),
              Text(
                TaskCopy.completed(completedAt!),
                style: TideType.labelMuted.copyWith(color: TideColors.lantern),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: title,
          style: TideType.hero.copyWith(fontSize: 26, letterSpacing: -0.8),
          cursorColor: TideColors.lantern,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Task name',
            hintStyle: TideType.hero.copyWith(
              fontSize: 26,
              color: TideColors.silt,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
        TextField(
          controller: notes,
          style: TideType.body.copyWith(color: TideColors.silt),
          cursorColor: TideColors.lantern,
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          decoration: InputDecoration(
            hintText: 'Add notes',
            hintStyle: TideType.bodyMuted.copyWith(
              color: TideColors.silt.withValues(alpha: 0.7),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(text, style: TideType.sectionHeader),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: TideType.labelMuted),
        ],
      ),
    );
  }
}

/// A card of rows, hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TideColors.shelf,
        borderRadius: TideElevation.radius20,
        border: Border.all(color: TideColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 52),
                color: TideColors.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A setting and its current answer. Taps open a sheet; the × clears it.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.onClear,
    this.active = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool active;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? TideColors.lantern.withValues(alpha: 0.14)
                    : TideColors.bone.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: active ? TideColors.lantern : TideColors.silt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TideType.label.copyWith(
                  color: muted ? TideColors.silt : TideColors.bone,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  style: TideType.label.copyWith(
                    color: active ? TideColors.bone : TideColors.silt,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (onClear != null)
              _ClearButton(onTap: onClear!)
            else if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: TideColors.silt.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
    return onTap == null
        ? row
        : PressScale(onTap: onTap, scale: 0.99, child: row);
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove',
      child: PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.close_rounded, size: 18, color: TideColors.silt),
        ),
      ),
    );
  }
}

/// A row that is a field: type and press return, and it stays open.
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.bone.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: TideColors.silt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TideType.label,
              cursorColor: TideColors.lantern,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: onSubmitted,
              onEditingComplete: () {},
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TideType.label.copyWith(color: TideColors.silt),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How this to-do's reminders will arrive. To-dos follow the defaults in
/// Settings → Reminders rather than carrying their own, so the editor says
/// what those are instead of offering controls it does not have.
String _reminderNote(BuildContext context) {
  final defaults =
      ReminderScope.maybeOf(context)?.settings.taskDefaults ??
      ReminderOptions.taskDefaults;
  final arrives = defaults.style == AlarmStyle.call
      ? 'Rings as the Lighthouse'
      : 'Arrives as a notification';
  final lead = defaults.leadMinutes > 0
      ? ', with a heads-up ${defaults.leadMinutes} min before'
      : '';
  return '$arrives$lead. Snooze ${defaults.snoozeMinutes} min. '
      'Change it in Settings → Reminders.';
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(text, style: TideType.labelMuted.copyWith(fontSize: 12.5)),
    );
  }
}
