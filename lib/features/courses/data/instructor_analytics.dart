/// `GET /courses/{id}/instructor-analytics/?period=`.
///
/// Null means the server has not recorded that figure. Zero is a real zero
/// and must not be turned into a dash.
class InstructorCourseAnalytics {
  const InstructorCourseAnalytics({
    required this.period,
    this.periodStart,
    this.periodEnd,
    this.revenue = const AnalyticsMoney(),
    this.students = const AnalyticsStudents(),
    this.watchTimeSeconds,
    this.watchTimeDeltaPercent,
    this.avgCompletionPercent,
    this.avgCompletionDeltaPoints,
    this.enrollmentsByDay = const [],
    this.retention = const [],
    this.sources = const [],
  });

  final String period;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final AnalyticsMoney revenue;
  final AnalyticsStudents students;
  final int? watchTimeSeconds;
  final double? watchTimeDeltaPercent;
  final double? avgCompletionPercent;
  final double? avgCompletionDeltaPoints;
  final List<DailyEnrollment> enrollmentsByDay;
  final List<SectionRetention> retention;
  final List<EnrollmentSourceShare> sources;

  /// `Oct 19, 2026 – Nov 17, 2026  ·  vs. previous 30 days`, from the server's
  /// window. `All time` has no previous window.
  String get rangeLabel {
    final start = periodStart;
    final end = periodEnd;
    if (period == 'all' || start == null || end == null) return 'All time';
    final days = end.difference(start).inDays + 1;
    return '${formatAnalyticsDate(start)} – ${formatAnalyticsDate(end)}'
        '  ·  vs. previous $days days';
  }

  static InstructorCourseAnalytics? tryParse(Object? body) {
    if (body is! Map) return null;
    final revenue = body['revenue'];
    final students = body['students'];
    return InstructorCourseAnalytics(
      period: body['period'] is String ? body['period'] as String : '30d',
      periodStart: _date(body['period_start']),
      periodEnd: _date(body['period_end']),
      revenue: revenue is Map
          ? AnalyticsMoney(
              amount: revenue['amount'] == null ? null : '${revenue['amount']}',
              currency: revenue['currency'] is String
                  ? revenue['currency'] as String
                  : 'NPR',
              deltaPercent: _double(revenue['delta_percent']),
            )
          : const AnalyticsMoney(),
      students: students is Map
          ? AnalyticsStudents(
              enrolledNow: _int(students['enrolled_now']),
              newInPeriod: _int(students['new_in_period']),
              deltaPercent: _double(students['delta_percent']),
            )
          : const AnalyticsStudents(),
      watchTimeSeconds: _int(body['watch_time_seconds']),
      watchTimeDeltaPercent: _double(body['watch_time_delta_percent']),
      avgCompletionPercent: _double(body['avg_completion_percent']),
      avgCompletionDeltaPoints: _double(body['avg_completion_delta_points']),
      enrollmentsByDay: [
        for (final row in _list(body['enrollments_by_day']))
          if (row['date'] is String && _int(row['count']) != null)
            DailyEnrollment(
              date: row['date'] as String,
              count: _int(row['count'])!,
            ),
      ],
      retention: [
        for (final row in _list(body['retention']))
          if (row['section'] is String)
            SectionRetention(
              section: row['section'] as String,
              lessonCount: _int(row['lesson_count']) ?? 0,
              completionPercent: _double(row['completion_percent']),
            ),
      ],
      sources: [
        for (final row in _list(body['sources']))
          if (row['key'] is String)
            EnrollmentSourceShare(
              key: row['key'] as String,
              sharePercent: _double(row['share_percent']),
              conversionPercent: _double(row['conversion_percent']),
            ),
      ],
    );
  }
}

class AnalyticsMoney {
  const AnalyticsMoney({this.amount, this.currency = 'NPR', this.deltaPercent});

  /// Decimal string (`"18420.00"`), or null when revenue is not recorded.
  final String? amount;
  final String currency;
  final double? deltaPercent;
}

class AnalyticsStudents {
  const AnalyticsStudents({
    this.enrolledNow,
    this.newInPeriod,
    this.deltaPercent,
  });

  final int? enrolledNow;
  final int? newInPeriod;
  final double? deltaPercent;
}

class DailyEnrollment {
  const DailyEnrollment({required this.date, required this.count});

  final String date;
  final int count;
}

class SectionRetention {
  const SectionRetention({
    required this.section,
    required this.lessonCount,
    this.completionPercent,
  });

  final String section;
  final int lessonCount;
  final double? completionPercent;
}

class EnrollmentSourceShare {
  const EnrollmentSourceShare({
    required this.key,
    this.sharePercent,
    this.conversionPercent,
  });

  final String key;
  final double? sharePercent;
  final double? conversionPercent;
}

/// The query value for a period chip. Unknown labels are the 30-day default
/// the server uses when `period` is omitted.
String analyticsPeriodQuery(String label) => switch (label) {
  '7 days' => '7d',
  '90 days' => '90d',
  'All time' => 'all',
  _ => '30d',
};

/// The same window the server uses, for the moment before the response arrives.
///
/// `30d` is 30 days ending today, UTC, inclusive. A local "subtract 30 days"
/// is one day longer than that.
String analyticsRangeFallback(String query) {
  if (query == 'all') return 'All time';
  final days = switch (query) {
    '7d' => 7,
    '90d' => 90,
    _ => 30,
  };
  final now = DateTime.now().toUtc();
  final end = DateTime.utc(now.year, now.month, now.day);
  final start = end.subtract(Duration(days: days - 1));
  return '${formatAnalyticsDate(start)} – ${formatAnalyticsDate(end)}'
      '  ·  vs. previous $days days';
}

String formatAnalyticsDate(DateTime date) {
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
  final utc = date.toUtc();
  return '${months[utc.month - 1]} ${utc.day}, ${utc.year}';
}

/// `Rs 18,420`, `Rs 0`, or `—`.
String formatAnalyticsMoney(String? amount) {
  if (amount == null || amount.trim().isEmpty) return '—';
  final value = double.tryParse(amount.replaceAll(',', ''));
  if (value == null) return '—';
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer(rounded < 0 ? '-' : '');
  buffer.write('Rs ');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `312h`, `2m`, `30s`, `0s`, or `—`.
String formatWatchTime(int? seconds) {
  if (seconds == null) return '—';
  if (seconds <= 0) return '0s';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remain = seconds % 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  if (minutes > 0 && remain > 0) return '${minutes}m ${remain}s';
  if (minutes > 0) return '${minutes}m';
  return '${remain}s';
}

/// `72%`, or `—`.
String formatAnalyticsPercent(double? value) {
  if (value == null) return '—';
  return '${value.round()}%';
}

/// `+22.4%`, `-3%`, or null when there is no comparison.
String? formatSignedPercent(double? value) {
  if (value == null) return null;
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  if (rounded > 0) return '+$text%';
  return '$text%';
}

/// `+6 pts`, or null.
String? formatSignedPoints(double? value) {
  if (value == null) return null;
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  if (rounded > 0) return '+$text pts';
  return '$text pts';
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

int? _int(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return [
    for (final row in value)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}
