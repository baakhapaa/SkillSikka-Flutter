/// One row of an instructor's own course list.
///
/// Deliberately smaller than `CourseDraft`: the profile grid needs a title, a
/// price, a cover and whether the course is live — nothing else. Parsing the full
/// draft here would drag the lesson list along with it for every card.
class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    required this.isPublished,
    required this.isPaid,
    this.price,
    this.thumbnailUrl,
    this.lessonCount,
  });

  final int id;
  final String title;
  final bool isPublished;
  final bool isPaid;

  /// A decimal string on the wire (`"1299.00"`), null for a free course.
  final String? price;

  final String? thumbnailUrl;
  final int? lessonCount;

  /// `Rs 1,299`, `Free`, or `Paid` when the price is unreadable.
  String get priceLabel {
    if (!isPaid) return 'Free';
    final raw = price;
    if (raw == null || raw.trim().isEmpty) return 'Paid';
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return 'Rs $raw';
    final rounded = value.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return 'Rs $buffer';
  }

  /// The two initials the generated cover prints when there is no image.
  String get initials {
    final words = title.trim().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) return 'NEW';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static CourseSummary? tryParse(Object? row) {
    if (row is! Map<String, dynamic>) return null;
    final id = row['id'];
    if (id is! int) return null;
    final thumbnail = row['thumbnail_url'];
    return CourseSummary(
      id: id,
      title: (row['title'] as String?)?.trim().isNotEmpty ?? false
          ? (row['title'] as String).trim()
          : 'Untitled course',
      isPublished: row['is_published'] == true,
      isPaid: row['is_paid'] == true,
      price: row['price'] == null ? null : '${row['price']}',
      thumbnailUrl: thumbnail is String && thumbnail.trim().isNotEmpty
          ? thumbnail.trim()
          : null,
      lessonCount: row['lessons_count'] is int
          ? row['lessons_count'] as int
          : null,
    );
  }
}
