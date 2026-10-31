import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/course_image.dart';
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_course_detail_page.dart';

const _cream = Color(0xFFFAF9F6);
const _ink = Color(0xFF282828);
const _gray = Color(0xFF4B5563);
const _titleInk = Color(0xFF111827);
const _gold = Color(0xFF816501);

/// The skill catalogue.
///
/// **Reads `GET /courses/?course_type=skill`** and filters by category in the
/// client, because the four chips print a course **count** each — one request
/// per chip could not populate the other three. A skill catalogue is small, so
/// fetching it once is cheaper than four requests and keeps the counts honest.
class SkillCoursesPage extends ConsumerStatefulWidget {
  const SkillCoursesPage({super.key, this.initialSkill});

  /// The skill to open on, e.g. `Coding`.
  ///
  /// Set by the home rail's skill cards so that tapping "Music" lands on Music
  /// rather than on whichever chip happens to be first. Null opens on the first
  /// skill. An unrecognised label is ignored rather than throwing — a stale home
  /// card must not be able to break this screen.
  final String? initialSkill;

  @override
  ConsumerState<SkillCoursesPage> createState() => _SkillCoursesPageState();
}

class _SkillCoursesPageState extends ConsumerState<SkillCoursesPage> {
  int _hoveredSkillIndex = -1;

  /// Drives the chip row, so a preselected skill can be scrolled into view.
  final ScrollController _chipScrollController = ScrollController();

  /// One chip (140 wide) plus one gap (14). Both are fixed above, which is what
  /// makes the offset arithmetic below exact rather than a guess.
  static const _chipStride = 154.0;

  /// The four skills the design opens with, in chip order.
  ///
  /// **These are the starting chips, not the whole list.** The server's
  /// `LearningInterest` table has fifteen rows and the course builder offers all
  /// of them, so a skill course in any of the other eleven used to be published,
  /// present in this fetch, and reachable by no chip at all — the "I added a
  /// course and it is not in the app" bug. [_chips] appends whatever else the
  /// catalogue actually contains.
  static const _knownSkills = <(IconData, String)>[
    (Icons.code, 'Coding'),
    (Icons.brush, 'Drawing'),
    (Icons.mic, 'Public Speaking'),
    (Icons.music_note, 'Music'),
  ];

  /// The chip a course with no `skill_category` falls into.
  ///
  /// Only added when such a course exists. A published course without a
  /// category is a data fault, but hiding it from the catalogue is a worse one:
  /// the instructor would have no way to tell it apart from a course that never
  /// saved.
  static const _otherSkill = 'Other';

  /// The label the user picked. Null means "whatever the first chip is", which
  /// is what keeps the selection stable while the chip list is still empty.
  String? _selectedSkill;

  /// Every published skill course, fetched once — see the class doc.
  List<CourseDetailData> _courses = const [];
  bool _loading = true;
  String? _error;

  /// The chip row: the four design skills, then every other category the
  /// catalogue actually has, most-used first.
  ///
  /// Derived rather than authored so a newly created course is reachable the
  /// moment it is published. The four known chips stay even at zero — they are
  /// part of the screen's design, and an empty chip explains itself.
  List<(IconData, String)> get _chips {
    final counts = <String, int>{};
    for (final course in _courses) {
      final category = course.category.trim();
      final key = category.isEmpty ? _otherSkill : category;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final known = {for (final skill in _knownSkills) skill.$2};
    final extra = counts.keys.where((label) => !known.contains(label)).toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });

    return [..._knownSkills, for (final label in extra) (_iconFor(label), label)];
  }

  /// The selected label, resolved against the current chip list.
  String get _selectedLabel {
    final chips = _chips;
    final wanted = _selectedSkill;
    if (wanted != null && chips.any((chip) => chip.$2 == wanted)) return wanted;
    return chips.first.$2;
  }

  int get _selectedSkillIndex {
    final index = _chips.indexWhere((chip) => chip.$2 == _selectedLabel);
    return index < 0 ? 0 : index;
  }

  /// The fetched list narrowed to the selected skill.
  ///
  /// There is no `All` chip on this tab, so the selection is always a real
  /// skill — never the absence of a filter.
  List<CourseDetailData> get _visibleSkillCourses {
    final skill = _selectedLabel;
    return _courses.where((course) {
      final category = course.category.trim();
      if (skill == _otherSkill) return category.isEmpty;
      return category == skill;
    }).toList();
  }

  int _countFor(String skill) => _courses.where((course) {
    final category = course.category.trim();
    if (skill == _otherSkill) return category.isEmpty;
    return category == skill;
  }).length;

  /// A glyph for a category the design did not name.
  ///
  /// Keyword matching, not a lookup table of all fifteen rows: the server's
  /// category list is editable, and an unknown label has to land on something
  /// sensible rather than on an assertion.
  static IconData _iconFor(String label) {
    final value = label.toLowerCase();
    if (value.contains('code') || value.contains('program')) return Icons.code;
    if (value.contains('draw') ||
        value.contains('art') ||
        value.contains('paint') ||
        value.contains('design')) {
      return Icons.brush;
    }
    if (value.contains('speak') || value.contains('present')) return Icons.mic;
    if (value.contains('music') ||
        value.contains('sing') ||
        value.contains('dance')) {
      return Icons.music_note;
    }
    if (value.contains('math')) return Icons.calculate_outlined;
    if (value.contains('science') || value.contains('physic')) {
      return Icons.science_outlined;
    }
    if (value.contains('language')) return Icons.translate;
    if (value.contains('photo') || value.contains('camera')) {
      return Icons.photo_camera_outlined;
    }
    if (value.contains('business') || value.contains('market')) {
      return Icons.trending_up;
    }
    return Icons.school_outlined;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(courseApiProvider)
          .list(courseType: 'skill', pageSize: 50);
      if (!mounted) return;
      setState(() {
        _courses = page.courses;
        _loading = false;
      });
      _revealSelectedChip();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.displayMessage;
      });
    }
  }

  void _openCourse(CourseDetailData course) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SkillCourseDetailPage(course: course)),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedSkill = widget.initialSkill;
    _load();
  }

  /// Scrolls a preselected chip into view once the chip list exists.
  ///
  /// The chip row scrolls horizontally and the later chips sit off screen at
  /// 360pt, so a preselected `Music` would otherwise be selected but invisible.
  /// Runs after the fetch, because the list is derived from the courses — before
  /// it lands, `_chips` is only the four design skills and a category added
  /// since would not be found.
  void _revealSelectedChip() {
    final index = _selectedSkillIndex;
    if (index <= 0) return;
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
    final chips = _chips;
    final selected = _selectedSkillIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final s = chips[index];
            final isSelected = index == selected;
            final isHovered = index == _hoveredSkillIndex;
            final isActive = isSelected || isHovered;
            final count = _countFor(s.$2);

            return Padding(
              padding: EdgeInsets.zero,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredSkillIndex = index),
                onExit: (_) => setState(() => _hoveredSkillIndex = -1),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSkill = s.$2),
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
                    CourseImage(
                      course.image,
                      fallback: Container(
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
                  course.priceLabel,
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
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 32, color: _gray),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 13, color: _gray),
            ),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final courses = _visibleSkillCourses;
    if (courses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Center(
          child: Text(
            'No $_selectedLabel courses yet.',
            style: GoogleFonts.figtree(fontSize: 13, color: _gray),
          ),
        ),
      );
    }

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
              child: CourseImage(
                course.image,
                width: 80,
                height: 80,
                fallback: Container(
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
                        course.priceLabel,
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
