import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// Six cells, and one real text field under them.
///
/// Six separate fields is the obvious build and the wrong one. Focus has to
/// be walked from box to box by hand, backspace has to walk it back, a
/// pasted "482913" lands whole in the first box, and the keyboard's
/// one-time-code suggestion has nowhere to go. One field does all of that
/// natively; the cells are only how its text is drawn.
///
/// The field fills the row and is invisible — no text, no caret, no
/// selection colour — so a tap anywhere focuses it and a long press offers
/// Paste, while the cells on top ignore the pointer entirely.
class CodeCells extends StatefulWidget {
  const CodeCells({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onChanged,
    required this.accepted,
    this.error = false,
    this.errorTick = 0,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onChanged;

  /// 0..1 through the acceptance: drives the cells lighting left to right.
  final Animation<double> accepted;

  final bool error;

  /// Increment to replay the shake.
  final int errorTick;

  final bool enabled;

  @override
  State<CodeCells> createState() => _CodeCellsState();
}

class _CodeCellsState extends State<CodeCells>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: TideMotion.errorShake,
  );

  static const double _cellHeight = 60;
  static const double _maxCellWidth = 52;
  static const double _gap = 8;

  /// Six digits read as two groups of three, the way people read them out
  /// and the way the email sets them.
  static const double _groupGap = 18;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_keepCaretAtEnd);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CodeCells old) {
    super.didUpdateWidget(old);
    if (old.errorTick != widget.errorTick && widget.errorTick > 0) {
      _shake
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_keepCaretAtEnd);
    widget.focusNode.removeListener(_onFocus);
    _shake.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  /// The caret belongs after the last digit. The field is invisible, so a
  /// tap that parked it mid-code would make the next digit land in a cell
  /// the person was not looking at.
  void _keepCaretAtEnd() {
    final value = widget.controller.value;
    final end = value.text.length;
    if (value.selection.isCollapsed && value.selection.baseOffset == end) {
      return;
    }
    widget.controller.selection = TextSelection.collapsed(offset: end);
  }

  bool get _grouped => widget.length == 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gaps =
            _gap * (widget.length - 1) + (_grouped ? _groupGap - _gap : 0);
        final cellWidth = math.min(
          _maxCellWidth,
          (constraints.maxWidth - gaps) / widget.length,
        );

        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            // Three decaying swings, matching the refused-field shake.
            final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 6) * 7 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Center(
            child: SizedBox(
              width: cellWidth * widget.length + gaps,
              height: _cellHeight,
              child: Stack(
                children: [
                  Positioned.fill(child: _field()),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        widget.controller,
                        widget.accepted,
                      ]),
                      builder: (context, _) => Row(
                        children: [
                          for (var i = 0; i < widget.length; i++) ...[
                            if (i > 0)
                              SizedBox(
                                width: _grouped && i == widget.length ~/ 2
                                    ? _groupGap
                                    : _gap,
                              ),
                            _cell(i, cellWidth),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field() {
    return DefaultSelectionStyle(
      selectionColor: Colors.transparent,
      cursorColor: Colors.transparent,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: !widget.enabled,
        autofocus: true,
        expands: true,
        maxLines: null,
        showCursor: false,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.length),
        ],
        onChanged: widget.onChanged,
        style: const TextStyle(color: Colors.transparent, fontSize: 1),
        decoration: const InputDecoration.collapsed(hintText: null),
      ),
    );
  }

  Widget _cell(int i, double width) {
    final text = widget.controller.text;
    final digit = i < text.length ? text[i] : null;
    final active =
        widget.enabled &&
        widget.focusNode.hasFocus &&
        text.length < widget.length &&
        i == text.length;

    // Acceptance runs left to right: each cell starts a little after the
    // one before it and lights over the same span.
    final start = i / widget.length * 0.5;
    final lit = TideMotion.sheetCurve.transform(
      ((widget.accepted.value - start) / 0.35).clamp(0.0, 1.0),
    );
    final lighting = widget.accepted.value > 0;

    final Color border;
    if (lighting) {
      border = TideColors.lantern.withValues(alpha: 0.25 + 0.45 * lit);
    } else if (widget.error) {
      border = TideColors.coral.withValues(alpha: 0.65);
    } else if (active) {
      border = TideColors.lantern.withValues(alpha: 0.6);
    } else if (digit != null) {
      border = TideColors.bone.withValues(alpha: 0.14);
    } else {
      // An empty cell still needs an edge. A trench fill with no border is
      // near-black on near-black on Midnight, and a row of six read on a
      // phone as a single lit box — the active one — with nothing beside it.
      border = TideColors.hairline;
    }

    return AnimatedContainer(
      // The acceptance drives these values every frame itself; tweening on
      // top of it would make each cell trail its own animation.
      duration: lighting ? Duration.zero : TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      width: width,
      height: _cellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          TideColors.lantern.withValues(alpha: 0.16 * lit),
          TideColors.trench,
        ),
        borderRadius: TideElevation.radius12,
        border: Border.all(color: border, width: active ? 1.5 : 1),
      ),
      child: AnimatedSwitcher(
        duration: TideMotion.codeDigit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: animation, curve: TideMotion.overshoot),
            ),
            child: child,
          ),
        ),
        child: digit != null
            ? Text(
                digit,
                key: ValueKey('digit-$i-$digit'),
                style: TideType.gauge(
                  26,
                  color: Color.lerp(TideColors.bone, TideColors.lantern, lit),
                ),
              )
            : active
            ? const _Caret(key: ValueKey('caret'))
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

/// Where the next digit goes. Still rather than blinking: the lit border
/// already says which cell is next, and a blink is an ambient loop this
/// screen has not earned.
class _Caret extends StatelessWidget {
  const _Caret({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 24,
      decoration: BoxDecoration(
        color: TideColors.lantern,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
