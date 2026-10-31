/// The draft an instructor is editing in the course builder.
///
/// **Why this is not just the server's `Course`.** The builder is designed
/// around a curriculum of modules, per-lesson durations and free-preview flags,
/// and the draft is the shape the three steps edit. `CourseBuilderApi` writes it
/// to the wire field by field, so the mapping is visible in one place rather
/// than spread through the widgets.
///
/// Everything here is immutable; the builder replaces the draft wholesale
/// through [copyWith] so a rebuild always reflects one coherent state.
library;

import 'dart:typed_data';

/// Academic vs skill vs premium. The wire values are the model's own choice
/// names.
///
/// **Premium is a paid skill course, not a third curriculum.** It is authored
/// exactly like a skill course — a category, no subject/grade, no placement
/// test — and the one thing that separates it is the price: there is no free
/// premium course. The chip row in step 1 builds itself from [values], so the
/// type is offered wherever the builder is.
enum CourseKind {
  skill,
  academic,
  premium;

  String get wire => name;

  String get label => switch (this) {
    CourseKind.skill => 'Skill course',
    CourseKind.academic => 'Academic',
    CourseKind.premium => 'Premium',
  };

  /// The one-word form, for summary lines that already say "course".
  String get shortLabel => switch (this) {
    CourseKind.skill => 'Skill',
    CourseKind.academic => 'Academic',
    CourseKind.premium => 'Premium',
  };

  /// True for every kind authored like a skill course: category, no subject or
  /// grade. Premium is one of those.
  bool get isSkillLike => this != CourseKind.academic;

  /// A premium course is paid by definition. There is no such thing as a free
  /// one, so the builder cannot offer the choice.
  bool get isAlwaysPaid => this == CourseKind.premium;

  static CourseKind fromWire(Object? value) => switch (value) {
    'academic' => CourseKind.academic,
    'premium' => CourseKind.premium,
    _ => CourseKind.skill,
  };
}

/// The four content types the server accepts. Deliberately closed: `quiz` is
/// not one of them, and a quiz is authored through its own surface.
enum LessonKind {
  video,
  pdf,
  text,
  ebook;

  String get wire => name;

  String get label => switch (this) {
    LessonKind.video => 'Video',
    LessonKind.pdf => 'PDF',
    LessonKind.text => 'Text',
    LessonKind.ebook => 'Ebook',
  };

  /// What the row prints under the lesson title.
  String get tag => switch (this) {
    LessonKind.video => 'VIDEO',
    LessonKind.pdf => 'PDF',
    LessonKind.text => 'TEXT',
    LessonKind.ebook => 'EBOOK',
  };

  /// Text lessons carry their content inline; every other type needs a link or
  /// an upload.
  bool get usesBody => this == LessonKind.text;

  static LessonKind fromWire(Object? value) {
    for (final kind in LessonKind.values) {
      if (kind.name == value) return kind;
    }
    return LessonKind.video;
  }
}

enum CourseLevel {
  beginner,
  intermediate,
  advanced;

  String get label => switch (this) {
    CourseLevel.beginner => 'Beginner',
    CourseLevel.intermediate => 'Intermediate',
    CourseLevel.advanced => 'Advanced',
  };

  static CourseLevel? fromWire(Object? value) {
    for (final level in CourseLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }
}

/// One lesson in the builder.
///
/// [key] is a client-side identity used for list keys and for addressing a
/// lesson while it has no server id yet. [id] is null until the lesson has been
/// saved, which is the only thing that distinguishes "new" from "existing" on
/// the wire.
class CourseLesson {
  const CourseLesson({
    required this.key,
    required this.title,
    required this.kind,
    this.id,
    this.duration,
    this.isPreview = false,
    this.contentUrl,
    this.contentText,
  });

  final String key;
  final int? id;
  final String title;
  final LessonKind kind;
  final Duration? duration;
  final bool isPreview;
  final String? contentUrl;
  final String? contentText;

