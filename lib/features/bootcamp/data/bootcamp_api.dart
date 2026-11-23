import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../courses/data/course_resources_api.dart';
import 'bootcamp.dart';

/// Reads the bootcamp screens from the course API.
///
/// **There is no bootcamp-only endpoint, and there should not be.** A bootcamp
/// is a `Course` with `course_type='bootcamp'`, so the catalogue, the detail
/// payload, the lessons, the resources and the discussions are the same routes
/// every other course uses. This class is the one place that knows which of
/// their fields a bootcamp cares about.
///
/// Three contract details, all measured:
///
/// 1. `GET /courses/` answers a **paginated envelope**; `/lessons/` and
///    `/courses/{id}/resources/` answer **bare arrays**.
/// 2. The profile is **flattened onto the course row** by
///    `CourseSerializer.to_representation`, so `venue_name` sits beside `title`.
/// 3. `/resources/` needs an **active enrolment** (or staff). A student who is
///    not enrolled gets `403 NOT_ENROLLED`, not an empty list — so the page
///    enrols first and this method treats the 403 as "no files yet" rather than
///    failing the whole screen over one tab.
class BootcampApi {
  const BootcampApi(this._client);

  final ApiClient _client;

  /// `GET /courses/?course_type=bootcamp` — published camps, newest run first.
  ///
  /// `days` is **not** a server filter; it narrows the result here, which is
  /// what the home rail's duration selector does.
  Future<List<BootcampCard>> list({int? days, int pageSize = 30}) async {
    final body = await _client.get<Object?>(
      '/courses/',
      query: {'course_type': 'bootcamp', 'page_size': pageSize},
    );
    if (body is! Map) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The bootcamps came back in an unexpected shape.',
      );
    }
    final results = body['results'];
    if (results is! List) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The bootcamps came back in an unexpected shape.',
      );
    }
    final camps = [for (final row in results) ?BootcampCard.tryParse(row)];
    if (days == null) return camps;
    return [
      for (final camp in camps)
        if (camp.days == days) camp,
    ];
  }

  /// One camp: the course row, its lessons and its resource pack.
  ///
  /// The course and its lessons are required — without them there is no screen.
  /// The resource pack is best effort: a bootcamp whose files call fails still
  /// renders, with an empty Resources tab.
  Future<BootcampDetail> detail(int id) async {
    final courseCall = _client.get<Map<String, dynamic>>('/courses/$id/');
    final lessonsCall = _client.get<List<dynamic>>(
      '/lessons/',
      query: {'course': id},
    );
    final resourcesCall = _resourcesOrEmpty(id);
    final course = await courseCall;
    final lessons = _rows(await lessonsCall);

    return BootcampDetail.fromWire(
      course: course,
      lessons: lessons,
      resources: await resourcesCall,
    );
  }

  Future<List<CourseResource>> _resourcesOrEmpty(int id) async {
    try {
      final body = await _client.get<Object?>('/courses/$id/resources/');
      if (body is! List) return const [];
      return [for (final row in body) ?tryParseCourseResource(row)];
    } on ApiException {
      // `403 NOT_ENROLLED` is the normal answer before the page enrols, and a
      // missing pack is not a reason to fail the screen.
      return const [];
    }
  }

  static List<Map<String, dynamic>> _rows(List<dynamic> body) => [
    for (final row in body)
      if (row is Map<String, dynamic>) row,
  ];
}

/// The published camps, for the home rail.
final bootcampsProvider = FutureProvider<List<BootcampCard>>(
  (ref) => ref.watch(bootcampApiProvider).list(),
);

final bootcampApiProvider = Provider<BootcampApi>(
  (ref) => BootcampApi(ref.watch(apiClientProvider)),
);

/// One camp's full record, kept per id so reopening it is instant.
final bootcampDetailProvider = FutureProvider.family<BootcampDetail, int>(
  (ref, id) => ref.watch(bootcampApiProvider).detail(id),
  dependencies: [bootcampApiProvider],
);
