/// In-memory books the reader has bought during this app session.
///
/// There is no book payment API. Buying records the title here so the place
/// screen and the chapter reader can share progress, bookmarks, and the
/// reading settings for that book.
class BookLibrary {
  BookLibrary._();

  static final BookLibrary instance = BookLibrary._();

  final Map<String, OwnedBook> _owned = {};
  final Map<int, OwnedBook> _byId = {};

  bool owns(String title) => _owned.containsKey(title);

  bool ownsId(int id) => _byId.containsKey(id);

  /// Keeps a shelf loaded from the server so the place and reader screens,
  /// which read synchronously, open on the same layout they always have.
  void adopt(OwnedBook book) {
    _owned[book.title] = book;
    final id = book.id;
    if (id != null) _byId[id] = book;
  }

  OwnedBook byId(int id) {
    final owned = _byId[id];
    if (owned == null) {
      throw StateError('Book $id has not been opened.');
    }
    if (owned.reading.brightness == 0.7) owned.reading.brightness = 1;
    return owned;
  }

  OwnedBook book(String title) {
    final owned = _owned[title];
    if (owned == null) {
      throw StateError('Book "$title" has not been bought.');
    }
    // Earlier builds started at 70%, which grayed the light page.
    if (owned.reading.brightness == 0.7) {
      owned.reading.brightness = 1;
    }
    return owned;
  }

  /// Records a purchase. A second buy of the same title keeps the reading place.
  void buy({
    required String title,
    required String author,
    required String image,
    required String description,
  }) {
    _owned.putIfAbsent(title, () => _seed(title, author, image, description));
  }

  void toggleCurrentBookmark(String title) {
    final owned = book(title);
    final index = owned.currentChapter;
    if (owned.bookmarks.contains(index)) {
      owned.bookmarks.remove(index);
    } else {
      owned.bookmarks.add(index);
    }
  }

  /// Moves the reading place to the start of [index], unless that chapter is
  /// already the current one (its saved page stays put).
  void goToChapter(String title, int index) {
    final owned = book(title);
    if (index == owned.currentChapter) return;
    final chapter = owned.chapters[index];
    owned.currentChapter = index;
    owned.pageInChapter = 1;
    owned.overallPage = chapter.startPage;
    owned.minutesLeft = chapter.minutes;
    final ratio = (chapter.startPage / owned.totalPages) * 100;
    owned.percent = ratio.round().clamp(0, 100);
  }
}

class OwnedBook {
  OwnedBook({
    this.id,
    required this.title,
    required this.author,
    required this.image,
    required this.totalPages,
    required this.chapters,
    required this.currentChapter,
    required this.pageInChapter,
    required this.overallPage,
    required this.percent,
    required this.minutesLeft,
    required this.completed,
    required this.bookmarks,
    Map<int, int>? bookmarkIds,
    ReadingSettings? reading,
  }) : bookmarkIds = bookmarkIds ?? <int, int>{},
       reading = reading ?? ReadingSettings();

  /// Server id. Null only for a book bought from the offline details preview.
  final int? id;

  final String title;
  final String author;
  final String image;
  final int totalPages;
  final List<BookChapter> chapters;

  int currentChapter;
  int pageInChapter;
  int overallPage;
  int percent;
  int minutesLeft;
  final Set<int> completed;
  final Set<int> bookmarks;

  /// Chapter index to the bookmark id the server returned for it.
  final Map<int, int> bookmarkIds;

  final ReadingSettings reading;

  BookChapter get chapter => chapters[currentChapter];

  bool get currentIsBookmarked => bookmarks.contains(currentChapter);
}

enum ReadingFont { lora, figtree }

enum ReadingAppearance { light, sepia, dark }

/// Choices from the reading settings sheet. One copy per bought book.
class ReadingSettings {
  ReadingSettings({
    this.font = ReadingFont.lora,
    this.textSize = 18,
    this.lineHeight = 1.6,
    this.appearance = ReadingAppearance.light,
    this.brightness = 1,
  });

  static const minTextSize = 14;
  static const maxTextSize = 28;
  static const lineHeights = <double>[1.4, 1.6, 1.8];

  ReadingFont font;
  int textSize;
  double lineHeight;
  ReadingAppearance appearance;

