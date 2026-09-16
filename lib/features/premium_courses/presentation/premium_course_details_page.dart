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

class CourseDetailsPage extends StatefulWidget {
  const CourseDetailsPage({super.key});

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage> {
  late final VideoPlayerController _videoController;
  bool _videoReady = false;
  bool _showFullDescription = false;

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.asset("assets/figma/stlearning/video.mp4")
          ..initialize().then((_) {
            if (mounted) setState(() => _videoReady = true);
          });
  }

  @override
  void dispose() {
    _videoController.dispose();
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
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
                // Play/pause overlay
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _videoController.value.isPlaying
                            ? _videoController.pause()
                            : _videoController.play();
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
                        _videoController.value.isPlaying
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DevSecOps & DevOps with Jenkins, Kubernetes, Terraform & AWS',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.27,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Implement DAST, SCA & DAST in Jenkins DevSecOps Pipelines from scratch and setup infra using Terraform, Kubernetes in AWS',
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
                '4.7',
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(14,820 ratings)',
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
              const SizedBox(width: 8),
              Text('•', style: GoogleFonts.figtree(color: _gray)),
              const SizedBox(width: 8),
              Text(
                '4,195 students enrolled',
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
                  'assets/figma/stlearning/avatar.png',
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
                    'Baakhapaa Digital Pvt Ltd',
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
                'Last updated 10/2026',
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
                'English, Nepali, Hindi',
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
                'CC English [Auto]',
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatYouLearn() {
    const items = [
      'Learn to create AWS Infrastructure to be used by Jenkins',
      'Learn to perform Continuous Integration and Continuous Deployment using Jenkins',
      'Learn DevSecOps Implementation in AWS',
      'Learn DevSecOps Multibranch Pipeline',
    ];

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
          for (final item in items) ...[
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

  Widget _buildCurriculum() {
    const modules = [
      ('Introduction and Course Agenda', '4 lessons', '45 mins'),
      ('Understand the Core concepts of DevSecOps', '6 lessons', '1h 12m'),
      ('Terraform Infrastructure automation in AWS', '8 lessons', '55 mins'),
    ];

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
            '12 sections • 50 lectures • 3h 27m total length',
            style: GoogleFonts.figtree(fontSize: 11, color: _gray),
          ),
          const SizedBox(height: 16),
          for (final m in modules) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 18, color: _gray),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        m.$2,
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(color: Color(0xFF99A6B8)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.$3,
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                    ],
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
  // SECTION INCLUDES
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionIncludes() {
    const items = [
      (Icons.play_circle_outline, '3 hours, 22 minutes on-demand video'),
      (Icons.quiz_outlined, '1 Quiz'),
      (Icons.description_outlined, '3 Support files'),
      (Icons.article_outlined, '5 Articles'),
      (Icons.all_inclusive, 'Full lifetime access'),
      (Icons.devices, 'Access on mobile, desktop and TV'),
      (Icons.verified_outlined, 'Certificate of completion'),
    ];

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
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(item.$1, size: 18, color: _gray),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$2,
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
    const reqs = [
      'Basic computer knowledge',
      'Good to have some AWS Knowledge',
    ];

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
          for (final r in reqs) ...[
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
          Text(
            'Course Updates:',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'v 4.0 - April 2026',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Added AWS Lab in Lecture 11 - Working with AWS CLI',
            style: GoogleFonts.figtree(fontSize: 13, color: _gray, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'v 3.0 - May 2025...',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          if (_showFullDescription) ...[
            Text(
              'Improved guided labs, added CI/CD examples, and expanded the '
              'AWS security modules with practical exercises.',
              style: GoogleFonts.figtree(
                fontSize: 13,
                color: _gray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'v 2.0 - October 2024',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Updated the project material and added beginner-friendly '
              'deployment walkthroughs.',
              style: GoogleFonts.figtree(
                fontSize: 13,
                color: _gray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
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

  Widget _buildSectionInstructors() {
    final instructors = [
      (
        'assets/figma/instructors/instructor.png',
        'Shuvanga Karki',
        'Security Architect',
        '4.5',
        '11,067',
        '68,611',
        '15',
        'A Security Guru is a dedicated mentor and expert in the field of application security, DevSecOps, DevOps, and security architecture.',
      ),
      (
        'assets/figma/instructors/instructor1.png',
        'Amrit Poudel',
        'App Security | DevSecOps | Pen Test | Testing | Automation',
        '4.5',
        '19,326',
        '1,03,287',
        '42',
        'With over 10 years of experience in security, automation, development, Gen AI and cloud architecture.',
      ),
    ];

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
          for (final i in instructors) ...[
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
                          i.$1,
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
                              i.$2,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              i.$3,
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
                      _statCol(i.$4, 'Rating'),
                      _statCol(i.$5, 'Reviews'),
                      _statCol(i.$6, 'Students'),
                      _statCol(i.$7, 'Courses'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    i.$8,
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
    const bars = [
      ('5 ★', 52, 78.0),
      ('4 ★', 37, 56.0),
      ('3 ★', 9, 14.0),
      ('2 ★', 1, 2.0),
      ('1 ★', 1, 2.0),
    ];

    const reviews = [
      ('Ajay Badukale', '11 days ago', 5, 'good'),
      ('Sanchita Majumder Ghosh', '15 days ago', 5, 'awesome learning'),
      ('Flintin VF', '23 days ago', 5, 'good'),
    ];

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
                    '4.4',
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
                    for (final b in bars) ...[
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
                                    widthFactor: b.$2 / 100,
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
                                  b.$1,
                                  style: GoogleFonts.figtree(
                                    fontSize: 9,
                                    color: _gray,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${b.$2}%',
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
          for (final r in reviews) ...[
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
                          r.$1,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      Text(
                        r.$2,
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
                      5,
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
                    r.$4,
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
                    'TOTAL TIME',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _softGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '10hrs',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Enrolled successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _ink,
                    ),
                  );
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
                    'Enroll Now',
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
