import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/models/habit.dart';
import '../../services/models/tide_glyph.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/habit_glyph.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/ripple_burst.dart';
import '../../widgets/segmented_pill.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_fab.dart';
import '../../widgets/tide_sheet.dart';
import 'widgets/day_selector.dart';
import 'widgets/freeze_stepper.dart';
import 'widgets/icon_picker.dart';
import 'widgets/live_habit_preview.dart';
import 'widgets/name_field.dart';
import 'widgets/reminder_row.dart';
import 'widgets/target_fields.dart';
import 'widgets/unsaved_changes_nudge.dart';

/// Create or edit a habit.
///
/// Presented as a sheet the FAB grows into. Everything on it feeds the live
/// preview at the top, so the form is never describing a habit in the
/// abstract — the card is right there, changing as you type.
class AddEditHabitSheet extends StatefulWidget {
  const AddEditHabitSheet({super.key, this.habitId});

  /// Null creates; a habit id edits.
  final String? habitId;

  @override
  State<AddEditHabitSheet> createState() => _AddEditHabitSheetState();
}

class _AddEditHabitSheetState extends State<AddEditHabitSheet> {
  final TextEditingController _name = TextEditingController();

  TideGlyph _glyph = TideGlyph.diamond;
  HabitType _type = HabitType.binary;
  num _target = 1;
  String _unit = '';
  Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  int _freezes = AppConstants.defaultFreezeAllowance;

  TideButtonPhase _phase = TideButtonPhase.idle;
  int _errorTick = 0;
  int _savedTick = 0;
  bool _dirty = false;
  bool _showUnsavedNudge = false;

  Habit? _existing;

  bool get _isEditing => widget.habitId != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.habitId == null
        ? null
        : TideScope.read(context).habitById(widget.habitId!);

    if (habit != null) {
      _existing = habit;
      _name.text = habit.name;
      _glyph = habit.glyph;
      _type = habit.type;
      _target = habit.target;
      _unit = habit.unit;
      _days = Set<int>.from(habit.days);
      _reminderEnabled = habit.reminderEnabled;
      _reminderTime = habit.reminderTime;
      _freezes = habit.freezeAllowance;
    }