  /// 1 is full brightness, the same white as the book details page.
  double brightness;

  void decreaseTextSize() {
    if (textSize > minTextSize) textSize -= 2;
  }

  void increaseTextSize() {
    if (textSize < maxTextSize) textSize += 2;
  }

  /// The sheet only offers Lora and Figtree. The server stores a generic family.
  factory ReadingSettings.fromServer(Map<String, dynamic> row) {
    final family = row['font_family']?.toString() ?? 'system';
    final font = family == 'sans-serif' || family == 'monospace'
        ? ReadingFont.figtree
        : ReadingFont.lora;
    final rawSize = _asInt(row['font_size']) ?? 18;
    var size = rawSize.clamp(minTextSize, maxTextSize);
    if (size.isOdd) size -= 1;
    final spacing = _asDouble(row['line_spacing']) ?? 1.6;
    var line = lineHeights.first;
    var best = (spacing - line).abs();
    for (final candidate in lineHeights) {
      final gap = (spacing - candidate).abs();
      if (gap < best) {
        best = gap;
        line = candidate;
      }
    }
    final appearance = switch (row['theme']?.toString()) {
      'sepia' => ReadingAppearance.sepia,
      'dark' => ReadingAppearance.dark,
      _ => ReadingAppearance.light,
    };
    return ReadingSettings(
      font: font,
      textSize: size,
      lineHeight: line,
      appearance: appearance,
    );
  }

