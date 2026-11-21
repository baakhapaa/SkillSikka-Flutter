import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_image.dart';
import '../../courses/data/course_builder_api.dart';
import '../../courses/data/course_summary.dart';
import '../../courses/data/my_courses_api.dart';
import '../../courses/presentation/course_builder_page.dart';
import '../../quiz/data/quiz_api.dart';
import 'instructor_course_insights.dart';
import '../data/user_profile.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _gold = Color(0xFFF6C945);

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
  const MyCoursesPage({super.key, this.showBack = true});

  /// False when this list is the instructor's bottom tab. See All still shows
  /// the back control, because that copy is pushed on top of the profile.
  final bool showBack;

  @override
  ConsumerState<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends ConsumerState<MyCoursesPage> {
  final _search = TextEditingController();
  List<CourseSummary> _courses = const [];
  bool _loading = true;
  String? _error;
  _CourseFilter _filter = _CourseFilter.all;
  _LibraryGroup _group = _LibraryGroup.category;
  _CourseSort _sort = _CourseSort.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  /// Opens the course details screen, then reloads in case Edit published,
  /// unpublished, or deleted the course.
  Future<void> _open(CourseSummary course) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InstructorCourseDetailsPage(course: course),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _create() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CourseBuilderPage(
          api: ref.read(courseBuilderApiProvider),
          quizApi: ref.read(quizApiProvider),
          instructorVerified: ref.read(userProfileProvider).canPublish,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  List<CourseSummary> get _visible {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final course in _courses)
        if (_filter.matches(course) &&
            (query.isEmpty || course.title.toLowerCase().contains(query)))
          course,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _courses.fold<int>(
      0,
      (sum, course) => sum + (course.lessonCount ?? 0),
    );
    final categories = _courses.map((course) => course.category).toSet().length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/my_courses_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showBack)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _roundIcon(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.maybePop(context),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workspace',
                                style: GoogleFonts.figtree(
                                  fontSize: 12,
                                  color: _gray,
                                ),
                              ),
                              Text(
                                'My Courses',
                                style: GoogleFonts.manrope(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _create,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.upload_outlined,
                                  size: 16,
                                  color: _ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Upload',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          _stat('${_courses.length}', 'Courses'),
                          _statDivider(),
                          _stat('$lessons', 'Lessons'),
                          _statDivider(),
                          _stat('$categories', 'Category'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.manrope(fontSize: 14, color: _ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search your courses',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 14,
                          color: _gray,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter in _CourseFilter.values)
                          _filterChip(filter),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _body(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(label, style: GoogleFonts.figtree(fontSize: 12, color: _gray)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 28, color: const Color(0xFFE7D7A8));
  }

  Widget _filterChip(_CourseFilter filter) {
    final selected = filter == _filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _gold : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '${filter.label} ${_count(filter)}',
          style: GoogleFonts.figtree(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: _ink),
      ),
    );
  }

  List<MapEntry<String, List<CourseSummary>>> _grouped(
    List<CourseSummary> courses,
  ) {
    final groups = <String, List<CourseSummary>>{};
    for (final course in _sorted(courses)) {
      groups.putIfAbsent(course.category, () => []).add(course);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries;
  }

  List<CourseSummary> _sorted(List<CourseSummary> courses) {
    final next = [...courses];
    next.sort((a, b) {
      switch (_sort) {
        case _CourseSort.recent:
          final left = a.updatedAt;
          final right = b.updatedAt;
          if (left == null && right == null) {
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          if (left == null) return 1;
          if (right == null) return -1;
          return right.compareTo(left);
        case _CourseSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _CourseSort.lessons:
          final byLessons = (b.lessonCount ?? 0).compareTo(a.lessonCount ?? 0);
          if (byLessons != 0) return byLessons;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return next;
  }

  Widget _grid(List<CourseSummary> courses) {
    return Column(
      children: [
        for (var i = 0; i < courses.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CourseCard(
                    course: courses[i],
                    onTap: () => _open(courses[i]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < courses.length
                      ? _CourseCard(
                          course: courses[i + 1],
                          onTap: () => _open(courses[i + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _menu<T>({
    required IconData? icon,
    required String label,
    required List<T> items,
    required T selected,
    required String Function(T item) itemLabel,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      initialValue: selected,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x22111827),
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 196),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    itemLabel(item),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: item == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ),
                if (item == selected)
                  const Icon(Icons.check, size: 16, color: _gold),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: _gray),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: _gray),
          ],
        ),
      ),
    );
  }

  int _count(_CourseFilter filter) => _courses.where(filter.matches).length;

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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'You have not created a course yet.',
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(fontSize: 13, color: _gray),
        ),
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No courses match this search.',
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(fontSize: 13, color: _gray),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _menu<_LibraryGroup>(
                    icon: Icons.folder_open,
                    label: _group.label,
                    items: _LibraryGroup.values,
                    selected: _group,
                    itemLabel: (item) => item.label,
                    onSelected: (item) => setState(() => _group = item),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _menu<_CourseSort>(
                    icon: null,
                    label: _sort.label,
                    items: _CourseSort.values,
                    selected: _sort,
                    itemLabel: (item) => item.label,
                    onSelected: (item) => setState(() => _sort = item),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_group == _LibraryGroup.category)
          for (final entry in _grouped(visible)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  entry.value.length == 1
                      ? '1 course'
                      : '${entry.value.length} courses',
                  style: GoogleFonts.figtree(fontSize: 12, color: _gray),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _grid(entry.value),
            const SizedBox(height: 8),
          ]
        else
          _grid(_sorted(visible)),
        Center(
          child: Text(
            'All ${visible.length} courses',
            style: GoogleFonts.figtree(fontSize: 12, color: _gray),
          ),
        ),
      ],
    );
  }
}

enum _CourseFilter {
  all('All'),
  live('Published'),
  draft('Draft');

  const _CourseFilter(this.label);
  final String label;

  bool matches(CourseSummary course) => switch (this) {
    _CourseFilter.all => true,
    _CourseFilter.live => course.isPublished,
    _CourseFilter.draft => !course.isPublished,
  };
}

enum _LibraryGroup {
  category('By category'),
  all('All courses');

  const _LibraryGroup(this.label);
  final String label;
}

enum _CourseSort {
  recent('Recently updated'),
  title('Title'),
  lessons('Most lessons');

  const _CourseSort(this.label);
  final String label;
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lessons = course.lessonCount;
    final videos = lessons == null
        ? ''
        : lessons == 1
        ? '1 video'
        : '$lessons videos';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CourseImage(
                course.thumbnailUrl ?? '',
                fit: BoxFit.cover,
                fallback: const ColoredBox(
                  color: Color(0xFFE8E5DE),
                  child: SizedBox.expand(
                    child: Icon(Icons.image_outlined, color: Color(0xFF9C9890)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusChip(isPublished: course.isPublished),
                      const Spacer(),
                      if (videos.isNotEmpty)
                        Text(
                          videos,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: const Color(0xFF1B1C1E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    course.durationLabel.isEmpty
                        ? 'Manage →'
                        : '${course.durationLabel} · Manage →',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      height: 1.1,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Published` or `Draft` under the cover, on a tinted pill.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: isPublished ? const Color(0xFFE5F6EA) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      isPublished ? 'Published' : 'Draft',
      style: GoogleFonts.figtree(
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: isPublished ? const Color(0xFF1F8A4C) : const Color(0xFF6B7280),
      ),
    ),
  );
}
