import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPageIndex = 0;

  final List<Map<String, String>> _pagesData = [
    {
      'image': 'assets/figma/onboarding_1.png',
      'title': 'Learn from Expert Instructors',
      'subtitle':
          'Access thousands of video courses taught by certified educators in coding, science, math, and more.',
    },
    {
      'image': 'assets/figma/onboarding_2.png',
      'title': 'Practice with Challenges',
      'subtitle':
          'Test your knowledge with quizzes, coding challenges, and earn certificates as you progress.',
    },
    {
      'image': 'assets/figma/onboarding_3.png',
      'title': 'Track Your Progress',
      'subtitle':
          'Set learning goals, maintain your streak, and unlock achievements as you grow your skills.',
    },
  ];

  void _goToNextPage() {
    if (_currentPageIndex < _pagesData.length - 1) {
      setState(() => _currentPageIndex++);
    } else {
      context.push('/login-screen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F2600),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/figma/academic_cap.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    height: 50,
                    child: Image.asset(
                      'assets/figma/skillsikka_wordmark.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const Spacer(),
                  if (_currentPageIndex < _pagesData.length - 1)
                    TextButton(
                      onPressed: () => context.push('/login-screen'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          color: const Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              _pagesData[_currentPageIndex]['image']!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          _pagesData[_currentPageIndex]['title']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            height: 1.2,
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pagesData[_currentPageIndex]['subtitle']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            height: 1.5,
                            color: const Color(0xFF4B5563),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pagesData.length, (index) {
                      final isActive = index == _currentPageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 8),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE6B800)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6B800),
                        foregroundColor: const Color(0xFF111827),
                        elevation: 4,
                        shadowColor: const Color(0x40E6B800),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _currentPageIndex == _pagesData.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
