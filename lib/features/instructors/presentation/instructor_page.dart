import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFF2F1F7);
const _ink = Color(0xFF282828);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF8D887F);
const _badgeBg = Color(0xFFFFFBEB);
const _gold = Color(0xFF816501);

class AllInstructorsPage extends StatefulWidget {
  const AllInstructorsPage({super.key});

  @override
  State<AllInstructorsPage> createState() => _AllInstructorsPageState();
}

class _AllInstructorsPageState extends State<AllInstructorsPage> {
  int _selectedCategory = 0;
  final _searchController = TextEditingController();

  static const _categories = [
    'All',
    'Design',
    'Development',
    'Marketing',
    'Photography',
    'Business',
    'Music',
  ];

  static const _instructors = <_Instructor>[
    _Instructor(
      image: 'assets/figma/instructors/instructor.png',
      badge: 'Adobe Certified Instructor',
      name: 'Shuvanga Karki',
      rating: '4.9',
      stats: '915K stds • 40 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor1.png',
      badge: 'Senior Frontend Dev',
      name: 'Sarah Jenkins',
      rating: '4.8',
      stats: '420K stds • 18 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor2.png',
      badge: 'Startup Coach & MBA',
      name: 'David Chen',
      rating: '4.7',
      stats: '154K stds • 12 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor3.png',
      badge: 'Portrait Photographer',
      name: 'Elena Rostova',
      rating: '4.9',
      stats: '88K stds • 8 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor4.png',
      badge: 'Music Producer',
      name: 'Marcus Aurelius',
      rating: '4.6',
      stats: '62K stds • 5 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor5.png',
      badge: 'Marketing Strategist',
      name: 'Aisha Diop',
      rating: '4.8',
      stats: '310K stds • 22 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor6.png',
      badge: 'Full Stack Architect',
      name: 'Kenji Sato',
      rating: '4.9',
      stats: '245K stds • 15 crs',
    ),
    _Instructor(
      image: 'assets/figma/instructors/instructor7.png',
      badge: 'UX/UI Lead Designer',
      name: 'Sophia Martinez',
      rating: '4.7',
      stats: '180K stds • 11 crs',
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
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildCategories(),
                    const SizedBox(height: 20),
                    _buildInstructorsGrid(),
                    const SizedBox(height: 16),
                    _buildResultsInfo(),
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
  // HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
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
            'All Instructors',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const Spacer(),
          // Filter button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: const Icon(Icons.tune, size: 16, color: _ink),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: _softGray),
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
                  hintText: 'Search instructors, specialties...',
                  hintStyle: GoogleFonts.figtree(
                    fontSize: 14,
                    color: _softGray,
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
  // CATEGORIES
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _ink : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? _ink : const Color(0xFFF3F4F6),
                ),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : _gray,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INSTRUCTORS GRID  (2 columns)
  // ─────────────────────────────────────────────────────────────
  Widget _buildInstructorsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < _instructors.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildInstructorCard(_instructors[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < _instructors.length
                      ? _buildInstructorCard(_instructors[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (i + 2 < _instructors.length) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructorCard(_Instructor inst) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1C1917),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portrait
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 116,
              width: double.infinity,
              child: Image.asset(
                inst.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _badgeBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              inst.badge,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.figtree(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            inst.name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 11),
              const SizedBox(width: 4),
              Text(
                inst.rating,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  inst.stats,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _softGray,
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
  // RESULTS INFO
  // ─────────────────────────────────────────────────────────────
  Widget _buildResultsInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          'Showing ${_instructors.length} top professional instructors',
          style: GoogleFonts.figtree(
            fontSize: 12,
            color: _softGray,
          ),
        ),
      ),
    );
  }
}

class _Instructor {
  const _Instructor({
    required this.image,
    required this.badge,
    required this.name,
    required this.rating,
    required this.stats,
  });

  final String image;
  final String badge;
  final String name;
  final String rating;
  final String stats;
}