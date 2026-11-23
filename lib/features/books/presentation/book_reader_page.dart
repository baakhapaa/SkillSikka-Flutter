import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/books/data/book_api.dart';
import 'package:skillsikka/features/books/data/book_library.dart';
import 'package:skillsikka/features/books/presentation/book_chrome.dart';
import 'package:skillsikka/features/books/presentation/book_settings_sheet.dart';

/// One chapter, with the place-in-book footer and a chapter switcher.
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({super.key, this.bookId, this.title});

  final int? bookId;
  final String? title;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  BookApi? _apiCache;

  OwnedBook get _book => widget.bookId != null
      ? BookLibrary.instance.byId(widget.bookId!)
      : BookLibrary.instance.book(widget.title!);

  BookApi get _api => _apiCache!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiCache ??= ProviderScope.containerOf(context).read(bookApiProvider);
  }

  @override
  void dispose() {
    final api = _apiCache;
    final book = _bookOrNull;
    if (api != null &&
        book != null &&
        book.id != null &&
        book.chapters.isNotEmpty) {
      api.saveProgress(book, completed: true);
    }
    super.dispose();
  }

  OwnedBook? get _bookOrNull {
    try {
      return _book;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSettings() {
    return showReadingSettings(
      context,
      book: _book,
      onChanged: () {
        if (mounted) setState(() {});
        if (_book.id == null) return;
        _api.saveSettings(_book.reading);
      },
    );
  }

  Future<void> _pickChapter() async {
    final book = _book;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < book.chapters.length; i++)
                ListTile(
                  title: Text(
                    'Ch. ${i + 1}  ${book.chapters[i].title}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: i == book.currentChapter
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: bookInk,
                    ),
                  ),
                  trailing: i == book.currentChapter
                      ? const Icon(Icons.check, color: bookGoldDeep)
                      : null,
                  onTap: () => Navigator.pop(context, i),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    if (book.id == null) {
      BookLibrary.instance.goToChapter(widget.title!, selected);
    } else if (selected != book.currentChapter) {
      book.currentChapter = selected;
      book.pageInChapter = 1;
      book.overallPage = book.chapters[selected].startPage;
      book.minutesLeft = book.chapters[selected].minutes;
      try {
        await _api.loadChapterText(book, selected);
        await _api.saveProgress(book, completed: false);
      } on ApiException {
        // The chapter title is already on screen.
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final chapter = book.chapter;
    final settings = book.reading;
    final palette = ReadingPalette.of(settings.appearance);
    final number = (book.currentChapter + 1).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: palette.background,
      body: ReadingBrightness(
        brightness: settings.brightness,
        child: SafeArea(
          child: Column(
            children: [
              BookTopBar(
                title: book.title,
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Center(
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(width: 28, height: 2, color: bookGold),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'CHAPTER $number',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: bookGoldDeep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      chapter.title,
                      style: readingFace(
                        settings,
                        fontSize: settings.textSize * 1.75,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      chapter.lead,
                      style: readingFace(
                        settings,
                        fontSize: settings.textSize * 0.94,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final paragraph in chapter.paragraphs) ...[
                      Text(
                        paragraph,
                        style: readingFace(
                          settings,
                          fontSize: settings.textSize.toDouble(),
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (chapter.pausePrompt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _PauseAndThink(
                        prompt: chapter.pausePrompt,
                        settings: settings,
                        ink: palette.ink,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: palette.chip),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _pickChapter,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ch. ${book.currentChapter + 1} of ${book.chapters.length}',
                                  style: GoogleFonts.figtree(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink,
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: palette.ink,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Page ${book.overallPage} of ${book.totalPages}',
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${book.minutesLeft} min left in chapter',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${book.percent}% read',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: palette.muted,
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
      ),
    );
  }
}

class _PauseAndThink extends StatelessWidget {
  const _PauseAndThink({
    required this.prompt,
    required this.settings,
    required this.ink,
  });

  final String prompt;
  final ReadingSettings settings;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2, color: bookGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAUSE & THINK',
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: bookGoldDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  prompt,
                  style: readingFace(
                    settings,
                    fontSize: settings.textSize * 0.94,
                    fontStyle: FontStyle.italic,
                    height: settings.lineHeight,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
