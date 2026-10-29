import 'package:flutter/material.dart';

import '../../../core/widgets/course_detail_view.dart';
import 'course_cover_art.dart';

/// Maps the course API's wire shapes onto [CourseDetailData].
///
/// **Why an adapter and not a model refactor:** [CourseDetailView] is built on a
/// presentational model with 30 fields, and 34 catalogue entries construct it.
/// Adding a required field to it has broken all 34 twice (2026-10-13,
/// 2026-10-14). This keeps the view untouched and puts every wire-shape decision
/// in one testable function instead.
///
/// **What is filled and what is honestly empty.** Everything the instructor can
/// author in the course builder now reaches this screen:
///
/// | Field | Source |
/// |---|---|
/// | `level` | `Course.level` — `Beginner` / `Intermediate` / `Advanced` |
/// | `languages` | `Course.language`, one value |
/// | `subtitleTracks` | **no field** — dropped by `courseMetaRows` |
/// | `includes` | derived from the course's total duration plus three product rows, see [_includes] |
/// | `resources` | lifted from `pdf`/`ebook` lessons, see [_resources] |
/// | `rating` | `null` on the wire until a course has a review |
///
/// Everything else — title, cover, rating, review count, students, grade,
/// subject, instructor, outcomes, requirements, description, sections, lessons,
/// durations, price, total time — comes from the payload.
class CourseMapper {
  const CourseMapper._();

  /// One row of `GET /courses/` — enough for a grid card, no lessons.
  static CourseDetailData summary(Map<String, dynamic> row) => _build(row);

  /// `GET /courses/{id}/` + `GET /lessons/?course=` + reviews + instructor.
  ///
  /// Every part after the course itself is optional: a detail screen that got
  /// the course but failed on reviews should still render the course.
  static CourseDetailData detail({
    required Map<String, dynamic> course,
    required List<Map<String, dynamic>> lessons,
    List<Map<String, dynamic>> reviews = const [],
    Map<String, dynamic>? instructor,
  }) => _build(
    course,
    lessons: lessons,
    reviews: reviews,
    instructor: instructor,
  );

  static CourseDetailData _build(
    Map<String, dynamic> course, {
    List<Map<String, dynamic>> lessons = const [],
    List<Map<String, dynamic>> reviews = const [],
    Map<String, dynamic>? instructor,
  }) {
    final isAcademic = _str(course['course_type']) == 'academic';
    final subject = _str(course['subject_name']);
    final grade = _str(course['grade_name']);
    final category = _str(course['skill_category_name']);

    final rating = _ratingLabel(course['average_rating']);
    final reviewCount = _int(course['review_count']) ?? 0;
    final modules = _modules(lessons);
    final resources = _resources(lessons);
    final totalSeconds = _int(course['total_duration_seconds']);

    final description = _str(course['description']);
    final updates = _courseUpdates(course);

    // A real cover always wins. Only when the server has none does the bundled
    // subject art stand in — see `course_cover_art.dart` for why that is not
    // inventing data.
    final thumbnail = _str(course['thumbnail_url']);

    return CourseDetailData(
      id: _int(course['id']),
      image: thumbnail.isNotEmpty
          ? thumbnail
          : courseCoverAsset(
              subject: subject,
              category: category,
              title: _str(course['title']),
            ),
      courseType: _str(course['course_type']),
      title: _str(course['title'], fallback: 'Untitled course'),
      // **The description belongs under the title, not in the Description
      // section.** The design — the premium screen and all 34 catalogue
      // entries — puts a one-paragraph lede here and keeps the Description
      // section for the changelog (`Course Updates:`). This used to do the
      // reverse: the category went here and the description became the
      // section's only body, so `Course Updates:` sat above a paragraph of
      // marketing copy. The category line survives only as the fallback for a
      // course that has no description at all, rather than printing nothing.
      subtitle: description.isNotEmpty
          ? description
          : isAcademic
          ? [grade, subject].where((part) => part.isNotEmpty).join(' · ')
          : category,
      rating: rating,
      // `Beginner` / `Intermediate` / `Advanced`, or blank for a course whose
      // instructor never picked one — the meta row then simply does not render.
      level: _levelLabel(course['level']),
      // **An academic course is not enrolled in, it is opened.** The server
      // refuses `POST /courses/{id}/enroll/` for anything that is not a skill
      // course (`COURSE_NOT_ENROLLABLE`) and grants school courses by grade
      // instead, so `Enroll Now` on one of them can only ever fail. The label
      // is the client half of that rule; `startCourse` is the other half.
      enrollLabel: isAcademic ? 'Start Learning' : 'Enroll Now',
      category: isAcademic ? subject : category,
      classLevel: grade,
      ratingsCount: _ratingsCount(reviewCount),
      studentsEnrolled: _studentsEnrolled(_int(course['students_enrolled'])),
      instructorName: _str(course['instructor_name']),
      instructorAvatar: _str(instructor?['profile_photo_url']),
      lastUpdated: _lastUpdated(course['updated_at']),
      languages: _str(course['language']),
      subtitleTracks: '',
      learningOutcomes: _stringList(course['learning_outcomes']),
      curriculumSummary: _curriculumSummary(modules, totalSeconds),
      modules: modules,
      includes: _includes(
        course,
        lessons,
        // The server counts the real resource table; the fallback list only
        // knows about `pdf`/`ebook` lessons. Prefer the server's number when the
        // payload carries it — a list row does not, a detail fetch does.
        _int(course['resources_count']) ?? resources.length,
      ),
      requirements: _stringList(course['requirements']),
      // The Description section is the changelog, as the design has it. With no
      // updates to show, the intro goes too — `Course Updates:` over nothing
      // reads as a broken section.
      descriptionIntro: updates.isEmpty ? '' : 'Course Updates:',
      descriptionBlocks: updates,
      descriptionMoreBlocks: const <CourseDescriptionBlock>[],
      instructors: [_instructor(course, instructor)],
      courseRating: rating,
      ratingBars: _ratingBars(reviews),
      reviews: _reviews(reviews),
      totalTime: _totalTime(totalSeconds),
      resources: resources,
      price: _price(course),
      isPaid: course['is_paid'] == true,
    );
  }

