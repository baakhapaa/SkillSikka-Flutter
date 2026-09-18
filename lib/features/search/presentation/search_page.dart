import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/instructors/presentation/instructor_profile.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF6B7280);
const _softGray = Color(0xFF8D887F);
const _border = Color(0xFFE5E7EB);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchFocused = false;

  static const _trendingSearches = [
    'Python',
    'CSS Grid',
    'React Hooks',
    'Machine Learning',
    'Algorithms',
    'UX Design',
  ];

  static const _popularCourses = <_PopularCourse>[
    _PopularCourse(
      image: 'assets/figma/courses/python.png',
      title: 'Python Data Science',
      rating: '4.8',
      level: 'Beginner',
    ),
    _PopularCourse(
      image: 'assets/figma/courses/react.png',
      title: 'React Architecture',
      rating: '4.9',
      level: 'Advanced',
    ),
  ];

  static const _creators = <_Creator>[
    _Creator(
      image: 'assets/figma/instructors/instructor.png',
      handle: '@sarah_codes',
    ),
    _Creator(
      image: 'assets/figma/instructors/instructor1.png',
      handle: '@alex_dev',
    ),
    _Creator(
      image: 'assets/figma/instructors/instructor2.png',
      handle: '@stem_tutor',
    ),
    _Creator(
      image: 'assets/figma/instructors/instructor3.png',
      handle: '@coding_ninja',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
    // Auto-open the keyboard once on first frame.
    // We do NOT use `autofocus: true` on the TextField because that
    // re-requests focus on every rebuild, which fights the Cancel button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _searchFocused = _searchFocus.hasFocus);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Dismisses the keyboard and flips the UI back to idle.
  /// Belt-and-suspenders: unfocus the field, unfocus the whole scope,
  /// and force a rebuild so the Cancel button disappears immediately.
  void _exitSearch() {
    _searchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() => _searchFocused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchRow(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrendingSearches(),
                    _buildPopularCourses(),
                    _buildTrendingCreators(),
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
  // SEARCH ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          // Back arrow — only visible when the field is idle
          if (!_searchFocused) ...[
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
            const SizedBox(width: 8),
          ],

          // Search field
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: _softGray),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      // NOTE: no `autofocus: true` here on purpose.
                      // We request focus once in initState instead so it
                      // doesn't re-claim focus on every rebuild.
                      textInputAction: TextInputAction.search,
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        color: _ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search courses, creators...',
                        hintStyle: GoogleFonts.figtree(
                          fontSize: 14,
                          color: _softGray,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cancel — only shown while the field has focus
          if (_searchFocused) ...[
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _exitSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TRENDING SEARCHES
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrendingSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Searches',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _trendingSearches) _buildTag(tag),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        _searchFocus.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Text(
          text,
          style: GoogleFonts.figtree(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _ink,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // POPULAR COURSES
  // ─────────────────────────────────────────────────────────────
  Widget _buildPopularCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Popular Courses',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _popularCourses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final c = _popularCourses[index];
                return _buildPopularCourseCard(c);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCourseCard(_PopularCourse course) {
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: Image.asset(
                course.image,
                fit: BoxFit.cover,
errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade300,
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
            padding: const EdgeInsets.all(12),
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
                    const Icon(
                      Icons.star,
                      color: Color(0xFFFBBF24),
                      size: 11,
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
  // TRENDING CREATORS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrendingCreators() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Creators',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < _creators.length; i++) ...[
                Flexible(child: _buildCreator(_creators[i])),
                if (i < _creators.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreator(_Creator creator) {
    return SizedBox(
      width: 70,
      child: Semantics(
        button: true,
        label: 'Open ${creator.handle} profile',
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InstructorProfilePage(),
              ),
            );
          },
          child: Column(
            children: [
              ClipOval(
                child: Image.asset(
                  creator.image,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                creator.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  color: _gray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _Creator {
  const _Creator({required this.image, required this.handle});

  final String image;
  final String handle;
}
