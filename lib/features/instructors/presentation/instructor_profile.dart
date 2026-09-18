import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF8D887F);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _chipBg = Color(0xFFF2F1F7);

class InstructorProfilePage extends StatefulWidget {
  const InstructorProfilePage({super.key});

  @override
  State<InstructorProfilePage> createState() => _InstructorProfilePageState();
}

class _InstructorProfilePageState extends State<InstructorProfilePage> {
  static const _premiumCourses = <_CourseCard>[
    _CourseCard(
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'The Art of Problem Solving',
      price: 'Rs.24.99',
    ),
    _CourseCard(
      image: 'assets/figma/instructorprofile/adobe-certified.png',
      title: 'Adobe Certified Foundations',
      price: 'Rs.19.99',
    ),
  ];

  static const _coursesByInstructor = <_CourseCard>[
    _CourseCard(
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'The Art of Problem Solving',
      price: 'Rs.24.99',
    ),
    _CourseCard(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Adobe Certified Foundations',
      price: 'Rs.19.99',
    ),
    _CourseCard(
      image: 'assets/figma/instructorprofile/ds.png',
      title: 'Design Systems Fundamentals',
      price: 'Rs.21.99',
    ),
    _CourseCard(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'Digital Art Masterclass',
      price: 'Rs.27.99',
    ),
  ];

  static const _popularCourses = <_PopularCourse>[
    _PopularCourse(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'Python Data Science',
      rating: '4.8',
      level: 'Beginner',
    ),
    _PopularCourse(
      image: 'assets/figma/instructorprofile/ds.png',
      title: 'Python Data Science',
      rating: '4.8',
      level: 'Beginner',
    ),
  ];

  static const _reviews = <_Review>[
    _Review(
      name: 'Suman Shrestha',
      rating: '5',
      text:
          '"Prof. Shuvanga teaches in an incredibly visual and easy to understand manner."',
    ),
    _Review(
      name: 'Prerna Subedi',
      rating: '4.8',
      text:
          '"The art of problem solving totally changed how my son approaches difficult math."',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildScreenHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeaderCard(),
                    _buildPremiumCourses(),
                    _buildCoursesByInstructor(),
                    _buildPopularCourses(),
                    _buildReviewsSection(),
                    const SizedBox(height: 24),
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
  // SCREEN HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Instructor Profile',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // TODO: share
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.share_outlined,
                size: 18,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROFILE HEADER CARD
  //   Matches the screenshot: avatar + name + title on top,
  //   3-column stats row with dividers, then Biography block —
  //   all inside ONE bordered white card.
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name + title ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/figma/instructorprofile/adobe-certified.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 70,
                      height: 70,
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prof. Shuvanga Karki',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adobe Certified Instructor & Illustrator',
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: _gray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats row ─────────────────────────────────────
            Row(
              children: [
                _buildStat('915.2K', 'Students'),
                _buildStatDivider(),
                _buildStat('40', 'Courses'),
                _buildStatDivider(),
                _buildStat('4.9', 'Rating'),
              ],
            ),
            const SizedBox(height: 20),

            // ── Biography ─────────────────────────────────────
            Text(
              'Biography',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prof. Karki is an expert illustrator and digital arts certified '
              'educator with over 12 years of teaching design theory, UI concepts, '
              'and logical visual structures to over 900k pupils world-wide.',
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.5,
                color: _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 11,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: _border,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PREMIUM COURSES
  // ─────────────────────────────────────────────────────────────
  Widget _buildPremiumCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Courses',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _premiumCourses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildPremiumCard(_premiumCourses[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(_CourseCard course) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Image.asset(
                course.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course.price,
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _yellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSES BY THIS INSTRUCTOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildCoursesByInstructor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Courses by this Instructor',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // TODO: navigate to all courses
                },
                child: Text(
                  'See All (40)',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _coursesByInstructor.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildCoursesByCard(_coursesByInstructor[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesByCard(_CourseCard course) {
    return Container(
      width: 164,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: Image.asset(
                course.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      course.price,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _yellow,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.figtree(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _gray,
                        ),
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

  // ─────────────────────────────────────────────────────────────
  // POPULAR COURSES
  // ─────────────────────────────────────────────────────────────
  Widget _buildPopularCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Courses',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 194,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _popularCourses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildPopularCard(_popularCourses[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCard(_PopularCourse course) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              // Keep the card content within the horizontal list's fixed
              // height, including the title, rating row, and card padding.
              height: 118,
              width: double.infinity,
              child: Image.asset(
                course.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF282828),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Image.asset(
                      'assets/figma/instructorprofile/star.png',
                      width: 11,
                      height: 11,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.star,
                        size: 11,
                        color: Color(0xFFFBBF24),
                      ),
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
                    const Spacer(),
                    Text(
                      course.level,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STUDENT REVIEWS
  // ─────────────────────────────────────────────────────────────
  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Reviews',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          for (final review in _reviews) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.name,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/figma/instructorprofile/star.png',
                        width: 14,
                        height: 14,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.rating,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.text,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────
class _CourseCard {
  const _CourseCard({
    required this.image,
    required this.title,
    required this.price,
  });

  final String image;
  final String title;
  final String price;
}

class _PopularCourse {
  const _PopularCourse({
    required this.image,
    required this.title,
    required this.rating,
    required this.level,
  });

  final String image;
  final String title;
  final String rating;
  final String level;
}

class _Review {
  const _Review({
    required this.name,
    required this.rating,
    required this.text,
  });

  final String name;
  final String rating;
  final String text;
}
