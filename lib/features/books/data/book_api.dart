import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'book_library.dart';
import 'catalogue_book.dart';

/// Reads the ebook catalogue and the signed-in reader's shelf.
class BookApi {
  const BookApi(this._client);

  final ApiClient _client;

  Future<List<CatalogueBook>> list({
    String? search,
    String ordering = 'latest',
    int? page,
    int? pageSize,
  }) async {
    final body = await _client.get<dynamic>(
      '/ebooks/',
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'ordering': ordering,
        'page': ?page,
        'page_size': ?pageSize,
      },
    );
    return catalogueBooksFromBody(body);
  }

  Future<CatalogueBook> detail(int id) async {
    final body = await _client.get<Map<String, dynamic>>('/ebooks/$id/');
    return CatalogueBook.fromJson(body);
  }

  Future<void> save(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/ebooks/$id/save/',
      data: const {},
    );
  }

  Future<void> unsave(int id) async {
    await _client.delete('/ebooks/$id/save/');
  }

  /// Claims a zero-price book. The body says access was granted.
  Future<void> getFree(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/ebooks/$id/get-free/',
      data: const {},
    );
  }

  /// Paid checkout. Today the server answers 503 and grants nothing.
  Future<void> buy(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/ebooks/$id/buy/',
      data: const {},
    );
  }

  Future<OwnedBook> openShelf(CatalogueBook book) async {
    final contents = await _client.get<Map<String, dynamic>>(
      '/ebooks/${book.id}/chapters/',
    );
    List<Map<String, dynamic>> bookmarks = const [];
    try {
      final rows = await _client.get<dynamic>('/ebooks/${book.id}/bookmarks/');
      bookmarks = [
        for (final row in rows is List ? rows : const [])
          if (row is Map)
            row.map((key, value) => MapEntry(key.toString(), value)),
      ];
    } on ApiException {
      bookmarks = const [];
    }
    ReadingSettings? settings;
    try {
      final row = await _client.get<Map<String, dynamic>>('/reader/settings/');
      settings = ReadingSettings.fromServer(row);
    } on ApiException {
      settings = null;
    }
    final shelf = BookShelfPayload.fromParts(
      contents: contents,
      bookmarks: bookmarks,
    );
    final owned = ownedFromShelf(book, shelf, settings: settings);
    BookLibrary.instance.adopt(owned);
    return owned;
  }

  Future<void> loadChapterText(OwnedBook book, int index) async {
    final chapter = book.chapters[index];
    final chapterId = chapter.id;
    final bookId = book.id;
    if (chapterId == null || bookId == null) return;
    if (chapter.lead.isNotEmpty || chapter.paragraphs.isNotEmpty) return;
    final body = await _client.get<Map<String, dynamic>>(
      '/ebooks/$bookId/chapters/$chapterId/',
    );
    final row = body['chapter'];
    final content = row is Map ? row['content']?.toString() ?? '' : '';
    final parts = [
      for (final part in content.split('\n\n'))
        if (part.trim().isNotEmpty) part,
    ];
    book.chapters[index] = chapter.copyWith(
      lead: parts.isEmpty ? '' : parts.first,
      paragraphs: parts.length <= 1 ? const [] : parts.sublist(1),
    );
  }

  Future<void> saveProgress(OwnedBook book, {required bool completed}) async {
    final bookId = book.id;
    if (bookId == null || book.chapters.isEmpty) return;
    final chapter = book.chapter;
    final chapterId = chapter.id;
    if (chapterId == null) return;
    final body = await _client.put<Map<String, dynamic>>(
      '/ebooks/$bookId/progress/',
      data: {
        'chapter_id': chapterId,
        'position': {'paragraph': 0, 'offset': 0},
        'completed': completed,
      },
    );
    final percent = body['overall_percentage'];
    if (percent is num) book.percent = percent.round().clamp(0, 100);
    final done = body['completed_chapter_ids'];
    if (done is List) {
      final ids = {
        for (final id in done)
          if (id is int) id,
      };
      book.completed
        ..clear()
        ..addAll([
          for (var i = 0; i < book.chapters.length; i++)
            if (ids.contains(book.chapters[i].id)) i,
        ]);
    }
  }

  Future<void> toggleBookmark(OwnedBook book) async {
    final bookId = book.id;
    if (bookId == null || book.chapters.isEmpty) {
      BookLibrary.instance.toggleCurrentBookmark(book.title);
      return;
    }
    final index = book.currentChapter;
    final existing = book.bookmarkIds[index];
    if (existing != null) {
      await _client.delete('/ebooks/$bookId/bookmarks/$existing/');
      book.bookmarkIds.remove(index);
      book.bookmarks.remove(index);
      return;
    }
    final chapterId = book.chapters[index].id;
    if (chapterId == null) return;
    final body = await _client.post<Map<String, dynamic>>(
      '/ebooks/$bookId/bookmarks/',
      data: {
        'chapter_id': chapterId,
        'position': {'paragraph': 0, 'offset': 0},
      },
    );
    final id = body['id'];
    if (id is int) book.bookmarkIds[index] = id;
    book.bookmarks.add(index);
  }

  Future<void> saveSettings(ReadingSettings settings) async {
    await _client.patch<Map<String, dynamic>>(
      '/reader/settings/',
      data: settings.toServer(),
    );
  }
}

