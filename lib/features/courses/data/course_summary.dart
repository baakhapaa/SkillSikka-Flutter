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
    this.category = 'Uncategorized',
    this.updatedAt,
    this.durationSeconds,
  });

  final int id;
  final String title;
  final bool isPublished;
  final bool isPaid;

  /// A decimal string on the wire (`"1299.00"`), null for a free course.
  final String? price;

  final String? thumbnailUrl;
  final int? lessonCount;

  /// Skill, premium, or subject name. `Uncategorized` when the row has none.
  final String category;

  final DateTime? updatedAt;

  /// Total lesson time, in seconds, when the server sent it.
  final int? durationSeconds;

  /// `3h 24m total`, or empty when the course has no recorded time.
  String get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m total';
    if (hours > 0) return '${hours}h total';
    return '${minutes}m total';
  }

  /// `Rs 1,299`, `Free`, or **empty**.
  ///
  /// **A free course says `Free`** (product decision, 2026-10-31). This reverses
  /// the 2026-10-30 rule that no card printed the word: the price slot was then
  /// blank for a free course, and a blank slot reads as a card whose price
  /// failed to load. The original objection — that `Free` competed with the
  /// DRAFT/LIVE chip — is answered by the chip keeping its own line.
  ///
  /// `is_paid` still wins over the amount: a paid course whose price is missing
  /// or unreadable prints nothing rather than claiming to be free. The old
  /// `'Paid'` fallback stays gone — that is not a price either.
  String get priceLabel {
    if (!isPaid) return 'Free';
    final raw = price;
    if (raw == null || raw.trim().isEmpty) return '';
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return '';
    final rounded = value.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return 'Rs $buffer';
  }

  static CourseSummary? tryParse(Object? row) {
    if (row is! Map<String, dynamic>) return null;
    final id = row['id'];
    if (id is! int) return null;
    final thumbnail = row['thumbnail_url'];
    final premium = _label(row['premium_category_name']);
    final skill = _label(row['skill_category_name']);
    final subject = _label(row['subject_name']);
    final category = premium.isNotEmpty
        ? premium
        : skill.isNotEmpty
        ? skill
        : subject;
    final updated = row['updated_at'];
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
      category: category.isEmpty ? 'Uncategorized' : category,
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
      durationSeconds: row['total_duration_seconds'] is int
          ? row['total_duration_seconds'] as int
          : null,
    );
  }

  static String _label(Object? value) => value is String ? value.trim() : '';
}