  // ── modules ───────────────────────────────────────────────────────────────

  /// Groups lessons by `section`, in first-seen order.
  ///
  /// The server has no module table — a module is just a string repeated on each
  /// of its lessons — so this is the only place the grouping exists. Lessons with
  /// no section fall into one unnamed container rather than disappearing.
  ///
  /// **A `pdf`/`ebook` row is not a lecture — it is a resource**, and is lifted
  /// into [CourseDetailData.resources] instead (see [_resources]). Leaving it in
  /// the curriculum is what put `PDF` rows in a lecture list the player has
  /// nowhere to play.
  ///
  /// **A `text` row still becomes a lecture**, deliberately. The product has one
  /// lesson type, but a text row carries prose with no file, so it is neither a
  /// lecture the player can stream nor a resource — dropping it would delete
  /// content that is already on the server, and it is the one non-video kind the
  /// player can render without a URL. The builder can no longer create one; the
  /// only rows that exist are the dev seed's.
  ///
  /// **The cost of skipping pdfs is a progress mismatch on bad data.**
  /// `GET /courses/{id}/progress/` counts every lesson row, including the ones
  /// dropped here, so a course carrying pdf rows shows fewer lectures than the
  /// server's `total_lessons` and its local percentage can disagree with My
  /// Learning's. That is exactly the dev seed today (`seed_courses.py:64` makes
  /// a third of the lessons `pdf`); a course whose lessons are all videos —
  /// every course the app can now create — is unaffected.
  static List<CourseModule> _modules(List<Map<String, dynamic>> lessons) {
    final grouped = <String?, List<CourseLesson>>{};
    for (final row in lessons) {
      final kind = CourseLessonKind.fromWire(row['content_type']);
      if (kind.isDocument) continue;
      final section = _str(row['section']).trim();
      (grouped[section.isEmpty ? null : section] ??= <CourseLesson>[]).add(
        CourseLesson(
          _str(row['title'], fallback: 'Untitled lesson'),
          _clock(_int(row['duration_seconds'])),
          id: _int(row['id']),
          isPreview: row['is_preview'] == true,
          kind: kind,
          // The paywall nulls this for a student who is not enrolled, so null is
          // a lock, not an empty lesson — the player decides which by asking
          // whether the course has an id.
          contentUrl: _str(row['content_url']).isEmpty
              ? null
              : _str(row['content_url']),
          contentText: _str(row['content_text']).isEmpty
              ? null
              : _str(row['content_text']),
          // No bundled asset exists for an API lesson; the player prefers
          // `contentUrl` and only falls back to this.
          videoAsset: null,
        ),
      );
    }

    return [
      for (final entry in grouped.entries)
        CourseModule(entry.key ?? '', _minutes(entry.value), entry.value),
    ];
  }

