import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupRolePage extends StatefulWidget {
  const SignupRolePage({super.key});

  @override
  State<SignupRolePage> createState() => _SignupRolePageState();
}

class _SignupRolePageState extends State<SignupRolePage> {
  bool _isStudent = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/login-screen');
                              }
                            },
                            padding: EdgeInsets.zero,
                            icon: SvgPicture.asset(
                              'assets/figma/signup_arrow_left.svg',
                              width: 50,
                              height: 50,
                            ),
                            style: IconButton.styleFrom(
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Step: 1 of 4',
                            style: GoogleFonts.manrope(
                              color: const Color.fromARGB(255, 44, 43, 45),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F2600),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.asset(
                                'assets/figma/academic_cap.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/figma/skillsikka_wordmark.png',
                              width: 150,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 57),
                        Text(
                          'Choose Your Role',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF111827),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Are you here to learn or guide others?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF4B5563),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 84),
                        _RoleCard(
                          selected: _isStudent,
                          title: 'I am a Student',
                          description:
                              'Explore world-class courses, attend bootcamps, and build high-income tech skills.',
                          iconAsset: 'assets/figma/signup_graduation_cap.svg',
                          onTap: () => setState(() => _isStudent = true),
                        ),
                        const SizedBox(height: 16),
                        _RoleCard(
                          selected: !_isStudent,
                          title: 'I am an Instructor',
                          description:
                              'Share your knowledge, upload high-quality tutorials, and manage your learner cohorts.',
                          iconAsset: 'assets/figma/signup_chart_column.svg',
                          onTap: () => setState(() => _isStudent = false),
                        ),
                        const SizedBox(height: 84),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () {
                              context.push(
                                _isStudent
                                    ? '/signup/student'
                                    : '/signup/instructor',
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE6B800),
                              foregroundColor: const Color(0xFF111827),
                              elevation: 4,
                              shadowColor: const Color(0x40E6B800),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Continue',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
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
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String description;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFBF0) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFFE6B800) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x40E6B800),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE6B800)
                    : const Color(0xFFF2F1F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(iconAsset),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF4B5563),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RadioIndicator(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFE6B800) : const Color(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE6B800),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
