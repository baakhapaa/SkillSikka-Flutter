import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../../core/widgets/course_image.dart';
import '../../courses/data/course_api.dart';
import '../../courses/data/course_builder_api.dart';
import '../../courses/data/course_summary.dart';
import '../../courses/data/instructor_analytics.dart';
import '../../courses/presentation/course_builder_page.dart';
import '../../courses/presentation/course_details_page.dart';
import '../../quiz/data/quiz_api.dart';
import '../data/user_profile.dart';

const _ink = Color(0xFF1B1C1E);
const _gray = Color(0xFF77756F);
const _muted = Color(0xFF77756F);
const _line = Color(0xFFE8E5DE);
const _gold = Color(0xFFFFD233);
const _cream = Color(0xFFFFF6D5);
const _page = Color(0xFFFCFBF8);
const _panelBg = Color(0xFFF3F1EB);

/// Cover, status, and the two actions from the course-details frame.
///
/// Edit always opens the current builder. View opens the student course page
/// only when the course is already published.
class InstructorCourseDetailsPage extends ConsumerWidget {
  const InstructorCourseDetailsPage({super.key, required this.course});

  final CourseSummary course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = course.lessonCount;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _roundIcon(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Courses',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        CourseImage(
                          course.thumbnailUrl ?? '',
                          width: double.infinity,
                          height: 174,
                          fallback: const ColoredBox(
                            color: Color(0xFFF3F4F6),
                            child: SizedBox(
                              height: 174,
                              child: Icon(Icons.image_outlined, color: _muted),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _LiveBadge(published: course.isPublished),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    course.title,
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lessons == null
                        ? course.priceLabel
                        : '$lessons lessons'
                              '${course.priceLabel.isEmpty ? '' : '  ·  ${course.priceLabel}'}',
                    style: GoogleFonts.figtree(fontSize: 13, color: _gray),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          icon: Icons.edit_outlined,
                          label: 'Edit course',
                          filled: true,
                          onTap: () => _edit(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          icon: Icons.open_in_new,
                          label: 'Preview',
                          filled: false,
                          onTap: () => _view(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: _panelBg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_DetailsPerformance(course: course)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CourseBuilderPage(
          api: ref.read(courseBuilderApiProvider),
          quizApi: ref.read(quizApiProvider),
          instructorVerified: ref.read(userProfileProvider).canPublish,
          courseId: course.id,
        ),
      ),
    );
  }

  void _view(BuildContext context) {
    if (!course.isPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publish the course before students can open it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(course: _studentPreview(course)),
      ),
    );
  }
}

/// Studio Analytics. Numbers come from
/// `GET /courses/{id}/instructor-analytics/`. A null field stays a dash.
class InstructorCoursePerformancePage extends StatefulWidget {
  const InstructorCoursePerformancePage({super.key, required this.course});

  final CourseSummary course;

