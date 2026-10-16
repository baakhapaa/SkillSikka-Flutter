import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';
import 'package:skillsikka/features/skill_courses/data/skill_course.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_course_detail_page.dart';

const _cream = Color(0xFFFAF9F6);
const _ink = Color(0xFF282828);
const _gray = Color(0xFF4B5563);
const _titleInk = Color(0xFF111827);
const _gold = Color(0xFF816501);

class SkillCoursesPage extends StatefulWidget {
  const SkillCoursesPage({super.key, this.initialSkill});

  /// The skill to open on, e.g. `Coding`.
  ///
  /// Set by the home rail's skill cards so that tapping "Music" lands on Music
  /// rather than on whichever chip happens to be first. Null opens on the first
  /// skill. An unrecognised label is ignored rather than throwing — a stale home
  /// card must not be able to break this screen.
  final String? initialSkill;

  @override
  State<SkillCoursesPage> createState() => _SkillCoursesPageState();
}

class _SkillCoursesPageState extends State<SkillCoursesPage> {
  int _selectedSkillIndex = 0;
  int _hoveredSkillIndex = -1;

  /// Drives the chip row, so a preselected skill can be scrolled into view.
  final ScrollController _chipScrollController = ScrollController();

  /// One chip (140 wide) plus one gap (14). Both are fixed above, which is what
  /// makes the offset arithmetic below exact rather than a guess.
  static const _chipStride = 154.0;

  /// The four skills, in chip order. Each label must match a
  /// [CourseDetailData.category] in [skillCoursePool] **exactly** — the chips
  /// filter on it, so a typo here silently empties a chip.
  ///
  /// The course count under each label is derived from the pool rather than
  /// authored: the old hardcoded `'32 Courses'` could claim more than the chip
  /// actually showed.
  static const _skills = <(IconData, String)>[
    (Icons.code, 'Coding'),
    (Icons.brush, 'Drawing'),
    (Icons.mic, 'Public Speaking'),
    (Icons.music_note, 'Music'),
  ];

  /// The pool narrowed to the selected skill.
  ///
  /// There is no `All` chip on this tab, so the selection is always a real
  /// skill — never the absence of a filter.
  List<CourseDetailData> get _visibleSkillCourses {
    final skill = _skills[_selectedSkillIndex].$2;
    return skillCoursePool.where((c) => c.category == skill).toList();
  }

  void _openCourse(CourseDetailData course) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SkillCourseDetailPage(course: course)),
    );
  }

  @override
  void initState() {
    super.initState();

    final skill = widget.initialSkill;
    if (skill == null) return;

    final index = _skills.indexWhere((s) => s.$2 == skill);
    if (index < 0) return;
    _selectedSkillIndex = index;

    // The chip row scrolls horizontally and the last chip sits off screen at
    // 360pt, so a preselected `Music` would otherwise be selected but invisible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chipScrollController.hasClients) return;
      final max = _chipScrollController.position.maxScrollExtent;
      _chipScrollController.jumpTo(
        (index * _chipStride).clamp(0.0, max).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

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
                    const SizedBox(height: 20),
                    _buildSectionHeader('Top Course'),
                    const SizedBox(height: 18),
                    _buildTopCoursesCarousel(),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Course'),
                    const SizedBox(height: 32),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SectionBar(),
          const SizedBox(width: 7),
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

  Widget _buildSkillsGrid() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _skills.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final s = _skills[index];
            final isSelected = index == _selectedSkillIndex;
            final isHovered = index == _hoveredSkillIndex;
            final isActive = isSelected || isHovered;
            final count = skillCoursePool
                .where((c) => c.category == s.$2)
                .length;

            return Padding(
              padding: EdgeInsets.zero,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredSkillIndex = index),
                onExit: (_) => setState(() => _hoveredSkillIndex = -1),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSkillIndex = index),
                  child: AnimatedScale(
                    scale: isHovered ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: 140,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isActive
                              ? [
                                  Colors.white.withValues(alpha: 0.98),
                                  const Color(
                                    0xFFF2F4F7,
                                  ).withValues(alpha: 0.7),
                                ]
                              : const [Color(0xFFFAFAFA), Color(0xFFF7F7F8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isActive ? 0.9 : 0.55,
                          ),
                        ),
                        boxShadow: isActive
                            ? const [
                                BoxShadow(
                                  color: Color(0x24000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Color(0xCCFFFFFF),
                                  blurRadius: 2,
                                  offset: Offset(0, -1),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _titleInk,
                                  ),
                                ),
                                Text(
                                  '$count Courses',
                                  maxLines: 1,
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
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The selected skill's first three courses — the "Top Course" highlight.
  ///
  /// Order is the curation: the pool is authored with each skill's strongest
  /// three first, the same way the home rail takes the first four of
  /// `coursePool`. The list below shows the whole filtered pool, so these three
  /// appear there too — deliberately, and the reason the two sections cannot
  /// disagree about what a skill contains.
  Widget _buildTopCoursesCarousel() {
    final courses = _visibleSkillCourses.take(3).toList();

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildCourseCard(courses[index]),
      ),
    );
  }

  Widget _buildCourseCard(CourseDetailData course) {
    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
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
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
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
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          course.badge,
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
              course.title,
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
                  course.rating,
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.studentsEnrolled,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      color: const Color(0xFF8D887F),
                    ),
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
                  course.price,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                ),
                const Spacer(),
                _GlassActionButton(onTap: () => _openCourse(course)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSE LIST (vertical list cards)
  // ─────────────────────────────────────────────────────────────
  /// The whole filtered pool, so the list and the carousel above it can never
  /// disagree about which courses a skill contains.
  Widget _buildTopRatedList() {
    final courses = _visibleSkillCourses;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final course in courses) ...[
            _buildListCard(course),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildListCard(CourseDetailData course) {
    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
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
                course.image,
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
                    course.title,
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
                    course.instructorName,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: const Color(0xFF8D887F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFBBF24),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        course.rating,
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // `Expanded` rather than a `Spacer` so a longer ratings
                      // string ellipsises instead of overflowing the card.
                      Expanded(
                        child: Text(
                          course.ratingsCount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        course.price,
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
      ),
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  const _GlassActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: _hovered ? 0.98 : 0.86),
                const Color(
                  0xFFF2F4F7,
                ).withValues(alpha: _pressed ? 0.78 : 0.58),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? const Color(0x2E000000)
                    : const Color(0x22000000),
                blurRadius: _hovered ? 10 : 7,
                offset: Offset(0, _pressed ? 1 : 3),
              ),
              const BoxShadow(
                color: Color(0xCCFFFFFF),
                blurRadius: 2,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Text(
            'View',
            style: GoogleFonts.figtree(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _titleInk,
            ),
          ),
        ),
      ),
    );
  }
}
