import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _cream = Color(0xFFFAF9F6);
const _ink = Color(0xFF282828);
const _gray = Color(0xFF4B5563);
const _titleInk = Color(0xFF111827);
const _gold = Color(0xFF816501);

class SkillCoursesPage extends StatefulWidget {
  const SkillCoursesPage({super.key});

  @override
  State<SkillCoursesPage> createState() => _SkillCoursesPageState();
}

class _SkillCoursesPageState extends State<SkillCoursesPage> {
  int _selectedSkillIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 12, bottom: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSkillsGrid(),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Top Course'),
                    const SizedBox(height: 14),
                    _buildTopCoursesCarousel(),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Course'),
                    const SizedBox(height: 14),
                    _buildTopRatedList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppHeader(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button circle (glass)
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: _ink,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Skill Courses',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _titleInk,
            ),
          ),
          const Spacer(),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: const Icon(Icons.search, size: 20, color: _ink),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION HEADER  ( |  Title )
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '| ',
            style: GoogleFonts.manrope(
              fontSize: 21,
              fontWeight: FontWeight.w300,
              color: const Color(0x1F282828),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF201C15),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SKILLS GRID (horizontal scroller)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSkillsGrid() {
    final skills = [
      (Icons.code, 'Coding', '32 Courses'),
      (Icons.brush, 'Drawing', '24 Courses'),
      (Icons.mic, 'Public Speaking', '18 Courses'),
      (Icons.music_note, 'Music', '40 Lessons'),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 0),
      child: SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          itemCount: skills.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final s = skills[index];
            final isSelected = index == _selectedSkillIndex;

            return GestureDetector(
              onTap: () => setState(() => _selectedSkillIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : const [],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        s.$1,
                        size: 18,
                        color: const Color(0xFFE6BD1E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.$2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _titleInk,
                            ),
                          ),
                          Text(
                            s.$3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                              fontSize: 9,
                              color: _gray,
                            ),
                          ),
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

  // ─────────────────────────────────────────────────────────────
  // TOP COURSES CAROUSEL (horizontal cards)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopCoursesCarousel() {
    final courses = [
      (
        'assets/figma/skillcourse/skillcourse.png',
        'Python',
        'Python for Beginners: Complete Bootcamp 2024',
        '4.9',
        '32,450 students',
        'Rs. 1,299',
      ),
      (
        'assets/figma/skillcourse/skillcourse1.png',
        'React.js',
        'React & Next.js: Full-Stack Web Development',
        '4.8',
        '21,780 students',
        'Rs. 1,999',
      ),
      (
        'assets/figma/skillcourse/skillcourse2.png',
        'DSA',
        'Data Structures & Algorithms Masterclass',
        '4.9',
        '45,600 students',
        'Rs. 2,499',
      ),
    ];

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = courses[index];
          return _buildCourseCard(
            image: c.$1,
            badge: c.$2,
            title: c.$3,
            rating: c.$4,
            students: c.$5,
            price: c.$6,
          );
        },
      ),
    );
  }

  Widget _buildCourseCard({
    required String image,
    required String badge,
    required String title,
    required String rating,
    required String students,
    required String price,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          // Meta row
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 12),
              const SizedBox(width: 4),
              Text(
                rating,
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Text(
                students,
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  color: const Color(0xFF8D887F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                price,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP RATED LIST (vertical list cards)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopRatedList() {
    final items = [
      (
        'assets/figma/skillcourse/skillcourse3.png',
        'JavaScript: The Complete Guide',
        'Kyle Simpson',
        '4.9',
        '(2,340)',
        'Rs.24.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse4.png',
        'Node.js Backend Development',
        'Sarah Chen',
        '4.7',
        '(1,456)',
        'Rs.19.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse5.png',
        'TypeScript Advanced Patterns',
        'Matt Pocock',
        '4.8',
        '(987)',
        'Rs.29.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse6.png',
        'Django & REST API Masterclass',
        'Prof. Amir Khan',
        '4.9',
        '(1,890)',
        'Rs.34.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse7.png',
        'Flutter Mobile App Development',
        'Andrea Bizzotto',
        '4.8',
        '(2,103)',
        'Rs.22.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse8.png',
        'Git & GitHub for Teams',
        'Scott Chacon',
        '4.7',
        '(3,210)',
        'Rs.14.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse9.png',
        'SQL & Database Design',
        'Dr. Lisa Nguyen',
        '4.9',
        '(1,678)',
        'Rs.27.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse10.png',
        'Docker & Kubernetes Essentials',
        'Kelsey Hightower',
        '4.8',
        '(945)',
        'Rs.32.99',
      ),
      (
        'assets/figma/skillcourse/skillcourse11.png',
        'Machine Learning with Python',
        'Dr. Ananya Patel',
        '4.9',
        '(4,512)',
        'Rs.39.99',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final item in items) ...[
            _buildListCard(
              image: item.$1,
              title: item.$2,
              instructor: item.$3,
              rating: item.$4,
              reviews: item.$5,
              price: item.$6,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildListCard({
    required String image,
    required String title,
    required String instructor,
    required String rating,
    required String reviews,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF201C15),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instructor,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: const Color(0xFF8D887F),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star,
                        color: Color(0xFFFBBF24), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reviews,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      price,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
