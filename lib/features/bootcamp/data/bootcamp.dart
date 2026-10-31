import '../../../core/widgets/course_detail_view.dart';

/// The ICT & AI Bootcamp, as the app sees it.
///
/// **A bootcamp is a `Course` with a `BootcampProfile`**, not a separate entity:
/// `course_type == 'bootcamp'`, and `GET /courses/{id}/` flattens the profile
/// onto the course row (`venue_name`, `days`, `starts_on`, `ends_on`, `status`,
/// `episode_no`, `short_description`, `hero_video_url`, `hero_poster_url`,
/// `quality_label`, `view_count`) plus an `instructors` roster.
///
/// **Only an administrator can create one**, from the Django dashboard — the
/// app has no authoring path at all (`CourseKind` has no bootcamp member) and
/// the API answers `403 ADMIN_ONLY` to every other role. This file is read-only
/// on purpose.
///
/// The models are bootcamp-shaped rather than reusing [CourseDetailData]
/// because the design is a *player*: day tabs, a per-day curriculum, a resource
/// pack grouped by section, and a venue/date/roster block that no other course
/// type has.
class BootcampCard {
  const BootcampCard({
    required this.id,
    required this.title,
    required this.venueName,
    required this.days,
    required this.studentsEnrolled,
    required this.viewCount,
    required this.image,
    required this.qualityLabel,
    required this.status,
  });

  final int id;
  final String title;
  final String venueName;

  /// The camp's run, e.g. `4`. Also what the rail's duration filter matches on.
  final int days;

  final int studentsEnrolled;
  final int viewCount;

  /// `hero_poster_url`, else `thumbnail_url`, else `''`.
  ///
  /// Empty is a real state — the rail draws its bundled camp artwork instead,
  /// which is what the design shipped with.
  final String image;

  final String qualityLabel;

  /// `upcoming | ongoing | completed | cancelled`.
  final String status;

  /// The rail's third pill: `2.5K VIEWS`, or the run when nobody has watched.
  ///
  /// Upper case to match the pill beside it (`SKILL SIKKA`); the student count
  /// keeps the natural `12.4k students`, which is prose rather than a label.
  String get viewLabel => viewCount <= 0
      ? '$days DAYS'
      : '${compactCount(viewCount).toUpperCase()} VIEWS';

  static BootcampCard? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    if (id is! int) return null;
    final profile = value['bootcamp_profile'];
    final profileMap = profile is Map ? profile : const <String, dynamic>{};

    return BootcampCard(
      id: id,
      title: _str(value['title'], fallback: 'Bootcamp'),
      venueName: _str(value['venue_name'] ?? profileMap['venue_name']),
      days: _int(value['days'] ?? profileMap['days']) ?? 0,
      studentsEnrolled: _int(value['students_enrolled']) ?? 0,
      viewCount: _int(value['view_count'] ?? profileMap['view_count']) ?? 0,
      image: _imageOf(value, profileMap),
      qualityLabel: _str(value['quality_label'] ?? profileMap['quality_label']),
      status: _str(
        value['status'] ?? profileMap['status'],
        fallback: 'upcoming',
      ),
    );
  }
}

