import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 54),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 600,
                            height: 500,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/figma/academic_cap.png',
                                  width: 350,
                                  height: 350,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 18),
                                Image.asset(
                                  'assets/figma/skillsikka_wordmark.png',
                                  width: 250,
                                  height: 70,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: () => context.push('/login-screen'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE6B800),
                                foregroundColor: const Color(0xFF111827),
                                elevation: 4,
                                shadowColor: const Color(0x40E6B800),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Get Started',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          GestureDetector(
                            onTap: () => context.push('/login-screen'),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.manrope(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Already have an account? ',
                                    style: GoogleFonts.manrope(fontSize: 15),
                                  ),
                                  TextSpan(
                                    text: 'Log In',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      color: const Color(0xFFE6B800),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
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
