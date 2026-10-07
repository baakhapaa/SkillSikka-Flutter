import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/session.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/otp_code_field.dart';
import '../../auth/data/auth_repository.dart';

/// How long "Send a new code" stays locked after a request.
///
/// **A client affordance, not a mirror of a server rule.** Unlike signup's
/// resend, the reset endpoint has no server-side cooldown — but every request
/// invalidates the previous code, so a user who taps twice ends up with one
/// working code and two confusing emails. 60 seconds matches the signup screen so
/// the two OTP flows behave alike.
const _resendCooldownSeconds = 60;

/// The three steps, in order.
///
/// One screen with internal state rather than three routes, deliberately: the
/// `reset_token` from step 2 has to reach step 3 and **must not outlive the
/// flow**, and a private field on a `State` is the shortest-lived home available.
/// A provider or a route argument would both persist it somewhere it could be
/// read after the flow is abandoned.
enum _Step { email, code, password }

/// Password reset: email → 4-digit code → new password.
///
/// Replaces a stub that had `onPressed: () {}` and copy promising a "reset link"
/// — there is no link, and there never was. The backend sends a **4-digit code**
/// (the same length as signup, but a completely separate flow with its own three
/// endpoints).
///
/// The steps and their failure modes come from the backend's integration guide,
/// verified 2026-10-07. Two of its details shape this screen:
///
/// - **Step 1 succeeds whether or not the address has an account.** The server
///   answers with a fixed "if an account exists…" sentence, so this screen
///   advances to the code step either way. Saying "no such account" would turn
///   the endpoint into an address-enumeration oracle.
/// - **Step 3 does not sign the user in.** The backend returns no tokens and
///   invalidates every existing session for the account, so success ends on the
///   login screen — not in the app.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;

  /// The address the code was sent to. Held separately from the controller so a
  /// later step cannot be confused by the user editing a field it no longer
  /// shows — the server keys the code to the address that was submitted.
  String _email = '';

  /// The digits from [OtpCodeField], kept in step through its callback.
  String _code = '';

  /// Step 3's credential. **In memory only, and never leaves this State** — it is
  /// single-use and expires in 10 minutes, so persisting it would only widen the
  /// window in which it is useful to someone else.
  String? _resetToken;

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  /// Seconds left before a new code can be requested. Zero means the action is
  /// live.
  int _secondsLeft = 0;

  /// Drives [_secondsLeft]. Held so [dispose] can cancel it.
  Timer? _cooldown;

  /// Errors stay hidden until the first submit attempt, then update live as the
  /// user types.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// Field messages the server sent, keyed the way this form's controllers are.
  final _serverErrors = <String, String>{};

  @override
  void dispose() {
    // Not optional: a live periodic timer that calls setState on a disposed State
    // throws once the user leaves.
    _cooldown?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Restarts the cooldown, cancelling any timer already running.
  ///
  /// Assigns rather than calling setState, so it is safe from a setState callback.
  void _startCooldown() {
    _cooldown?.cancel();
    _secondsLeft = _resendCooldownSeconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  /// `mm:ss`, so the label reads correctly if the constant passes a minute.
  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Back one step, or out of the flow.
  ///
  /// Stepping back rather than popping is what makes this feel like one flow: the
  /// user who mistyped their email does not lose the code they already have, and
  /// the router stack does not fill with half-finished attempts.
  void _goBack() {
    if (_step == _Step.email) {
      if (context.canPop()) context.pop();
      return;
    }
    // Back to the code step, not the email step: the token is still valid and
    // re-verifying is one tap. If the code was consumed by the earlier successful
    // verify, the code step offers "Send a new code".
    _goToStep(_step == _Step.code ? _Step.email : _Step.code);
  }

  void _goToStep(_Step next) {
    setState(() {
      _step = next;
      _serverErrors.clear();
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  /// Re-checks the form after a programmatic write, and drops stale server
  /// messages for the field the user just corrected.
  void _revalidate() {
    if (_autovalidateMode == AutovalidateMode.disabled) return;
    _serverErrors.clear();
    _formKey.currentState?.validate();
  }

  // ---------------------------------------------------------------------------
  // Step 1 — request the code
  // ---------------------------------------------------------------------------

  /// Asks for a code. Also serves as "send a new code" from the code step, which
  /// is the same request — the guide is explicit that a fresh request kills the
  /// previous code, so there is nothing to distinguish.
  Future<void> _sendCode() async {
    if (_isSubmitting) return;

    // Captured before the step changes, so the confirmation can tell the first
    // send from a resend.
    final isFirstSend = _step == _Step.email;

    // On the code step the email was already validated and is no longer on
    // screen, so there is nothing to re-check.
    if (isFirstSend) {
      final form = _formKey.currentState;
      if (form == null || !form.validate()) {
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
        _showSnack('Please check the highlighted fields.');
        return;
      }
      _email = _emailController.text.trim();
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _email);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _startCooldown();
      // **Always advance.** The endpoint answers 200 whether or not the address
      // has an account, so there is nothing here to branch on — and a client that
      // showed an error for an unknown address would leak exactly what the
      // backend's wording is designed to hide.
      _goToStep(_Step.code);
      _showSnack(
        isFirstSend
            ? 'If an account exists, a 4-digit code is on its way.'
            : 'If your account is eligible, a new code is on its way.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showApiErrorSnack(context, error);
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2 — verify the code
  // ---------------------------------------------------------------------------

  Future<void> _verifyCode() async {
    if (_isSubmitting) return;

    if (!RegExp(r'^[0-9]{4}$').hasMatch(_code)) {
      _showSnack('Enter the 4-digit code.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetOtp(email: _email, code: _code);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (token == null) {
        // A 2xx with no token. The flow cannot continue without one, so this is a
        // failure however the status read.
        _showSnack(
          'That code could not be confirmed. Please request a new one.',
        );
        return;
      }

      _resetToken = token;
      _goToStep(_Step.password);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // The server sends one message for a wrong, expired or used-up code, so
      // there is nothing more specific to say. Stay put and offer the resend.
      showApiErrorSnack(context, error);
    }
  }

  // ---------------------------------------------------------------------------
  // Step 3 — set the new password
  // ---------------------------------------------------------------------------

  Future<void> _submitPassword() async {
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      _showSnack('Please check the highlighted fields.');
      return;
    }

    final token = _resetToken;
    if (token == null) {
      // Unreachable through the UI — step 3 is only entered with a token — but a
      // silent null here would send `reset_token: null` and read as a bad token.
      _goToStep(_Step.email);
      _showSnack('Please start again so we can verify your email.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            resetToken: token,
            newPassword: _passwordController.text,
            confirmPassword: _confirmController.text,
          );
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // The backend invalidated every session for this account, and the app is
      // only reachable here signed out — but clearing is the honest reflection of
      // what the server just did, and costs nothing when there is nothing there.
      ref.read(sessionProvider.notifier).state = null;

      _showSnack('Password reset. Please log in with your new password.');
      context.go('/login-screen');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // **Two failure kinds, and they need opposite handling.** A field error is
      // the user's to fix in place; anything else on this call is a dead reset
      // token — used, expired past 10 minutes, or tampered with — and the only
      // recovery is to start over.
      //
      // Detected structurally, by the *absence* of field errors, rather than by
      // matching the server's sentence. The guide's own example
      // (`{"detail": ["Invalid or expired reset token."]}`) carries no field
      // errors, while every password-rule failure carries them.
      if (!error.hasFieldErrors) {
        _resetToken = null;
        // Clears the field messages too, so nothing from the abandoned attempt
        // is left on screen.
        _goToStep(_Step.email);
      } else {
        _applyServerFieldErrors(error);
      }

      showApiErrorSnack(
        context,
        error,
        fieldErrorsAreShown: error.hasFieldErrors,
      );
    }
  }

  /// Puts the server's per-field messages onto the matching inputs.
  ///
  /// Only the two password fields can carry one. The wire name is
  /// `new_password` and this form's controller is `password`, so that one needs
  /// translating; anything else the server names has no input here.
  void _applyServerFieldErrors(ApiException error) {
    if (!error.hasFieldErrors) return;

    for (final entry in error.fieldErrors.entries) {
      final key = entry.key == 'new_password' ? 'password' : entry.key;
      if (key == 'password' || key == 'confirm') {
        _serverErrors[key] = entry.value;
      }
    }
    if (_serverErrors.isEmpty) return;

    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    _formKey.currentState?.validate();
  }

  /// Wraps a client-side [validator] so a server message for the same field wins
  /// until the field is edited.
  FormFieldValidator<String> _serverAware(
    String key,
    FormFieldValidator<String> validator,
  ) {
    return (value) => _serverErrors[key] ?? validator(value);
  }

  /// The primary action for the current step.
  VoidCallback get _onPrimary => switch (_step) {
    _Step.email => _sendCode,
    _Step.code => _verifyCode,
    _Step.password => _submitPassword,
  };

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  /// The fields for the current step, in order.
  ///
  /// **Every field carries a `ValueKey`, and that is load-bearing.** The three
  /// steps put different fields at the same positions in the same `Column`, and
  /// without keys Flutter matches them by type and *updates* the existing element
  /// rather than building a new one — so the step-3 password box would inherit the
  /// step-1 email field's `FormFieldState`, error text and touched flag included.
  /// A key per field forces a fresh element per step, which is what "a different
  /// form" means.
  List<Widget> _stepFields() {
    switch (_step) {
      case _Step.email:
        return [
          LabeledTextField(
            key: const ValueKey('reset-email'),
            label: 'Email Address',
            hint: 'e.g. skill@email.com',
            requiredField: true,
            leading: 'assets/figma/mail.svg',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _revalidate(),
            validator: validateEmail,
          ),
        ];

      case _Step.code:
        return [
          OtpCodeField(
            key: const ValueKey('reset-code'),
            onChanged: (code) => _code = code,
            enabled: !_isSubmitting,
          ),
        ];

      case _Step.password:
        return [
          LabeledTextField(
            key: const ValueKey('reset-password'),
            label: 'New Password',
            hint: '••••••••••••',
            requiredField: true,
            leading: 'assets/figma/signup_lock.svg',
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => _revalidate(),
            validator: _serverAware('password', validatePassword),
            trailingWidget: IconButton(
              onPressed: _togglePassword,
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: _obscurePassword
                  ? const Icon(
                      Icons.visibility_off_outlined,
                      color: Color(0xFF4B5462),
                      size: 20,
                    )
                  : SvgPicture.asset(
                      'assets/figma/eye.svg',
                      width: 16,
                      height: 16,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          LabeledTextField(
            key: const ValueKey('reset-confirm'),
            label: 'Confirm New Password',
            hint: '••••••••••••',
            requiredField: true,
            leading: 'assets/figma/signup_lock.svg',
            controller: _confirmController,
            obscureText: _obscurePassword,
            onChanged: (_) => _revalidate(),
            validator: _serverAware(
              'confirm',
              (value) =>
                  validateConfirmPassword(value, _passwordController.text),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'At least 8 characters, with a letter and a number.',
            style: GoogleFonts.manrope(
              color: const Color(0xFF4B5563),
              fontSize: 12,
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: _goBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LockBadge(),
                      const SizedBox(height: 16),
                      _Heading(step: _step, email: _email),
                      const SizedBox(height: 24),
                      ..._stepFields(),
                    ],
                  ),
                ),
              ),
            ),
            _BottomBar(
              step: _step,
              isSubmitting: _isSubmitting,
              countdown: _secondsLeft > 0 ? _countdownLabel : null,
              onPrimary: _onPrimary,
              onResend: _sendCode,
            ),
          ],
        ),
      ),
    );
  }
}

/// The back button, matching the signup screens.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: SvgPicture.asset(
            'assets/figma/signup_arrow_left.svg',
            width: 40,
            height: 40,
          ),
        ),
      ),
    ),
  );
}

