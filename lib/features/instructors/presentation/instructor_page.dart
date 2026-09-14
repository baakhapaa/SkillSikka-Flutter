import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _chipBg = Color(0xFFF2F1F7);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF9CA3AF);
const _gold = Color(0xFF816501);
const _border = Color(0xFFEAEAEA);

class TopInstructorsPage extends StatefulWidget {
  const TopInstructorsPage({super.key});

  @override
  State<TopInstructorsPage> createState() => _TopInstructorsPageState();
}

class _TopInstructorsPageState extends State<TopInstructorsPage> {
  int _hoveredCategory = -1;
  final _searchController = TextEditingController();

  static const _categories = <_CategoryChip>[
    _CategoryChip(label: 'All', icon: null),
    _CategoryChip(label: 'Mathematics', icon: Icons.calculate_outlined),
    _CategoryChip(label: 'Programming', icon: Icons.terminal),
    _CategoryChip(label: 'Science', icon: Icons.science_outlined),
    _CategoryChip(label: 'Literature', icon: Icons.menu_book_outlined),
    _CategoryChip(label: 'History', icon: Icons.account_balance_outlined),
    _CategoryChip(label: 'Psychology', icon: Icons.psychology_outlined),
    _CategoryChip(label: 'Business', icon: Icons.bar_chart),
    _CategoryChip(label: 'Art & Design', icon: Icons.palette_outlined),
    _CategoryChip(label: 'Philosophy', icon: Icons.format_quote_outlined),
    _CategoryChip(label: 'Engineering', icon: Icons.settings_outlined),
  ];

  static const _instructors = <_Instructor>[
    _Instructor(
      image: 'assets/figma/instructors/instructor.png',
      name: 'Prof. Shuvanga Karki',
      specialty: 'Adobe Certified Instructor',
      students: '915,213 students',
      courses: '40 courses',
      rating: '4.9',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor1.png',
      name: 'Dr. Sarah Pakhrin',
      specialty: 'PhD in Pure Mathematics',
      students: '124,500 students',
      courses: '12 courses',
      rating: '4.8',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor2.png',
      name: 'Alexa Thapa',
      specialty: 'Senior Python Developer',
      students: '89,200 students',
      courses: '8 courses',
      rating: '4.7',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor3.png',
      name: 'Anush Shrestha',
      specialty: 'Senior Front-End Lead',
      students: '215,000 students',
      courses: '15 courses',
      rating: '4.9',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor4.png',
      name: 'Rohan Shakya',
      specialty: 'Creative Arts Director',
      students: '56,400 students',
      courses: '22 courses',
      rating: '4.6',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor5.png',
      name: 'Mira Thapa',
      specialty: 'Data Analyst & Writer',
      students: '78,110 students',
      courses: '11 courses',
      rating: '4.8',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildScreenHeader(),
            _buildSearchRow(),
            _buildCategories(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: _buildInstructorsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Top Instructors',
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(Icons.tune, size: 18, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: _gray),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.figtree(fontSize: 14, color: _ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search instructors...',
                  hintStyle: GoogleFonts.figtree(fontSize: 14, color: _gray),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hovered = index == _hoveredCategory;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredCategory = index),
            onExit: (_) => setState(() => _hoveredCategory = -1),
            child: GestureDetector(
              child: Center(
                child: _glassChip(
                  label: _categories[index].label,
                  icon: _categories[index].icon,
                  hovered: hovered,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glassChip({
    required String label,
    IconData? icon,
    required bool hovered,
  }) {
    const radius = 14.0;

    // ── Gradient: pure white top → soft gray bottom ─────────────
    final topColor = const Color(0xFFFFFFFF);
    final midColor = hovered
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFFBFBFC);
    final bottomColor = hovered
        ? const Color(0xFFD9DCE2) // deeper gray on hover
        : const Color(0xFFEAECEF);

    // ── Border: soft whitish edge ───────────────────────────────
    final borderColor = hovered
        ? Colors.white
        : Colors.white.withValues(alpha: 0.85);

    // ── Outer drop shadow (blurred, below the pill) ─────────────
    final outerColor = hovered
        ? const Color(0x3D000000) // stronger on hover
        : const Color(0x24000000);
    final outerBlur = hovered ? 16.0 : 10.0;
    final outerOffsetY = hovered ? 6.0 : 3.0;

    // ── Top specular highlight (glossy shine) ───────────────────
    final highlightColor = hovered
        ? const Color(0xFFFFFFFF)
        : const Color(0xE6FFFFFF);
    final highlightBlur = hovered ? 5.0 : 3.0;
    final highlightOffsetY = hovered ? -2.5 : -1.5;

    // ── Bottom inset (soft shadow inside bottom edge) ───────────
    final bottomInsetColor = hovered
        ? const Color(0x33000000)
        : const Color(0x1F000000);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // Top → bottom glossy gradient
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, midColor, bottomColor],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(radius),
        // Soft whitish border
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          // 1. Outer blurred drop shadow below
          BoxShadow(
            color: outerColor,
            blurRadius: outerBlur,
            offset: Offset(0, outerOffsetY),
          ),
          // 2. Bright specular highlight hugging the top inside edge
          BoxShadow(
            color: highlightColor,
            blurRadius: highlightBlur,
            offset: Offset(0, highlightOffsetY),
            spreadRadius: -1,
          ),
          // 3. Soft dark inset hugging the bottom inside edge
          BoxShadow(
            color: bottomInsetColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
          // 4. Soft hover glow outside the chip
          if (hovered)
            const BoxShadow(
              color: Color(0x1F5B8DEF),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: hovered ? _ink : _gray),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorsList() {
    return Column(
      children: _instructors
          .map(
            (inst) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _buildInstructorCard(inst),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInstructorCard(_Instructor inst) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 104),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset(
                inst.image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          inst.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFBBF24),
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            inst.rating,
                            style: GoogleFonts.figtree(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inst.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          inst.students,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            color: _softGray,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          color: _softGray,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          inst.courses,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _gold,
                          ),
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

class _Instructor {
  const _Instructor({
    required this.image,
    required this.name,
    required this.specialty,
    required this.students,
    required this.courses,
    required this.rating,
  });

  final String image;
  final String name;
  final String specialty;
  final String students;
  final String courses;
  final String rating;
}

class _CategoryChip {
  const _CategoryChip({required this.label, this.icon});
  final String label;
  final IconData? icon;
}
