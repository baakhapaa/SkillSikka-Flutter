import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/books/data/book_api.dart';
import 'package:skillsikka/features/books/data/book_library.dart';
import 'package:skillsikka/features/books/presentation/book_chrome.dart';
import 'package:skillsikka/features/books/presentation/book_reader_page.dart';
import 'package:skillsikka/features/books/presentation/book_settings_sheet.dart';

/// "Your place in the book": progress, contents, bookmarks, and continue.
class BookPlacePage extends StatefulWidget {
  const BookPlacePage({super.key, this.bookId, this.title});

  final int? bookId;
  final String? title;

  @override
  State<BookPlacePage> createState() => _BookPlacePageState();
}

class _BookPlacePageState extends State<BookPlacePage> {
  var _showBookmarks = false;

  OwnedBook get _book => widget.bookId != null
      ? BookLibrary.instance.byId(widget.bookId!)
      : BookLibrary.instance.book(widget.title!);

  BookApi get _api => ProviderScope.containerOf(context).read(bookApiProvider);

  Future<void> _openSettings() {
    return showReadingSettings(
      context,
      book: _book,
      onChanged: () {
        if (mounted) setState(() {});
        final id = _book.id;
        if (id == null) return;
        _api.saveSettings(_book.reading);
      },
    );
  }

  Future<void> _openReader() async {
    final book = _book;
    if (book.chapters.isEmpty) return;
    if (book.id != null) {
      try {
        await _api.loadChapterText(book, book.currentChapter);
        await _api.saveProgress(book, completed: false);
      } on ApiException {
        // The chapter title still opens.
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookReaderPage(bookId: widget.bookId, title: widget.title),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openChapter(int index) {
    final book = _book;
    if (book.id == null) {
      BookLibrary.instance.goToChapter(widget.title!, index);
    } else if (index != book.currentChapter) {
      book.currentChapter = index;
      book.pageInChapter = 1;
      book.overallPage = book.chapters[index].startPage;
      book.minutesLeft = book.chapters[index].minutes;
    }
    setState(() {});
    _openReader();
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final settings = book.reading;
    final palette = ReadingPalette.of(settings.appearance);
    final scale = settings.textSize / 18;
    final listed = _showBookmarks
        ? [
            for (var i = 0; i < book.chapters.length; i++)
              if (book.bookmarks.contains(i)) i,
          ]
        : [for (var i = 0; i < book.chapters.length; i++) i];

    return Scaffold(
      backgroundColor: palette.background,
      body: ReadingBrightness(
        brightness: settings.brightness,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookTopBar(
                title: 'Book Details',
                bookmarked: book.currentIsBookmarked,
                foreground: palette.ink,
                actionFill: palette.chip,
                onBack: () => Navigator.maybePop(context),
                onBookmark: () async {
                  try {
                    await _api.toggleBookmark(_book);
                  } on ApiException {
                    // The icon stays as it was.
                  }
                  if (mounted) setState(() {});
                },
                onFont: _openSettings,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Text(
                      'Your place in the book',
                      style: readingFace(
                        settings,
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BookIdentity(book: book, scale: scale, palette: palette),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '${book.percent}% read',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Page ${book.overallPage} of ${book.totalPages}',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: book.percent / 100,
                        minHeight: 4,
                        backgroundColor: palette.chip,
                        color: bookGold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _TabLabel(
                          label: 'Contents',
                          selected: !_showBookmarks,
                          palette: palette,
                          onTap: () => setState(() => _showBookmarks = false),
                        ),
                        const SizedBox(width: 20),
                        _TabLabel(
                          label: 'Bookmarks ${book.bookmarks.length}',
                          selected: _showBookmarks,
                          palette: palette,
                          onTap: () => setState(() => _showBookmarks = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (listed.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No bookmarks yet.',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            color: palette.muted,
                          ),
                        ),
                      )
                    else
                      for (var n = 0; n < listed.length; n++) ...[
                        _ChapterRow(
                          index: listed[n],
                          book: book,
                          scale: scale,
                          palette: palette,
                          onTap: () => _openChapter(listed[n]),
                        ),
                        if (n != listed.length - 1)
                          Divider(height: 1, color: palette.chip),
                      ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: GestureDetector(
                  onTap: () {
                    _openReader();
                  },
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bookGold,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Continue chapter ${book.currentChapter + 1}  →',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: bookInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookIdentity extends StatelessWidget {
  const _BookIdentity({
    required this.book,
    required this.scale,
    required this.palette,
  });

  final OwnedBook book;
  final double scale;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BookCoverImage(
            image: book.image,
            width: 44,
            height: 62,
            fallback: Container(
              width: 44,
              height: 62,
              color: palette.chip,
              child: Icon(Icons.menu_book, size: 18, color: palette.muted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: readingFace(
                  book.reading,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'By ${book.author}',
                style: GoogleFonts.figtree(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ReadingPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? palette.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.ink : palette.muted,
          ),
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.book,
    required this.scale,
    required this.palette,
    required this.onTap,
  });

  final int index;
  final OwnedBook book;
  final double scale;
  final ReadingPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chapter = book.chapters[index];
    final current = index == book.currentChapter;
    final done = book.completed.contains(index) && !current;
    final number = (index + 1).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    number,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: palette.soft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: readingFace(
                          book.reading,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.subtitle,
                        style: GoogleFonts.figtree(
                          fontSize: 12 * scale,
                          color: palette.muted,
                          height: book.reading.lineHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (current)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: palette.ink,
                    ),
                  )
                else if (done)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 18, color: palette.muted),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${chapter.startPage}',
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        color: palette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
