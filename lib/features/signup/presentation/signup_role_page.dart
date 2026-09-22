import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// The scroll view's padding. Its vertical part is what turns the viewport
/// height into the column's minimum height, so keep the two in step.
const _pagePadding = EdgeInsets.only(bottom: 16);

/// Below this viewport height the spacing stops tightening. 600pt is roughly a
/// 360x640 Android minus its system bars — the smallest portrait phone that
/// still ships a modern Flutter build.
const _tightBudget = 600.0;

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
          builder: (context, constraints) {
            // The page is drawn for a 737.5pt viewport (360x800 minus the system
            // bars). Shorter phones get the same arrangement with the air
            // squeezed out, so Continue stays above the fold instead of hiding
            // below it. Nothing tightens at or above 737.5pt, so the design
            // values are untouched on the target phone and anything larger.
            final t =
                ((constraints.maxHeight - _tightBudget) /
                        (737.5 - _tightBudget))
                    .clamp(0.0, 1.0);
            double gap(double tight, double roomy) =>
                tight + (roomy - tight) * t;

            final topGap = gap(12, 20); // header -> logo
            final logoTitleGap = gap(16, 44); // logo -> heading
            final titleCardsGap = gap(24, 61); // subtitle -> first card
            final cardGap = gap(12, 16); // between the two cards
            final ctaGap = gap(10, 16); // cards -> Continue

            return SingleChildScrollView(
              padding: _pagePadding,
              child: ConstrainedBox(
                // Fill the viewport exactly so spaceBetween can anchor the
                // Continue button to the bottom. `constraints.maxHeight` on its
                // own added the padding back on top of a full-height column, so
                // the page always scrolled by 16pt even when it fitted.
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - _pagePadding.vertical,
                ),
                child: Column(
                  // Three children, so `spaceBetween` splits the slack across
                  // the two gaps instead of dumping it into one. Two children
                  // left the header stranded at the top with the form jammed
                  // against the bottom on a 440x956 browser viewport (the form
                  // block started at y=458 of 956; splitting it puts it at 230).
                  //
                  // An IntrinsicHeight + Spacers version distributes the same
                  // way but is not safe here: a Row reports its flex children at
                  // infinite width, so each card's description counts as a single
                  // line and the column can come out shorter than it lays out.
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      padding: EdgeInsets.fromLTRB(24, topGap, 24, 0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
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
                              const SizedBox(width: 2),
                              Image.asset(
                                'assets/figma/skillsikka_wordmark.png',
                                width: 150,
                                height: 50,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          SizedBox(height: logoTitleGap),
                          Text(
                            'Choose Your Role',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF111827),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
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
                          SizedBox(height: titleCardsGap),
                          _RoleCard(
                            selected: _isStudent,
                            title: 'I am a Student',
                            description:
                                'Explore world-class courses, attend bootcamps, and build high-income tech skills.',
                            iconAsset: 'assets/figma/signup_graduation_cap.svg',
                            onTap: () => setState(() => _isStudent = true),
                          ),
                          SizedBox(height: cardGap),
                          _RoleCard(
                            selected: !_isStudent,
                            title: 'I am an Instructor',
                            description:
                                'Share your knowledge, upload high-quality tutorials, and manage your learner cohorts.',
                            iconAsset: 'assets/figma/signup_chart_column.svg',
                            onTap: () => setState(() => _isStudent = false),
                          ),
                        ],
                      ),
                    ),
                    // 16pt is the floor once the spacers collapse, so the cards
                    // never touch the button on a short screen.
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, ctaGap, 24, 0),
                      child: SizedBox(
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
        // Padding + border must total 20pt in both states. The selected card's
        // 2pt border otherwise shaves 2pt off the text width, and on a 360pt
        // phone that was enough to push the student description onto a fourth
        // line: the card grew 20pt and everything above it jumped 9pt when you
        // switched roles.
        padding: EdgeInsets.all(selected ? 18 : 19),
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
