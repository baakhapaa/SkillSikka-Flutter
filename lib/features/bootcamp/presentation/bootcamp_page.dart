import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF6B7280);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);

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
        _Lesson(number: 1, title: 'Demo', duration: '22:10', isDemo: true),
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
                  _buildPlayerControls(),
                  _buildCourseInfoSection(),
                  _buildCourseNavigationTabs(),
                  if (_selectedTab == 0) ...[
                    const SizedBox(height: 8),
                    _buildLessonsModuleContainer(),
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
  // HERO (dark backdrop, centered poster, white circle back button)
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
          if (!_videoReady || !_videoController.value.isPlaying)
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
                child: Image.asset(
                  'assets/figma/bootcamp/play.png',
                  width: 52,
                  height: 52,
                ),
              ),
            ),
          // White circular back button
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
  // COURSE INFO SECTION (no card border)
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
                  width: 80,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 110,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.25,
                        ),
                        children: const [
                          TextSpan(text: '4 days\n'),
                          TextSpan(
                            text: 'ICT & AI BOOTCAMP at Sundarbazar.',
                            style: TextStyle(fontSize: 18),
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
                    Row(
                      children: [
                        _buildMetaTag('HD', highlighted: true),
                        const SizedBox(width: 4),
                        _buildMetaTag('CC'),
                        const SizedBox(width: 4),
                        _buildMetaTag('ENG'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Master the foundations of design strategy, brand framework '
            'design, and digital delivery systems. Learn to align creative '
            'output directly to tangible business indicators.',
            style: GoogleFonts.figtree(
              fontSize: 13,
              height: 1.5,
              color: _gray,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetaRow(
            'Instructor:',
            'Shuvanga Karki, Amrit Bhandari, Shahil Paudel, Sudip, '
                'Sushant Sapkota, Shreesam, Nadish Manandhar, Anjesh',
          ),
          const SizedBox(height: 6),
          _buildMetaRow('Released:', 'Oct 2026', valueColor: _gray),
          const SizedBox(height: 6),
          _buildMetaRow('Status:', 'Complete',
              valueColor: const Color(0xFF10B981)),
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Text(
              '[less]',
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
  // COURSE NAVIGATION TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCourseNavigationTabs() {
    const tabs = ['Lessons', 'Resources', 'Q&A'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
  // LESSONS MODULE
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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
            _buildChapterHeader(section),
            for (final lesson in section.lessons)
              _buildLessonRow(lesson),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterHeader(_LessonSection section) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD9D9D9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              section.title,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Text(
            '${section.lessons.length} lessons',
            style: GoogleFonts.figtree(
              fontSize: 11,
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
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(shape: BoxShape.circle),
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
                Row(
                  children: [
                    if (lesson.isDemo) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x26F59E0B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Demo',
                          style: GoogleFonts.figtree(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
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
}

class _Lesson {
  const _Lesson({
    required this.number,
    required this.title,
    required this.duration,
    this.isDemo = false,
    this.isActive = false,
  });

  final int number;
  final String title;
  final String duration;
  final bool isDemo;
  final bool isActive;
}

class _LessonSection {
  const _LessonSection({required this.title, required this.lessons});

  final String title;
  final List<_Lesson> lessons;
}