  Map<String, Object> toServer() {
    return {
      'font_family': font == ReadingFont.lora ? 'serif' : 'sans-serif',
      'font_size': textSize,
      'line_spacing': lineHeight.toStringAsFixed(1),
      'theme': switch (appearance) {
        ReadingAppearance.light => 'light',
        ReadingAppearance.sepia => 'sepia',
        ReadingAppearance.dark => 'dark',
      },
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class BookChapter {
  const BookChapter({
    this.id,
    required this.title,
    required this.subtitle,
    required this.startPage,
    required this.pageCount,
    required this.minutes,
    required this.lead,
    required this.paragraphs,
    required this.pausePrompt,
  });

  /// Server chapter id. Null on the offline preview chapters.
  final int? id;

  final String title;
  final String subtitle;
  final int startPage;
  final int pageCount;
  final int minutes;
  final String lead;
  final List<String> paragraphs;
  final String pausePrompt;

  BookChapter copyWith({String? lead, List<String>? paragraphs}) {
    return BookChapter(
      id: id,
      title: title,
      subtitle: subtitle,
      startPage: startPage,
      pageCount: pageCount,
      minutes: minutes,
      lead: lead ?? this.lead,
      paragraphs: paragraphs ?? this.paragraphs,
      pausePrompt: pausePrompt,
    );
  }
}

OwnedBook _seed(String title, String author, String image, String description) {
  if (title == 'The Art of Problem Solving (Intro)') {
    return OwnedBook(
      title: title,
      author: author,
      image: image,
      totalPages: 150,
      chapters: _problemSolvingChapters,
      currentChapter: 1,
      pageInChapter: 3,
      overallPage: 22,
      percent: 24,
      minutesLeft: 9,
      completed: {0},
      bookmarks: {1},
    );
  }

  return OwnedBook(
    title: title,
    author: author,
    image: image,
    totalPages: 96,
    chapters: _generatedChapters(title, description),
    currentChapter: 0,
    pageInChapter: 1,
    overallPage: 1,
    percent: 0,
    minutesLeft: 12,
    completed: {},
    bookmarks: {},
  );
}

const _problemSolvingChapters = <BookChapter>[
  BookChapter(
    title: 'Start with a better question',
    subtitle: 'Understanding the problem',
    startPage: 1,
    pageCount: 19,
    minutes: 15,
    lead: 'The first step is understanding.',
    paragraphs: [
      'Good problem solvers are not people who always know the answer. '
          'They are people who know how to begin.',
      'Before reaching for a formula, pause. What do you know? What are you '
          'trying to find?',
      'Share 12 apples among 3 friends. Ask not "Which operation?" but '
          '"What is an equal share?"',
    ],
    pausePrompt: 'How could you draw the problem before solving it?',
  ),
  BookChapter(
    title: 'Thinking visually',
    subtitle: 'Pictures',
    startPage: 20,
    pageCount: 16,
    minutes: 15,
    lead: 'A picture holds the problem still.',
    paragraphs: [
      'When a problem is only words, it keeps slipping. A sketch gives it '
          'edges, groups, and a place to point.',
      'Draw what you know first. Leave the unknown as an empty space. The '
          'empty space is the question.',
      'Twelve apples and three friends become three circles and a pile of '
          'marks. The operation shows up after the picture, not before it.',
    ],
    pausePrompt: 'Which part of the problem is still invisible on the page?',
  ),
  BookChapter(
    title: 'Find the pattern',
    subtitle: 'From examples to rules',
    startPage: 41,
    pageCount: 20,
    minutes: 14,
    lead: 'One example is a story. Three examples are a rule.',
    paragraphs: [
      'Work a small case by hand. Then a slightly larger one. Write down '
          'what stayed the same.',
      'The pattern is the part you can trust on a case you have not tried. '
          'Name it in a sentence before you name it in symbols.',
      'If the sentence breaks on the next example, the pattern was only a '
          'coincidence. That is useful news.',
    ],
    pausePrompt: 'What stayed the same in every example you tried?',
  ),
  BookChapter(
    title: 'Work backwards',
    subtitle: 'Begin with the end in mind',
    startPage: 61,
    pageCount: 20,
    minutes: 12,
    lead: 'Start from the answer you wish you had.',
    paragraphs: [
      'Some problems are easier from the finish. Picture the last step that '
          'would make the result true, then ask what had to be true before it.',
      'Each step backward is a smaller problem. You stop when you reach '
          'something you already know.',
      'The forward solution is just that path, read the other way.',
    ],
    pausePrompt: 'What is the last thing that would have to be true?',
  ),
  BookChapter(
    title: 'Break it down',
    subtitle: 'Small steps, clearer thinking',
    startPage: 81,
    pageCount: 20,
    minutes: 11,
    lead: 'A large problem is several small ones sharing a page.',
    paragraphs: [
      'If you cannot start, the problem is still too big. Split it where the '
          'question changes.',
      'Solve one piece and write the result in the margin. That result is now '
          'something you know for the next piece.',
      'Putting the pieces back together is its own step. Check that they '
          'answer the original question, not a nearby one.',
    ],
    pausePrompt: 'Where could this problem split into two smaller ones?',
  ),
  BookChapter(
    title: 'Put it into practice',
    subtitle: 'Everyday mental models',
    startPage: 101,
    pageCount: 50,
    minutes: 18,
    lead: 'A method you do not use is only a story about thinking.',
    paragraphs: [
      'Take a problem from today: a route, a budget, a schedule, a game. '
          'Ask the same opening question. What do you know, and what are you '
          'trying to find?',
      'Draw it. Try a smaller case. If you are stuck, start from the end.',
      'The goal is not a faster answer. It is a first move you can repeat '
          'when the problem is new.',
    ],
    pausePrompt: 'Which problem from this week deserves a sketch?',
  ),
];

List<BookChapter> _generatedChapters(String title, String description) {
  final blurb = description.trim().isEmpty
      ? 'A short guide to $title.'
      : description.trim();
  const outlines = <(String, String, int)>[
    ('Start here', 'Why this book', 1),
    ('The core idea', 'The method', 17),
    ('A worked example', 'See it once', 33),
    ('Practice', 'Try it yourself', 49),
    ('Common mistakes', 'What to watch', 65),
    ('Put it to use', 'Keep going', 81),
  ];

  return [
    for (final (name, subtitle, start) in outlines)
      BookChapter(
        title: name,
        subtitle: subtitle,
        startPage: start,
        pageCount: 16,
        minutes: 12,
        lead: blurb,
        paragraphs: [
          '$title is a book about practice. $blurb',
          'Read this chapter once for the idea, then once with a pencil. '
              'The second pass is where $subtitle starts to stick.',
          'When you close the book, you should be able to explain this '
              'chapter in two sentences to someone who has not opened it.',
        ],
        pausePrompt: 'What is the one idea from "$name" you could use today?',
      ),
  ];
}
