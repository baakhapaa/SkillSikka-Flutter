import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MyLearningPage extends StatelessWidget {
  const MyLearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('destination-My Learning'),
      color: const Color(0xFFFAF9F6),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _ContinueLearning(),
              SizedBox(height: 24),
              _LearningStats(),
              SizedBox(height: 28),
              _Certificates(),
              SizedBox(height: 28),
              _CompletedCourses(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Continue Learning'),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEAEAEA)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 7.1,
                child: Image.asset(
                  'assets/figma/learning/course_banner.png',
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Badge('Advanced Web Design'),
                        Text('68% Complete', style: _boldSmall()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Interactive Design Principles & Micro-animations',
                      style: _courseTitle(),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: const LinearProgressIndicator(
                        value: .68,
                        minHeight: 6,
                        backgroundColor: Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFFD233)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lesson 12 of 18  •  12m left',
                          style: _mutedSmall(),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD233),
                            foregroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Resume', style: _boldSmall()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _MiniCourse(
          title: 'Physical Chemistry Foundations',
          progress: .65,
          percent: '65%',
          image: 'assets/figma/learning/chemistry.png',
          accessed: 'Last accessed: 2 hours ago',
        ),
        const SizedBox(height: 10),
        const _MiniCourse(
          title: 'Python for Absolute Beginners',
          progress: .3,
          percent: '30%',
          image: 'assets/figma/learning/python.png',
          accessed: 'Last accessed: 1 day ago',
        ),
      ],
    );
  }
}

class _MiniCourse extends StatelessWidget {
  const _MiniCourse({
    required this.title,
    required this.progress,
    required this.percent,
    required this.image,
    required this.accessed,
  });

  final String title;
  final double progress;
  final String percent;
  final String image;
  final String accessed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(image, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _miniTitle(),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFE6B800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(percent, style: _boldTiny()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(accessed, style: _tiny(color: const Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningStats extends StatelessWidget {
  const _LearningStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(value: '24.5h', label: 'HOURS LEARNED'),
          _Stat(value: '12', label: 'COMPLETED'),
          _Stat(value: '🔥 8 Days', label: 'DAY STREAK'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: _statValue()),
          const SizedBox(height: 4),
          Text(
            label,
            style: _tiny(color: Color(0xFF4B5563), weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Certificates extends StatelessWidget {
  const _Certificates();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(),
        const SizedBox(height: 8),
        Row(
          children: const [
            Expanded(
              child: _Certificate(
                title: 'Basic Geometry',
                image: 'assets/figma/learning/certificate_geometry.png',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _Certificate(
                title: 'React Native Mobile',
                image: 'assets/figma/learning/certificate_react.png',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Certificate extends StatelessWidget {
  const _Certificate({required this.title, required this.image});

  final String title;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              image,
              height: 70,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cardTitle(),
          ),
          const SizedBox(height: 4),
          Text(
            'Verified Certificate',
            style: _tiny(color: const Color(0xFF1E751E)),
          ),
        ],
      ),
    );
  }
}

class _CompletedCourses extends StatelessWidget {
  const _CompletedCourses();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Completed Courses'),
        const SizedBox(height: 12),
        const _CompletedCard(),
        const SizedBox(height: 10),
        const _CompletedCard(),
        const SizedBox(height: 10),
        Center(child: Text('View All', style: _actionText())),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/figma/learning/completed_course.png',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Figma Foundations & Layout Basics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _miniTitle(),
                ),
                Text('Completed May 14, 2026', style: _mutedSmall()),
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/figma/learning/check.svg',
                      width: 12,
                      height: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Certificate Issued',
                      style: _tiny(
                        color: Color(0xFF10B981),
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF111827),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel();
  @override
  Widget build(BuildContext context) => const Text(
    'MY CERTIFICATES',
    style: TextStyle(
      color: Color(0xFF4B5563),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: _tiny(color: const Color(0xFF4B5563), weight: FontWeight.w600),
    ),
  );
}

TextStyle _boldSmall() => const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _courseTitle() => const TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _miniTitle() => const TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _cardTitle() => const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _mutedSmall() =>
    const TextStyle(fontSize: 11, color: Color(0xFF4B5563));
TextStyle _boldTiny() => const TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  color: Color(0xFF4B5563),
);
TextStyle _tiny({
  required Color color,
  FontWeight weight = FontWeight.normal,
}) => TextStyle(fontSize: 9, color: color, fontWeight: weight);
TextStyle _statValue() => const TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: Color(0xFF111827),
);
TextStyle _actionText() => const TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Color(0xFF4B5563),
);