/// Everything the bootcamp screen renders.
class BootcampDetail {
  const BootcampDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.shortDescription,
    required this.venueName,
    required this.status,
    required this.heroVideoUrl,
    required this.heroPosterUrl,
    required this.image,
    required this.qualityLabel,
    required this.level,
    required this.language,
    required this.durationDays,
    required this.studentsEnrolled,
    required this.viewCount,
    required this.startsOn,
    required this.endsOn,
    required this.instructorNames,
    required this.days,
    required this.fileSections,
    required this.lessonCount,
    this.episodeNo,
  });

  final int id;
  final String title;
  final String description;

  /// The two-line lede under the title. Falls back to [description] when the
  /// admin did not write one, so the collapsed block is never empty on a camp
  /// that has a description.
  final String shortDescription;

  final String venueName;

  /// `upcoming | ongoing | completed | cancelled`.
  final String status;

  /// A remote MP4. Empty means the hero is the poster, and the play control is
  /// not drawn — a play button over a still that cannot play is a lie.
  final String heroVideoUrl;
  final String heroPosterUrl;

  /// The card/poster image, already absolute (`CourseSerializer` resolves it).
  final String image;

  /// e.g. `HD`. Empty hides the tag.
  final String qualityLabel;

  final String level;
  final String language;

  /// `days` from the profile — the camp's run, not its lesson count.
  final int durationDays;

  final int studentsEnrolled;
  final int viewCount;

  final DateTime? startsOn;
  final DateTime? endsOn;

  /// The roster, lead first. Empty renders `—`.
  final List<String> instructorNames;

  /// The curriculum, grouped by `Lesson.day_number` and then by `section`.
  final List<BootcampDay> days;

  /// The Resources tab, grouped by `CourseResource.section`.
  final List<BootcampFileSection> fileSections;

  final int lessonCount;

  /// The pill beside `Discussions`. Null hides it.
  final int? episodeNo;

  /// What the collapsed description prints.
  String get lede =>
      shortDescription.isNotEmpty ? shortDescription : description;

  /// `4 days` — the design's first title line.
  String get runLabel => durationDays == 1 ? '1 day' : '$durationDays days';

  /// `12.4k students`, `1 student`, or `No students yet`.
  String get studentsLabel {
    if (studentsEnrolled <= 0) return 'No students yet';
    if (studentsEnrolled == 1) return '1 student';
    return '${compactCount(studentsEnrolled)} students';
  }

  /// `Shuvanga Karki, Amrit Bhandari` — the expanded `Instructor:` row.
  String get instructorLine =>
      instructorNames.isEmpty ? '—' : instructorNames.join(', ');

  /// `Oct 2026`.
  String get releasedLabel => startsOn == null ? '—' : monthYear(startsOn!);

  /// `21 – 24 Sep 2026`, or the single day.
  String get dateRangeLabel {
    final start = startsOn;
    final end = endsOn;
    if (start == null) return '—';
    if (end == null || end == start) return _dayMonthYear(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${end.day} ${monthYear(start)}';
    }
    return '${_dayMonthYear(start)} – ${_dayMonthYear(end)}';
  }

  /// `Upcoming`, `Ongoing`, `Completed`, `Cancelled`.
  String get statusLabel => switch (status) {
    'ongoing' => 'Ongoing',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => 'Upcoming',
  };

  bool get isLive => status == 'ongoing';

  static BootcampDetail fromWire({
    required Map<String, dynamic> course,
    required List<Map<String, dynamic>> lessons,
    List<CourseResource> resources = const [],
  }) {
    final profile = course['bootcamp_profile'];
    final profileMap = profile is Map ? profile : const <String, dynamic>{};

    Object? pick(String key) => course[key] ?? profileMap[key];

    return BootcampDetail(
      id: _int(course['id']) ?? 0,
      title: _str(course['title'], fallback: 'Bootcamp'),
      description: _str(course['description']),
      shortDescription: _str(pick('short_description')),
      venueName: _str(pick('venue_name')),
      status: _str(pick('status'), fallback: 'upcoming'),
      heroVideoUrl: _str(pick('hero_video_url')),
      heroPosterUrl: _str(pick('hero_poster_url')),
      image: _imageOf(course, profileMap),
      qualityLabel: _str(pick('quality_label')),
      level: _str(course['level']),
      language: _str(course['language']),
      durationDays: _int(pick('days')) ?? 0,
      studentsEnrolled: _int(course['students_enrolled']) ?? 0,
      viewCount: _int(pick('view_count')) ?? 0,
      startsOn: _date(pick('starts_on')),
      endsOn: _date(pick('ends_on')),
      instructorNames: _roster(course['instructors']),
      days: _curriculum(lessons),
      fileSections: _files(resources),
      lessonCount: lessons.length,
      episodeNo: _int(pick('episode_no')),
    );
  }
}

/// One Day tab.
class BootcampDay {
  const BootcampDay(this.number, this.sections);

  /// `Lesson.day_number`, 1-based.
  final int number;

  final List<BootcampSection> sections;

  String get label => 'Day $number';

  int get lessonCount =>
      sections.fold(0, (total, section) => total + section.lessons.length);
}

/// One heading inside a Day tab — `Section 1: Research & Strategy Foundations`.
class BootcampSection {
  const BootcampSection(this.title, this.lessons);

  /// Empty for lessons the admin filed with no section; the header is dropped
  /// then rather than printed blank.
  final String title;

  final List<BootcampLesson> lessons;
}

/// One row in the curriculum.
class BootcampLesson {
  const BootcampLesson({
    required this.number,
    required this.title,
    required this.duration,
    required this.dayNumber,
    required this.section,
    required this.kind,
    required this.isPreview,
    required this.isCompleted,
    this.id,
    this.contentUrl,
    this.contentText,
  });

