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
  int _selectedCategory = 0;
  int _hoveredCategory = -1;
  final _searchController = TextEditingController();

  // Categories with icons (mirrors HTML chips)
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: _buildInstructorsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Back button
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
          // Right icon (settings/sliders)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.tune,
              size: 18,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH ROW
  // ─────────────────────────────────────────────────────────────
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
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search instructors...',
                  hintStyle: GoogleFonts.figtree(
                    fontSize: 14,
                    color: _gray,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CATEGORIES (glossy chips)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategory;
          final hovered = index == _hoveredCategory;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredCategory = index),
            onExit: (_) => setState(() => _hoveredCategory = -1),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = index),
              child: _glossyChip(
                label: _categories[index].label,
                icon: _categories[index].icon,
                pressed: selected,
                hovered: hovered,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glossyChip({
    required String label,
    IconData? icon,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _gray),
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

  // ─────────────────────────────────────────────────────────────
  // INSTRUCTORS LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildInstructorsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final inst in _instructors) ...[
            _buildInstructorCard(inst),
            const SizedBox(height: 12),
          ],
        ],
      ),
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
          // Avatar
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
          // Name + specialty + metadata
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
                        const Icon(Icons.star, color: Color(0xFFFBBF24), size: 10),
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
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    color: _gray,
                  ),
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