  /// `04:12`, or an em dash when the duration is unknown. Unknown only happens
  /// on a lesson loaded from a server that does not store durations yet.
  String get durationLabel {
    final value = duration;
    if (value == null) return '—';
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) return '${value.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  /// The second line of a curriculum row: `VIDEO · 04:12 · Free preview`.
  String get metaLabel {
    final parts = <String>[kind.tag, durationLabel];
    if (isPreview) parts.add('Free preview');
    return parts.join(' · ');
  }

  CourseLesson copyWith({
    String? title,
    LessonKind? kind,
    Duration? duration,
    bool? isPreview,
    String? contentUrl,
    String? contentText,
    int? id,
    bool clearDuration = false,
  }) {
    return CourseLesson(
      key: key,
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      duration: clearDuration ? null : (duration ?? this.duration),
      isPreview: isPreview ?? this.isPreview,
      contentUrl: contentUrl ?? this.contentUrl,
      contentText: contentText ?? this.contentText,
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'kind': kind.wire,
    'durationSeconds': duration?.inSeconds,
    'isPreview': isPreview,
    'contentUrl': contentUrl,
    'contentText': contentText,
  };
}

/// A named group of lessons.
///
/// **Grouping is persisted as `Lesson.section`** — a plain string on each
/// lesson, added by backend commit `ed3a273`; there is no module table. The
/// builder assigns each lesson a global `order` (module order, then position
/// inside it) *and* the module's name as its section, so both the sequence and
/// the boundaries survive a save. [CourseDraft.fromServer] rebuilds the modules
/// from those strings.
///
/// The consequences worth knowing: renaming a module has to re-push every lesson
/// in it, which `_syncOrders` in `course_builder_page.dart` does; and two modules
/// with the same name merge on reload, because the server cannot tell them apart.
class CourseModule {
  const CourseModule({
    required this.key,
    required this.title,
    this.lessons = const [],
  });

  final String key;
  final String title;
  final List<CourseLesson> lessons;

  Duration get totalDuration => lessons.fold(
    Duration.zero,
    (total, lesson) => total + (lesson.duration ?? Duration.zero),
  );

  /// `3 lessons · 12 min`, matching the card header in the design.
  String get metaLabel {
    final count = lessons.length;
    final plural = count == 1 ? 'lesson' : 'lessons';
    final minutes = totalDuration.inMinutes;
    if (minutes <= 0) return '$count $plural';
    return '$count $plural · $minutes min';
  }

