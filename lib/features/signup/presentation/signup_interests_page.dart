import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupInterestsPage extends StatefulWidget {
  const SignupInterestsPage({super.key});

  @override
  State<SignupInterestsPage> createState() => _SignupInterestsPageState();
}

class _SignupInterestsPageState extends State<SignupInterestsPage> {
  final _topics = const [
    ('Coding', 'assets/figma/interests_code.svg'),
    ('Mathematics', 'assets/figma/interests_plus_square.svg'),
    ('Physics', 'assets/figma/interests_atom.svg'),
    ('Chemistry', 'assets/figma/interests_test_tube.svg'),
    ('Biology', 'assets/figma/interests_dna.svg'),
    ('Data Science', 'assets/figma/interests_database.svg'),
    ('AI & ML', 'assets/figma/interests_cpu.svg'),
    ('Web Dev', 'assets/figma/interests_globe.svg'),
    ('App Dev', 'assets/figma/interests_smartphone.svg'),
    ('Robotics', 'assets/figma/interests_cog.svg'),
    ('Electronics', 'assets/figma/interests_bolt.svg'),
    ('3D Design', 'assets/figma/interests_shapes.svg'),
  ];

  late final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1F7),
      body: PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !context.canPop()) {
            context.go('/signup/verify');
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/signup/verify'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 45,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset('assets/figma/academic_cap.png'),
                        ),
                        const SizedBox(width: 1),
                        Image.asset(
                          'assets/figma/skillsikka_wordmark.png',
                          width: 150,
                          height: 45,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF4B5563),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What do you want to learn?',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF111827),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select at least 3 topics to personalize your feed',
                        style: GoogleFonts.manrope(
                          color: const Color.fromARGB(255, 38, 43, 50),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topics.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: 56,
                            ),
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          return _TopicCard(
                            name: topic.$1,
                            icon: topic.$2,
                            selected: _selected.contains(topic.$1),
                            onTap: () => setState(
                              () => _selected.contains(topic.$1)
                                  ? _selected.remove(topic.$1)
                                  : _selected.add(topic.$1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${_selected.length} selected',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF111827),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _selected.length >= 3
                            ? () => context.go('/')
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE6B800),
                          foregroundColor: const Color(0xFF111827),
                          elevation: 4,
                          shadowColor: const Color.fromARGB(51, 75, 75, 74),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
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
            'Step: 4 of 4',
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

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFFE6B800) : const Color(0xFFE5E7EB),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14E6B800),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(1.3),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF2F1F7),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              icon,
              colorFilter: ColorFilter.mode(
                selected ? const Color(0xFFE6B800) : const Color(0xFF111827),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: const Color(0xFF111827),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selected)
            Container(
              width: 16,
              height: 16,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFE6B800),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: SvgPicture.asset('assets/figma/interests_check.svg'),
            ),
        ],
      ),
    ),
  );
}
