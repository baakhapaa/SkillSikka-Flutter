import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoAnimation;
  late final Animation<double> _ctaAnimation;
  late final Animation<double> _loginAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _logoAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    );
    _ctaAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.72, curve: Curves.easeOutCubic),
    );
    _loginAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                                AnimatedBuilder(
                                  animation: _logoAnimation,
                                  builder: (context, child) {
                                    final offset =
                                        30 * (1 - _logoAnimation.value);
                                    return Opacity(
                                      opacity: _logoAnimation.value,
                                      child: Transform.translate(
                                        offset: Offset(0, offset),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/figma/academic_cap.png',
                                    width: 350,
                                    height: 350,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                AnimatedBuilder(
                                  animation: _logoAnimation,
                                  builder: (context, child) {
                                    final offset =
                                        22 * (1 - _logoAnimation.value);
                                    return Opacity(
                                      opacity: _logoAnimation.value,
                                      child: Transform.translate(
                                        offset: Offset(0, offset),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/figma/skillsikka_wordmark.png',
                                    width: 250,
                                    height: 70,
                                    fit: BoxFit.contain,
                                  ),
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
                          AnimatedBuilder(
                            animation: _ctaAnimation,
                            builder: (context, child) {
                              final offset = 28 * (1 - _ctaAnimation.value);
                              return Opacity(
                                opacity: _ctaAnimation.value,
                                child: Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: () => context.push('/onboarding'),
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
                          ),
                          const SizedBox(height: 30),
                          AnimatedBuilder(
                            animation: _loginAnimation,
                            builder: (context, child) {
                              final offset = 18 * (1 - _loginAnimation.value);
                              return Opacity(
                                opacity: _loginAnimation.value,
                                child: Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
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
