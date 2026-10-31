import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_image.dart';
import '../../courses/data/course_builder_api.dart';
import '../../courses/data/course_summary.dart';
import '../../courses/data/my_courses_api.dart';
import '../../courses/presentation/course_builder_page.dart';
import '../data/user_profile.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _line = Color(0xFFF3F4F6);

/// Every course this instructor has authored, as a list.
///
/// This is what the profile tab's **See All (25)** opens. It is a *list* rather
/// than a repeat of the two-column shelf on purpose: the shelf is a glance at
/// three or four courses, and 25 tiles is a long scroll of near-identical
/// pictures. A row carries the same facts — cover, title, LIVE/DRAFT, price —
/// in a fraction of the height, and the whole row is the tap target for the
/// builder.
///
/// It fetches its own copy instead of taking the profile's, because the point of
/// the screen is to be complete: the profile may have failed to load, and this
/// one has to say so rather than showing an empty list.
class MyCoursesPage extends ConsumerStatefulWidget {
  const MyCoursesPage({super.key});

  @override
  ConsumerState<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends ConsumerState<MyCoursesPage> {
  List<CourseSummary> _courses = const [];
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
    final id = ref.read(userProfileProvider).id;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Your profile has not loaded yet. Go back and try again.';
      });
      return;
    }
    try {
      final courses = await ref.read(myCoursesApiProvider).list(id);
      if (!mounted) return;
      setState(() {
        _courses = courses;
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

  /// Opens the builder, then reloads: the course may have been published, saved
  /// as a draft, unpublished or deleted while it was open.
  Future<void> _open(CourseSummary course) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CourseBuilderPage(
          api: ref.read(courseBuilderApiProvider),
          instructorVerified: ref.read(userProfileProvider).canPublish,
          courseId: course.id,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: _ink,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'My Courses',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${_courses.length}',
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(fontSize: 13, color: _gray),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'You have not created a course yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(fontSize: 13, color: _gray),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _courses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final course = _courses[index];
        return _CourseRow(course: course, onTap: () => _open(course));
      },
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.onTap});

  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = course.priceLabel;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CourseImage(
                  course.thumbnailUrl ?? '',
                  width: 64,
                  height: 64,
                  fallback: const ColoredBox(
                    color: _line,
                    child: Icon(Icons.image_outlined, color: _gray),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusChip(isPublished: course.isPublished),
                        if (price.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.figtree(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF524C00),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _gray),
            ],
          ),
        ),
      ),
    );
  }
}

/// `LIVE` or `DRAFT`, the same two states the shelf's cards carry.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: isPublished ? const Color(0xFFE8F5EC) : const Color(0xFFFBF4D9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      isPublished ? 'LIVE' : 'DRAFT',
      style: GoogleFonts.figtree(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isPublished ? const Color(0xFF1C7C3C) : const Color(0xFF8A7A2E),
      ),
    ),
  );
}
