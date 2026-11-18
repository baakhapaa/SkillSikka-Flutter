import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/courses/data/instructor_analytics.dart';
import 'package:skillsikka/features/learning/data/lesson_watch_reporter.dart';

void main() {
  test('null stays unrecorded and zero stays zero', () {
    final analytics = InstructorCourseAnalytics.tryParse({
      'period': '30d',
      'period_start': '2026-10-19',
      'period_end': '2026-11-17',
      'revenue': {'amount': '0.00', 'currency': 'NPR', 'delta_percent': null},
      'students': {
        'enrolled_now': 4,
        'new_in_period': 0,
        'delta_percent': 22.4,
      },
      'watch_time_seconds': null,
      'avg_completion_percent': 72.4,
      'avg_completion_delta_points': 6,
      'enrollments_by_day': [
        {'date': '2026-10-19', 'count': 0},
        {'date': '2026-10-20', 'count': 2},
      ],
      'retention': [
        {'section': 'Foundations', 'lesson_count': 4, 'completion_percent': 81},
      ],
      'sources': [
        {'key': 'direct', 'share_percent': 100, 'conversion_percent': null},
      ],
    });

    expect(analytics, isNotNull);
    expect(formatAnalyticsMoney(analytics!.revenue.amount), 'Rs 0');
    expect(analytics.students.newInPeriod, 0);
    expect(analytics.watchTimeSeconds, isNull);
    expect(formatWatchTime(null), '—');
    expect(formatWatchTime(0), '0s');
    expect(formatWatchTime(30), '30s');
    expect(formatAnalyticsPercent(analytics.avgCompletionPercent), '72%');
    expect(formatSignedPoints(analytics.avgCompletionDeltaPoints), '+6 pts');
    expect(formatSignedPercent(analytics.students.deltaPercent), '+22.4%');
    expect(analytics.enrollmentsByDay, hasLength(2));
    expect(analytics.retention.single.completionPercent, 81);
    expect(analytics.sources.single.conversionPercent, isNull);
    expect(
      analytics.rangeLabel,
      'Oct 19, 2026 – Nov 17, 2026  ·  vs. previous 30 days',
    );
    expect(analyticsPeriodQuery('Last 30 days'), '30d');
    expect(analyticsPeriodQuery('All time'), 'all');
  });

  test('time on a lesson is what gets reported', () async {
    final calls = <(int, int, int)>[];
    final reporter = LessonWatchReporter((
      id, {
      required watchedSeconds,
      required positionSeconds,
    }) async {
      calls.add((id, watchedSeconds, positionSeconds));
    });

    reporter.setActive(lessonId: 3, active: true, positionSeconds: 4);
    reporter.advance(const Duration(seconds: 20));
    await Future<void>.value();
    expect(calls, [(3, 20, 4)]);

    reporter.advance(const Duration(seconds: 5));
    reporter.setActive(lessonId: 3, active: false, positionSeconds: 9);
    await Future<void>.value();
    expect(calls, [(3, 20, 4), (3, 5, 9)]);

    reporter.dispose();
  });
}
