import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../auth/data/auth_repository.dart';

/// Padding around the form. Its vertical part is also what turns the viewport
/// height into the column's minimum height, so keep the two in step.
const _pagePadding = EdgeInsets.fromLTRB(24, 14, 24, 12);

class LoginScreenPage extends ConsumerStatefulWidget {
  const LoginScreenPage({super.key});

  @override
  ConsumerState<LoginScreenPage> createState() => _LoginScreenPageState();
}

class _LoginScreenPageState extends ConsumerState<LoginScreenPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// True while the sign-in request is in flight, so the button cannot be
  /// pressed twice and the user can see something is happening.
  bool _isSubmitting = false;

  /// Field errors, held here rather than in a `Form`.
  ///
  /// Deliberate: this screen has two fields, and — more importantly — signing in
  /// must **not** re-apply the registration password policy. A `Form` wired to
  /// the same validators the signup forms use would reject a valid password the
  /// moment the policy changed, so the rules are spelled out here instead.
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final emailError = validateEmail(_emailController.text);
    final passwordError = validateRequired(
      _passwordController.text,
      'password',
    );
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .logIn(
            email: _emailController.text.trim(),
            // Not trimmed: leading and trailing spaces are legitimate password
            // characters, and the server compares what was typed.
            password: _passwordController.text,
          );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.go('/');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Wrong credentials come back as a 400 carrying a JSON `detail`, so the
      // server's own wording is the most useful thing to show. No field is
      // highlighted: the backend does not say which of the two was wrong, and
      // guessing would point the user at the wrong one half the time.
      showApiErrorSnack(context, error);
    }
  }

  /// Clears a field's message as soon as the user edits it, so a stale complaint
  /// does not sit under a field they have already fixed.
  void _clearEmailError() {
    if (_emailError != null) setState(() => _emailError = null);
  }

  void _clearPasswordError() {
    if (_passwordError != null) setState(() => _passwordError = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: _pagePadding,
              child: ConstrainedBox(
                // Fill the viewport exactly: spaceBetween then anchors the
                // sign-up line to the bottom on tall screens. The old `- 58`
                // under-filled by 22pt, so the column never reached the bottom.
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - _pagePadding.vertical,
                ),
                child: Column(
                  // The whole form is 687pt tall, so on a 360x800 phone it fits
                  // between the status bar and the gesture inset with room to
                  // spare; that slack is spread evenly instead of pooling at
                  // the bottom. Shorter screens still scroll.
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SkillSikkaMark(),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF111827),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Log in to continue your learning journey',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _InputField(
                      controller: _emailController,
                      // `label` is the in-field hint text; `fieldLabel` is the
                      // small heading above it. Login is email-only — the
                      // backend uses email as USERNAME_FIELD and looks the user
                      // up by it, so there is no username to accept.
                      label: 'email',
                      fieldLabel: 'Email',
                      iconAsset: 'assets/figma/mail.svg',
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: (_) => _clearEmailError(),
                    ),
                    const SizedBox(height: 14),
                    _InputField(
                      controller: _passwordController,
                      label: 'password',
                      fieldLabel: 'Password',
                      iconAsset: 'assets/figma/lock.svg',
                      obscureText: _obscurePassword,
                      errorText: _passwordError,
                      onChanged: (_) => _clearPasswordError(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _obscurePassword
                              ? const Icon(
                                  Icons.visibility_off_outlined,
                                  key: ValueKey('password-hidden'),
                                  color: Color(0xFF4B5462),
                                  size: 20,
                                )
                              : SvgPicture.asset(
                                  'assets/figma/eye.svg',
                                  key: const ValueKey('password-visible'),
                                  width: 18,
                                  height: 18,
                                ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFB59100),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        // Null while in flight, so a second tap cannot fire a
                        // second sign-in.
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE6B800),
                          foregroundColor: const Color(0xFF111827),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                          // Kept gold rather than greyed, matching the signup
                          // forms: the spinner is the cue that it is working,
                          // and a grey button on a slow connection reads as
                          // broken.
                          disabledBackgroundColor: const Color(0xFFE6B800),
                          disabledForegroundColor: const Color(0xFF111827),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF111827),
                                ),
                              )
                            : const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _OrDivider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _SocialButton(asset: 'assets/figma/google.svg'),
                        const SizedBox(width: 15),
                        const _SocialButton(asset: 'assets/figma/apple.svg'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context.go('/signup/role'),
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Color(0xFF77736D),
                            fontSize: 15.5,
                          ),
                          children: [
                            TextSpan(text: "Don’t have an account? "),
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: Color(0xFFB59100),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkillSikkaMark extends StatelessWidget {
  const _SkillSikkaMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/figma/academic_cap.png', width: 145, height: 115),
        const SizedBox(height: 0),
        Image.asset(
          'assets/figma/skillsikka_wordmark.png',
          width: 117,
          height: 39,
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.fieldLabel,
    required this.iconAsset,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String fieldLabel;
  final String iconAsset;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  /// Shown under the field, and turns its border red. Null when it is fine.
  final String? errorText;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldLabel.toUpperCase(),
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: GoogleFonts.manrope(
            color: const Color(0xFF4B5563),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelStyle: GoogleFonts.manrope(
              color: const Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            hintText: label,
            hintStyle: GoogleFonts.manrope(
              color: const Color(0xFF4B5563),
              fontSize: 14,
            ),
            errorText: errorText,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(16),
              child: SvgPicture.asset(iconAsset, width: 18, height: 18),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF2F1F7),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 17,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5DFD5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              color: const Color.fromARGB(255, 150, 146, 146),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5DFD5))),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF24211D),
        side: const BorderSide(color: Color(0xFFE5DFD5)),
        minimumSize: const Size(56, 52),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: SvgPicture.asset(asset, width: 58, height: 58),
    );
  }
}
