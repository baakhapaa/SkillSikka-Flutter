import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'course_image.dart';

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
    this.isEnrolled = false,
    this.onContinue,
    this.onWriteReview,
    this.hasReviewed = false,
    this.ctaLabel,
  });

  final CourseDetailData data;

  /// Runs the enrolment flow. Owned by the caller because the gate needs a
  /// `ProviderContainer`, which this widget must not reach for.
  final Future<void> Function() onEnrol;

  /// Whether the user is already enrolled in [data].
  ///
  /// Defaults to false, so every caller that does not know about enrolment keeps
  /// exactly the behaviour it had: the bar reads `Enroll Now`.
  final bool isEnrolled;

  /// Opens the player for a course already enrolled in.
  ///
  /// Null falls back to [onEnrol] — a caller that does not distinguish the two
  /// states still does something sensible when the button is tapped, rather than
  /// rendering a button that does nothing.
  final VoidCallback? onContinue;

  /// Opens the "rate this course" sheet.
  ///
  /// **Null hides the control entirely**, which is the right answer for the
  /// premium screen and for a course in the hardcoded catalogue: there is no
  /// endpoint behind those, so a button would be a promise the app cannot keep.
  /// The two API-backed pages pass it once the student is enrolled, which is the
  /// server's own rule (`POST /courses/{id}/reviews/` answers 403 `NOT_ENROLLED`
  /// otherwise).
  final VoidCallback? onWriteReview;

  /// Whether this student already reviewed [data].
  ///
  /// Only changes the button's label — `Write a review` becomes
  /// `Edit your review`. The sheet itself decides between POST and PATCH.
  final bool hasReviewed;

  /// Overrides the bottom bar's call to action when the caller knows more than
  /// the course does.
  ///
  /// `Enroll Now` is the right label for a free course and for a caller that
  /// does not know the enrolment status. A paid course needs two more: `Buy
  /// Rs. 1,299` before the enrolment exists, and `Continue payment` once the row
  /// is `pending_payment` — a button that still says `Enroll Now` on a course the
  /// student has already started buying is how the first tap gets repeated.
  ///
  /// Null falls back to [CourseDetailData.enrollLabel], so every existing caller
  /// renders exactly what it did.
  final String? ctaLabel;

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
                        // A heading over an empty block reads as a rendering
                        // bug, so a section with nothing in it is not drawn at
                        // all. Both lists are genuinely empty on some courses:
                        // the API has no includes column, and a course created
                        // in the builder may have no requirements.
                        if (widget.data.includes.isNotEmpty) ...[
                          _buildSectionIncludes(),
                          const SizedBox(height: 24),
                        ],
                        if (widget.data.requirements.isNotEmpty) ...[
                          _buildSectionRequirements(),
                          const SizedBox(height: 24),
                        ],
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
        // The banner is an asset path for the catalogue and an http URL for an
        // API course — see [CourseImage].
        child: CourseImage(
          data.image,
          title: data.title,
          coverSeed: data.id ?? 0,
          fallback: Container(color: Colors.grey.shade300),
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
              // An unreviewed course has `average_rating: null`, which the
              // adapter maps to `''`. A gold star followed by nothing (and a
              // `(0 ratings)` count) reads as a broken row, so the whole rating
              // pair is replaced rather than left half-drawn.
              if (data.rating.isNotEmpty) ...[
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
              ] else ...[
                const Icon(
                  Icons.star_border_rounded,
                  color: Color(0xFFFBBF24),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'No ratings yet',
                  style: GoogleFonts.figtree(fontSize: 12, color: _gray),
                ),
              ],
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
                child: CourseImage(
                  data.instructorAvatar,
                  width: 40,
                  height: 40,
                  fallback: Container(
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
          // Last updated · level · languages — only the rows that have text are
          // built. See [courseMetaRows].
          ..._buildMetaRows(data),
        ],
      ),
    );
  }

  /// The small meta rows under the instructor, minus the empty ones.
  ///
  /// A row is `icon + text`, so a row with no text is an icon floating beside
  /// nothing — which reads as a rendering fault, not as "this course has none".
  /// Level, language and last-updated all come from the course record. The
  /// filter stays regardless — it is what keeps a future empty field from
  /// drawing a bare glyph.
  List<Widget> _buildMetaRows(CourseDetailData data) {
    final rows = courseMetaRows(data);
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        Row(
          children: [
            SvgPicture.asset(
              rows[i].icon,
              width: 14,
              height: 14,
              semanticsLabel: rows[i].semanticsLabel,
              colorFilter: ColorFilter.mode(rows[i].tint, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Text(
              rows[i].text,
              style: GoogleFonts.figtree(fontSize: 11, color: _gray),
            ),
          ],
        ),
      ],
    ];
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
          if (data.descriptionMoreBlocks.isNotEmpty)
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
                        child: CourseImage(
                          i.avatar,
                          width: 48,
                          height: 48,
                          fallback: Container(
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
            // The design's values are bare numbers (`27,640`, `10`), but the
            // column is a quarter of the card — one long value must ellipsize
            // rather than wrap into a second line and push the label down.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 9, color: _softGray),
          ),
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
          // **An unreviewed course used to render this section as a big empty
          // gap with a lone `course rating` label under it** — the summary row
          // drew a blank string and the bar list was empty, so there was nothing
          // to say and nothing to say it with. A course with no reviews is a
          // normal state, not a hole in the layout.
          if (data.reviews.isEmpty)
            _buildFeedbackEmptyState()
          else ...[
            _buildRatingSummary(data),
            const SizedBox(height: 16),
            for (final r in data.reviews) _buildReviewRow(r),
          ],
          if (widget.onWriteReview != null && data.reviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildReviewButton(),
          ],
        ],
      ),
    );
  }

  /// The `4.4` + five bars block. Only rendered when there is at least one
  /// review — see [_buildSectionFeedback].
  Widget _buildRatingSummary(CourseDetailData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              // Reviews exist but the average did not come back: a dash is
              // honest, `0.0` would claim the course is rated badly.
              data.courseRating.isEmpty ? '—' : data.courseRating,
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
    );
  }

  Widget _buildReviewRow(CourseReview r) {
    return Container(
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
                style: GoogleFonts.figtree(fontSize: 11, color: _softGray),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              r.stars,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(Icons.star, size: 12, color: Color(0xFFE6B800)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r.body,
            style: GoogleFonts.figtree(fontSize: 13, color: _gray, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// What a course with no reviews shows instead of an empty rating block.
  ///
  /// The button only appears when the caller can actually save a review; the
  /// premium screen and the hardcoded catalogue pass no [onWriteReview], and
  /// there the copy states the fact without offering a dead control.
  Widget _buildFeedbackEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4CC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_border_rounded,
              size: 24,
              color: _gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No reviews yet',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.onWriteReview == null
                ? 'This course has not been reviewed yet.'
                : 'Be the first to share what you think of this course.',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(fontSize: 12, color: _gray, height: 1.5),
          ),
          if (widget.onWriteReview != null) ...[
            const SizedBox(height: 16),
            _buildReviewButton(),
          ],
        ],
      ),
    );
  }

  /// `Write a review` / `Edit your review`.
  ///
  /// Outlined rather than gold: the sticky bar already carries the screen's one
  /// primary button, and two gold pills on the same page compete. This matches
  /// the instructor card's `View profile` treatment.
  Widget _buildReviewButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onWriteReview,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border_rounded, size: 15, color: _ink),
            const SizedBox(width: 6),
            Text(
              widget.hasReviewed ? 'Edit your review' : 'Write a review',
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
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
                onTap: () {
                  // Enrolled: the button reopens the course instead of trying to
                  // sell it again, and skips the profile gate — the user is
                  // already past it.
                  if (widget.isEnrolled) {
                    (widget.onContinue ?? widget.onEnrol)();
                    return;
                  }
                  widget.onEnrol();
                },
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
                    widget.isEnrolled
                        ? 'Continue Learning'
                        : widget.ctaLabel ?? widget.data.enrollLabel,
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

/// One `icon + text` line in the course header's meta block.
class CourseMetaRow {
  const CourseMetaRow({
    required this.icon,
    required this.text,
    required this.tint,
    this.semanticsLabel,
  });

  final String icon;
  final String text;
  final Color tint;
  final String? semanticsLabel;
}

/// The meta rows [CourseDetailData] can actually fill, in design order.
///
/// **Empty fields produce no row.** A row is `icon + text`, so a row with no text
/// is an icon floating beside nothing — which reads as a rendering fault, not as
/// "this course has none". Level, language and last-updated all come from the
/// course record.
///
/// **There is no subtitle/CC row.** It was removed on 2026-10-30: no backend
/// field ever fed it, so the only thing it ever printed was the catalogue's
/// hardcoded `CC English [Auto]` — a claim about a course we cannot check, and
/// a row that vanished the moment the same course came from the API. A row that
/// exists for demo data and not for real data is a lie either way.
///
/// Kept as a pure function rather than inline in the widget so it can be tested
/// without pumping a screen.
List<CourseMetaRow> courseMetaRows(CourseDetailData data) {
  const amber = Color(0xFFFBBF24);

  return [
    CourseMetaRow(
      icon: 'assets/figma/stlearning/alert-circle.svg',
      text: data.lastUpdated,
      tint: amber,
    ),
    // Level leads the attribute rows: it is the one thing a student scans for
    // before deciding whether a course is for them.
    CourseMetaRow(
      icon: 'assets/figma/stlearning/award.svg',
      text: data.level,
      tint: amber,
      semanticsLabel: 'Course level',
    ),
    CourseMetaRow(
      icon: 'assets/figma/stlearning/language.svg',
      text: data.languages,
      tint: amber,
      semanticsLabel: 'Available languages',
    ),
  ].where((row) => row.text.trim().isNotEmpty).toList(growable: false);
}

/// Everything [CourseDetailView] renders.
///
/// One model serves both entry points: the premium screen builds a single
/// `const` instance, the Courses tab builds one per catalogue entry. That is
/// why the list-card fields ([image], [title], [rating], [level]) sit alongside
/// the detail fields — the same object feeds the card and the screen it opens.
class CourseDetailData {
  const CourseDetailData({
    this.id,
    this.courseType = '',
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
    this.isPaid = false,
    this.badge = '',
    this.resources = const <CourseResource>[],
    this.discussions = const <CourseDiscussion>[],
  });

  /// The server's `Course.id`, or null for an entry in the hardcoded catalogue.
  ///
  /// **This exists so enrolment can stop keying on [title].** The in-memory
  /// store compares titles because there was no API to compare ids with; that
  /// breaks the moment two courses share a title, and it breaks outright once
  /// `/courses/{id}/enroll/` is the thing that records the enrolment. Nullable
  /// and defaulted so the 34 catalogue construction sites keep compiling.
  final int? id;

  /// `academic` or `skill` from the wire; `''` for a bundled catalogue entry.
  ///
  /// **This decides whether the CTA enrols.** The server answers
  /// `400 COURSE_NOT_ENROLLABLE` to `POST /courses/{id}/enroll/` for any course
  /// that is not a skill course — a school course is opened by grade, with no
  /// enrolment row anywhere — so offering `Enroll Now` on one of them is a
  /// button whose only outcome is an error toast.
  final String courseType;

  /// A school course: opened by grade, never enrolled in.
  bool get isAcademic => courseType == 'academic';

  /// Thumbnail in the catalogue list, and the still banner when
  /// [bannerVideoAsset] is null.
  ///
  /// **An asset path today, an http URL once the API feeds it.** Anything that
  /// renders it has to branch — see the plan at
  /// `.workbuddy-ai/docs/course-backend-integration-plan-2026-10-27.md`.
  final String image;

  final String title;

  /// The lede directly under [title] — the design's one-paragraph course
  /// description, not the `Description` section's changelog.
  ///
  /// **Keep the two apart.** Every catalogue entry, the premium screen and
  /// `CourseMapper` put the course's own words here and `Course Updates:` in
  /// the Description section; swapping them makes the page read as a marketing
  /// blurb filed under a changelog heading.
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

  final List<String> learningOutcomes;
  final String curriculumSummary;
  final List<CourseModule> modules;
  final List<CourseInclude> includes;
  final List<String> requirements;

  /// Shown before "Show more" is tapped.
  final List<CourseDescriptionBlock> descriptionBlocks;

  /// Revealed by "Show more". Empty means there is nothing further to show, and
  /// the toggle is **not rendered** — a link that opens onto nothing is worse
  /// than no link. The premium screen and the catalogue always fill it.
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

  /// `is_paid` from the wire. False for every bundled catalogue entry.
  ///
  /// **This is not the same question as `price.isNotEmpty`.** A paid course whose
  /// price the API did not send has an empty [price] and is still paid, and
  /// enrolment has to treat it that way: a paid course only opens on an `active`
  /// or `completed` enrolment, and inferring "free" from a missing string is
  /// exactly how a student would get in without paying.
  final bool isPaid;

  /// What a card prints in its price slot: the price, or `Free`.
  ///
  /// **Reverses the 2026-10-30 "no card prints Free" rule** (product decision,
  /// 2026-10-31). A free course's slot used to be blank, which reads as a card
  /// that failed to load its price rather than as a course that costs nothing.
  ///
  /// `isPaid` decides, not `price.isEmpty`: a paid course whose price the API
  /// did not send says nothing rather than claiming to be free. Cards use this;
  /// the bottom bar keeps its own two-state rule on [price] (price vs. total
  /// time), which is why [price] itself is left untouched.
  String get priceLabel {
    if (price.isNotEmpty) return price;
    return isPaid ? '' : 'Free';
  }

  /// The card's top-left tag, e.g. `Python`. Card-only — the detail screen does
  /// not render it. Empty for the class catalogue, whose cards label themselves
  /// with [level] instead.
  final String badge;

  /// The downloadable pack on the player's **Resources** tab. Empty renders the
  /// tab's empty state.
  final List<CourseResource> resources;

  /// The thread on the player's **Q&A** tab. Empty renders the empty state.
  final List<CourseDiscussion> discussions;
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

/// What a lecture actually *is*, so the player knows how to render it.
///
/// Mirrors `Lesson.content_type` on the wire (`video | pdf | ebook | text`) and
/// deliberately lives here rather than reusing the builder's `LessonKind`: that
/// one carries a `wire` value and a `usesBody` flag for writing lessons, and
/// `core/` must not depend on `features/`.
enum CourseLessonKind {
  video,
  pdf,
  ebook,
  text;

  /// Anything unrecognised is treated as a video, which is the common case and
  /// the one whose fallback (the still poster) is harmless.
  static CourseLessonKind fromWire(Object? value) {
    final text = value is String ? value.trim().toLowerCase() : '';
    for (final kind in CourseLessonKind.values) {
      if (kind.name == text) return kind;
    }
    return CourseLessonKind.video;
  }

  /// A document that lives at a URL and needs a viewer, not a player.
  bool get isDocument => this == pdf || this == ebook;

  /// Prose that renders inline, so it has no URL at all.
  bool get isInlineText => this == text;
}

/// One lecture inside a [CourseModule], shown when its section is expanded.
class CourseLesson {
  const CourseLesson(
    this.title,
    this.duration, {
    this.id,
    this.isPreview = false,
    this.videoAsset,
    this.kind = CourseLessonKind.video,
    this.contentUrl,
    this.contentText,
  });

  /// `Lesson.id`, or null for a catalogue entry.
  ///
  /// **This is the handle progress is keyed on.** The in-memory store used to
  /// track completions by position, which shifts every time a lesson is
  /// inserted; a server lesson has a stable id and `POST /lessons/{id}/complete/`
  /// needs one. Catalogue lessons have none, so the player falls back to a
  /// negative position key — see `lessonProgressKey` in `enrollment.dart`.
  final int? id;

  final String title;

  /// e.g. `04:12`.
  final String duration;

  /// Udemy marks a lecture or two per course as free to watch; this renders as
  /// a `Preview` tag on the detail screen's curriculum and as a green play icon
  /// on the player's lesson row.
  final bool isPreview;

  /// A **bundled** video. Catalogue-only.
  ///
  /// **Null on every entry in the catalogue, and that is the honest state** —
  /// no lesson video assets exist in this repo. The player falls back to the
  /// course's still image, the same way the detail screen's banner does, and a
  /// null here is also what keeps `video_player` (no platform implementation
  /// under `flutter test`) off every test path.
  final String? videoAsset;

  /// What this lecture is. Defaults to [CourseLessonKind.video] so the
  /// catalogue's 34 entries keep their meaning without being touched.
  final CourseLessonKind kind;

  /// A **remote** video, PDF or ebook URL, from `Lesson.content_url`.
  ///
  /// **Null means gated, for a course that came from the API.** The server
  /// withholds `content_url` from a student who is not enrolled in the course
  /// (the paywall), so on an API course a null here is a lock rather than an
  /// empty lesson. A catalogue course has no id and never sets this, which is
  /// why the player distinguishes the two by `CourseDetailData.id`.
  final String? contentUrl;

  /// The body of a [CourseLessonKind.text] lecture.
  final String? contentText;
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

/// One downloadable file on the player's **Resources** tab.
///
/// **Per-lesson since 2026-10-29.** A resource row now carries an optional
/// `lesson` (`CourseResource.lesson` on the server), so the builder attaches
/// files while it is editing a lesson and the player shows the current lesson's
/// pack. The design's header already names the episode, which is what this
/// finally matches. A null [lessonId] is a course-wide row — every bootcamp pack
/// that predates the change.
///
/// [url] is what makes the row openable. The old model carried a title and a
/// kind and nothing else, so the download button was decoration; the demo
/// catalogue's entries still have no URL and still render as decoration.
class CourseResource {
  const CourseResource(
    this.title,
    this.type, {
    this.id,
    this.url,
    this.lessonId,
    this.sizeBytes,
    this.section = '',
  });

  final String title;
  final CourseResourceType type;

  /// The server's row id, or null for a demo-catalogue entry.
  final int? id;

  /// The file itself. Null on catalogue rows.
  final String? url;

  /// The lesson this file belongs to, or null for a course-wide row.
  final int? lessonId;

  final int? sizeBytes;

  /// The `CourseResource.section` heading, e.g. `Section 1: Course Materials`.
  ///
  /// Empty for a course-wide file with no heading — the bootcamp player groups
  /// the Resources tab by this, and an empty value becomes one unnamed group.
  final String section;

  bool get isOpenable => url != null && url!.trim().isNotEmpty;

  /// The second line under the title: `PDF · 2.4 MB`, or just `PDF`.
  String get subtitle {
    final size = _sizeLabel(sizeBytes);
    return size == null ? type.label : '${type.label} · $size';
  }

  static String? _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final rounded = value >= 10 || unit == 0
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }
}

/// The file kind behind a [CourseResource] — which is all a row needs, because
/// the kind is what the row prints and the colour it prints it in.
enum CourseResourceType {
  pdf('PDF', Color(0xFFD93025), Icons.picture_as_pdf_outlined),
  doc('DOC', Color(0xFF1A73E8), Icons.description_outlined),
  xls('XLS', Color(0xFF1E8E3E), Icons.grid_on_outlined),

  /// Figma is its own format on the server (`figma`), and a design file is not
  /// an image — the bootcamp's Resources tab has a Figma glyph for it, and
  /// labelling it `IMG` made a design file look like a broken screenshot.
  figma('FIGMA', Color(0xFF6B21A8), Icons.design_services_outlined),
  zip('ZIP', Color(0xFFB06000), Icons.folder_zip_outlined),
  image('IMG', Color(0xFF7B1FA2), Icons.image_outlined),
  link('LINK', Color(0xFF00695C), Icons.link),
  other('FILE', Color(0xFF5F6368), Icons.insert_drive_file_outlined);

  const CourseResourceType(this.label, this.color, this.icon);

  /// The small caps label under the file's title, e.g. `PDF`.
  final String label;
  final Color color;
  final IconData icon;

  /// Maps the server's `file_format` vocabulary
  /// (`pdf, doc, docx, xls, xlsx, figma, svg, zip, link, other`) onto a row
  /// style. Unknown values fall back to [other] rather than throwing: the
  /// server owns that list and may add to it.
  static CourseResourceType fromFormat(Object? format) {
    final value = format is String ? format.trim().toLowerCase() : '';
    return switch (value) {
      'pdf' => CourseResourceType.pdf,
      'doc' || 'docx' || 'word' => CourseResourceType.doc,
      'xls' || 'xlsx' || 'csv' || 'excel' => CourseResourceType.xls,
      'figma' => CourseResourceType.figma,
      'zip' || 'rar' || '7z' => CourseResourceType.zip,
      'svg' || 'png' || 'jpg' || 'jpeg' => CourseResourceType.image,
      'link' => CourseResourceType.link,
      _ => CourseResourceType.other,
    };
  }
}

/// One message in a course's discussion thread, shown on the player's **Q&A**
/// tab.
///
/// Also course-level, and for the same reason: the design's `Episode 2` pill
/// scopes the thread to the lesson being watched, but the thread itself is the
/// course's.
class CourseDiscussion {
  const CourseDiscussion(
    this.author,
    this.role,
    this.when,
    this.body, {
    this.isStaff = false,
    this.reactions = 0,
    this.id,
    this.isMine = false,
    this.isLiked = false,
  });

  final String author;

  /// The line under the name, e.g. `Student` or `Product Owner`.
  final String role;

  /// e.g. `3h ago`.
  final String when;

  final String body;

  /// Marks the instructor's own replies, which the design badges.
  final bool isStaff;

  /// Reactions the message arrived with.
  ///
  /// For a **server** row this is `likes_count` and the player replaces it with
  /// the server's answer after a tap. For a catalogue row it is a fixed number
  /// and the player adds one locally, because there is nothing to send it to.
  final int reactions;

  /// The server's `discussion.id`, or null for a message that only exists in
  /// the hardcoded catalogue.
  ///
  /// **Null is the demo switch**, exactly as it is on [CourseDetailData.id]: a
  /// card without an id cannot be liked, answered or deleted on the server, so
  /// the player keeps those three local instead of firing a request at nothing.
  final int? id;

  /// The signed-in user wrote this row — the server's `is_mine`.
  final bool isMine;

  /// The signed-in user has liked this row — the server's `is_liked`.
  final bool isLiked;

  /// The letter the avatar circle shows. The design has no photos, so every
  /// avatar is an initial.
  String get initial => author.isEmpty ? '?' : author[0].toUpperCase();
}