/// Builds the in-memory shelf the place screen already draws.
OwnedBook ownedFromShelf(
  CatalogueBook book,
  BookShelfPayload shelf, {
  ReadingSettings? settings,
}) {
  final chapters = <BookChapter>[];
  var cursor = 1;
  var usesPdf = false;
  for (final row in shelf.chapters) {
    final start = _asInt(row['pdf_page_start']);
    final end = _asInt(row['pdf_page_end']);
    final pdf = start != null && end != null && end >= start;
    if (pdf) usesPdf = true;
    final pageCount = pdf ? end - start + 1 : 1;
    final startPage = pdf ? start : cursor;
    chapters.add(
      BookChapter(
        id: _asInt(row['id']),
        title: _asString(row['title']) ?? 'Chapter',
        subtitle: _minutesLabel(_asInt(row['estimated_reading_minutes']) ?? 0),
        startPage: startPage,
        pageCount: pageCount,
        minutes: _asInt(row['estimated_reading_minutes']) ?? 0,
        lead: '',
        paragraphs: const [],
        pausePrompt: '',
      ),
    );
    cursor = pdf ? end + 1 : cursor + 1;
  }
  final totalPages = usesPdf
      ? chapters.fold<int>(0, (sum, chapter) {
          final end = chapter.startPage + chapter.pageCount - 1;
          return end > sum ? end : sum;
        })
      : chapters.length;
  final completedIds = {
    for (final id in _asList(shelf.progress['completed_chapter_ids']))
      if (id is int) id,
  };
  final completed = <int>{
    for (var i = 0; i < chapters.length; i++)
      if (completedIds.contains(chapters[i].id)) i,
  };
  final lastId = _asInt(shelf.progress['last_chapter_id']);
  var current = 0;
  if (lastId != null) {
    final index = chapters.indexWhere((chapter) => chapter.id == lastId);
    if (index >= 0) current = index;
  }
  final bookmarkIds = <int, int>{};
  final bookmarks = <int>{};
  for (final row in shelf.bookmarks) {
    final chapterId = _asInt(row['chapter_id']) ?? _asInt(row['chapter']);
    final bookmarkId = _asInt(row['id']);
    if (chapterId == null || bookmarkId == null) continue;
    final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (index < 0 || bookmarkIds.containsKey(index)) continue;
    bookmarkIds[index] = bookmarkId;
    bookmarks.add(index);
  }
  final currentChapter = chapters.isEmpty ? null : chapters[current];
  return OwnedBook(
    id: book.id,
    title: book.title,
    author: book.author,
    image: book.coverUrl,
    totalPages: totalPages == 0 ? 1 : totalPages,
    chapters: chapters,
    currentChapter: current,
    pageInChapter: 1,
    overallPage: currentChapter?.startPage ?? 1,
    percent: (_asDouble(shelf.progress['overall_percentage']) ?? 0)
        .round()
        .clamp(0, 100),
    minutesLeft: currentChapter?.minutes ?? 0,
    completed: completed,
    bookmarks: bookmarks,
    bookmarkIds: bookmarkIds,
    reading: settings,
  );
}

String _minutesLabel(int minutes) {
  if (minutes <= 0) return '';
  return minutes == 1 ? '1 min' : '$minutes min';
}

final bookApiProvider = Provider<BookApi>(
  (ref) => BookApi(ref.watch(apiClientProvider)),
);

/// The three cards under Recommended Books.
final homeRecommendedBooksProvider = FutureProvider<List<CatalogueBook>>((
  ref,
) async {
  return ref
      .watch(bookApiProvider)
      .list(ordering: 'highest_rated', page: 1, pageSize: 3);
});

/// The browse page. [search] is the box text, or empty for the first page.
final bookCatalogueProvider =
    FutureProvider.family<List<CatalogueBook>, String>((ref, search) async {
      return ref
          .watch(bookApiProvider)
          .list(search: search, page: 1, pageSize: 50);
    });

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

String? _asString(Object? value) {
  if (value is! String) return null;
  return value;
}

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  return const [];
}