/// The padlock in its gold disc — unchanged from the stub, because it was the one
/// part of that screen that was already right.
class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 74,
        height: 74,
        decoration: const BoxDecoration(
          color: Color(0xFFE6B800),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset('assets/figma/lock.svg', width: 32, height: 32),
      ),
    ),
  );
}

/// The title and explanation for the current step.
class _Heading extends StatelessWidget {
  const _Heading({required this.step, required this.email});

  final _Step step;
  final String email;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (step) {
      _Step.email => (
        'Forgot Password?',
        'Enter the email address associated with your account and we\'ll send '
            'you a 4-digit code to reset your password.',
      ),
      _Step.code => (
        'Enter the Code',
        'We sent a 4-digit code to $email. It expires in 10 minutes.',
      ),
      _Step.password => (
        'Set a New Password',
        'Choose a new password for $email.',
      ),
    };

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: const Color(0xFF4B5563),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// The primary button, the resend action, and the log-in link.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.isSubmitting,
    required this.countdown,
    required this.onPrimary,
    required this.onResend,
  });

  final _Step step;
  final bool isSubmitting;

  /// `mm:ss` while the resend is locked, or null when it is available.
  final String? countdown;

  final VoidCallback onPrimary;
  final VoidCallback onResend;

  String get _label => switch (step) {
    _Step.email => 'Send Reset Code',
    _Step.code => 'Verify Code',
    _Step.password => 'Reset Password',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Only the code step has anything to resend.
          if (step == _Step.code) ...[
            if (countdown case final String remaining)
              Text.rich(
                TextSpan(
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF4B5563),
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'Send a new code in '),
                    TextSpan(
                      text: remaining,
                      style: const TextStyle(
                        color: Color(0xFFB59100),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: isSubmitting ? null : onResend,
                child: Text(
                  'Send a new code',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFFB59100),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: isSubmitting ? null : onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE6B800),
                foregroundColor: const Color(0xFF111827),
                elevation: 4,
                shadowColor: const Color(0x33E6B800),
                shape: const StadiumBorder(),
                // Kept gold rather than greyed: the spinner is the cue that it is
                // working, and a grey button on a slow connection reads as broken.
                disabledBackgroundColor: const Color(0xFFE6B800),
                disabledForegroundColor: const Color(0xFF111827),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF111827),
                      ),
                    )
                  : Text(
                      _label,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (step == _Step.email) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.pop(),
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF4B5563),
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'Remember your password? '),
                    TextSpan(
                      text: 'Log In',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFFB59100),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
