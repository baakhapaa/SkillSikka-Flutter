import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF8D887F);
const _border = Color(0xFFEAEAEA);
const _gold = Color(0xFFE6B800);

/// The full course-detail screen, shared by the Courses tab and Premium Courses.
///
/// Extracted from `premium_course_details_page.dart` on 2026-10-13 so the two
/// entry points cannot drift apart. Every value it renders comes from
/// [CourseDetailData]; it holds no content of its own.
///
/// **It is deliberately free of Riverpod.** The only thing that needs a
/// `ProviderContainer` is the enrolment gate, so that arrives as the [onEnrol]
/// callback instead. That keeps this widget pumpable in a test with no
/// `ProviderScope` above it — the trap `navigation_test.dart` hit with the
/// profile tab.
///
/// The banner is a video when [CourseDetailData.bannerVideoAsset] is set and a
/// still image otherwise. The premium screen has a video; a course in the
/// catalogue has only its thumbnail, so it gets a static banner with no
/// play/pause overlay. Everything else renders identically for both.
class CourseDetailView extends StatefulWidget {
  const CourseDetailView({
    super.key,
    required this.data,
    required this.onEnrol,
  });

  final CourseDetailData data;

  /// Runs the enrolment flow. Owned by the caller because the gate needs a
  /// `ProviderContainer`, which this widget must not reach for.
  final Future<void> Function() onEnrol;

