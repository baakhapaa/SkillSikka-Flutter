import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/pressable_chip.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';

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

  static const _chips = [
    'All',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];

  /// The catalogue filtered by the selected Class chip.
  ///
  /// `All` is the **absence** of a filter, not a value on any course — see
  /// [CourseDetailData.classLevel]. This used to ignore the chips entirely and
  /// tile the six-entry pool to eighteen cards so the grid had something to
  /// scroll, which is why every chip appeared to do nothing.
  List<CourseDetailData> get _visibleCourses {
    final chip = _chips[_selectedChip];
    if (chip == 'All') return coursePool;
    return coursePool.where((c) => c.classLevel == chip).toList();
  }

  @override
  Widget build(BuildContext context) {
    final courses = _visibleCourses;

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
                    const SizedBox(height: 28),
                    _buildSectionHeader(),
                    const SizedBox(height: 16),
                    if (courses.isEmpty)
                      _buildEmptyState()
                    else
                      _buildCoursesGrid(courses),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: IconButton(
              tooltip: 'Search courses',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
              icon: const Icon(Icons.search, size: 20, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHIPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: _chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Center(
            child: PressableChip(
              label: _chips[index],
              selected: index == _selectedChip,
              onTap: () => setState(() => _selectedChip = index),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              textColor: _ink,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    // Names the filter, so a filtered grid cannot be mistaken for the whole
    // catalogue — "All Courses" over two Class 6 cards would be a lie.
    final chip = _chips[_selectedChip];

    return Row(
      children: [
        Text(
          chip == 'All' ? 'All Courses' : '$chip Courses',
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
  /// Shown when a class has no courses yet, so a filter can never produce a
  /// blank screen that reads as a loading failure.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 32, color: _softGray),
            const SizedBox(height: 12),
            Text(
              'No courses for this class yet.',
              style: GoogleFonts.figtree(fontSize: 13, color: _softGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesGrid(List<CourseDetailData> courses) {
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

  Widget _buildCourseCard(CourseDetailData course) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseDetailPage(course: course)),
      ),
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