  @override
  State<InstructorCoursePerformancePage> createState() =>
      _InstructorCoursePerformancePageState();
}

class _InstructorCoursePerformancePageState
    extends State<InstructorCoursePerformancePage> {
  static const _periods = ['7 days', 'Last 30 days', '90 days', 'All time'];
  var _period = 'Last 30 days';

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final lessons = course.lessonCount;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                _roundIcon(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANALYTICS',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _muted,
                        ),
                      ),
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CourseImage(
                      course.thumbnailUrl ?? '',
                      width: 56,
                      height: 56,
                      fallback: const ColoredBox(
                        color: Color(0xFFF3F4F6),
                        child: Icon(Icons.image_outlined, color: _muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.isPublished
                              ? 'Published course'
                              : 'Draft course',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: _gray,
                          ),
                        ),
                        Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        Text(
                          lessons == null
                              ? 'Lessons'
                              : '$lessons lessons · Active cohort',
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in _periods) ...[
                    _PeriodChip(
                      label: period,
                      selected: period == _period,
                      onTap: () => setState(() => _period = period),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CourseFigures(
              courseId: course.id,
              period: analyticsPeriodQuery(_period),
              builder: (context, detail, analytics) {
                final enrolled = _enrolledNow(detail, analytics);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DashMetric(
                            label: 'Total revenue',
                            value: formatAnalyticsMoney(
                              analytics?.revenue.amount,
                            ),
                            note: _moneyNote(analytics?.revenue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashMetric(
                            label: 'Total students',
                            value: enrolled == null ? '—' : '$enrolled',
                            note: _studentsNote(analytics, enrolled),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DashMetric(
                            label: 'Watch time',
                            value: formatWatchTime(analytics?.watchTimeSeconds),
                            note: _watchNote(analytics),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashMetric(
                            label: 'Avg. completion',
                            value: formatAnalyticsPercent(
                              analytics?.avgCompletionPercent,
                            ),
                            note: _completionNote(analytics),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EnrollmentChartCard(
                      title: 'Enrollments & Activity',
                      total: analytics?.students.newInPeriod,
                      delta: formatSignedPercent(
                        analytics?.students.deltaPercent,
                      ),
                      days: analytics?.enrollmentsByDay ?? const [],
                      note: _insight(analytics),
                    ),
                    const SizedBox(height: 12),
                    _RetentionCard(
                      lessonCount: lessons,
                      modules: detail?.modules ?? const [],
                      sections: analytics?.retention ?? const [],
                    ),
                    const SizedBox(height: 12),
                    _SourcesCard(sources: analytics?.sources ?? const []),
                    const SizedBox(height: 12),
                    _SatisfactionCard(detail: detail),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _studioButton(
                    icon: Icons.campaign_outlined,
                    label: 'Promote Course',
                    filled: true,
                    onTap: () => _soon(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _studioButton(
                    icon: Icons.tune,
                    label: 'Adjust Cohort',
                    filled: false,
                    onTap: () => _soon(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This action is not connected yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({
    required this.lessonCount,
    this.modules = const [],
    this.sections = const [],
  });

  final int? lessonCount;
  final List<CourseModule> modules;
  final List<SectionRetention> sections;

  @override
  Widget build(BuildContext context) {
    final recorded = sections.isNotEmpty;
    final rows = recorded
        ? [
            for (final section in sections)
              (
                section.section,
                '${section.lessonCount} lessons'
                    '${section.completionPercent == null ? '' : ' · ${formatAnalyticsPercent(section.completionPercent)}'}',
                section.completionPercent,
              ),
          ]
        : modules.isEmpty
        ? <(String, String, double?)>[
            (
              'Lessons',
              lessonCount == null ? '—' : '$lessonCount lessons',
              null,
            ),
          ]
        : [
            for (final module in modules)
              (
                module.title,
                '${module.lessons.length} lessons'
                    '${module.duration.isEmpty ? '' : ' · ${module.duration}'}',
                null,
              ),
          ];
    return _panel(
      title: 'Curriculum Retention',
      trailing: '${rows.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recorded
                ? 'Share of enrolled students who finished the section.'
                : 'Module completion is not recorded. Lesson counts are.',
            style: GoogleFonts.figtree(fontSize: 12, color: _gray),
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(6)) ...[
            Text(
              row.$1,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              row.$2,
              style: GoogleFonts.figtree(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: row.$3 == null
                    ? 0
                    : (row.$3! / 100).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFF3F4F6),
                color: _gold,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({this.sources = const []});

  final List<EnrollmentSourceShare> sources;

  static const _placeholders = <(Color, String, String)>[
    (Color(0xFFF6C945), 'Direct & Newsletter', 'Studio link sharing'),
    (Color(0xFF22C55E), 'Organic Search / SEO', 'Course discovery platform'),
    (Color(0xFF9CA3AF), 'Social & Referrals', 'Alumni shares & X / LinkedIn'),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = sources.isEmpty
        ? [
            for (final source in _placeholders)
              (source.$1, source.$2, source.$3, '—', '—'),
          ]
        : [
            for (final source in sources)
              (
                _sourceColor(source.key),
                _sourceTitle(source.key),
                _sourceCaption(source.key),
                formatAnalyticsPercent(source.sharePercent),
                source.conversionPercent == null
                    ? '—'
                    : formatAnalyticsPercent(source.conversionPercent),
              ),
          ];
    final shares = [
      for (final source in sources)
        if ((source.sharePercent ?? 0) > 0) source,
    ];
    return _panel(
      title: 'Enrollment Sources',
      trailing: 'Conversion',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 10,
              width: double.infinity,
              child: shares.isEmpty
                  ? const ColoredBox(color: Color(0xFFF3F4F6))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final source in shares)
                          Expanded(
                            flex: _shareFlex(source.sharePercent),
                            child: ColoredBox(color: _sourceColor(source.key)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          for (final source in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: source.$1,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.$2,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        Text(
                          source.$3,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        source.$4,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        source.$5,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SatisfactionCard extends StatelessWidget {
  const _SatisfactionCard({this.detail});

  final CourseDetailData? detail;

  @override
  Widget build(BuildContext context) {
    final reviews = detail?.reviews ?? const <CourseReview>[];
    final counts = <int, int>{
      for (var stars = 1; stars <= 5; stars++) stars: 0,
    };
    for (final review in reviews) {
      final stars = review.stars;
      if (stars < 1 || stars > 5) continue;
      counts[stars] = (counts[stars] ?? 0) + 1;
    }
    final total = reviews.length;
    final rating = (detail?.rating ?? '').trim();
    final featured = reviews.isEmpty ? null : reviews.first;
    return _panel(
      title: 'Student Satisfaction',
      trailing: '',
      trailingChild: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: _gold),
          const SizedBox(width: 4),
          Text(
            rating.isEmpty ? '— / 5' : '$rating / 5',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0
                ? 'No reviews yet'
                : 'Based on $total ${total == 1 ? 'review' : 'reviews'}',
            style: GoogleFonts.figtree(fontSize: 12, color: _gray),
          ),
          const SizedBox(height: 10),
          for (final stars in const [5, 4, 3, 2, 1])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$stars stars',
                      style: GoogleFonts.figtree(fontSize: 12, color: _gray),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (counts[stars] ?? 0) / total,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF3F4F6),
                        color: _gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      total == 0
                          ? '—'
                          : '${(((counts[stars] ?? 0) / total) * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (featured != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Text(
                          featured.name.isEmpty
                              ? '?'
                              : featured.name.characters.first.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              featured.name,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              featured.when,
                              style: GoogleFonts.figtree(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < 5; i++)
                        Icon(
                          Icons.star,
                          size: 12,
                          color: i < featured.stars
                              ? _gold
                              : const Color(0xFFE5E7EB),
                        ),
                    ],
                  ),
                  if (featured.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“${featured.body}”',
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        height: 1.4,
                        color: _ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int? _enrolledCount(CourseDetailData? detail) {
  final text = detail?.studentsEnrolled ?? '';
  final match = RegExp(r'[\d,]+').firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(0)!.replaceAll(',', ''));
}

class _CourseFigures extends ConsumerStatefulWidget {
  const _CourseFigures({
    required this.courseId,
    required this.period,
    required this.builder,
  });

  final int courseId;

  /// `7d`, `30d`, `90d`, or `all`.
  final String period;
  final Widget Function(
    BuildContext context,
    CourseDetailData? detail,
    InstructorCourseAnalytics? analytics,
  )
  builder;

  @override
  ConsumerState<_CourseFigures> createState() => _CourseFiguresState();
}

class _CourseFiguresState extends ConsumerState<_CourseFigures> {
  CourseDetailData? _detail;
  InstructorCourseAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadAnalytics();
  }

  @override
  void didUpdateWidget(covariant _CourseFigures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId) {
      _detail = null;
      _analytics = null;
      _loadDetail();
      _loadAnalytics();
    } else if (oldWidget.period != widget.period) {
      _analytics = null;
      _loadAnalytics();
    }
  }

  Future<void> _loadDetail() async {
    final id = widget.courseId;
    try {
      final detail = await ref.read(courseApiProvider).detail(id);
      if (!mounted || widget.courseId != id) return;
      setState(() => _detail = detail);
    } on Object {
      // The rating card stays blank when the course record cannot be read.
    }
  }

  Future<void> _loadAnalytics() async {
    final id = widget.courseId;
    final period = widget.period;
    try {
      final analytics = await ref
          .read(courseApiProvider)
          .instructorAnalytics(id, period: period);
      if (!mounted || widget.courseId != id || widget.period != period) return;
      setState(() => _analytics = analytics);
    } on Object {
      if (!mounted || widget.courseId != id || widget.period != period) return;
      setState(() => _analytics = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _detail, _analytics);
}

class _DetailsPerformance extends ConsumerStatefulWidget {
  const _DetailsPerformance({required this.course});

  final CourseSummary course;

  @override
  ConsumerState<_DetailsPerformance> createState() =>
      _DetailsPerformanceState();
}

class _DetailsPerformanceState extends ConsumerState<_DetailsPerformance> {
  var _period = 'Last 30 days';

  @override
  Widget build(BuildContext context) {
    final query = analyticsPeriodQuery(_period);
    return _CourseFigures(
      courseId: widget.course.id,
      period: query,
      builder: (context, detail, analytics) {
        final enrolled = _enrolledNow(detail, analytics);
        final rating = (detail?.rating ?? '').trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PerformanceHeading(
              period: _period,
              range: analytics?.rangeLabel ?? analyticsRangeFallback(query),
              onSelected: (value) => setState(() => _period = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashMetric(
                    label: 'Total students',
                    value: enrolled == null ? '—' : '$enrolled',
                    note: _studentsNote(analytics, enrolled),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashMetric(
                    label: 'Watch time',
                    value: formatWatchTime(analytics?.watchTimeSeconds),
                    note: _watchNote(analytics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EnrollmentChartCard(
              total: analytics?.students.newInPeriod,
              delta: formatSignedPercent(analytics?.students.deltaPercent),
              days: analytics?.enrollmentsByDay ?? const [],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashMetric(
                    label: 'Avg. completion',
                    value: formatAnalyticsPercent(
                      analytics?.avgCompletionPercent,
                    ),
                    note: _completionNote(analytics),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashMetric(
                    label: 'Student rating',
                    value: rating.isEmpty ? '—' : rating,
                    note: detail == null
                        ? '—'
                        : '${detail.reviews.length} reviews',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InsightBanner(body: _insight(analytics)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InstructorCoursePerformancePage(
                        course: widget.course,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _line),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Studio analytics',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

int? _enrolledNow(
  CourseDetailData? detail,
  InstructorCourseAnalytics? analytics,
) {
  if (analytics != null) return analytics.students.enrolledNow;
  return _enrolledCount(detail);
}

String _studentsNote(InstructorCourseAnalytics? analytics, int? enrolled) {
  if (analytics == null) return enrolled == null ? '—' : 'Enrolled now';
  final fresh = analytics.students.newInPeriod;
  final delta = formatSignedPercent(analytics.students.deltaPercent);
  if (fresh != null && delta != null) return '$fresh new · $delta';
  if (fresh != null) return '$fresh new';
  if (delta != null) return delta;
  return enrolled == null ? '—' : 'Enrolled now';
}

String _moneyNote(AnalyticsMoney? money) {
  if (money == null || money.amount == null) return 'Not recorded';
  return formatSignedPercent(money.deltaPercent) ?? 'This period';
}

String _watchNote(InstructorCourseAnalytics? analytics) {
  if (analytics == null || analytics.watchTimeSeconds == null) {
    return 'Not recorded';
  }
  return formatSignedPercent(analytics.watchTimeDeltaPercent) ?? 'This period';
}

String _completionNote(InstructorCourseAnalytics? analytics) {
  if (analytics == null || analytics.avgCompletionPercent == null) {
    return 'Not recorded';
  }
  return formatSignedPoints(analytics.avgCompletionDeltaPoints) ??
      'This period';
}

String _insight(InstructorCourseAnalytics? analytics) {
  final days = analytics?.enrollmentsByDay ?? const <DailyEnrollment>[];
  if (days.isEmpty) {
    return 'Daily enrollments are not available for this period.';
  }
  final total = days.fold<int>(0, (sum, day) => sum + day.count);
  if (total == 0) return 'No new enrollments in this period.';
  final noun = total == 1 ? 'enrollment' : 'enrollments';
  return '$total new $noun across ${days.length} days.';
}

int _shareFlex(double? share) {
  final rounded = (share ?? 0).round();
  if (rounded < 1) return 1;
  if (rounded > 1000) return 1000;
  return rounded;
}

Color _sourceColor(String key) => switch (key) {
  'direct' => const Color(0xFFF6C945),
  'organic' => const Color(0xFF22C55E),
  'social' => const Color(0xFF9CA3AF),
  _ => const Color(0xFFD1D5DB),
};

String _sourceTitle(String key) => switch (key) {
  'direct' => 'Direct & Newsletter',
  'organic' => 'Organic Search / SEO',
  'social' => 'Social & Referrals',
  _ => 'Unknown',
};

String _sourceCaption(String key) => switch (key) {
  'direct' => 'Studio link sharing',
  'organic' => 'Course discovery platform',
  'social' => 'Alumni shares & X / LinkedIn',
  _ => 'No source was recorded',
};

Widget _panel({
  required String title,
  required String trailing,
  Widget? trailingChild,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            trailingChild ??
                Text(
                  trailing,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _gray,
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _studioButton({
  required IconData icon,
  required String label,
  required bool filled,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _gold : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: filled ? null : Border.all(color: _line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: published ? const Color(0xFF16A34A) : _gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            published ? 'Live' : 'Draft',
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceHeading extends StatelessWidget {
  const _PerformanceHeading({
    required this.period,
    required this.range,
    required this.onSelected,
  });

  static const _periods = ['7 days', 'Last 30 days', '90 days', 'All time'];

  final String period;
  final String range;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Performance',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              initialValue: period,
              onSelected: onSelected,
              position: PopupMenuPosition.under,
              offset: const Offset(0, 8),
              color: Colors.white,
              elevation: 8,
              shadowColor: const Color(0x14111827),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (context) => [
                for (final period in _periods)
                  PopupMenuItem<String>(
                    value: period,
                    height: 40,
                    child: Text(
                      period,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: period == this.period
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      period,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: _gray,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(range, style: GoogleFonts.figtree(fontSize: 12, color: _muted)),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, this.selected = true, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _gold : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? _gold : _line),
        ),
        child: Text(
          label,
          style: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _DashMetric extends StatelessWidget {
  const _DashMetric({
    required this.label,
    this.value = '—',
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 12, color: _gray)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(note, style: GoogleFonts.figtree(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }
}

class _EnrollmentChartCard extends StatelessWidget {
  const _EnrollmentChartCard({
    this.title = 'New enrollments',
    this.total,
    this.delta,
    this.days = const [],
    this.note,
  });

  final String title;
  final int? total;
  final String? delta;
  final List<DailyEnrollment> days;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final axisMax = _chartMax(days);
    final dates = _chartDates(days);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'This period',
                style: GoogleFonts.figtree(fontSize: 12, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total == null ? '—' : '$total',
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: _ink,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    delta!,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: delta!.startsWith('-')
                          ? const Color(0xFFB45309)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final value in [axisMax, axisMax ~/ 2, 0])
                        Text(
                          '$value',
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            color: _muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GoldChart(
                    counts: [for (final day in days) day.count],
                    axisMax: axisMax,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final date in dates)
                  Text(
                    date,
                    style: GoogleFonts.figtree(fontSize: 11, color: _muted),
                  ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up, size: 16, color: _ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note!,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        height: 1.4,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _chartMax(List<DailyEnrollment> days) {
  var peak = 0;
  for (final day in days) {
    if (day.count > peak) peak = day.count;
  }
  if (peak <= 4) return 4;
  if (peak <= 8) return 8;
  if (peak <= 10) return 10;
  final step = peak <= 40 ? 4 : 10;
  return ((peak + step - 1) ~/ step) * step;
}

List<String> _chartDates(List<DailyEnrollment> days) {
  if (days.isEmpty) return const ['', '', '', ''];
  final indexes = days.length <= 4
      ? [for (var i = 0; i < days.length; i++) i]
      : [0, days.length ~/ 3, (2 * days.length) ~/ 3, days.length - 1];
  final seen = <int>{};
  return [
    for (final index in indexes)
      if (seen.add(index)) _chartDate(days[index].date),
  ];
}

String _chartDate(String iso) {
  final match = RegExp(r'^\d{4}-(\d{2})-(\d{2})').firstMatch(iso);
  if (match == null) return '';
  const months = [
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
  final month = int.tryParse(match.group(1) ?? '') ?? 1;
  final day = int.tryParse(match.group(2) ?? '') ?? 1;
  return '${months[(month - 1).clamp(0, 11)]} $day';
}

class _GoldChart extends StatelessWidget {
  const _GoldChart({required this.counts, required this.axisMax});

  final List<int> counts;
  final int axisMax;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoldLinePainter(counts: counts, axisMax: axisMax),
      child: const SizedBox.expand(),
    );
  }
}

class _GoldLinePainter extends CustomPainter {
  const _GoldLinePainter({required this.counts, required this.axisMax});

  final List<int> counts;
  final int axisMax;

  @override
  void paint(Canvas canvas, Size size) {
    final series = counts.isEmpty ? const <int>[0, 0] : counts;
    const inset = 2.0;
    final top = inset;
    final bottom = size.height - inset;
    final grid = Paint()
      ..color = const Color(0xFFE8E5DE)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + (bottom - top) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final max = axisMax <= 0 ? 1 : axisMax;
    double yOf(int count) => bottom - (count / max) * (bottom - top);

    final path = Path();
    for (var i = 0; i < series.length; i++) {
      final x = series.length == 1 ? 0.0 : size.width * i / (series.length - 1);
      final y = yOf(series[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (series.length == 1) path.lineTo(size.width, yOf(series.first));
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF5B400)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.width - 2, yOf(series.last)),
      4,
      Paint()..color = const Color(0xFFF5B400),
    );
  }

  @override
  bool shouldRepaint(covariant _GoldLinePainter oldDelegate) {
    if (oldDelegate.axisMax != axisMax ||
        oldDelegate.counts.length != counts.length) {
      return true;
    }
    for (var i = 0; i < counts.length; i++) {
      if (oldDelegate.counts[i] != counts[i]) return true;
    }
    return false;
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        body,
        style: GoogleFonts.figtree(fontSize: 13, height: 1.4, color: _ink),
      ),
    );
  }
}

Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: _ink),
    ),
  );
}

Widget _action({
  required IconData icon,
  required String label,
  required bool filled,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _gold : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: filled ? null : Border.all(color: _line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    ),
  );
}

CourseDetailData _studentPreview(CourseSummary course) {
  return CourseDetailData(
    id: course.id,
    image: course.thumbnailUrl ?? '',
    title: course.title,
    subtitle: '',
    rating: '',
    level: '',
    category: '',
    ratingsCount: '',
    studentsEnrolled: '',
    instructorName: '',
    instructorAvatar: '',
    lastUpdated: '',
    languages: '',
    learningOutcomes: const [],
    curriculumSummary: '',
    modules: const [],
    includes: const [],
    requirements: const [],
    descriptionBlocks: const [],
    descriptionMoreBlocks: const [],
    instructors: const [],
    courseRating: '',
    ratingBars: const [],
    reviews: const [],
    totalTime: '',
    price: course.priceLabel,
    isPaid: course.isPaid,
  );
}
