import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _softGray = Color(0xFF737D8C);

class IctBootcampPage extends StatefulWidget {
  const IctBootcampPage({super.key});

  @override
  State<IctBootcampPage> createState() => _IctBootcampPageState();
}

class _IctBootcampPageState extends State<IctBootcampPage> {
  int _selectedDay = 0;
  int _selectedTab = 0;
  bool _autoPlay = true;
  bool _autoNext = true;
  bool _descriptionExpanded = false;
  bool _showAllDiscussions = false;
  late final VideoPlayerController _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/figma/bootcamp/video.mp4',
    )..initialize().then((_) {
        if (mounted) setState(() => _videoReady = true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  static const _days = ['Day 1', 'Day 2', 'Day 3', 'Day 4'];

  static const _sections = <_LessonSection>[
    _LessonSection(
      title: 'Section 1: Research & Strategy Foundations',
      lessons: [
        _Lesson(number: 1, title: 'Demo', duration: '22:10'),
        _Lesson(
            number: 2,
            title: 'Defining the Product Strategy Grid',
            duration: '18:45',
            isActive: true),
        _Lesson(
            number: 3,
            title: 'Introduction to Design Thinking',
            duration: '18:45'),
        _Lesson(
            number: 4,
            title: 'Conducting Stakeholder Interviews',
            duration: '24:30'),
        _Lesson(
            number: 5,
            title: 'Competitive Analysis & Benchmarking',
            duration: '19:15'),
        _Lesson(
            number: 6,
            title: 'Creating Effective User Surveys',
            duration: '16:50'),
        _Lesson(
            number: 7,
            title: 'Journey Mapping Fundamentals',
            duration: '27:20'),
      ],
    ),
    _LessonSection(
      title: 'Section 2: Design & Prototyping',
      lessons: [
        _Lesson(
            number: 8,
            title: 'Information Architecture Basics',
            duration: '21:05'),
        _Lesson(
            number: 9,
            title: 'Wireframing for Mobile Interfaces',
            duration: '32:40'),
        _Lesson(
            number: 10,
            title: 'Prototyping with Interactive States',
            duration: '28:15'),
        _Lesson(
            number: 11,
            title: 'Usability Testing Methods',
            duration: '25:30'),
        _Lesson(
            number: 12,
            title: 'Accessibility & Inclusive Design',
            duration: '20:10'),
        _Lesson(
            number: 13,
            title: 'Visual Hierarchy & Typography',
            duration: '23:55'),
        _Lesson(
            number: 14,
            title: 'Color Theory for Digital Products',
            duration: '17:20'),
      ],
    ),
    _LessonSection(
      title: 'Section 3: Systems, Polish & Handoff',
      lessons: [
        _Lesson(
            number: 15,
            title: 'Design Systems & Component Libraries',
            duration: '34:10'),
        _Lesson(
            number: 16,
            title: 'Responsive Layout Patterns',
            duration: '22:45'),
        _Lesson(
            number: 17,
            title: 'Micro-interactions & Motion Design',
            duration: '26:30'),
        _Lesson(
            number: 18,
            title: 'Heuristic Evaluation Techniques',
            duration: '19:50'),
        _Lesson(
            number: 19,
            title: 'Presenting Designs to Stakeholders',
            duration: '15:25'),
        _Lesson(
            number: 20,
            title: 'Iterating Based on User Feedback',
            duration: '21:40'),
      ],
    ),
  ];

  static const _resourceSections = <_ResourceSection>[
    _ResourceSection(
      title: 'Section 1: Course Materials',
      resources: [
        _Resource(
            title: 'Product Strategy Grid Template',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
        _Resource(
            title: 'Design Thinking Workbook',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
        _Resource(
            title: 'Stakeholder Interview Guide',
            format: 'DOC',
            formatStyle: _ResourceFormat.doc),
        _Resource(
            title: 'Competitive Analysis Framework',
            format: 'XLS',
            formatStyle: _ResourceFormat.xls),
        _Resource(
            title: 'User Survey Templates',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
      ],
    ),
    _ResourceSection(
      title: 'Section 2: Design Tools & Assets',
      resources: [
        _Resource(
            title: 'Wireframing Kit',
            format: 'Figma',
            formatStyle: _ResourceFormat.figma),
        _Resource(
            title: 'Component Library',
            format: 'Figma',
            formatStyle: _ResourceFormat.figma),
        _Resource(
            title: 'Icon Pack',
            format: 'SVG',
            formatStyle: _ResourceFormat.svg),
        _Resource(
            title: 'Stock Photo Collection',
            format: 'ZIP',
            formatStyle: _ResourceFormat.zip),
        _Resource(
            title: 'Color Palette Guide',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
      ],
    ),
    _ResourceSection(
      title: 'Section 3: Additional Reading',
      resources: [
        _Resource(
            title: 'UX Research Best Practices',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
        _Resource(
            title: 'Mobile Design Guidelines',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
        _Resource(
            title: 'Accessibility Checklist',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
        _Resource(
            title: 'Design System Documentation',
            format: 'PDF',
            formatStyle: _ResourceFormat.pdf),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(),
                  _buildVideoProgress(),
                  _buildPlayerControls(),
                  _buildCourseInfoSection(),
                  _buildCourseNavigationTabs(),
                  if (_selectedTab == 0) ...[
                    const SizedBox(height: 8),
                    _buildLessonsModuleContainer(),
                  ],
                  if (_selectedTab == 1) ...[
                    const SizedBox(height: 8),
                    _buildResourcesTab(),
                  ],
                  if (_selectedTab == 2) ...[
                    const SizedBox(height: 8),
                    _buildQaTab(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      height: 222,
      color: const Color(0xFF1F1F1F),
      child: Stack(
        children: [
          Positioned.fill(
            child: _videoReady
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Image.asset(
                    'assets/figma/bootcamp/course-poster.png',
                    fit: BoxFit.contain,
                  ),
          ),
          if (_videoReady)
            Center(
              child: GestureDetector(
                onTap: () {
                  if (!_videoReady) return;
                  setState(() {
                    _videoController.value.isPlaying
                        ? _videoController.pause()
                        : _videoController.play();
                  });
                },
                child: _videoController.value.isPlaying
                    ? const Icon(Icons.pause, size: 52, color: Colors.white)
                    : Image.asset(
                        'assets/figma/bootcamp/play.png',
                        width: 52,
                        height: 52,
                      ),
              ),
            ),
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoProgress() {
    return SizedBox(
      height: 6,
      child: _videoReady
          ? VideoProgressIndicator(
              _videoController,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: _yellow,
                bufferedColor: Color(0xFFD1D1D1),
                backgroundColor: Color(0xFFE5E7EB),
              ),
            )
          : const ColoredBox(color: Color(0xFFD1D1D1)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PLAYER CONTROLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildPlayerControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildToggle(
            label: 'Auto Play',
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v),
          ),
          const SizedBox(width: 16),
          _buildToggle(
            label: 'Auto Next',
            value: _autoNext,
            onChanged: (v) => setState(() => _autoNext = v),
          ),
          const Spacer(),
          _buildPlayerButton(label: 'Prev'),
          const SizedBox(width: 16),
          _buildPlayerButton(label: 'Next'),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            value
                ? 'assets/figma/bootcamp/greentick.png'
                : 'assets/figma/bootcamp/greytick.png',
            width: 13,
            height: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerButton({required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          label == 'Prev'
              ? 'assets/figma/bootcamp/prev.png'
              : 'assets/figma/bootcamp/next.png',
          width: 14,
          height: 14,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _gray,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSE INFO
  // ─────────────────────────────────────────────────────────────
  Widget _buildCourseInfoSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/figma/bootcamp/course-poster.png',
                  width: 130,
                  height: 178,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 130,
                    height: 178,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.25,
                        ),
                        children: const [
                          TextSpan(text: '4 days\n'),
                          TextSpan(
                            text: 'ICT & AI BOOTCAMP at Sundarbazar.',
                            style: TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '12.4k students',
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildMetaTag('HD', highlighted: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _descriptionExpanded
                ? 'Master the foundations of design strategy, brand framework '
                    'design, and digital delivery systems. Learn to align '
                    'creative output directly to tangible business indicators.'
                : 'Master the foundations of design strategy, brand framework '
                    'design, and digital delivery systems.',
            style: GoogleFonts.figtree(
              fontSize: 13,
              height: 1.5,
              color: _gray,
            ),
          ),
          if (_descriptionExpanded) ...[
            const SizedBox(height: 12),
            _buildMetaRow(
              'Instructor:',
              'Shuvanga Karki, Amrit Bhandari, Shahil Paudel, Sudip Gurung, '
                  'Sushant Sapkota, Shreesum Manandhar, Nadish Manandhar, Anjesh Pathak',
            ),
            const SizedBox(height: 6),
            _buildMetaRow('Released:', 'Oct 2026'),
            const SizedBox(height: 6),
            _buildMetaRow(
              'Status:',
              'Completed',
              valueColor: const Color(0xFF10B981),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _descriptionExpanded = !_descriptionExpanded,
            ),
            child: Text(
              _descriptionExpanded ? '[less]' : '[more]',
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x26F59E0B)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: highlighted ? const Color(0xFFF59E0B) : _ink,
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _softGray,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.figtree(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFFF59E0B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildCourseNavigationTabs() {
    const tabs = ['Lessons', 'Resources', 'Q&A'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            _selectedTab == i ? _yellow : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedTab == i ? _ink : _gray,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LESSONS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildLessonsModuleContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _selectedDay;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _yellow : const Color(0xFFEAEAEA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _days[index],
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          for (final section in _sections) ...[
            _buildChapterHeader(
                section.title, section.lessons.length, 'lessons'),
            for (final lesson in section.lessons) _buildLessonRow(lesson),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterHeader(String title, int count, String countLabel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Text(
            '$count $countLabel',
            style: GoogleFonts.figtree(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF737D8C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonRow(_Lesson lesson) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: lesson.isActive ? const Color(0xFFDBDBDB) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (lesson.number == 1)
            Image.asset(
              'assets/figma/bootcamp/greentick.png',
              width: 20,
              height: 20,
            )
          else if (lesson.number >= 3)
            Image.asset(
              'assets/figma/bootcamp/greytick.png',
              width: 20,
              height: 20,
            )
          else
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Text(
                  '${lesson.number}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.duration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667080),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.play_circle_outline,
            size: 20,
            color: _ink,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RESOURCES TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildResourcesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in _resourceSections) ...[
            _buildChapterHeader(
              section.title,
              section.resources.length,
              'files',
            ),
            const SizedBox(height: 10),
            for (final resource in section.resources) ...[
              _buildResourceRow(resource),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildResourceRow(_Resource resource) {
    final colors = _formatColors(resource.formatStyle);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              _formatIcon(resource.formatStyle),
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => Icon(
                _formatFallbackIcon(resource.formatStyle),
                size: 20,
                color: colors.badgeText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    resource.format.toUpperCase(),
                    style: GoogleFonts.figtree(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colors.badgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading ${resource.title}...')),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/figma/bootcamp/download.png',
                width: 16,
                height: 16,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.download_outlined,
                  size: 16,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Q&A TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildQaTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDiscussionHeader(),
          const SizedBox(height: 12),
          _buildInputComposer(),
          const SizedBox(height: 12),
          _buildCommentPost(
            avatarPath: 'assets/figma/instructors/instructor.png',
            username: 'design_lead_mira',
            meta: '3h ago • Staff Strategist',
            message:
                'These frameworks match precisely with the OKR models we deployed '
                'last quarter. Highly recommend mapping Module 2 directly into your roadmap.',
          ),
          const SizedBox(height: 12),
          _buildCommentPost(
            avatarPath: 'assets/figma/instructors/instructor1.png',
            username: 'dev_sam',
            meta: '5h ago • Product Manager',
            message:
                'Great breakdown in Section 1. The Product Strategy Grid template '
                'saved me a full day of prep work last week.',
          ),
          if (_showAllDiscussions) ...[
            const SizedBox(height: 12),
            _buildCommentPost(
              avatarPath: 'assets/figma/instructors/instructor2.png',
              username: 'ux_amy',
              meta: '8h ago • UX Researcher',
              message:
                  'The stakeholder interview guide was surprisingly practical. '
                  'Would love to see a follow-up on synthesis techniques.',
            ),
            const SizedBox(height: 12),
            _buildCommentPost(
              avatarPath: 'assets/figma/instructors/instructor3.png',
              username: 'product_raj',
              meta: '1d ago • Founder',
              message:
                  'Anyone else using Module 3 as a checklist for their Q1 planning? '
                  'It maps almost 1:1 to our quarterly OKRs.',
            ),
            const SizedBox(height: 12),
            _buildCommentPost(
              avatarPath: 'assets/figma/instructors/instructor4.png',
              username: 'frontend_lea',
              meta: '2d ago • Frontend Lead',
              message:
                  'The component library section paid for itself in one sprint. '
                  'Highly recommend the Figma kit if you\'re building a design system.',
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _showAllDiscussions = !_showAllDiscussions,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _showAllDiscussions ? 'View less' : 'View more',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  height: 1.5,
                  color: const Color(0xFF171717),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Discussions header (title + count + Episode pill) ──────
  Widget _buildDiscussionHeader() {
    return Row(
      children: [
        Text(
          'Discussions',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDDDCDB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '148',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _gray,
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: _yellow,
          child: Text(
            'Episode 2',
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
    );
  }

  // ── Input composer ─────────────────────────────────────────
  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Add to the strategy discussion...',
              style: GoogleFonts.figtree(
                fontSize: 12,
                color: _gray,
              ),
            ),
          ),
          const Icon(
            Icons.sentiment_satisfied_alt_outlined,
            size: 14,
            color: _gray,
          ),
        ],
      ),
    );
  }

  // ── Comment post card ──────────────────────────────────────
  Widget _buildCommentPost({
    required String avatarPath,
    required String username,
    required String meta,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  avatarPath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 24,
                    height: 24,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 10,
                          color: Color(0xFF1D9BF0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      meta,
                      style: GoogleFonts.figtree(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.figtree(
              fontSize: 14,
              height: 1.4,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCommentAction(
                icon: Icons.favorite_border,
                label: 'React',
              ),
              const SizedBox(width: 12),
              _buildCommentAction(
                icon: Icons.chat_bubble_outline,
                label: 'Reply',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentAction({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _gray),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _gray,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMAT HELPERS
  // ─────────────────────────────────────────────────────────────
  String _formatIcon(_ResourceFormat format) {
    switch (format) {
      case _ResourceFormat.pdf:
        return 'assets/figma/bootcamp/pdf.png';
      case _ResourceFormat.doc:
        return 'assets/figma/bootcamp/doc.png';
      case _ResourceFormat.xls:
        return 'assets/figma/bootcamp/xls.png';
      case _ResourceFormat.figma:
        return 'assets/figma/bootcamp/figma.png';
      case _ResourceFormat.svg:
        return 'assets/figma/bootcamp/svg.png';
      case _ResourceFormat.zip:
        return 'assets/figma/bootcamp/zip.png';
    }
  }

  IconData _formatFallbackIcon(_ResourceFormat format) {
    switch (format) {
      case _ResourceFormat.pdf:
        return Icons.picture_as_pdf_outlined;
      case _ResourceFormat.doc:
        return Icons.description_outlined;
      case _ResourceFormat.xls:
        return Icons.table_chart_outlined;
      case _ResourceFormat.figma:
        return Icons.design_services_outlined;
      case _ResourceFormat.svg:
        return Icons.image_outlined;
      case _ResourceFormat.zip:
        return Icons.folder_zip_outlined;
    }
  }

  _FormatColors _formatColors(_ResourceFormat format) {
    switch (format) {
      case _ResourceFormat.pdf:
        return const _FormatColors(
          iconBg: Color(0xFFFEE2E2),
          badgeBg: Color(0xFFFEE2E2),
          badgeText: Color(0xFF991B1B),
        );
      case _ResourceFormat.doc:
        return const _FormatColors(
          iconBg: Color(0xFFDBEAFE),
          badgeBg: Color(0xFFDBEAFE),
          badgeText: Color(0xFF1E40AF),
        );
      case _ResourceFormat.xls:
        return const _FormatColors(
          iconBg: Color(0xFFD1FAE5),
          badgeBg: Color(0xFFD1FAE5),
          badgeText: Color(0xFF065F46),
        );
      case _ResourceFormat.figma:
        return const _FormatColors(
          iconBg: Color(0xFFF3E8FF),
          badgeBg: Color(0xFFF3E8FF),
          badgeText: Color(0xFF6B21A8),
        );
      case _ResourceFormat.svg:
        return const _FormatColors(
          iconBg: Color(0xFFFEF3C7),
          badgeBg: Color(0xFFFEF3C7),
          badgeText: Color(0xFF92400E),
        );
      case _ResourceFormat.zip:
        return const _FormatColors(
          iconBg: Color(0xFFF3F4F6),
          badgeBg: Color(0xFFF3F4F6),
          badgeText: Color(0xFF374151),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────
class _Lesson {
  const _Lesson({
    required this.number,
    required this.title,
    required this.duration,
    this.isActive = false,
  });

  final int number;
  final String title;
  final String duration;
  final bool isActive;
}

class _LessonSection {
  const _LessonSection({required this.title, required this.lessons});

  final String title;
  final List<_Lesson> lessons;
}

enum _ResourceFormat { pdf, doc, xls, figma, svg, zip }

class _Resource {
  const _Resource({
    required this.title,
    required this.format,
    required this.formatStyle,
  });

  final String title;
  final String format;
  final _ResourceFormat formatStyle;
}

class _ResourceSection {
  const _ResourceSection({required this.title, required this.resources});

  final String title;
  final List<_Resource> resources;
}

class _FormatColors {
  const _FormatColors({
    required this.iconBg,
    required this.badgeBg,
    required this.badgeText,
  });

  final Color iconBg;
  final Color badgeBg;
  final Color badgeText;
}