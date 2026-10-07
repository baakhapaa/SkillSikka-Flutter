import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/otp_code_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_profile.dart';

/// Shown the address the code was sent to, falling back to the placeholder when
/// signup never captured one (e.g. deep-linking straight here).
const _placeholderEmail = 'sarah@email.com';

/// How long the resend action stays locked after a code goes out.
///
/// **60 seconds, matching the backend's own cooldown** (confirmed 2026-10-07).
/// Counted from arrival rather than from the last tap: this screen is only
/// reached by completing the step that sent a code, so the wait has already
/// started by the time it appears.
///
/// **This countdown is not a nicety — it is the only thing enforcing the
/// cooldown.** `resend-otp` answers `200` even inside the window (it never
/// refuses, to avoid confirming which addresses are registered), so a shorter
/// client value would let the user tap straight into a request the server
/// silently drops.
const _resendCooldownSeconds = 60;

class SignupVerificationPage extends ConsumerStatefulWidget {
  const SignupVerificationPage({super.key});

  @override
  ConsumerState<SignupVerificationPage> createState() =>
      _SignupVerificationPageState();
}

class _SignupVerificationPageState
    extends ConsumerState<SignupVerificationPage> {
  /// The digits entered so far, kept in step by [OtpCodeField].
  ///
  /// Held here rather than read out of four controllers at submit time, because
  /// the widget now owns those. Shorter than four until every box is filled —
  /// see the widget's doc.
  String _code = '';

  /// True while a request is in flight. See the student form's field of the same
  /// name — same reason: a slow request must not look frozen, and the button
  /// must not be tappable twice.
  bool _isSubmitting = false;

  /// True while a resend is in flight. Separate from [_isSubmitting] so that
  /// asking for a new code cannot disable Verify, or the other way round.
  bool _isResending = false;

  /// Seconds left before the code can be asked for again. Zero means the resend
  /// action is live.
  int _secondsLeft = _resendCooldownSeconds;

  /// Drives [_secondsLeft]. Held so it can be cancelled — see [dispose].
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    // No setState: the first frame has not been built yet, so there is nothing
    // to rebuild. The periodic tick below takes over from here.
    _startCooldown();
  }

  /// Restarts the cooldown, cancelling any timer already running.
  ///
  /// Assigns rather than calling setState, so it is safe to call from
  /// [initState] as well as from inside a setState callback.
  void _startCooldown() {
    _cooldown?.cancel();
    _secondsLeft = _resendCooldownSeconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        // Cannot happen with the cancel in dispose, but a tick that outlives
        // the State would throw on setState, so stop it rather than trust it.
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

  /// `mm:ss`, so raising [_resendCooldownSeconds] past a minute still reads
  /// correctly instead of showing `00:75`.
  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sends a fresh code.
  ///
  /// The cooldown is restarted only on success: a failed resend sent nothing,
  /// so locking the action for another minute would leave the user with no code
  /// and no way to ask again.
  ///
  /// **"Success" here is weaker than it looks.** The endpoint answers 200 for
  /// every well-formed request, including one it decided not to act on. Per the
  /// backend's integration guide it silently skips when either of two conditions
  /// holds:
  ///
  /// - fewer than **60 seconds** have passed since the last code, or
  /// - the account has had **10 codes in the last 24 hours**.
  ///
  /// That is enumeration defence, not a bug on our side — see
  /// [AuthApi.resendOtp] — which is why the confirmation message is worded as a
  /// possibility rather than a receipt.
  Future<void> _resend() async {
    if (_isResending || _secondsLeft > 0) return;

    final profile = ref.read(userProfileProvider);
    final email = profile.email;
    final role = profile.role;
    if (email.isEmpty || role == null) {
      _showSnack('Start again from signup so we know which email to use.');
      return;
    }

    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendOtp(role: role, email: email);
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _startCooldown();
      });
      // **Not "we sent it".** The backend answers 200 whether or not it sent
      // anything — it silently skips inside the 60-second cooldown and once the
      // account has had 10 codes in 24 hours, and it never refuses, so that the
      // endpoint cannot be used to discover which addresses are registered. A
      // client that promised delivery would be claiming something it cannot
      // know. The backend's own integration guide asks for exactly this wording.
      _showSnack('If your account is eligible, a new code is on its way.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isResending = false);
      showApiErrorSnack(context, error);
    }
  }

  /// Confirms the code with the server — **and this is what signs the user in.**
  ///
  /// Registration no longer returns a session for either role (confirmed live
  /// 2026-10-07): it answers 201 with `email_verification_required: true` and no
  /// tokens. So this call is the only place a signup session comes from, and a
  /// user who never gets here never gets an account they can use.
  ///
  /// The role decides which endpoint the code goes to, which is why it is read
  /// from the store rather than assumed: the two roles have separate paths.
  Future<void> _verify() async {
    if (_isSubmitting) return;

    final code = _code;
    // Four digits, matching the backend's `^[0-9]{4}$`. The length alone is not
    // enough — a paste can put a letter in a box that a numeric keyboard would
    // never produce — and catching it here saves a round trip to be told.
    if (!RegExp(r'^[0-9]{4}$').hasMatch(code)) {
      _showSnack('Enter the 4-digit code.');
      return;
    }

    final profile = ref.read(userProfileProvider);
    final email = profile.email;
    final role = profile.role;
    if (email.isEmpty || role == null) {
      // Only reachable by deep-linking straight here, or by arriving with a
      // cleared store. There is no account to verify against.
      _showSnack('Start again from signup so we know which email to verify.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(role: role, email: email, code: code);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.push('/signup/interests');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // No inline validation on the boxes, so the server's message — one
      // sentence covering a wrong, expired or unknown-code case — is shown as it
      // came.
      showApiErrorSnack(context, error);
    }
  }

  @override
  void dispose() {
    // Not optional: a live periodic timer keeps calling setState on a State
    // that is no longer mounted, which throws once the user leaves the screen.
    // The code boxes' controllers and focus nodes are no longer disposed here —
    // `OtpCodeField` owns them and disposes them itself.
    _cooldown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftEmail = ref.watch(userProfileProvider).email;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onBack: () => context.pop()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Your Account',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF111827),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF4B5563),
                            fontSize: 15,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  "We've sent a 4-digit verification code to your email ",
                            ),
                            TextSpan(
                              text: draftEmail.isEmpty
                                  ? _placeholderEmail
                                  : draftEmail,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Column(
                    children: [
                      OtpCodeField(
                        onChanged: (code) => _code = code,
                        // Locked while a request is in flight, but the digits
                        // stay on screen so a rejected code can be corrected
                        // rather than retyped.
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 24),
                      if (_secondsLeft > 0)
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF4B5563),
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Resend code in '),
                              TextSpan(
                                text: _countdownLabel,
                                style: const TextStyle(
                                  color: Color(0xFFB59100),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // A real button rather than a tappable span: it carries
                        // its own disabled state and hit target, and there is no
                        // gesture recogniser to dispose.
                        TextButton(
                          onPressed: _isResending ? null : _resend,
                          child: Text(
                            _isResending
                                ? 'Sending a new code…'
                                : 'Resend code',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFFB59100),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      // Null while in flight, and no longer unconditional: it
                      // used to advance on any input at all, including none.
                      onPressed: _isSubmitting ? null : _verify,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE6B800),
                        foregroundColor: const Color(0xFF111827),
                        elevation: 4,
                        shadowColor: const Color(0x33E6B800),
                        shape: const StadiumBorder(),
                        disabledBackgroundColor: const Color(0xFFE6B800),
                        disabledForegroundColor: const Color(0xFF111827),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF111827),
                              ),
                            )
                          : Text(
                              'Verify',
                              style: GoogleFonts.manrope(
                                color: const Color(0xFF111827),
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: SvgPicture.asset(
                'assets/figma/signup_arrow_left.svg',
                width: 50,
                height: 50,
              ),
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Step: 3 of 4',
              style: GoogleFonts.manrope(
                color: const Color.fromARGB(255, 44, 43, 45),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