  /// The number the row prints — sequential across the whole camp, as the
  /// design has it, not the lesson's position within its day.
  final int number;

  final int? id;
  final String title;

  /// `18:45`, or `''` when the admin left it blank.
  final String duration;

  final int dayNumber;
  final String section;
  final CourseLessonKind kind;
  final bool isPreview;
  final bool isCompleted;

  /// **Null means locked.** The server withholds `content_url` from a student
  /// without an active enrolment, so a null here is a paywall, not an empty
  /// lesson.
  final String? contentUrl;
  final String? contentText;

  bool get isPlayable =>
      contentUrl != null && contentUrl!.trim().isNotEmpty ||
      kind.isInlineText && (contentText ?? '').trim().isNotEmpty;
}

/// One heading on the Resources tab.
class BootcampFileSection {
  const BootcampFileSection(this.title, this.files);

  final String title;
  final List<CourseResource> files;
}

// ── wire helpers ────────────────────────────────────────────────────────────

/// The profile nests its copy of these on some payloads and flattens them on
/// others, so both are read rather than assuming one.
String _imageOf(Map<dynamic, dynamic> course, Map<dynamic, dynamic> profile) {
  for (final value in [
    profile['hero_poster_url'],
    course['hero_poster_url'],
    course['thumbnail_url'],
    profile['thumbnail_url'],
  ]) {
    final text = _str(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

List<String> _roster(Object? value) {
  if (value is! List) return const [];
  final names = <String>[];
  for (final row in value) {
    if (row is! Map) continue;
    final name = _str(row['name']);
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}

/// Groups by day, then by section, keeping first-seen order and sorting lessons
/// by `order` — the server's own column, which is what the design's numbering
/// follows.
List<BootcampDay> _curriculum(List<Map<String, dynamic>> rows) {
  final byDay = <int, Map<String, List<Map<String, dynamic>>>>{};
  for (final row in rows) {
    final day = _int(row['day_number']) ?? 1;
    final section = _str(row['section']);
    (byDay[day] ??= <String, List<Map<String, dynamic>>>{})
        .putIfAbsent(section, () => <Map<String, dynamic>>[])
        .add(row);
  }

  var number = 0;
  final days = <BootcampDay>[];
  for (final day in byDay.keys.toList()..sort()) {
    final sections = <BootcampSection>[];
    final groups = byDay[day]!;
    for (final title in groups.keys) {
      final lessons = groups[title]!
        ..sort((a, b) {
          final orderA = _int(a['order']) ?? 0;
          final orderB = _int(b['order']) ?? 0;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return (_int(a['id']) ?? 0).compareTo(_int(b['id']) ?? 0);
        });
      sections.add(
        BootcampSection(title, [
          for (final row in lessons)
            BootcampLesson(
              number: ++number,
              id: _int(row['id']),
              title: _str(row['title'], fallback: 'Untitled lesson'),
              duration: clock(_int(row['duration_seconds'])),
              dayNumber: day,
              section: title,
              kind: CourseLessonKind.fromWire(row['content_type']),
              isPreview: row['is_preview'] == true,
              isCompleted: row['is_completed'] == true,
              contentUrl: _str(row['content_url']).isEmpty
                  ? null
                  : _str(row['content_url']),
              contentText: _str(row['content_text']).isEmpty
                  ? null
                  : _str(row['content_text']),
            ),
        ]),
      );
    }
    days.add(BootcampDay(day, sections));
  }
  return days;
}

/// Groups files by their section heading, first-seen order. A course-wide file
/// with no heading lands in one unnamed group, which the tab renders without a
/// header rather than dropping.
List<BootcampFileSection> _files(List<CourseResource> resources) {
  final grouped = <String, List<CourseResource>>{};
  for (final resource in resources) {
    grouped
        .putIfAbsent(resource.section, () => <CourseResource>[])
        .add(resource);
  }
  return [
    for (final entry in grouped.entries)
      BootcampFileSection(entry.key, entry.value),
  ];
}

String _str(Object? value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value.trim()) : null;

/// `18:45` from seconds; `''` when the admin left the duration blank.
String clock(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

/// `12400` → `12.4k`, `980` → `980`, `1250000` → `1.3m`.
String compactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final thousands = value / 1000;
    return '${_trim(thousands)}k';
  }
  final millions = value / 1000000;
  return '${_trim(millions)}m';
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// `Oct 2026`.
String monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// `24 Sep 2026`.
String _dayMonthYear(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
