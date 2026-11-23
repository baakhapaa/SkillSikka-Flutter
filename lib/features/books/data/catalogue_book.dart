/// One published book from `GET /ebooks/` or `GET /ebooks/{id}/`.
///
/// The screens already have their layout. This only carries the values those
/// slots display.
class CatalogueBook {
  const CatalogueBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.category,
    required this.subjectName,
    required this.difficulty,
    required this.highlights,
    required this.price,
    required this.currency,
    required this.rating,
    required this.isSaved,
    required this.hasReadingAccess,
    required this.action,
  });

  final int id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String category;
  final String subjectName;
  final String difficulty;
  final List<String> highlights;
  final double? price;
  final String currency;
  final double rating;
  final bool isSaved;
  final bool hasReadingAccess;

  /// `get_free`, `read_now`, `continue_reading`, `buy_now`, or `unavailable`.
  final String action;

  String get categoryLabel {
    if (category.trim().isNotEmpty) return category.trim();
    return subjectName.trim();
  }

  /// The two chips under the category. Difficulty first, then one highlight.
  List<String> get tags {
    final chips = <String>[];
    final level = difficulty.trim();
    if (level.isNotEmpty) {
      chips.add(level[0].toUpperCase() + level.substring(1));
    }
    for (final highlight in highlights) {
      final text = highlight.trim();
      if (text.isEmpty || chips.contains(text)) continue;
      chips.add(text);
      if (chips.length == 2) break;
    }
    return chips;
  }

  String get ratingLabel => rating.toStringAsFixed(1);

  /// The PRICE line. Zero is free. A missing price stays a dash.
  String get priceLabel {
    final amount = price;
    if (amount == null) return '\u2014';
    if (amount == 0) return 'Free';
    final shown = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    final unit = currency.trim();
    return unit.isEmpty ? shown : '$unit $shown';
  }

  factory CatalogueBook.fromJson(Map<String, dynamic> row) {
    return CatalogueBook(
      id: _asInt(row['id']) ?? 0,
      title: _asString(row['title']) ?? '',
      author: _asString(row['author']) ?? '',
      description: _asString(row['description']) ?? '',
      coverUrl: _asString(row['cover_url']) ?? '',
      category: _asString(row['category']) ?? '',
      subjectName: _asString(row['subject_name']) ?? '',
      difficulty: _asString(row['difficulty']) ?? '',
      highlights: [
        for (final item in _asList(row['highlights']))
          if (item is String && item.trim().isNotEmpty) item,
      ],
      price: _asDouble(row['price']),
      currency: _asString(row['currency']) ?? 'NPR',
      rating: _asDouble(row['average_rating']) ?? 0,
      isSaved: row['is_saved'] == true,
      hasReadingAccess: row['has_reading_access'] == true,
      action: _asString(row['available_action']) ?? 'unavailable',
    );
  }
}

/// Chapters, progress, and bookmarks for the place screen.
class BookShelfPayload {
  const BookShelfPayload({
    required this.readerMode,
    required this.chapters,
    required this.progress,
    required this.bookmarks,
  });

  final String readerMode;
  final List<Map<String, dynamic>> chapters;
  final Map<String, dynamic> progress;
  final List<Map<String, dynamic>> bookmarks;

  factory BookShelfPayload.fromParts({
    required Map<String, dynamic> contents,
    required List<Map<String, dynamic>> bookmarks,
  }) {
    return BookShelfPayload(
      readerMode: _asString(contents['reader_mode']) ?? 'chapters',
      chapters: [
        for (final row in _asList(contents['chapters']))
          if (row is Map) _stringKeyMap(row),
      ],
      progress: contents['progress'] is Map
          ? _stringKeyMap(contents['progress'] as Map)
          : const {},
      bookmarks: bookmarks,
    );
  }
}

List<CatalogueBook> catalogueBooksFromBody(Object? body) {
  final rows = body is Map && body['results'] is List
      ? body['results'] as List
      : body is List
      ? body
      : const [];
  return [
    for (final row in rows)
      if (row is Map) CatalogueBook.fromJson(_stringKeyMap(row)),
  ];
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> row) {
  return row.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  return const [];
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

String? _asString(Object? value) {
  if (value is! String) return null;
  return value;
}
