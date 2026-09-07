import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class LoginScreenPage extends StatefulWidget {
  const LoginScreenPage({super.key});

  @override
  State<LoginScreenPage> createState() => _LoginScreenPageState();
}

class _LoginScreenPageState extends State<LoginScreenPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 58,
                ),
                child: Column(
                  children: [
                    const _SkillSikkaMark(),
                    const SizedBox(height: 25),
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF111827),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log in to continue your learning journey',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 35),
                    _InputField(
                      controller: _emailController,
                      label: 'username',
                      fieldLabel: 'Email or Phone',
                      iconAsset: 'assets/figma/mail.svg',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      controller: _passwordController,
                      label: 'password',
                      fieldLabel: 'Password',
                      iconAsset: 'assets/figma/lock.svg',
                      obscureText: _obscurePassword,
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => context.push('/'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE6B800),
                          foregroundColor: const Color(0xFF111827),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _OrDivider(),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _SocialButton(asset: 'assets/figma/google.svg'),
                        const SizedBox(width: 15),
                        const _SocialButton(asset: 'assets/figma/apple.svg'),
                      ],
                    ),
                    const SizedBox(height: 45),
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
  });

  final TextEditingController controller;
  final String label;
  final String fieldLabel;
  final String iconAsset;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

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