  @override
  State<CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<CourseDetailView> {
  /// Null when the data has no video — see the class doc. The controller is
  /// only ever constructed for a screen that actually has one, which also keeps
  /// `video_player` (no platform implementation under `flutter test`) off the
  /// path of any test that renders an image-only course.
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _showFullDescription = false;

  /// Curriculum sections the user has opened.
  ///
  /// A set rather than a single index because Udemy lets several sections sit
  /// open at once — collapsing one should not close another.
  final Set<int> _expandedModules = <int>{};

  void _toggleModule(int index) {
    setState(() {
      // `Set.remove` returns false when the key was absent, so this both tests
      // and toggles in one step.
      if (!_expandedModules.remove(index)) _expandedModules.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    final asset = widget.data.bannerVideoAsset;
    if (asset == null) return;

    _videoController = VideoPlayerController.asset(asset)
      ..initialize().then((_) {
        if (mounted) setState(() => _videoReady = true);
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildNavigationHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBannerSection(),
                        const SizedBox(height: 24),
                        _buildCoreDetails(),
                        const SizedBox(height: 24),
                        _buildWhatYouLearn(),
                        const SizedBox(height: 24),
                        _buildCurriculum(),
                        const SizedBox(height: 24),
                        _buildSectionIncludes(),
                        const SizedBox(height: 24),
                        _buildSectionRequirements(),
                        const SizedBox(height: 24),
                        _buildSectionDescription(),
                        const SizedBox(height: 24),
                        _buildSectionInstructors(),
                        const SizedBox(height: 24),
                        _buildSectionFeedback(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomStickyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: _bg,
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
          // Share button
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.share_outlined, size: 16, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection() {
    final data = widget.data;

    if (data.bannerVideoAsset == null) {
      return SizedBox(
        height: 210,
        width: double.infinity,
        child: Image.asset(
          data.image,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: Colors.grey.shade300),
        ),
      );
    }

    final controller = _videoController!;
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: _videoReady
          ? Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                // Play/pause overlay
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }

  Widget _buildCoreDetails() {
    final data = widget.data;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.27,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            style: GoogleFonts.figtree(
              fontSize: 14,
              height: 1.43,
              fontWeight: FontWeight.w500,
              color: _gray,
            ),
          ),
          const SizedBox(height: 12),
          // Rating meta row
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 14),
              const SizedBox(width: 4),
              Text(
                data.rating,
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.ratingsCount,
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
              const SizedBox(width: 8),
              Text('•', style: GoogleFonts.figtree(color: _gray)),
              const SizedBox(width: 8),
              Text(
                data.studentsEnrolled,
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          // Instructor row
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  data.instructorAvatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created by',
                    style: GoogleFonts.figtree(fontSize: 13, color: _gray),
                  ),
                  Text(
                    data.instructorName,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SvgPicture.asset(
                'assets/figma/stlearning/alert-circle.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFBBF24),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.lastUpdated,
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Language info
          Row(
            children: [
              SvgPicture.asset(
                'assets/figma/stlearning/language.svg',
                width: 14,
                height: 14,
                semanticsLabel: 'Available languages',
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFBBF24),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.languages,
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SvgPicture.asset(
                'assets/figma/stlearning/cc.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(_gray, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                data.subtitleTracks,
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatYouLearn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What you'll learn",
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in widget.data.learningOutcomes) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'assets/figma/stlearning/check.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFBBF24),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        height: 1.4,
                        color: _gray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The curriculum, as Udemy does it: each section is a row you tap to open,
  /// revealing its lectures.
  ///
  /// This used to be a static card with a decorative `expand_more` chevron and a
  /// `4 lessons` string that came from the data — a chevron that did nothing,
  /// promising content that did not exist. The count is now derived from the
  /// lesson list, so the header cannot claim more than the section holds.
  Widget _buildCurriculum() {
    final modules = widget.data.modules;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curriculum',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.data.curriculumSummary,
            style: GoogleFonts.figtree(fontSize: 11, color: _gray),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < modules.length; i++)
            _buildModuleCard(i, modules[i]),
        ],
      ),
    );
  }

  Widget _buildModuleCard(int index, CourseModule module) {
    final expanded = _expandedModules.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            // Opaque so the whole row is a target, not just the text runs.
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleModule(index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          module.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: const Icon(
                          Icons.expand_more,
                          size: 18,
                          color: _gray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        // Derived, never authored — see [CourseModule.lessons].
                        '${module.lessons.length} lessons',
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(color: Color(0xFF99A6B8)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        module.duration,
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: _border),
            for (final lesson in module.lessons) _buildLessonRow(lesson),
          ],
        ],
      ),
    );
  }

  Widget _buildLessonRow(CourseLesson lesson) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, size: 16, color: _gray),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(fontSize: 12, color: _ink),
            ),
          ),
          if (lesson.isPreview) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F1F7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Preview',
                style: GoogleFonts.figtree(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _gray,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            lesson.duration,
            style: GoogleFonts.figtree(fontSize: 11, color: _softGray),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION INCLUDES
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionIncludes() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This course includes',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in widget.data.includes) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: _gray),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionRequirements() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in widget.data.requirements) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: GoogleFonts.figtree(fontSize: 13, color: _gray),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: GoogleFonts.figtree(fontSize: 13, color: _gray),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionDescription() {
    final data = widget.data;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          if (data.descriptionIntro.isNotEmpty) ...[
            Text(
              data.descriptionIntro,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final block in data.descriptionBlocks) ...[
            _buildDescriptionBlock(block),
          ],
          if (_showFullDescription)
            for (final block in data.descriptionMoreBlocks) ...[
              _buildDescriptionBlock(block),
            ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _showFullDescription = !_showFullDescription),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _showFullDescription ? 'Show less' : 'Show more',
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: const Color(0xFF5D2EE6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One heading/body pair in the Description section. [heading] may be empty —
  /// the premium copy has a body that continues under the previous heading.
  ///
  /// **The gaps are conditional because the premium screen's are not uniform:**
  /// a heading with a body under it sits 4pt above it, a heading on its own is
  /// followed by 8pt, and a heading-less continuation paragraph gets 12pt.
  /// Preserved rather than normalised so the premium screen renders exactly as
  /// it did before this was extracted.
  Widget _buildDescriptionBlock(CourseDescriptionBlock block) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.heading.isNotEmpty) ...[
          Text(
            block.heading,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          SizedBox(height: block.body.isEmpty ? 8 : 4),
        ],
        if (block.body.isNotEmpty) ...[
          Text(
            block.body,
            style: GoogleFonts.figtree(fontSize: 13, color: _gray, height: 1.5),
          ),
          SizedBox(height: block.heading.isEmpty ? 12 : 8),
        ],
      ],
    );
  }

  Widget _buildSectionInstructors() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructors',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          for (final i in widget.data.instructors) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          i.avatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.name,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              i.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.figtree(
                                fontSize: 11,
                                color: _gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCol(i.rating, 'Rating'),
                      _statCol(i.reviews, 'Reviews'),
                      _statCol(i.students, 'Students'),
                      _statCol(i.courses, 'Courses'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    i.bio,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: _gray,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Center(
                      child: Text(
                        'View profile',
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCol(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: _softGray)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION FEEDBACK
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionFeedback() {
    final data = widget.data;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student feedback',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    data.courseRating,
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _gold,
                    ),
                  ),
                  Text(
                    'course rating',
                    style: GoogleFonts.inter(fontSize: 11, color: _softGray),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final b in data.ratingBars) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: b.percent / 100,
                                    child: Container(height: 6, color: _gold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Row(
                              children: [
                                Text(
                                  b.label,
                                  style: GoogleFonts.figtree(
                                    fontSize: 9,
                                    color: _gray,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${b.percent}%',
                                  style: GoogleFonts.figtree(
                                    fontSize: 9,
                                    color: _softGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final r in data.reviews) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      Text(
                        r.when,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          color: _softGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      r.stars,
                      (_) => const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.star,
                          size: 12,
                          color: Color(0xFFE6B800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.body,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: _gray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM STICKY BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomStickyBar() {
    // A paid course leads with what it costs; a free one has nothing to charge
    // for, so it leads with the duration instead. One rule, both states — the
    // label and the value always describe the same thing.
    final hasPrice = widget.data.price.isNotEmpty;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasPrice ? 'TOTAL PRICE' : 'TOTAL TIME',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _softGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    hasPrice ? widget.data.price : widget.data.totalTime,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => widget.onEnrol(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    widget.data.enrollLabel,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────

/// Everything [CourseDetailView] renders.
///
/// One model serves both entry points: the premium screen builds a single
/// `const` instance, the Courses tab builds one per catalogue entry. That is
/// why the list-card fields ([image], [title], [rating], [level]) sit alongside
/// the detail fields — the same object feeds the card and the screen it opens.
class CourseDetailData {
  const CourseDetailData({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.level,
    required this.category,
    this.classLevel = '',
    required this.ratingsCount,
    required this.studentsEnrolled,
    required this.instructorName,
    required this.instructorAvatar,
    required this.lastUpdated,
    required this.languages,
    required this.subtitleTracks,
    required this.learningOutcomes,
    required this.curriculumSummary,
    required this.modules,
    required this.includes,
    required this.requirements,
    required this.descriptionBlocks,
    required this.descriptionMoreBlocks,
    required this.instructors,
    required this.courseRating,
    required this.ratingBars,
    required this.reviews,
    required this.totalTime,
    this.descriptionIntro = '',
    this.enrollLabel = 'Enroll Now',
    this.bannerVideoAsset,
    this.price = '',
    this.badge = '',
  });

  /// Thumbnail in the catalogue list, and the still banner when
  /// [bannerVideoAsset] is null.
  final String image;

  final String title;
  final String subtitle;

  /// Card/list rating, e.g. `4.7`.
  final String rating;

  /// Card/list level, e.g. `Beginner`. Shown on the Courses tab's grid cards.
  final String level;

  /// Subject area, e.g. `Physics`. Shown on the home rail's chip.
  ///
  /// Deliberately separate from [level] rather than reusing it: they are two
  /// different attributes, and the two card designs label themselves with
  /// different ones. Overloading one field would mean a course's "level" reading
  /// `Physics` on one screen and `Beginner` on another.
  final String category;

  /// The school class this course belongs to, e.g. `Class 6`.
  ///
  /// Drives the class chips on the Courses tab and the home rail, so it has to
  /// match those chip labels exactly. `All` is not a value here — it is the
  /// absence of a filter.
  ///
  /// **Empty for a course that is not part of the class-filtered catalogue** —
  /// a skill course has no class. This is a filter key only: the detail view
  /// never renders it.
  final String classLevel;

  /// The `(14,820 ratings)` style string, parentheses included.
  final String ratingsCount;

  /// The `4,195 students enrolled` string.
  final String studentsEnrolled;

  final String instructorName;
  final String instructorAvatar;

  /// The `Last updated 10/2026` string.
  final String lastUpdated;

  final String languages;
  final String subtitleTracks;

  final List<String> learningOutcomes;
  final String curriculumSummary;
  final List<CourseModule> modules;
  final List<CourseInclude> includes;
  final List<String> requirements;

  /// Shown before "Show more" is tapped.
  final List<CourseDescriptionBlock> descriptionBlocks;

  /// Revealed by "Show more". Empty when there is nothing further to show — the
  /// toggle is still rendered, matching the premium screen.
  final List<CourseDescriptionBlock> descriptionMoreBlocks;

  final List<CourseInstructor> instructors;

  /// The big number in Student feedback, e.g. `4.4`.
  final String courseRating;

  final List<RatingBar> ratingBars;
  final List<CourseReview> reviews;

  /// The `10hrs` string in the bottom bar. Shown only when [price] is empty —
  /// a paid course's bar leads with the price instead.
  final String totalTime;

  /// Rendered above the description blocks, e.g. `Course Updates:`. Omitted
  /// entirely when empty.
  final String descriptionIntro;

  final String enrollLabel;

  /// When set, the banner plays this video. When null the banner is a still
  /// image — the catalogue case.
  final String? bannerVideoAsset;

  /// The card's price, e.g. `Rs. 1,299`.
  ///
  /// **This drives the bottom bar.** Non-empty, the bar reads `TOTAL PRICE` +
  /// this value; empty, it stays `TOTAL TIME` + [totalTime]. One rule with two
  /// states, so a card's price is never dropped on the screen it opens and a
  /// free course is never given a price it does not have.
  final String price;

  /// The card's top-left tag, e.g. `Python`. Card-only — the detail screen does
  /// not render it. Empty for the class catalogue, whose cards label themselves
  /// with [level] instead.
  final String badge;
}

class CourseModule {
  const CourseModule(this.title, this.duration, this.lessons);

  final String title;

  /// e.g. `45 mins`.
  final String duration;

  /// The lectures in this section.
  ///
  /// The `N lessons` label is **derived** from this list's length rather than
  /// authored separately, so the header and the expanded list cannot disagree.
  final List<CourseLesson> lessons;
}

/// One lecture inside a [CourseModule], shown when its section is expanded.
class CourseLesson {
  const CourseLesson(this.title, this.duration, {this.isPreview = false});

  final String title;

  /// e.g. `04:12`.
  final String duration;

  /// Udemy marks a lecture or two per course as free to watch; this renders as
  /// a `Preview` tag on the row.
  final bool isPreview;
}

class CourseInclude {
  const CourseInclude(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// One heading/body pair in the Description section.
///
/// Both halves are optional and either may be empty: the premium copy has a
/// heading-only entry (`v 3.0 - May 2025...`) and a heading-less continuation
/// paragraph. A block with both empty renders nothing.
class CourseDescriptionBlock {
  const CourseDescriptionBlock({this.heading = '', this.body = ''});

  final String heading;
  final String body;
}

class CourseInstructor {
  const CourseInstructor({
    required this.avatar,
    required this.name,
    required this.title,
    required this.rating,
    required this.reviews,
    required this.students,
    required this.courses,
    required this.bio,
  });

  final String avatar;
  final String name;
  final String title;
  final String rating;
  final String reviews;
  final String students;
  final String courses;
  final String bio;
}

class RatingBar {
  const RatingBar(this.label, this.percent);

  /// e.g. `5 ★`.
  final String label;

  /// 0–100.
  final int percent;
}

class CourseReview {
  const CourseReview({
    required this.name,
    required this.when,
    required this.body,
    this.stars = 5,
  });

  final String name;

  /// e.g. `11 days ago`.
  final String when;

  final String body;
  final int stars;
}
