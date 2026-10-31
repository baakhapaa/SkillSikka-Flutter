import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/course_image.dart';
import 'package:skillsikka/core/widgets/pressable_chip.dart';
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_course_details_page.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';

const _pageBackground = Color(0xFFF9FAFB);
const _ink = Color(0xFF201C15);
const _muted = Color(0xFF8D887F);
const _yellow = Color(0xFFFFD233);

class PremiumCoursesPage extends ConsumerStatefulWidget {
  const PremiumCoursesPage({super.key});

  @override
  ConsumerState<PremiumCoursesPage> createState() => _PremiumCoursesPageState();
}

/// The premium catalogue, read from `GET /courses/?course_type=premium`.
///
/// **It used to be twelve hardcoded cards.** A premium course created in the
/// builder existed on the server and appeared nowhere here, because this page
/// never asked for it. The cards are unchanged — same layout, same slots — only
/// where their contents come from.
class _PremiumCoursesPageState extends ConsumerState<PremiumCoursesPage> {
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

  List<CourseDetailData> _courses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(courseApiProvider)
          .list(courseType: 'premium', pageSize: 50);
      if (!mounted) return;
      setState(() {
        _courses = page.courses;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.displayMessage;
      });
    }
  }

  /// What the selected chip shows. `All` is the absence of a filter, which is
  /// why it is index 0 rather than a category called "All" — the chips did
  /// nothing at all before this page had real data.
  List<CourseDetailData> get _visible => selectedCategory == 0
      ? _courses
      : [
          for (final course in _courses)
            if (course.category == categories[selectedCategory]) course,
        ];

  /// The carousel takes the first three and the list takes the rest, which is
  /// how the design splits one shelf into two.
  List<CourseDetailData> get _carousel => _visible.take(3).toList();
  List<CourseDetailData> get _rest => _visible.skip(3).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topBar()),
            SliverToBoxAdapter(child: _categoryBar()),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(fontSize: 13, color: _muted),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_visible.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Text(
                    selectedCategory == 0
                        ? 'No premium courses yet.'
                        : 'No courses in this category yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(fontSize: 13, color: _muted),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _sectionTitle('Top Courses')),
              SliverToBoxAdapter(child: _topCourses(_carousel)),
              if (_rest.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionTitle('Course', top: 24)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.builder(
                    itemCount: _rest.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ListCourseCard(course: _rest[index]),
                    ),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
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
          _CircleButton(
            Icons.search,
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
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
        itemBuilder: (context, index) => Center(
          child: PressableChip(
            label: categories[index],
            selected: selectedCategory == index,
            onTap: () => setState(() => selectedCategory = index),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            textColor: _ink,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {double top = 16}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 14),
      child: Row(
        children: [
          const SectionBar(),
          const SizedBox(width: 7),
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

  Widget _topCourses(List<CourseDetailData> courses) {
    return SizedBox(
      height: 286,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
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
  final CourseDetailData course;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _open(context, course),
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
                course.priceLabel,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF524C00),
                ),
              ),
              PressableChip(
                label: 'View',
                onTap: () => _open(context, course),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                horizontalPadding: 12,
                verticalPadding: 7,
                textColor: _ink,
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
  final CourseDetailData course;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _open(context, course),
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
                      _ratingLabel(course),
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _countLabel(course),
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      course.priceLabel,
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
  final CourseDetailData course;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.star, size: 12, color: _yellow),
      const SizedBox(width: 4),
      Text(
        _ratingLabel(course),
        style: GoogleFonts.figtree(fontSize: 11, color: _ink),
      ),
      const Spacer(),
      Text(
        _studentsLabel(course),
        style: GoogleFonts.figtree(fontSize: 10, color: _muted),
      ),
    ],
  );
}

/// `4.9`, or `New` for a course nobody has rated yet — the slot is a number and
/// printing nothing beside a star reads as a rendering bug.
String _ratingLabel(CourseDetailData course) =>
    course.rating.isEmpty ? 'New' : course.rating;

/// `(214)` — the design's shape. `ratingsCount` is `(214 ratings)`, which is a
/// sentence in a slot built for a token.
String _countLabel(CourseDetailData course) =>
    course.ratingsCount.replaceAll(' ratings', '').replaceAll(' rating', '');

/// `4,195 students` — `studentsEnrolled` is `4,195 students enrolled`, and the
/// card's line already says what the number is.
String _studentsLabel(CourseDetailData course) =>
    course.studentsEnrolled.replaceAll(' enrolled', '');

/// Opens the tapped course, not the demo screen.
///
/// The id is what the detail page fetches; a card without one (there are none
/// from the API) falls back to the bundled demo.
void _open(BuildContext context, CourseDetailData course) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PremiumCourseDetailsPage(courseId: course.id),
    ),
  );
}

class _CourseImage extends StatelessWidget {
  const _CourseImage({
    required this.course,
    required this.height,
    this.width = double.infinity,
  });
  final CourseDetailData course;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    // **`CourseImage`, not `Image.asset`.** A premium course's cover is an http
    // URL once it comes from the API, and a bundled demo course's is an asset
    // path; `CourseImage` handles both, which is what every other card in the
    // app already uses.
    child: CourseImage(
      course.image,
      width: width,
      height: height,
      fallback: const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Icon(Icons.image_outlined, color: _muted),
      ),
    ),
  );
}