  /// The course's **fallback resource pack**.
  ///
  /// **Real resources come from `GET /courses/{id}/resources/`**, which the
  /// player fetches lazily and which wins whenever it answers a non-empty list
  /// (see `course_player_page.dart`). This function is what a course with no
  /// resource rows falls back to, and it exists for one case: the dev seed
  /// (`seed_courses.py:64`) makes a third of every course's lessons `pdf`, and
  /// those rows were the only file the app ever showed. Dropping them here would
  /// make every seeded course's Resources tab go empty.
  ///
  /// A `pdf`/`ebook` **lesson** is still not a lecture — `_modules` skips it —
  /// so lifting it out here is the only place it can appear. Its `content_url`
  /// is the file, which is why these rows are now openable: they used to carry a
  /// title and nothing else, and the download button was decoration.
  ///
  /// `CourseResourceType.fromFormat` maps `content_type` too, so an `ebook`
  /// labels as `PDF` only because that is what the seed stores it as.
  static List<CourseResource> _resources(List<Map<String, dynamic>> lessons) {
    return [
      for (final row in lessons)
        if (CourseLessonKind.fromWire(row['content_type']).isDocument)
          CourseResource(
            _str(row['title'], fallback: 'Resource'),
            CourseResourceType.fromFormat(row['content_type']),
            id: _int(row['id']),
            url: _str(row['content_url']).isEmpty
                ? null
                : _str(row['content_url']),
          ),
    ];
  }

  // ── includes ──────────────────────────────────────────────────────────────

  /// The rows in **This course includes**.
  ///
  /// **A course's lessons are all videos.** There is no text, PDF or ebook
  /// lesson type in the product: a PDF is a *resource* attached to the course,
  /// not a lecture. So the duration row is the course's own
  /// `total_duration_seconds` — the server's aggregate over every lesson —
  /// rather than a sum filtered by `content_type`, and the support-files row
  /// counts [resourceCount].
  ///
  /// The last three rows are **product policy, not payload**: lifetime access,
  /// mobile/desktop/TV and the certificate hold for every course in the app, and
  /// the catalogue prints the same three on all 34 entries.
  ///
  /// **Quizzes are deliberately missing.** `Quiz` exists and
  /// `GET /courses/{id}/quizzes/` could count them, but it answers
  /// `403 NOT_ENROLLED` to everyone else — a row that appears only for enrolled
  /// students is worse than no row. The fix is `quizzes_count` on the payload.
  static List<CourseInclude> _includes(
    Map<String, dynamic> course,
    List<Map<String, dynamic>> lessons,
    int resourceCount,
  ) {
    // The server's own total, falling back to the lessons we were handed — a
    // list row carries the total but no lessons, a detail fetch carries both.
    final seconds =
        _int(course['total_duration_seconds']) ??
        lessons.fold<int>(
          0,
          (sum, lesson) => sum + (_int(lesson['duration_seconds']) ?? 0),
        );

    return [
      if (seconds > 0)
        CourseInclude(
          Icons.play_circle_outline,
          '${_compact(seconds)} of on-demand video',
        ),
      if (resourceCount > 0)
        CourseInclude(
          Icons.description_outlined,
          '$resourceCount support ${resourceCount == 1 ? 'file' : 'files'}',
        ),
      const CourseInclude(Icons.all_inclusive, 'Full lifetime access'),
      const CourseInclude(Icons.devices, 'Access on mobile, desktop and TV'),
      const CourseInclude(Icons.verified_outlined, 'Certificate of completion'),
    ];
  }

  // ── reviews ───────────────────────────────────────────────────────────────

