import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/api_error_snack.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/course_grid_card.dart';
import 'package:skillsikka/core/widgets/pressable_chip.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _softGray = Color(0xFF8D887F);

/// The academic catalogue.
///
/// **Reads `GET /courses/?course_type=academic`.** It used to filter the const
/// `coursePool`, which is why every chip appeared to do nothing until 2026-10-13.
class AllCoursesPage extends ConsumerStatefulWidget {
  const AllCoursesPage({super.key});

  @override
  ConsumerState<AllCoursesPage> createState() => _AllCoursesPageState();
}

class _AllCoursesPageState extends ConsumerState<AllCoursesPage> {
  int _selectedChip = 0;

  static const _chips = [
    'All',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];

  static const _pageSize = 20;

  List<CourseDetailData> _courses = const [];
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The grade id the selected chip stands for.
  ///
  /// `Class 6` is the chip label; the server's grade is `Grade 6` and the filter
  /// takes its **id**. Sending the label instead would be silently ignored —
  /// unknown query values do not 400 — and the grid would show the whole
  /// catalogue while looking filtered. That is the trap this resolves.
  Future<int?> _gradeIdForChip() async {
    if (_selectedChip == 0) return null;
    final grades = await ref.read(gradesProvider.future);
    final wanted = 'grade ${_selectedChip + 5}';
    for (final grade in grades) {
      // `ReferenceItem.id` is a String on that model; the course filter wants an
      // int, so this is the one place the two vocabularies meet.
      if (grade.name.trim().toLowerCase() == wanted) {
        return int.tryParse(grade.id);
      }
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final gradeId = await _gradeIdForChip();
      // A class we cannot resolve is a real empty state, never "show
      // everything": an unfiltered grid under a `Class 6` heading is a lie.
      if (_selectedChip > 0 && gradeId == null) {
        if (!mounted) return;
        setState(() {
          _courses = const [];
          _next = null;
          _loading = false;
          _error = '${_chips[_selectedChip]} has no courses yet.';
        });
        return;
      }

      final page = await ref
          .read(courseApiProvider)
          .list(courseType: 'academic', grade: gradeId, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _courses = page.courses;
        _next = page.next;
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

  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(courseApiProvider).nextPage(next);
      if (!mounted) return;
      setState(() {
        _courses = [..._courses, ...page.courses];
        _next = page.next;
        _loadingMore = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      // The page already on screen stays: losing it over a failed second page
      // would be a worse outcome than a snack.
      showApiErrorSnack(context, error);
    }
  }

  void _selectChip(int index) {
    if (index == _selectedChip) return;
    setState(() => _selectedChip = index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChips(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(),
                    const SizedBox(height: 16),
                    if (_loading)
                      _buildLoading()
                    else if (_error != null)
                      _buildError(_error!)
                    else if (_courses.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildCoursesGrid(_courses),
                      if (_next != null) _buildLoadMore(),
                    ],
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
  // APP HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Text(
            'Courses',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: IconButton(
              tooltip: 'Search courses',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
              icon: const Icon(Icons.search, size: 20, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHIPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: _chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Center(
            child: PressableChip(
              label: _chips[index],
              selected: index == _selectedChip,
              onTap: () => _selectChip(index),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              textColor: _ink,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    // Names the filter, so a filtered grid cannot be mistaken for the whole
    // catalogue — "All Courses" over two Class 6 cards would be a lie.
    final chip = _chips[_selectedChip];

    return Row(
      children: [
        Text(
          chip == 'All' ? 'All Courses' : '$chip Courses',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.tune, size: 14, color: _softGray),
            const SizedBox(width: 4),
            Text(
              'Filters',
              style: GoogleFonts.figtree(fontSize: 12, color: _softGray),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOADING / ERROR / LOAD MORE
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// A failed load gets its own state and a retry, so it cannot be mistaken for
  /// "this class has no courses".
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 32, color: _softGray),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 13, color: _softGray),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _loadMore,
                child: const Text('Load more courses'),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSES GRID (2 columns × N rows)
  // ─────────────────────────────────────────────────────────────
  /// Shown when a class has no courses yet, so a filter can never produce a
  /// blank screen that reads as a loading failure.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 32, color: _softGray),
            const SizedBox(height: 12),
            Text(
              'No courses for this class yet.',
              style: GoogleFonts.figtree(fontSize: 13, color: _softGray),
            ),
          ],
        ),
      ),
    );
  }

  /// The same two-column grid the home rail draws, cell for cell.
  ///
  /// It used to be hand-built rows of [Expanded] cards, which meant each row
  /// sized itself to its own titles — a one-line title and a two-line title
  /// side by side made ragged rows — and the card inside was a *different*
  /// card from the home rail's. A `GridView` with the rail's own delegate fixes
  /// both: uniform cells, and one card widget behind both screens.
  Widget _buildCoursesGrid(List<CourseDetailData> courses) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: courses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final course = courses[index];
        return CourseGridCard(
          course: course,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CourseDetailPage(course: course)),
          ),
        );
      },
    );
  }
}
