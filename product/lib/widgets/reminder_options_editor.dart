import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../services/models/reminder_options.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';
import 'segmented_pill.dart';
import 'tide_switch.dart';

/// How a reminder arrives: the heads-up before it, full screen or gentle at
/// its time, its sound, and its snooze.
///
/// One editor for three places — a habit's own reminder, the habit defaults
/// and the to-do defaults in Settings → Reminders — so the three can never
/// drift into describing the same choice three ways. [forTasks] only changes
/// the names: a to-do's full-screen call is the Lighthouse, not the Tide
/// Call.
///
/// [foldSoundAndSnooze] folds the less-used half away behind one row, for the
/// habit form, which is long enough already.
class ReminderOptionsEditor extends StatefulWidget {
  const ReminderOptionsEditor({
    super.key,
    required this.options,
    required this.onChanged,
    this.forTasks = false,
    this.fullScreenCalls = true,
    this.onPreviewTone,
    this.foldSoundAndSnooze = false,
  });

  final ReminderOptions options;
  final ValueChanged<ReminderOptions> onChanged;
  final bool forTasks;

  /// The phone can take the screen. Where it cannot (iOS), the call is a
  /// time-sensitive alert that opens it, and the copy says so.
  final bool fullScreenCalls;

  /// Plays a tone on the spot. Null where the platform cannot.
  final ValueChanged<ReminderTone>? onPreviewTone;

  final bool foldSoundAndSnooze;

  @override
  State<ReminderOptionsEditor> createState() => _ReminderOptionsEditorState();
}

class _ReminderOptionsEditorState extends State<ReminderOptionsEditor> {
  bool _open = false;

  ReminderOptions get _options => widget.options;

  void _set(ReminderOptions next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    const leads = AppConstants.reminderLeadChoices;
    const snoozes = AppConstants.reminderSnoozeChoices;
    final callName = widget.forTasks ? 'Lighthouse' : 'Tide Call';

    final soundAndSnooze = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Sound'),
        _ToneChips(
          selected: _options.tone,
          onSelected: (tone) {
            _set(_options.copyWith(tone: tone));
            widget.onPreviewTone?.call(tone);
          },
          previews: widget.onPreviewTone != null,
        ),
        const SizedBox(height: 4),
        _ToggleRow(
          label: 'Vibrate',
          value: _options.vibrate,
          onChanged: (value) => _set(_options.copyWith(vibrate: value)),
        ),
        const SizedBox(height: 12),
        const _Label('Snooze for'),
        SegmentedPill(
          labels: [for (final m in snoozes) '$m min'],
          selectedIndex: snoozes
              .indexOf(_options.snoozeMinutes)
              .clamp(0, snoozes.length - 1),
          onChanged: (i) => _set(_options.copyWith(snoozeMinutes: snoozes[i])),
        ),
        if (_options.style == AlarmStyle.call && widget.fullScreenCalls) ...[
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Ring through Do Not Disturb',
            subtitle: 'Off means a silenced phone stays silent',
            value: _options.throughDnd,
            onChanged: (value) => _set(_options.copyWith(throughDnd: value)),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Heads-up before'),
        SegmentedPill(
          labels: [for (final m in leads) m == 0 ? 'None' : '$m min'],
          selectedIndex: leads
              .indexOf(_options.leadMinutes)
              .clamp(0, leads.length - 1),
          onChanged: (i) => _set(_options.copyWith(leadMinutes: leads[i])),
        ),
        const SizedBox(height: 14),
        _Label(widget.forTasks ? 'When it is due' : 'When it is time'),
        Row(
          children: [
            Expanded(
              child: _StyleCard(
                title: callName,
                detail: widget.fullScreenCalls
                    ? 'Full screen, even locked — like an alarm'
                    : 'An urgent alert that opens full screen',
                icon: widget.forTasks
                    ? Icons.flare_rounded
                    : Icons.waves_rounded,
                selected: _options.style == AlarmStyle.call,
                onTap: () => _set(_options.copyWith(style: AlarmStyle.call)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StyleCard(
                title: 'Gentle',
                detail: 'A notification, and nothing more',
                icon: Icons.notifications_none_rounded,
                selected: _options.style == AlarmStyle.gentle,
                onTap: () => _set(_options.copyWith(style: AlarmStyle.gentle)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!widget.foldSoundAndSnooze)
          soundAndSnooze
        else ...[
          _FoldRow(
            label: 'Sound and snooze',
            detail:
                '${_options.tone.label} · snooze ${_options.snoozeMinutes} min',
            open: _open,
            onTap: () => setState(() => _open = !_open),
          ),
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: soundAndSnooze,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TideType.sectionHeader),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $detail',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: TideMotion.tabSwitch,
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: selected
                  ? TideColors.lantern.withValues(alpha: 0.1)
                  : TideColors.shelf,
              borderRadius: TideElevation.radius12,
              border: Border.all(
                color: selected
                    ? TideColors.lantern.withValues(alpha: 0.6)
                    : TideColors.hairline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? TideColors.lantern : TideColors.silt,
                ),
                const SizedBox(height: 8),
                Text(title, style: TideType.label),
                const SizedBox(height: 2),
                Text(detail, style: TideType.labelMuted.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToneChips extends StatelessWidget {
  const _ToneChips({
    required this.selected,
    required this.onSelected,
    required this.previews,
  });

  final ReminderTone selected;
  final ValueChanged<ReminderTone> onSelected;
  final bool previews;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tone in ReminderTone.values)
          Semantics(
            button: true,
            selected: tone == selected,
            label: previews ? '${tone.label}, plays a preview' : tone.label,
            child: ExcludeSemantics(
              child: PressScale(
                onTap: () => onSelected(tone),
                child: AnimatedContainer(
                  duration: TideMotion.tabSwitch,
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: tone == selected
                        ? TideColors.lantern.withValues(alpha: 0.12)
                        : TideColors.shelf,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: tone == selected
                          ? TideColors.lantern.withValues(alpha: 0.6)
                          : TideColors.hairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tone == selected && previews) ...[
                        Icon(
                          Icons.volume_up_rounded,
                          size: 15,
                          color: TideColors.lantern,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        tone.label,
                        style: TideType.label.copyWith(
                          fontSize: 13,
                          color: tone == selected
                              ? TideColors.lantern
                              : TideColors.bone,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TideType.label),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TideType.labelMuted.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TideSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FoldRow extends StatelessWidget {
  const _FoldRow({
    required this.label,
    required this.detail,
    required this.open,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      label: '$label, $detail',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TideType.label),
                      Text(
                        detail,
                        style: TideType.labelMuted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: TideMotion.tabSwitch,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: TideColors.silt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