  static List<CourseReview> _reviews(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows)
        CourseReview(
          name: _studentName(row['student']),
          when: _relativeWhen(row['created_at']),
          body: _str(row['review']),
          stars: _int(row['rating']) ?? 0,
        ),
    ];
  }

  /// The five bars in Student feedback, derived from the reviews we were given.
  ///
  /// The API has no rating distribution endpoint, and `/courses/{id}/reviews/`
  /// is unpaginated, so counting client-side is exact for now. It stops being
  /// exact if the review list is ever paginated — at which point this becomes a
  /// request for a distribution field rather than a silent inaccuracy.
  static List<RatingBar> _ratingBars(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const <RatingBar>[];
    final counts = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
    for (final row in rows) {
      final stars = _int(row['rating']);
      if (stars != null && counts.containsKey(stars)) {
        counts[stars] = counts[stars]! + 1;
      }
    }
    return [
      for (var star = 5; star >= 1; star--)
        RatingBar('$star ★', ((counts[star]! / rows.length) * 100).round()),
    ];
  }

  static String _studentName(Object? value) {
    if (value is Map) return _str(value['name'], fallback: 'A student');
    // The schema types this `string`; the server sends an object. Accept both.
    final name = _str(value);
    return name.isEmpty ? 'A student' : name;
  }

  // ── instructor ────────────────────────────────────────────────────────────

  /// One instructor card. Falls back to the course's own `instructor_name` so
  /// the section is never empty — a course always has an owner.
  static CourseInstructor _instructor(
    Map<String, dynamic> course,
    Map<String, dynamic>? profile,
  ) {
    final name = _str(
      profile?['name'],
      fallback: _str(course['instructor_name'], fallback: 'Instructor'),
    );
    return CourseInstructor(
      avatar: _str(profile?['profile_photo_url']),
      name: name,
      title: _str(
        profile?['qualification'],
        fallback: _str(profile?['subject_expertise']),
      ),
      // **Bare numbers, never `'12 reviews'`.** The card prints each value above
      // its own label (`Rating`, `Reviews`, `Students`, `Courses`), so a unit in
      // the value printed it twice — and `19 courses` in a quarter-width column
      // wrapped onto two lines at 360pt. The catalogue and premium screens have
      // always passed bare numbers; this now matches them.
      rating: _statValue(_ratingLabel(profile?['average_rating'])),
      reviews: _thousands(_int(profile?['review_count']) ?? 0),
      students: _thousands(_int(profile?['total_students']) ?? 0),
      courses: _thousands(_int(profile?['total_courses']) ?? 0),
      bio: _str(profile?['subject_expertise']),
    );
  }

  // ── labels ────────────────────────────────────────────────────────────────

  /// `4.5`, or `''` when the course has no reviews yet.
  ///
  /// The wire type is genuinely inconsistent: `SerializerMethodField` over
  /// `Avg()` means a float or null, while the schema declares `string`. Both are
  /// accepted, and a numeric string is not re-parsed into something odd.
  static String _ratingLabel(Object? value) {
    final number = _number(value);
    if (number == null) return '';
    return number.toStringAsFixed(1);
  }

  static String _ratingsCount(int count) {
    final noun = count == 1 ? 'rating' : 'ratings';
    return '($count $noun)';
  }

  /// `Beginner`, `Intermediate`, `Advanced` — or `''`.
  ///
  /// The wire value is the model's own lowercase choice name, and it is
  /// **capitalised here rather than on the server** so the label can be reworded
  /// without a migration. An unrecognised value is title-cased rather than
  /// dropped: it is still the instructor's answer, and showing `Expert` is
  /// better than showing nothing.
  static String _levelLabel(Object? value) {
    final raw = _str(value);
    if (raw.isEmpty) return '';
    for (final level in const ['Beginner', 'Intermediate', 'Advanced']) {
      if (level.toLowerCase() == raw.toLowerCase()) return level;
    }
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// A stat column's value, with an em dash when the server has nothing to say.
  ///
  /// An instructor with no reviews yet has `average_rating: null`. A blank cell
  /// over the word `Rating` reads as a layout bug, so the card prints the
  /// conventional "no value" mark instead.
  static String _statValue(String value) => value.isEmpty ? '—' : value;

  static String _studentsEnrolled(int? count) {
    final noun = count == 1 ? 'student enrolled' : 'students enrolled';
    return '${_thousands(count ?? 0)} $noun';
  }

  static String _lastUpdated(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) return '';
    final month = parsed.month.toString().padLeft(2, '0');
    return 'Last updated $month/${parsed.year}';
  }

  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// The Description section's changelog: `v 1.0 - October 2026` + `First
  /// release.`
  ///
  /// **The backend has no course-updates column.** `Course` carries `title`,
  /// `description`, `created_at`, `updated_at` and nothing version-shaped, so
  /// the one entry that can be stated without inventing anything is the first
  /// release, dated the day the course was created. A second `v 1.1 — improved
  /// the labs` line would have to be written by us: `updated_at` moves on any
  /// save, including publishing the course, so it cannot be read as "content
  /// changed". A short true changelog beats a plausible false one — the real
  /// fix is a `course_updates` field on the backend.
  ///
  /// Empty when the record has no usable `created_at`; the section then renders
  /// nothing rather than an undated version.
  static List<CourseDescriptionBlock> _courseUpdates(
    Map<String, dynamic> course,
  ) {
    final created = _date(course['created_at']);
    if (created == null) return const <CourseDescriptionBlock>[];
    return [
      CourseDescriptionBlock(
        heading: 'v 1.0 - ${_monthYear(created)}',
        body: 'First release.',
      ),
    ];
  }

  /// `October 2026`. Local time, because the label is read by a person — a
  /// course created at 23:50 UTC on 31 October is a November course here.
  static String _monthYear(DateTime value) {
    final local = value.toLocal();
    return '${_months[local.month - 1]} ${local.year}';
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// `3 sections · 9 lessons · 1hr 1min`, dropping the parts that are unknown.
  ///
  /// The duration is only included when there is at least one lesson: a
  /// curriculum summary reading `1hr` with no sections under it is a claim about
  /// content that is not there.
  static String _curriculumSummary(
    List<CourseModule> modules,
    int? totalSeconds,
  ) {
    final lessons = modules.fold<int>(0, (sum, m) => sum + m.lessons.length);
    final sections = modules.length;
    final parts = <String>[
      if (sections > 0) '$sections ${sections == 1 ? 'section' : 'sections'}',
      if (lessons > 0) '$lessons ${lessons == 1 ? 'lesson' : 'lessons'}',
      if (lessons > 0 && totalSeconds != null && totalSeconds > 0)
        _compact(totalSeconds),
    ];
    return parts.join(' · ');
  }

  /// The bottom bar's `10hrs`. Empty when no lesson has a duration.
  static String _totalTime(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds <= 0) return '';
    return _compact(totalSeconds);
  }

  static String _compact(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${_hours(hours)} ${minutes}min';
    if (hours > 0) return _hours(hours);
    return '${minutes}min';
  }

  static String _hours(int hours) => hours == 1 ? '1hr' : '${hours}hrs';

  /// A section header's `45 mins`, summed from its lessons.
  static String _minutes(List<CourseLesson> lessons) {
    var seconds = 0;
    for (final lesson in lessons) {
      seconds += _clockSeconds(lesson.duration);
    }
    if (seconds == 0) return '';
    return '${(seconds / 60).round()} mins';
  }

  /// `04:12`, or `''` when the lesson has no duration.
  static String _clock(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  /// `mm:ss` back to seconds. Only ever reads what [_clock] wrote.
  static int _clockSeconds(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes * 60 + seconds;
  }

  /// `Rs. 1,299`, or `''` for a free course — the bottom bar leads with the
  /// duration instead when the price is empty.
  static String _price(Map<String, dynamic> course) {
    if (course['is_paid'] != true) return '';
    final raw = _str(course['price']);
    if (raw.isEmpty) return '';
    final value = double.tryParse(raw);
    if (value == null) return 'Rs. $raw';
    return 'Rs. ${_thousands(value.round())}';
  }

  static String _thousands(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// `11 days ago`, `today`, `last month` — enough for a review row.
  static String _relativeWhen(Object? value, {DateTime? now}) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) return '';
    final reference = now ?? DateTime.now();
    final days = reference.difference(parsed.toLocal()).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    final months = days ~/ 30;
    if (months == 1) return 'last month';
    if (months < 12) return '$months months ago';
    final years = days ~/ 365;
    return years <= 1 ? 'last year' : '$years years ago';
  }

  // ── wire primitives ───────────────────────────────────────────────────────

  static String _str(Object? value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// A number from a num or a numeric string. `null` for anything else,
  /// including the JSON `null` that `Avg()` produces for an unreviewed course.
  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}
