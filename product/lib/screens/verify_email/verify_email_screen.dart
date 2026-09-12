import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/auth/auth_service.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../auth/auth_screen.dart';
import 'widgets/code_cells.dart';
import 'widgets/mail_mark.dart';

/// How the code this screen asks for was sent, which decides whether Resend
/// starts locked.
enum CodeDelivery {
  /// Sign-up sent one a moment ago: Resend waits out its cooldown.
  justSent,

  /// Nothing has been sent on this visit — log in found the account still
  /// unconfirmed — so one goes out as the screen opens.
  sendNow,

  /// A relaunch with a sign-up still pending. A code may be in the inbox or
  /// may have expired; Resend is offered at once.
  unknown,
}

/// The second half of creating an account: the digits Supabase emailed.
///
/// It replaces a confirmation *link*, which only signed in the device that
/// opened it. A code works wherever the email was read, and nobody leaves
/// the app to use it.
///
/// **Nothing to press.** The code submits itself when the last digit lands,
/// whether it was typed, pasted or filled in by the keyboard. A "Verify"
/// button under six full cells is a second confirmation of something the
/// person has already plainly finished doing.
///
/// **The tick is the payoff, so it is not rushed.** When the code is
/// accepted the cells light up left to right, the envelope folds away into
/// a ring, and a tick draws through it — then a short hold, then the
/// welcome. Creating an account is the one form in the app that ends in
/// something genuinely new existing, and it gets a finish to match.
///
/// A wrong code shakes the cells and empties them, the way a refused field
/// does elsewhere, and says which of the two things it could be: Supabase
/// does not distinguish a mistyped code from an expired one, so neither
/// does the sentence.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.delivery = CodeDelivery.unknown});

  final CodeDelivery delivery;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();

  late final AnimationController _accepted = AnimationController(
    vsync: this,
    duration: TideMotion.codeAccepted,
  );

  /// Read once. The store forgets the pending address the moment the account
  /// arrives, which is part-way through the tick this screen is about to
  /// play, and the sentence under the title must not go blank mid-flourish.
  String _email = '';

  bool _checking = false;
  bool _confirmed = false;
  bool _sending = false;
  bool _leaving = false;

  String? _error;
  String? _info;
  int _errorTick = 0;

  int _cooldown = 0;
  Timer? _clock;

  static const Duration _second = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _email = TideScope.read(context).pendingVerificationEmail ?? '';
    switch (widget.delivery) {
      case CodeDelivery.justSent:
        _startCooldown(AppConstants.emailCodeResendSeconds);
      case CodeDelivery.sendNow:
        WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
      case CodeDelivery.unknown:
        break;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _code.dispose();
    _focus.dispose();
    _accepted.dispose();
    super.dispose();
  }

  /// Counts Resend down. Callers rebuild; this only sets the clock running.
  void _startCooldown(int seconds) {
    _clock?.cancel();
    _cooldown = seconds;
    _clock = Timer.periodic(_second, (clock) {
      if (!mounted) {
        clock.cancel();
        return;
      }
      setState(() => _cooldown = (_cooldown - 1).clamp(0, seconds));
      if (_cooldown == 0) clock.cancel();
    });
  }

  void _onChanged(String value) {
    if (_error != null || _info != null) {
      setState(() {
        _error = null;
        _info = null;
      });
    }
    if (value.length == AppConstants.emailCodeLength) _verify(value);
  }

  Future<void> _verify(String code) async {
    if (_checking || _confirmed) return;
    final store = TideScope.read(context);
    final router = GoRouter.of(context);

    setState(() {
      _checking = true;
      _error = null;
      _info = null;
    });

    try {
      await store.verifyEmailCode(code);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      _code.clear();
      setState(() {
        _checking = false;
        _error = _describe(failure);
        _errorTick++;
      });
      _focus.requestFocus();
      return;
    }

    if (!mounted) return;
    _clock?.cancel();
    _focus.unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _checking = false;
      _confirmed = true;
    });

    await _accepted.forward();
    await Future<void>.delayed(TideMotion.codeAcceptedHold);
    if (mounted) router.go(Routes.welcome);
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0 || _confirmed || _checking) return;
    final store = TideScope.read(context);

    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });

    try {
      await store.resendEmailCode();
      if (!mounted) return;
      _code.clear();
      _startCooldown(AppConstants.emailCodeResendSeconds);
      setState(() {
        _sending = false;
        _info = 'A new code is on its way.';
      });
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      // Too soon after the last one. Supabase says how long; the countdown
      // takes that over rather than showing an error for a code that was in
      // fact sent.
      final wait = failure.problem == AuthProblem.rateLimited
          ? int.tryParse(failure.detail ?? '')
          : null;
      if (wait != null) _startCooldown(wait);
      setState(() {
        _sending = false;
        if (wait != null) {
          _info = 'A code was sent a moment ago. Check your inbox.';
        } else {
          _error = _describe(failure);
        }
      });
    }
  }

  /// "Use a different email": back to sign-up, with the address kept so a
  /// typo costs a correction rather than a retype.
  void _back() {
    if (_checking || _confirmed) return;
    TideScope.read(context).abandonVerification();
    context.go(Routes.auth, extra: AuthDraft(email: _email, signingUp: true));
  }

  static String _describe(AuthFailure failure) => switch (failure.problem) {
    AuthProblem.invalidCode => 'That code is wrong or has expired',
    AuthProblem.rateLimited => 'Too many tries. Wait a minute, then try again.',
    AuthProblem.offline =>
      'Tide could not reach the server. Check the connection.',
    _ => failure.detail ?? 'Something went wrong. Try again.',
  };

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);

    // Signed in without this screen having accepted anything — the account
    // arrived some other way. There is no code left to ask for.
    if (store.signedIn && !_checking && !_confirmed && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.welcome);
      });
    }

    return PopScope(
      // The system back gesture means "wrong address", the same as the arrow.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(child: TideBackdrop(drift: true)),
            SafeArea(
              child: Column(
                children: [
                  _backRow(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        4,
                        24,
                        24 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: _body(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 24, 0),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: _confirmed ? 0 : 1,
            duration: TideMotion.tabSwitch,
            child: PressScale(
              onTap: _back,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 19,
                  color: TideColors.silt,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MailMark(accepted: _accepted),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: TideMotion.tabSwitch,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          child: Text(
            _confirmed ? 'Email confirmed' : 'Check your email',
            key: ValueKey(_confirmed),
            style: TideType.screenTitle,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: TideType.bodyMuted,
            children: _confirmed
                ? const [TextSpan(text: 'Your account is ready.')]
                : [
                    TextSpan(
                      text:
                          'Enter the ${AppConstants.emailCodeLength}-digit '
                          'code we sent to ',
                    ),
                    TextSpan(
                      text: _email,
                      style: TideType.body.copyWith(color: TideColors.bone),
                    ),
                    TextSpan(
                      text:
                          '. It works for '
                          '${AppConstants.emailCodeLifetimeMinutes} minutes.',
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 34),
        CodeCells(
          controller: _code,
          focusNode: _focus,
          length: AppConstants.emailCodeLength,
          onChanged: _onChanged,
          accepted: _accepted,
          error: _error != null,
          errorTick: _errorTick,
          enabled: !_confirmed,
        ),
        const SizedBox(height: 14),
        // A fixed-height slot, so a message arriving or leaving never moves
        // the Resend line under the thumb that is about to press it.
        SizedBox(
          height: 44,
          child: AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            child: _status(),
          ),
        ),
        AnimatedOpacity(
          opacity: _confirmed ? 0 : 1,
          duration: TideMotion.tabSwitch,
          child: IgnorePointer(ignoring: _confirmed, child: _help()),
        ),
      ],
    );
  }

  Widget _status() {
    if (_checking) {
      return Row(
        key: const ValueKey('checking'),
        children: [
          TideSpinner(size: 15, strokeWidth: 2, color: TideColors.lantern),
          const SizedBox(width: 10),
          Text('Checking the code…', style: TideType.labelMuted),
        ],
      );
    }
    final error = _error;
    if (error != null) {
      return Text(
        error,
        key: ValueKey('error-$_errorTick'),
        style: TideType.label.copyWith(color: TideColors.coral),
      );
    }
    final info = _info;
    if (info != null) {
      return Text(info, key: ValueKey(info), style: TideType.labelMuted);
    }
    return const SizedBox(key: ValueKey('quiet'));
  }

  Widget _help() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Didn't get it?", style: TideType.labelMuted),
            const SizedBox(width: 8),
            if (_sending)
              TideSpinner(size: 14, strokeWidth: 2, color: TideColors.lantern)
            else if (_cooldown > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Resend in ', style: TideType.labelMuted),
                  GaugeNumber(
                    value: _cooldown,
                    style: TideType.gauge(13, color: TideColors.silt),
                  ),
                  Text('s', style: TideType.labelMuted),
                ],
              )
            else
              PressScale(
                onTap: _resend,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Resend code',
                    style: TideType.label.copyWith(color: TideColors.lantern),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Codes can take a minute to arrive. Check spam or promotions too.',
          style: TideType.labelMuted,
        ),
        const SizedBox(height: 18),
        PressScale(
          onTap: _back,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Use a different email',
              style: TideType.label.copyWith(color: TideColors.lantern),
            ),
          ),
        ),
      ],
    );
  }
}