    _name.addListener(() => _markDirty());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _edit(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  /// Switching type resets the target to something sensible for that type
  /// rather than carrying "8 glasses" across into a duration habit.
  void _setType(int index) {
    final next = HabitType.values[index];
    _edit(() {
      _type = next;
      switch (next) {
        case HabitType.binary:
          _target = 1;
          _unit = '';
        case HabitType.quantity:
          if (_unit.isEmpty || _unit == 'min') _unit = 'glasses';
          if (_target <= 1) _target = 8;
        case HabitType.duration:
          _unit = 'min';
          if (_target <= 1) _target = 30;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) _edit(() => _reminderTime = picked);
  }

  String get _reminderPreview {
    // A habit that does not exist yet has no streak, and the preview must
    // not invent one — the whole point of showing the copy up front is that
    // it is the copy the user will actually receive.
    final streak = _existing == null
        ? 0
        : StreakCalculator.currentStreak(_existing!);
    final draft = Habit(
      id: 'preview',
      name: _name.text,
      glyph: _glyph,
      type: _type,
      createdAt: DateTime.now(),
    );
    return draft.reminderPreview(streak);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _days.isEmpty) {
      setState(() => _errorTick++);
      return;
    }

    setState(() => _phase = TideButtonPhase.busy);
    // A beat of spinner before the checkmark, so the save reads as one
    // continuous motion rather than the sheet blinking out.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    final store = TideScope.read(context);
    if (_existing != null) {
      store.updateHabit(
        _existing!.copyWith(
          name: _name.text.trim(),
          glyph: _glyph,
          type: _type,
          target: _target,
          unit: _unit,
          days: _days,
          reminderEnabled: _reminderEnabled,
          reminderTime: _reminderTime,
          freezeAllowance: _freezes,
          freezesRemaining: _freezes,
        ),
      );
    } else {
      store.addHabit(
        Habit(
          id: store.newHabitId(),
          name: _name.text.trim(),
          glyph: _glyph,
          type: _type,
          target: _target,
          unit: _unit,
          days: _days,
          reminderEnabled: _reminderEnabled,
          reminderTime: _reminderTime,
          freezeAllowance: _freezes,
          freezesRemaining: _freezes,
          createdAt: DateTime.now(),
        ),
      );
    }

    setState(() {
      _phase = TideButtonPhase.done;
      _savedTick++;
    });

    await Future<void>.delayed(TideMotion.ripple);
    if (mounted) context.pop();
  }

  void _delete() {
    TideScope.read(context).deleteHabit(widget.habitId!);
    context.pop();
  }

  void _attemptDismiss() {
    if (_dirty && !_showUnsavedNudge) {
      setState(() => _showUnsavedNudge = true);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _showUnsavedNudge,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showUnsavedNudge = true);
      },
      child: RippleBurst(
        trigger: _savedTick,
        color: TideColors.lantern,
        origin: Alignment.bottomCenter,
        intensity: 1.6,
        child: TideSheet(
          title: _isEditing ? 'Edit habit' : 'New habit',
          leading: TideFabMorphTarget(
            // Ground colour, because the disc under it is solid lantern —
            // the glyph was inheriting the accent and disappearing into it.
            child: HabitGlyph(
              glyph: _glyph,
              size: 16,
              color: TideColors.deepWater,
            ),
          ),
          onDismiss: _attemptDismiss,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnsavedChangesNudge(
                visible: _showUnsavedNudge,
                onDiscard: () => context.pop(),
                onKeepEditing: () => setState(() => _showUnsavedNudge = false),
              ),
              TideButton(
                label: _isEditing ? 'Save changes' : 'Create habit',
                phase: _phase,
                onPressed: _save,
              ),
            ],
          ),
          child: _form(),
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        LiveHabitPreview(
          name: _name.text,
          glyph: _glyph,
          type: _type,
          days: _days,
        ),
        const SizedBox(height: 22),

        _label('Name'),
        NameField(
          controller: _name,
          errorTick: _errorTick,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 20),

        _label('Icon'),
        IconPicker(
          selected: _glyph,
          onChanged: (glyph) => _edit(() => _glyph = glyph),
        ),
        const SizedBox(height: 20),

        _label('Type'),
        SegmentedPill(
          labels: [for (final type in HabitType.values) type.label],
          selectedIndex: HabitType.values.indexOf(_type),
          onChanged: _setType,
        ),
        TargetFields(
          type: _type,
          target: _target,
          unit: _unit,
          onTargetChanged: (value) => _edit(() => _target = value),
          onUnitChanged: (value) => _edit(() => _unit = value),
        ),
        const SizedBox(height: 20),

        _label('Days'),
        DaySelector(
          days: _days,
          onChanged: (days) => _edit(() => _days = days),
        ),
        const SizedBox(height: 20),

        ReminderRow(
          enabled: _reminderEnabled,
          time: _reminderTime,
          preview: _reminderPreview,
          onToggled: (value) => _edit(() => _reminderEnabled = value),
          onTimeTapped: _pickTime,
        ),
        const SizedBox(height: 12),

        FreezeStepper(
          value: _freezes,
          onChanged: (value) => _edit(() => _freezes = value),
        ),

        if (_isEditing) ...[
          const SizedBox(height: 20),
          HoldToConfirmButton(
            label: 'Hold to delete habit',
            holdingLabel: 'Keep holding…',
            onConfirm: _delete,
          ),
        ],
      ],
    );
  }

  /// A field label.
  ///
  /// Sentence case. These were tracked-out capitals — NAME, ICON, TYPE,
  /// DAYS — which is the loudest possible way to label a text box, and put
  /// four shouting labels above the four quietest controls in the app.
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: TideType.sectionHeader),
    );
  }
}