  CourseModule copyWith({String? title, List<CourseLesson>? lessons}) =>
      CourseModule(
        key: key,
        title: title ?? this.title,
        lessons: lessons ?? this.lessons,
      );
}

/// A cover the instructor picked, before it has been uploaded.
///
/// The **file name travels with the bytes** because the upload is multipart and
/// the server infers the content type from the extension. A PNG labelled
/// `cover.jpg` is rejected by any server that checks, so guessing here would
/// turn a working picker into a 400 for half the images a phone produces.
class PickedCover {
  const PickedCover({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// One file in a **batch** upload — a worksheet, a template, a starter pack.
///
/// Same reasoning as [PickedCover]: the bytes travel with the name, because the
/// server infers the content type from the extension. Separate type because a
/// batch is what `POST /courses/{id}/assets/` takes under `files`, and reusing
/// the cover type would suggest a course may have several covers.
class PickedFile {
  const PickedFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// The whole editable course.
class CourseDraft {
  const CourseDraft({
    this.id,
    this.title = '',
    this.description = '',
    this.kind = CourseKind.skill,
    this.level,
    this.category,
    this.isPaid = false,
    this.price = '',
    this.outcomes = const [],
    this.requirements = const [],
    this.modules = const [],
    this.cover,
    this.coverUrl,
    this.language = defaultLanguage,
    this.isPublished = false,
    this.subjectId,
    this.gradeId,
    this.skillCategoryId,
    this.premiumCategoryId,
  });

  /// The languages the builder offers. Deliberately a closed list for now: the
  /// server stores one string, and a free-text field would let an instructor
  /// type `eng` and split the language row into a dozen spellings.
  static const languages = <String>['English', 'Nepali', 'Hindi'];

  /// What a course is saved as when the instructor has not touched the picker.
  /// The dev catalogue is English, and `Course.language` is a plain string on
  /// the server, so this is a default rather than a constraint.
  static const defaultLanguage = 'English';

  /// The server id, null until step 1 has been saved once.
  final int? id;
  final String title;
  final String description;
  final CourseKind kind;
  final CourseLevel? level;

  /// The category's **name**, for display only.
  ///
  /// The wire wants an id — see [skillCategoryId]. Kept because the picker and
  /// the summary card both print a label, and because a course loaded from the
  /// server carries `skill_category_name` even when the id lookup has not run.
  final String? category;

  /// The category's **id**, which is what `skill_category` on the wire takes.
  ///
  /// `LearningInterest` is a table with 15 rows (Coding, Drawing, Public
  /// Speaking, Music, …), so a name is not addressable — sending one is silently
  /// ignored by the server, and the course then appears under no Skill chip at
  /// all. This is the field that makes the chips work.
  final int? skillCategoryId;

  /// The id a **premium** course is filed under, sent as `premium_category`.
  ///
  /// **A different list, not the same one.** Premium courses use
  /// `PremiumCategory` (`/premium-categories/` — Art & Craft, Design, Physics,
  /// Business, Technology, Music), because `LearningInterest` is the student's
  /// own skill taxonomy: the signup interests step reads it, so filing premium
  /// courses there would put "Business" in front of a student picking what they
  /// want to learn. Exactly one of the two ids is ever set; the server nulls the
  /// other one.
  final int? premiumCategoryId;

  final bool isPaid;

  /// Kept as the user's text rather than a double: the field is mid-edit most of
  /// the time, and `'1299.'` must not be rounded out from under them.
  final String price;

  final List<String> outcomes;
  final List<String> requirements;
  final List<CourseModule> modules;

  /// The cover the instructor just picked, not yet uploaded.
  ///
  /// Held in memory only. The picker renders it immediately, and the page
  /// uploads it once the course has an id — [coverUrl] is the durable half.
  final PickedCover? cover;

  /// The cover the server already has, from `thumbnail_url`.
  ///
  /// Cleared the moment a new file is picked, so a half-finished replacement
  /// never renders the old picture beside the new one.
  final String? coverUrl;

  /// `English` / `Nepali` / `Hindi` — one value, sent as `Course.language`.
  final String language;

  final bool isPublished;

  /// Academic courses need both; the server rejects one without the other.
  final int? subjectId;
  final int? gradeId;

  bool get hasId => id != null;

  int get lessonCount =>
      modules.fold(0, (total, module) => total + module.lessons.length);

  Duration get totalDuration => modules.fold(
    Duration.zero,
    (total, module) => total + module.totalDuration,
  );

  bool get hasEveryDuration => modules.every(
    (module) => module.lessons.every((l) => l.duration != null),
  );

  /// Whether another module already carries [title].
  ///
  /// **This is a real constraint, not a style rule.** The server has no module
  /// table — a module survives only as the `section` string every one of its
  /// lessons carries. Two modules named the same therefore reload as one, and
  /// the instructor's curriculum silently loses a divider. Keeping names unique
  /// on this side is what makes the storage shape safe; nothing server-side can
  /// enforce it.
  ///
  /// Case- and whitespace-insensitive, because "Foundations" and "foundations "
  /// are the same section once the server trims and stores them. [exceptKey]
  /// lets a rename keep its own name.
  bool hasModuleTitle(String title, {String? exceptKey}) {
    final wanted = title.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    for (final module in modules) {
      if (module.key == exceptKey) continue;
      if (module.title.trim().toLowerCase() == wanted) return true;
    }
    return false;
  }

  double? get parsedPrice {
    final cleaned = price.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// The initials the generated cover prints, e.g. `DI`.
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

  CourseDraft copyWith({
    int? id,
    String? title,
    String? description,
    CourseKind? kind,
    CourseLevel? level,
    String? category,
    bool? isPaid,
    String? price,
    List<String>? outcomes,
    List<String>? requirements,
    List<CourseModule>? modules,
    PickedCover? cover,
    String? coverUrl,
    String? language,
    bool? isPublished,
    int? subjectId,
    int? gradeId,
    int? skillCategoryId,
    int? premiumCategoryId,
    bool clearLevel = false,
    bool clearCategory = false,
    bool clearCover = false,
  }) {
    final nextKind = kind ?? this.kind;
    return CourseDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: nextKind,
      level: clearLevel ? null : (level ?? this.level),
      category: clearCategory ? null : (category ?? this.category),
      skillCategoryId: clearCategory
          ? null
          : (skillCategoryId ?? this.skillCategoryId),
      premiumCategoryId: clearCategory
          ? null
          : (premiumCategoryId ?? this.premiumCategoryId),
      // **Premium is paid, always.** Enforced on the way through `copyWith`
      // rather than in the chip, so every path that can produce a premium draft
      // obeys it — switching type, loading an existing course, restoring one.
      isPaid: nextKind.isAlwaysPaid ? true : (isPaid ?? this.isPaid),
      price: price ?? this.price,
      outcomes: outcomes ?? this.outcomes,
      requirements: requirements ?? this.requirements,
      modules: modules ?? this.modules,
      cover: clearCover ? null : (cover ?? this.cover),
      coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
      language: language ?? this.language,
      isPublished: isPublished ?? this.isPublished,
      subjectId: subjectId ?? this.subjectId,
      gradeId: gradeId ?? this.gradeId,
    );
  }

  /// Builds a draft from a `GET /courses/{id}/` body plus its lesson list.
  ///
  /// **Modules are restored from `Lesson.section`**, added by backend commit
  /// `ed3a273`. Sections are ordered by first appearance, which is also the
  /// order they were saved in: the server returns lessons ordered by `order`, and
  /// the builder writes `order` module-by-module.
  ///
  /// A lesson with no section — a course built before sections existed, or one
  /// created straight through the API — lands in a single module named
  /// [orphanSectionTitle] rather than vanishing from the screen. That module is
  /// only a display container: saving it back writes `section: null` again, so
  /// unsectioned content is not silently renamed.
  static CourseDraft fromServer(
    Map<String, dynamic> course,
    List<Map<String, dynamic>> lessons,
  ) {
    // LinkedHashMap: iteration order is first-appearance order, which is the
    // module order we want, so no separate index list is needed.
    final grouped = <String?, List<CourseLesson>>{};
    for (var index = 0; index < lessons.length; index++) {
      final row = lessons[index];
      final section = _sectionOf(row['section']);
      (grouped[section] ??= <CourseLesson>[]).add(
        CourseLesson(
          key: 'lesson-${row['id'] ?? index}',
          id: row['id'] is int ? row['id'] as int : null,
          title: (row['title'] as String?)?.trim() ?? 'Untitled lesson',
          kind: LessonKind.fromWire(row['content_type']),
          isPreview: row['is_preview'] == true,
          contentUrl: (row['content_url'] as String?)?.trim().isEmpty ?? true
              ? null
              : (row['content_url'] as String).trim(),
          contentText: (row['content_text'] as String?)?.trim().isEmpty ?? true
              ? null
              : (row['content_text'] as String).trim(),
          duration: row['duration_seconds'] is int
              ? Duration(seconds: row['duration_seconds'] as int)
              : null,
        ),
      );
    }

    final kind = CourseKind.fromWire(course['course_type']);
    return CourseDraft(
      id: course['id'] is int ? course['id'] as int : null,
      title: (course['title'] as String?) ?? '',
      description: (course['description'] as String?) ?? '',
      kind: kind,
      level: CourseLevel.fromWire(course['level']),
      // The two taxonomies have separate name fields, so a premium course must
      // read its own or the picker shows the wrong label.
      category: kind.isAlwaysPaid
          ? course['premium_category_name'] as String?
          : course['skill_category_name'] as String?,
      skillCategoryId: course['skill_category'] is int
          ? course['skill_category'] as int
          : null,
      premiumCategoryId: course['premium_category'] is int
          ? course['premium_category'] as int
          : null,
      isPaid: kind.isAlwaysPaid || course['is_paid'] == true,
      price: course['price'] == null ? '' : '${course['price']}',
      outcomes: _stringList(course['learning_outcomes']),
      requirements: _stringList(course['requirements']),
      isPublished: course['is_published'] == true,
      coverUrl: _urlOf(course['thumbnail_url']),
      language: _languageOf(course['language']),
      subjectId: course['subject'] is int ? course['subject'] as int : null,
      gradeId: course['grade'] is int ? course['grade'] as int : null,
      modules: [
        for (final (index, entry) in grouped.entries.indexed)
          CourseModule(
            key: 'module-$index',
            title: entry.key ?? orphanSectionTitle,
            lessons: entry.value,
          ),
      ],
    );
  }

  /// The module a lesson with no `section` is displayed in. Never written back.
  static const orphanSectionTitle = 'Lessons';

  static String? _urlOf(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// A course saved before `Course.language` existed reads back blank; the
  /// picker then shows the default rather than an empty selection.
  static String _languageOf(Object? value) {
    final trimmed = value is String ? value.trim() : '';
    if (trimmed.isEmpty) return defaultLanguage;
    for (final language in languages) {
      if (language.toLowerCase() == trimmed.toLowerCase()) return language;
    }
    // An unknown value is kept rather than replaced: it is the server's answer,
    // and silently rewriting it to English would make the builder lie.
    return trimmed;
  }

  static String? _sectionOf(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}

/// The six rows of the "Before you publish" checklist.
///
/// A value type rather than six booleans so the step widget cannot show one row
/// as passing while the publish call disagrees: [CourseDraft] answers once and
/// both read the same answer.
class PublishReadiness {
  const PublishReadiness({
    required this.detailsComplete,
    required this.hasLesson,
    required this.durationsComplete,
    required this.priceSet,
    required this.placementChosen,
    required this.instructorVerified,
  });

  final bool detailsComplete;
  final bool hasLesson;
  final bool durationsComplete;
  final bool priceSet;

  /// A skill course has a category; an academic one has a subject **and** a
  /// grade; a premium one has a **premium** category.
  ///
  /// **This is what makes a published course findable.** The Skills tab filters
  /// on the category and the Courses tab on the grade, so a course missing one
  /// is published and reachable by nobody — the exact "I added a course and it
  /// is not there" complaint. The server rejects a half-placed academic course
  /// outright, but it accepts a skill course with no category.
  ///
  /// Premium reads its own list here, not the skill one: they are separate
  /// tables, and a premium course filed under a skill category would sit in a
  /// taxonomy its own catalogue does not show.
  final bool placementChosen;

  final bool instructorVerified;

  bool get canPublish =>
      detailsComplete &&
      hasLesson &&
      durationsComplete &&
      priceSet &&
      placementChosen &&
      instructorVerified;

  static PublishReadiness of(
    CourseDraft draft, {
    required bool instructorVerified,
  }) {
    return PublishReadiness(
      detailsComplete:
          draft.title.trim().isNotEmpty && draft.description.trim().isNotEmpty,
      hasLesson: draft.lessonCount > 0,
      durationsComplete: draft.hasEveryDuration,
      priceSet: !draft.isPaid || (draft.parsedPrice ?? 0) > 0,
      placementChosen: switch (draft.kind) {
        CourseKind.academic => draft.subjectId != null && draft.gradeId != null,
        CourseKind.premium => draft.premiumCategoryId != null,
        CourseKind.skill => draft.skillCategoryId != null,
      },
      instructorVerified: instructorVerified,
    );
  }
}
