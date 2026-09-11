import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_gradients.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_field.dart';
import '../../widgets/tide_mark.dart';
import 'widgets/google_mark.dart';
import 'widgets/password_strength.dart';

/// The gate between the explanation and the app.
///
/// Front end only, and honest about it — there is no service behind this
/// the same way there is no persistence behind the habits. What it does
/// decide is real: creating an account opens Tide genuinely empty and arms
/// the guided tour, while logging in returns to an account that already has
/// history in it. Those are two different first screens, and the form is
/// where the app finds out which one to show.
///
/// **It opens on log in.** Sign-up was the default because onboarding runs
/// in front of it on a first launch, which made it look like everybody
/// arriving here was new. Everybody arriving here for the *second* time is
/// not, and they were being handed a form with an extra field, a password
/// meter and the wrong verb on the button — every single time. A returning
/// user is the common case for any screen that exists after the first day.
///
/// It is one screen with two modes rather than two screens. Log-in and
/// sign-up differ by a single field and a line of copy; splitting them
/// across a route boundary would mean a user who landed on the wrong one
/// has to navigate to fix it, and would put a page transition in the middle
/// of a decision that should cost a tap.
///
/// The mode switch is a sentence at the bottom rather than a segmented
/// control at the top. A pill labelled "Create account / Log in" is two
/// tabs of equal weight sitting above a form that only serves one of them,
/// so the page has to be read twice: once to see which half is selected,
/// once to read the form. A line that says what this screen is *not* and
/// offers the other one is read in the order people actually read a page.
///
/// The mark above the title is the ring onboarding just handed over. It
/// arrives already closed rather than redrawing itself, because the whole
/// claim of the hand-off is that it is the same object.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { logIn, signUp }

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Mode _mode = _Mode.logIn;

  /// The email button and the Google button each carry their own wait, so
  /// the one you did not press stays legible instead of both going busy.
  TideButtonPhase _phase = TideButtonPhase.idle;
  TideButtonPhase _googlePhase = TideButtonPhase.idle;

  bool _reveal = false;

  /// Which field is complaining, and what about.
  final Map<String, String> _errors = {};

  /// Bumped per submit so the same complaint shakes again.
  int _tick = 0;

  bool get _signingUp => _mode == _Mode.signUp;

  /// True while either button is mid-flight. Both are locked out then: two
  /// sign-ins racing each other would land two routes on the shell.
  bool get _busy =>
      _phase != TideButtonPhase.idle || _googlePhase != TideButtonPhase.idle;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (_busy) return;
    // Complaints belong to the mode that raised them: a name the log-in
    // form does not ask for must not still be marked as missing.
    setState(() {
      _mode = _signingUp ? _Mode.logIn : _Mode.signUp;
      _errors.clear();
    });
  }

  /// Deliberately loose. A form's job is to catch the typo — a missing @, an
  /// empty box — not to adjudicate which addresses exist; every stricter
  /// pattern rejects somebody's real mailbox.
  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && value.indexOf('.', at) > at + 1 && !value.endsWith('.');
  }

  Map<String, String> _validate() {
    final found = <String, String>{};
    if (_signingUp && _name.text.trim().isEmpty) {
      found['name'] = 'What should we call you?';
    }
    if (_email.text.trim().isEmpty) {
      found['email'] = 'Email is required';
    } else if (!_looksLikeEmail(_email.text.trim())) {
      found['email'] = 'That does not look like an email';
    }
    if (_password.text.isEmpty) {
      found['password'] = 'Password is required';
    } else if (_signingUp && _password.text.length < 8) {
      // Not the same words as the field's own hint: the hint is still in
      // the tree behind the typed text, and two identical strings in one
      // field is a thing you have to disambiguate rather than read.
      found['password'] = 'Use at least 8 characters';
    }
    return found;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final found = _validate();
    if (found.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(found);
        _tick++;
      });
      return;
    }

    final store = TideScope.read(context);
    final router = GoRouter.of(context);

    // The button carries the wait rather than a dialog or a spinner over
    // the page — the same busy-then-check it does when a habit saves, so
    // the one place in the app that talks to a server looks like the places
    // that do not.
    setState(() {
      _errors.clear();
      _phase = TideButtonPhase.busy;
    });
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    setState(() => _phase = TideButtonPhase.done);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    if (_signingUp) {
      store.signUp(name: _name.text, email: _email.text);
    } else {
      store.signIn(email: _email.text);
    }
    router.go(Routes.today);
  }

  /// Continue with Google.
  ///
  /// Front end only, like the rest of the form: there is no provider to
  /// hand off to, so this stands in for the handshake and comes back with
  /// whatever the user had already typed. It deliberately skips
  /// [_validate] — a provider flow returns its own verified identity, and
  /// making the user fill in a form before they are allowed to press the
  /// button that exists to avoid the form would be absurd.
  Future<void> _continueWithGoogle() async {
    if (_busy) return;

    final store = TideScope.read(context);
    final router = GoRouter.of(context);

    setState(() {
      _errors.clear();
      _googlePhase = TideButtonPhase.busy;
    });
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted) return;
    setState(() => _googlePhase = TideButtonPhase.done);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    if (_signingUp) {
      // The store falls back to a usable name when this is blank, which is
      // what an empty form arriving here means.
      store.signUp(name: _name.text, email: _email.text);
    } else {
      store.signIn(email: _email.text);
    }
    router.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      // The keyboard is handled by padding the scroll view rather than by
      // resizing the page: letting the Scaffold shrink the body would drag
      // the title and the mark up and out of frame every time a field takes
      // focus, which is most of the time this screen is on.
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
                    padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + insets),
                    child: _form(),
                  ),
                ),
                _modeSwitch(insets),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 24, 0),
      child: Row(
        children: [
          PressScale(
            // Back to the explanation, not out of the app. Someone who has
            // reached the form and wants to re-read what freezes are should
            // not have to reinstall to find out.
            onTap: () => context.go(Routes.onboarding),
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
          const Spacer(),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The mark sits above the headline, on the left, where the ring
        // onboarding was carrying comes to rest — and where the eye starts
        // reading rather than in the corner it ends in.
        const Align(
          alignment: Alignment.centerLeft,
          child: TideMark(
            size: 60,
            strokeWidth: 2.5,
            coreSize: 7,
            drawIn: false,
          ),
        ),
        const SizedBox(height: 24),

        AnimatedSwitcher(
          duration: TideMotion.tabSwitch,
          child: Text(
            _signingUp ? 'Start your first loop' : 'Welcome back',
            key: ValueKey(_mode),
            style: TideType.screenTitle,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _signingUp
              ? 'One account keeps your streaks, freezes and history in one '
                    'place.'
              : 'Pick up where the loop left off.',
          style: TideType.bodyMuted,
        ),
        const SizedBox(height: 30),

        // Only the name field comes and goes, and it does so by height so
        // the fields below slide rather than jump. Rebuilding the whole form
        // per mode would drop whatever had already been typed into the two
        // fields both modes share.
        AnimatedSize(
          duration: TideMotion.sheetIn,
          curve: TideMotion.sheetCurve,
          alignment: Alignment.topCenter,
          child: _signingUp
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TideField(
                      controller: _name,
                      label: 'Name',
                      hint: 'Jules Ramirez',
                      error: _errors['name'],
                      errorTick: _tick,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                    ),
                    const SizedBox(height: 18),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),

        TideField(
          controller: _email,
          label: 'Email',
          hint: 'you@example.com',
          error: _errors['email'],
          errorTick: _tick,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 18),

        TideField(
          controller: _password,
          label: 'Password',
          hint: _signingUp ? 'At least 8 characters' : '••••••••',
          error: _errors['password'],
          errorTick: _tick,
          obscure: !_reveal,
          textInputAction: TextInputAction.done,
          autofillHints: [
            _signingUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          trailing: TideFieldToggle(
            on: _reveal,
            onTap: () => setState(() => _reveal = !_reveal),
            onIcon: Icons.visibility_off_rounded,
            offIcon: Icons.visibility_rounded,
          ),
        ),

        // Only while a password is being chosen. On the log-in form the
        // strength of an existing password is not the user's problem.
        PasswordStrength(
          password: _password.text,
          visible: _signingUp && _password.text.isNotEmpty,
        ),

        const SizedBox(height: 28),
        TideButton(
          label: _signingUp ? 'Create account' : 'Log in',
          phase: _phase,
          enabled: _googlePhase == TideButtonPhase.idle,
          onPressed: _submit,
        ),

        // The provider sits below the form rather than above it, and behind
        // a rule. Above, it reads as the recommended route and the fields
        // become the fallback; below, the two are plainly alternatives and
        // the one the product actually owns is the one you meet first.
        const _OrRule(),

        TideButton(
          label: 'Continue with Google',
          variant: TideButtonVariant.secondary,
          phase: _googlePhase,
          enabled: _phase == TideButtonPhase.idle,
          icon: const GoogleMark(size: 19),
          onPressed: _continueWithGoogle,
        ),
        const SizedBox(height: 18),
        Text(
          _signingUp
              ? 'No email is sent and nothing leaves this device — this '
                    'prototype keeps your account for the session.'
              : 'Logging in opens the demo history, so there is something to '
                    'read on every screen.',
          style: TideType.labelMuted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// The other mode, offered as a sentence.
  ///
  /// Pinned to the bottom of the screen rather than left at the end of the
  /// scroll: it is the one control on this page that a person may be
  /// looking for before they have read anything, and hiding it under a form
  /// they do not want to fill in is the whole reason people abandon an
  /// account screen.
  Widget _modeSwitch(double insets) {
    if (insets > 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: PressScale(
        onTap: _toggleMode,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _signingUp
                    ? 'Already have an account?'
                    : 'New to Tide?',
                style: TideType.labelMuted,
              ),
              const SizedBox(width: 7),
              Text(
                _signingUp ? 'Log in' : 'Create one',
                style: TideType.label.copyWith(color: TideColors.lantern),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "or", with the hairline running out to both edges.
///
/// The app's separator gradient rather than a plain rule, so the line fades
/// before the margin instead of butting into it — the same treatment every
/// other divider in Tide gets.
class _OrRule extends StatelessWidget {
  const _OrRule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const Expanded(child: _Hairline()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or', style: TideType.labelMuted),
          ),
          const Expanded(child: _Hairline()),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: TideGradients.hairline),
        child: const SizedBox.expand(),
      ),
    );
  }
}
