import 'dart:async';

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
import '../../widgets/press_scale.dart';
import '../../widgets/ripple_burst.dart';
import '../../widgets/segmented_pill.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_dialog.dart';
import 'widgets/day_selector.dart';
import 'widgets/freeze_stepper.dart';
import 'widgets/icon_picker.dart';
import 'widgets/live_habit_preview.dart';
import 'widgets/name_field.dart';
import 'widgets/reminder_row.dart';
import 'widgets/target_fields.dart';

/// Create or edit a habit.
///
/// A screen, not a sheet. It was a sheet that grew out of the FAB — a
/// modal, non-opaque route that scaled a nine-field form up from one corner
/// while a `BackdropFilter` blurred everything behind it, every frame of
/// the way. That is the most expensive transition the app could possibly
/// have chosen, and it was spent on the longest-lived screen in it: a
/// blurred live page underneath a form nobody fills in in under a minute.
/// On a mid-range phone the entrance dropped frames before the first field
/// was even visible.
///
/// The form itself is unchanged in kind — everything on it still feeds the
/// live preview at the top, so it is never describing a habit in the
/// abstract. It simply arrives the way a page arrives.
class AddEditHabitScreen extends StatefulWidget {
  const AddEditHabitScreen({super.key, this.habitId});

  /// Null creates; a habit id edits.
  final String? habitId;

  @override
  State<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends State<AddEditHabitScreen> {
  final TextEditingController _name = TextEditingController();

  TideGlyph _glyph = TideGlyph.water;
  HabitType _type = HabitType.binary;
  num _target = 1;
  String _unit = '';

  /// Empty on a new habit: which days it runs is the person's decision, not a
  /// default they have to notice and undo. See [DaySelector].
  Set<int> _days = {};

  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  int _freezes = AppConstants.defaultFreezeAllowance;

  TideButtonPhase _phase = TideButtonPhase.idle;

  /// One pulse per field, so a missing schedule does not shake a name that
  /// was filled in perfectly well.
  int _nameErrorTick = 0;
  int _daysErrorTick = 0;

  int _savedTick = 0;
  bool _dirty = false;

  /// Where a failed save scrolls to. The save button is pinned below the
  /// form, so the field it is complaining about may be well out of view.
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _daysKey = GlobalKey();

  /// True from the moment leaving has been decided, so a save that pops and
  /// a back gesture cannot both drive the route at once.
  bool _leaving = false;

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

    _name.addListener(_markDirty);
  }

  @override
  void dispose() {
    _name.removeListener(_markDirty);
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
  ///
  /// It resets on any change of type, not only from a target of 1. The old
  /// guard kept any target above 1, so Quantity then Duration turned 8
  /// glasses into an 8-minute session.
  void _setType(int index) {
    final next = HabitType.values[index];
    if (next == _type) return;
    _edit(() {
      _type = next;
      switch (next) {
        case HabitType.binary:
          _target = 1;
          _unit = '';
        case HabitType.quantity:
          _unit = 'glasses';
          _target = 8;
        case HabitType.duration:
          // Duration is always carried in minutes; the control formats it.
          _unit = 'min';
          _target = 30;
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

  /// Pulses every field that is missing, and brings the first of them into
  /// view. Returns whether the form can be saved.
  bool _validate() {
    final missingName = _name.text.trim().isEmpty;
    final missingDays = _days.isEmpty;
    if (!missingName && !missingDays) return true;

    setState(() {
      if (missingName) _nameErrorTick++;
      if (missingDays) _daysErrorTick++;
    });
    final target = (missingName ? _nameKey : _daysKey).currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: TideMotion.sheetIn,
          curve: TideMotion.sheetCurve,
        ),
      );
    }
    return false;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _phase = TideButtonPhase.busy);
    // A beat of spinner before the checkmark, so the save reads as one
    // continuous motion rather than the page blinking out.
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
      _leaving = true;
      _dirty = false;
    });

    await Future<void>.delayed(TideMotion.ripple);
    if (mounted) context.pop();
  }

  void _delete() {
    setState(() => _leaving = true);
    TideScope.read(context).deleteHabit(widget.habitId!);
    context.pop();
  }

  /// The one way out. Both the × and the system back gesture end here, so
  /// they cannot disagree about what unsaved means.
  Future<void> _attemptLeave() async {
    if (_leaving) return;
    if (!_dirty) {
      context.pop();
      return;
    }
    setState(() => _leaving = true);
    final discard = await confirmDiscardChanges(context);
    if (!mounted) return;
    if (discard) {
      context.pop();
    } else {
      setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The home indicator's inset, except while the keyboard is up — the
    // scaffold has already lifted the whole body by then, and adding the
    // gesture inset on top of that leaves a band of dead ground between the
    // save button and the keys.
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > 0 ? 0.0 : media.padding.bottom;

    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptLeave();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        body: RippleBurst(
          trigger: _savedTick,
          color: TideColors.lantern,
          origin: Alignment.bottomCenter,
          intensity: 1.6,
          child: Stack(
            children: [
              const Positioned.fill(child: TideBackdrop()),
              Column(
                children: [
                  _header(),
                  Expanded(child: _form(context)),
                  _footer(bottom),
                ],
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TideTopScrim(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        MediaQuery.paddingOf(context).top + 10,
        20,
        6,
      ),
      child: Row(
        children: [
          PressScale(
            onTap: _attemptLeave,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 21,
                color: TideColors.bone,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _isEditing ? 'Edit habit' : 'New habit',
              style: TideType.hero,
            ),
          ),
          // The chosen icon, restated at the top of the page. It is the one
          // part of the form you cannot see the effect of without looking
          // back up at the preview.
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.lantern,
              shape: BoxShape.circle,
            ),
            child: HabitGlyph(
              glyph: _glyph,
              size: 18,
              color: TideColors.onLantern,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(double bottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      decoration: BoxDecoration(
        color: TideColors.deepWater,
        border: Border(top: BorderSide(color: TideColors.hairline)),
      ),
      child: TideButton(
        label: _isEditing ? 'Save changes' : 'Create habit',
        phase: _phase,
        onPressed: _save,
      ),
    );
  }

  Widget _form(BuildContext context) {
    // A scroll view over a column rather than a ListView: a lazy list does
    // not build the fields scrolled far out of view, and a failed save has to
    // be able to scroll to any of them.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiveHabitPreview(
            name: _name.text,
            glyph: _glyph,
            type: _type,
            days: _days,
          ),
          const SizedBox(height: 22),

          _label('Name', key: _nameKey),
          NameField(
            controller: _name,
            errorTick: _nameErrorTick,
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

          _label('Days', key: _daysKey),
          DaySelector(
            days: _days,
            errorTick: _daysErrorTick,
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
            ceiling: TideScope.of(context).freezeCeiling,
            onChanged: (value) => _edit(() => _freezes = value),
          ),

          if (_isEditing) ...[
            const SizedBox(height: 24),
            HoldToConfirmButton(
              label: 'Hold to delete habit',
              holdingLabel: 'Keep holding…',
              onConfirm: _delete,
            ),
          ],
        ],
      ),
    );
  }

  /// A field label.
  ///
  /// Sentence case. These were tracked-out capitals — NAME, ICON, TYPE,
  /// DAYS — which is the loudest possible way to label a text box, and put
  /// four shouting labels above the four quietest controls in the app.
  Widget _label(String text, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: TideType.sectionHeader),
    );
  }
}
