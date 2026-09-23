import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../profile/data/user_profile.dart';

/// Shown the address the code was sent to, falling back to the placeholder when
/// signup never captured one (e.g. deep-linking straight here).
const _placeholderEmail = 'sarah@email.com';

class SignupVerificationPage extends ConsumerStatefulWidget {
  const SignupVerificationPage({super.key});

  @override
  ConsumerState<SignupVerificationPage> createState() =>
      _SignupVerificationPageState();
}

class _SignupVerificationPageState
    extends ConsumerState<SignupVerificationPage> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == 3 ? 0 : 16,
                            ),
                            child: _OtpBox(
                              autofocus: index == 0,
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              focused: _focusNodes[index].hasFocus,
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 3) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                                setState(() {});
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF4B5563),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(text: 'Resend code in '),
                            TextSpan(
                              text: '00:45',
                              style: TextStyle(
                                color: Color(0xFFB59100),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                      onPressed: () => context.push('/signup/interests'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE6B800),
                        foregroundColor: const Color(0xFF111827),
                        elevation: 4,
                        shadowColor: const Color(0x33E6B800),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.autofocus,
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
  });

  final bool autofocus;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: onChanged,
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: focused
                  ? const Color(0xFFE6B800)
                  : const Color(0xFFE5E7EB),
              width: focused ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: focused
                  ? const Color(0xFFE6B800)
                  : const Color(0xFFE5E7EB),
              width: focused ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE6B800), width: 2),
          ),
        ),
      ),
    );
  }
}
