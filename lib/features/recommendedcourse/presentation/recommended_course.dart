import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/books/data/book_api.dart';
import 'package:skillsikka/features/books/data/catalogue_book.dart';
import 'package:skillsikka/features/books/presentation/book_chrome.dart';
import 'package:skillsikka/features/books/presentation/book_details.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF8D887F);
const _border = Color(0xFFEAEAEA);

// Author avatars — cycle through these 8 images
const _authorAvatars = <String>[
  'assets/figma/instructors/instructor.png',
  'assets/figma/instructors/instructor1.png',
  'assets/figma/instructors/instructor2.png',
  'assets/figma/instructors/instructor3.png',
  'assets/figma/instructors/instructor4.png',
  'assets/figma/instructors/instructor5.png',
  'assets/figma/instructors/instructor6.png',
  'assets/figma/instructors/instructor7.png',
];

class BrowseCategoriesPage extends ConsumerStatefulWidget {
  const BrowseCategoriesPage({super.key});

  @override
  ConsumerState<BrowseCategoriesPage> createState() =>
      _BrowseCategoriesPageState();
}

class _BrowseCategoriesPageState extends ConsumerState<BrowseCategoriesPage> {
  int _hoveredCategory = -1;
  int _selectedCategory = 0;
  String _query = '';
  Timer? _searchDebounce;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static const _categories = <_CategoryChip>[
    _CategoryChip(label: 'All', icon: null),
    _CategoryChip(label: 'Mathematics', icon: Icons.calculate_outlined),
    _CategoryChip(label: 'Programming', icon: Icons.terminal),
    _CategoryChip(label: 'Science', icon: Icons.science_outlined),
    _CategoryChip(label: 'Literature', icon: Icons.menu_book_outlined),
    _CategoryChip(label: 'History', icon: Icons.account_balance_outlined),
    _CategoryChip(label: 'Psychology', icon: Icons.psychology_outlined),
    _CategoryChip(label: 'Business', icon: Icons.bar_chart),
    _CategoryChip(label: 'Art & Design', icon: Icons.palette_outlined),
    _CategoryChip(label: 'Philosophy', icon: Icons.format_quote_outlined),
    _CategoryChip(label: 'Engineering', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavigationBar(),
            Expanded(
              child: SingleChildScrollView(
                // Bottom padding removed — list ends flush
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildCategoriesSection(),
                    const SizedBox(height: 24),
                    _buildPopularBooksSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            'Browse Categories',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: const Icon(Icons.tune, size: 18, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: _softGray),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = value.trim());
                });
              },
              style: GoogleFonts.figtree(fontSize: 14, color: _ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search books...',
                hintStyle: GoogleFonts.figtree(fontSize: 14, color: _softGray),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORIES',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final hovered = index == _hoveredCategory;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredCategory = index),
                onExit: (_) => setState(() => _hoveredCategory = -1),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = _selectedCategory == index ? 0 : index;
                  }),
                  child: Center(
                    child: _glassChip(
                      label: _categories[index].label,
                      icon: _categories[index].icon,
                      hovered: hovered || index == _selectedCategory,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _glassChip({
    required String label,
    IconData? icon,
    required bool hovered,
  }) {
    const radius = 14.0;

    final topColor = const Color(0xFFFFFFFF);
    final midColor = hovered
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFFBFBFC);
    final bottomColor = hovered
        ? const Color(0xFFD9DCE2)
        : const Color(0xFFEAECEF);

    final borderColor = hovered
        ? Colors.white
        : Colors.white.withValues(alpha: 0.85);

    final outerColor = hovered
        ? const Color(0x3D000000)
        : const Color(0x24000000);
    final outerBlur = hovered ? 16.0 : 10.0;
    final outerOffsetY = hovered ? 6.0 : 3.0;

    final highlightColor = hovered
        ? const Color(0xFFFFFFFF)
        : const Color(0xE6FFFFFF);
    final highlightBlur = hovered ? 5.0 : 3.0;
    final highlightOffsetY = hovered ? -2.5 : -1.5;

    final bottomInsetColor = hovered
        ? const Color(0x33000000)
        : const Color(0x1F000000);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, midColor, bottomColor],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: outerColor,
            blurRadius: outerBlur,
            offset: Offset(0, outerOffsetY),
          ),
          BoxShadow(
            color: highlightColor,
            blurRadius: highlightBlur,
            offset: Offset(0, highlightOffsetY),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: bottomInsetColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
          if (hovered)
            const BoxShadow(
              color: Color(0x1F5B8DEF),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: hovered ? _ink : _gray),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularBooksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionBar(color: Color(0x1F111827)),
            const SizedBox(width: 7),
            Text(
              _categories[_selectedCategory].label == 'All'
                  ? 'All Books'
                  : _categories[_selectedCategory].label,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ref
            .watch(bookCatalogueProvider(_query))
            .when(
              loading: () => const SizedBox(height: 8),
              error: (_, _) => Text(
                'Books could not be loaded.',
                style: GoogleFonts.figtree(fontSize: 13, color: _gray),
              ),
              data: (rows) {
                final label = _categories[_selectedCategory].label;
                final books = [
                  for (final book in rows)
                    if (_matchesCategory(book, label)) book,
                ];
                return Column(
                  children: [
                    for (var i = 0; i < books.length; i++) ...[
                      _buildBookRow(books[i], i),
                      if (i != books.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
      ],
    );
  }

  bool _matchesCategory(CatalogueBook book, String label) {
    if (label == 'All') return true;
    final hay = '${book.category} ${book.subjectName} ${book.difficulty}'
        .toLowerCase();
    final needle = label.toLowerCase();
    if (needle == 'mathematics') return hay.contains('math');
    if (needle == 'art & design') {
      return hay.contains('art') || hay.contains('design');
    }
    return hay.contains(needle);
  }

  Widget _buildBookRow(CatalogueBook book, int index) {
    final avatar = _authorAvatars[index % _authorAvatars.length];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        openCatalogueBook(context, book);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Book cover (fits into 80x114) ──────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 80,
                height: 114,
                child: BookCoverImage(
                  image: book.coverUrl,
                  width: 80,
                  height: 114,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // ── Book info ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.categoryLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [for (final tag in book.tags) _buildTag(tag)],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // ── Author avatar (circular, 20x20) ──────
                      ClipOval(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFBBF24),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        book.ratingLabel,
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _ink,
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

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(fontSize: 12, color: Colors.black),
      ),
    );
  }
}

class _CategoryChip {
  const _CategoryChip({required this.label, this.icon});
  final String label;
  final IconData? icon;
}
