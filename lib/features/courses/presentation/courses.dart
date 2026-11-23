import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/api_error_snack.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/course_grid_card.dart';
import 'package:skillsikka/core/widgets/loading_skeleton.dart';
import 'package:skillsikka/core/widgets/pressable_chip.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
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

  CatalogueQuery get _query => (type: 'academic', classIndex: _selectedChip);

  @override
  void initState() {
    super.initState();
    // Coming back to the tab: the cards already on screen are from the cache,
    // so ask for a fresh copy without blanking them.
    if (ref.read(catalogueProvider(_query)).hasValue) {
      Future.microtask(() {
        if (mounted) ref.invalidate(catalogueProvider(_query));
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogueProvider(_query));
    try {
      await ref.read(catalogueProvider(_query).future);
    } on ApiException {
      // The error state below says so, with its own retry.
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(catalogueProvider(_query).notifier).loadMore();
    } on ApiException catch (error) {
      if (!mounted) return;
      // The page already on screen stays: losing it over a failed second page
      // would be a worse outcome than a snack.
      showApiErrorSnack(context, error);
    }
  }

  void _selectChip(int index) {
    if (index == _selectedChip) return;
    setState(() => _selectedChip = index);
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider(_query));
    final state = catalogue.valueOrNull;
    final Object? error = catalogue.hasError && state == null
        ? catalogue.error
        : null;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppHeader(),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildChips(),
                              const SizedBox(height: 28),
                              _buildSectionHeader(),
                            ],
                          ),
                        ),
                      ),
                      if (state == null && error == null)
                        _boxed(const CourseGridSkeleton())
                      else if (error != null)
                        _boxed(_buildError(_errorText(error)))
                      else if (state!.emptyMessage != null)
                        _boxed(_buildError(state.emptyMessage!))
                      else if (state.courses.isEmpty)
                        _boxed(_buildEmptyState())
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverCourseCardGrid(
                            courses: state.courses,
                            onTap: _openCourse,
                          ),
                        ),
                        if (state.next != null)
                          _boxed(_buildLoadMore(state.loadingMore)),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boxed(Widget child) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverToBoxAdapter(child: child),
  );

  String _errorText(Object error) => error is ApiException
      ? error.displayMessage
      : 'Courses could not be loaded.';

  void _openCourse(CourseDetailData course) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => CourseDetailPage(course: course)));

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
          physics: const ClampingScrollPhysics(),
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
              glass: true,
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
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore(bool loadingMore) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: loadingMore
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
}
