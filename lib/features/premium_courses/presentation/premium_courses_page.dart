import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_course_details_page.dart';

const _pageBackground = Color(0xFFF9FAFB);
const _ink = Color(0xFF201C15);
const _muted = Color(0xFF8D887F);
const _yellow = Color(0xFFFFD233);

class PremiumCoursesPage extends StatefulWidget {
  const PremiumCoursesPage({super.key});

  @override
  State<PremiumCoursesPage> createState() => _PremiumCoursesPageState();
}

class _PremiumCoursesPageState extends State<PremiumCoursesPage> {
  static const categories = [
    'All',
    'Art & Craft',
    'Design',
    'Physics',
    'Business',
    'Technology',
    'Music',
  ];
  int selectedCategory = 0;
  int hoveredCategory = -1;

  static const courses = <_PremiumCourse>[
    _PremiumCourse(
      'premcourse.png',
      'Adobe Illustrator',
      'Illustrator CC: The Complete Problem Solving Guide',
      '4.9',
      '14,230 students',
      'Rs. 1,500',
    ),
    _PremiumCourse(
      'premcourse1.png',
      'Figma UI/UX',
      'UI/UX Pro: Design System Masterclass',
      '4.8',
      '8,912 students',
      'Rs. 2,200',
    ),
    _PremiumCourse(
      'premcourse2.png',
      'Design Theory',
      'Visual Storytelling & Brand Art',
      '4.9',
      '11,400 students',
      'Rs. 1,800',
    ),
    _PremiumCourse(
      'premcourse3.png',
      'Creative Geometry for Architects',
      'Creative Geometry for Architects',
      '4.9',
      '(98)',
      'Rs.19.99',
    ),
    _PremiumCourse(
      'premcourse4.png',
      'Watercolor Painting Essentials',
      'Watercolor Painting Essentials',
      '4.6',
      '(187)',
      'Rs.17.99',
    ),
    _PremiumCourse(
      'premcourse5.png',
      'Introduction to Astrophysics',
      'Introduction to Astrophysics',
      '4.8',
      '(126)',
      'Rs.21.99',
    ),
    _PremiumCourse(
      'premcourse6.png',
      'Modern Business Strategy',
      'Modern Business Strategy',
      '4.7',
      '(84)',
      'Rs.18.99',
    ),
    _PremiumCourse(
      'premcourse7.png',
      'Learn Python Through Projects',
      'Learn Python Through Projects',
      '4.9',
      '(214)',
      'Rs.24.99',
    ),
    _PremiumCourse(
      'premcourse8.png',
      'Music Production Essentials',
      'Music Production Essentials',
      '4.8',
      '(102)',
      'Rs.16.99',
    ),
    _PremiumCourse(
      'premcourse9.png',
      'Creative Writing Masterclass',
      'Creative Writing Masterclass',
      '4.7',
      '(76)',
      'Rs.14.99',
    ),
    _PremiumCourse(
      'premcourse10.png',
      'Digital Marketing Basics',
      'Digital Marketing Basics',
      '4.9',
      '(165)',
      'Rs.19.99',
    ),
    _PremiumCourse(
      'premcourse11.png',
      'Build Your Creative Portfolio',
      'Build Your Creative Portfolio',
      '4.8',
      '(91)',
      'Rs.17.99',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topBar()),
            SliverToBoxAdapter(child: _categoryBar()),
            SliverToBoxAdapter(child: _sectionTitle('Top Courses')),
            SliverToBoxAdapter(child: _topCourses()),
            SliverToBoxAdapter(child: _sectionTitle('Course', top: 24)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.builder(
                itemCount: courses.length - 3,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ListCourseCard(course: courses[index + 3]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          _CircleButton(
            Icons.arrow_back,
            () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Premium Courses',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          _CircleButton(Icons.search, () {}),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedCategory == index;
          final hovered = hoveredCategory == index;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => hoveredCategory = index),
            onExit: (_) => setState(() => hoveredCategory = -1),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: hovered ? 0.98 : 0.86),
                      const Color(
                        0xFFF2F4F7,
                      ).withValues(alpha: selected ? 0.76 : 0.56),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hovered
                          ? const Color(0x2E000000)
                          : const Color(0x22000000),
                      blurRadius: hovered ? 10 : 7,
                      offset: Offset(0, selected ? 1 : 3),
                    ),
                    const BoxShadow(
                      color: Color(0xCCFFFFFF),
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Text(
                  categories[index],
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, {double top = 16}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 14),
      child: Row(
        children: [
          Text(
            '| ',
            style: GoogleFonts.manrope(
              fontSize: 21,
              fontWeight: FontWeight.w300,
              color: const Color(0x1F282828),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topCourses() {
    return SizedBox(
      height: 286,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _CarouselCourseCard(course: courses[index]),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF3F4F6),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 19, color: _ink),
      ),
    ),
  );
}

class _CarouselCourseCard extends StatelessWidget {
  const _CarouselCourseCard({required this.course});
  final _PremiumCourse course;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CourseDetailsPage())),
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
          _CourseImage(course: course, height: 120),
          const SizedBox(height: 12),
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          _MetaRow(course: course),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                course.price,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF524C00),
                ),
              ),
              _ViewButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CourseDetailsPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ListCourseCard extends StatelessWidget {
  const _ListCourseCard({required this.course});
  final _PremiumCourse course;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CourseDetailsPage())),
    child: Container(
      height: 106,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          _CourseImage(course: course, width: 80, height: 80),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course.category,
                  style: GoogleFonts.figtree(fontSize: 11, color: _muted),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: _yellow),
                    const SizedBox(width: 4),
                    Text(
                      course.rating,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      course.students,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      course.price,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF524C00),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.course});
  final _PremiumCourse course;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.star, size: 12, color: _yellow),
      const SizedBox(width: 4),
      Text(
        course.rating,
        style: GoogleFonts.figtree(fontSize: 11, color: _ink),
      ),
      const Spacer(),
      Text(
        course.students,
        style: GoogleFonts.figtree(fontSize: 10, color: _muted),
      ),
    ],
  );
}

class _CourseImage extends StatelessWidget {
  const _CourseImage({
    required this.course,
    required this.height,
    this.width = double.infinity,
  });
  final _PremiumCourse course;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset(
      'assets/figma/premiumcourse/${course.asset}',
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Icon(Icons.image_outlined, color: _muted),
      ),
    ),
  );
}

class _ViewButton extends StatefulWidget {
  const _ViewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ViewButton> createState() => _ViewButtonState();
}

class _ViewButtonState extends State<_ViewButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
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
              const Color(0xFFF2F4F7).withValues(alpha: _pressed ? 0.78 : 0.58),
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
            color: _ink,
          ),
        ),
      ),
    ),
  );
}

class _PremiumCourse {
  const _PremiumCourse(
    this.asset,
    this.category,
    this.title,
    this.rating,
    this.students,
    this.price,
  );
  final String asset;
  final String category;
  final String title;
  final String rating;
  final String students;
  final String price;
}
