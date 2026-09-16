import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _softGray = Color(0xFF8D887F);

class AllCoursesPage extends StatefulWidget {
  const AllCoursesPage({super.key});

  @override
  State<AllCoursesPage> createState() => _AllCoursesPageState();
}

class _AllCoursesPageState extends State<AllCoursesPage> {
  int _selectedChip = 0;
  int _hoveredChip = -1;

  static const _chips = [
    'All',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];

  static const _coursePool = <_Course>[
    _Course(
      image: 'assets/figma/courses/ui-ux.png',
      title: 'UI/UX Design Fundamentals',
      rating: '4.7',
      level: 'Beginner',
    ),
    _Course(
      image: 'assets/figma/courses/js.png',
      title: 'JavaScript Masterclass',
      rating: '4.9',
      level: 'Intermediate',
    ),
    _Course(
      image: 'assets/figma/courses/ml.png',
      title: 'Machine Learning Basics',
      rating: '4.8',
      level: 'Advanced',
    ),
    _Course(
      image: 'assets/figma/courses/dm.png',
      title: 'Digital Marketing 101',
      rating: '4.5',
      level: 'Beginner',
    ),
    _Course(
      image: 'assets/figma/courses/react.png',
      title: 'React Native Development',
      rating: '4.6',
      level: 'Intermediate',
    ),
    _Course(
      image: 'assets/figma/courses/cc.png',
      title: 'Cloud Computing Essentials',
      rating: '4.3',
      level: 'Advanced',
    ),
  ];

  List<_Course> get _allCourses =>
      List.generate(18, (i) => _coursePool[i % _coursePool.length]);

  @override
  Widget build(BuildContext context) {
    final courses = _allCourses;
    // Group into 3 sections of 6 (3 rows × 2 cards each)
    const cardsPerSection = 6;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChips(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(),
                    const SizedBox(height: 16),
                    for (
                      var s = 0;
                      s < courses.length;
                      s += cardsPerSection
                    ) ...[
                      _buildCoursesGrid(
                        courses.sublist(
                          s,
                          (s + cardsPerSection).clamp(0, courses.length),
                        ),
                      ),
                      if (s + cardsPerSection < courses.length)
                        const SizedBox(height: 12),
                    ],
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
  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
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
            'Courses',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
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
  // CHIPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedChip;
          final hovered = index == _hoveredChip;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredChip = index),
            onExit: (_) => setState(() => _hoveredChip = -1),
            child: GestureDetector(
              onTap: () => setState(() => _selectedChip = index),
              child: Center(
                child: _chip(
                  label: _chips[index],
                  pressed: selected,
                  hovered: hovered,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool pressed,
    required bool hovered,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: hovered ? 0.98 : 0.84),
            const Color(0xFFF3F4F6).withValues(alpha: pressed ? 0.72 : 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: hovered ? const Color(0x2E000000) : const Color(0x22000000),
            blurRadius: hovered ? 10 : 7,
            offset: Offset(0, pressed ? 1 : 3),
          ),
          const BoxShadow(
            color: Color(0xCCFFFFFF),
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.figtree(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    return Row(
      children: [
        Text(
          'All Courses',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.tune, size: 14, color: _softGray),
            const SizedBox(width: 4),
            Text(
              'Filters',
              style: GoogleFonts.figtree(fontSize: 12, color: _softGray),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSES GRID (2 columns × N rows)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCoursesGrid(List<_Course> courses) {
    return Column(
      children: [
        for (var i = 0; i < courses.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCourseCard(courses[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < courses.length
                    ? _buildCourseCard(courses[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (i + 2 < courses.length) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildCourseCard(_Course course) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${course.title} selected'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _ink,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 105,
                width: double.infinity,
                child: Image.asset(
                  course.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.image,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            // Card info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFBBF24),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        course.rating,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        course.level,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _softGray,
                        ),
                      ),
                    ],
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

class _Course {
  const _Course({
    required this.image,
    required this.title,
    required this.rating,
    required this.level,
  });

  final String image;
  final String title;
  final String rating;
  final String level;
}
