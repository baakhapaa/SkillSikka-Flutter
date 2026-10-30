import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'course_summary.dart';

/// The instructor's own courses, for the profile grid.
///
/// Split from `CourseBuilderApi` because the two have nothing in common beyond
/// the resource: that one writes a single course the user is editing, this one
/// reads a list the user is browsing. Keeping them apart also means the builder's
/// dependency — and the fake a widget test hands it — stays small.
class MyCoursesApi {
  const MyCoursesApi(this._client);

  final ApiClient _client;

  /// `GET /courses/?instructor=<id>`.
  ///
  /// The server already scopes the list to `published OR mine` for an instructor,
  /// so the filter is what removes everyone else's published courses. Without it
  /// the grid would show the whole catalogue.
  ///
  /// Returns **every** status, drafts included — the endpoint has no
  /// `is_published` filter that means "mine", and the grid needs both halves.
  ///
  /// **`/courses/` answers a paginated envelope, not a bare array.** This used to
  /// ask for `List<dynamic>`, which throws on `{count, next, previous, results}`
  /// — and because the profile grid swallows that failure and falls back to its
  /// fixture cards, the symptom was not an error but a newly created course
  /// simply not appearing in the instructor's own shelf. The page size is asked
  /// for explicitly and `next` is followed, so the list is the whole list.
  Future<List<CourseSummary>> list(String instructorId) async {
    final summaries = <CourseSummary>[];
    var path = '/courses/';
    Map<String, dynamic>? query = {'instructor': instructorId, 'page_size': 50};

    // A hard page cap: `next` is server-provided, and a bug that returns the
    // same URL forever would otherwise hang the profile tab.
    for (var page = 0; page < 20; page++) {
      final body = await _client.get<Map<String, dynamic>>(path, query: query);
      final rows = body['results'];
      if (rows is! List) {
        throw ApiException(
          kind: ApiErrorKind.unknown,
          message: 'The server returned an unexpected response.',
        );
      }
      for (final row in rows) {
        final summary = CourseSummary.tryParse(row);
        if (summary != null) summaries.add(summary);
      }

      final next = body['next'];
      if (next is! String || next.trim().isEmpty) break;
      // The server's own URL already carries the filter and the page number.
      path = next.trim();
      query = null;
    }

    return summaries;
  }

  /// `PATCH /courses/{id}/ {"is_published": false}` — take a live course down.
  ///
  /// **Only ever unpublishes.** The grid deliberately offers no "publish" from a
  /// card: publishing is gated on six readiness checks that only the builder
  /// holds, and a one-tap publish here would let an instructor ship a course
  /// with no lessons straight from their profile. Re-publishing goes through the
  /// builder, which re-runs the checklist.
  ///
  /// The server only gates the `false → true` transition, so the owner may flip
  /// a course back to draft without any extra permission.
  Future<void> unpublish(int courseId) => _client.patch<Map<String, dynamic>>(
    '/courses/$courseId/',
    data: {'is_published': false},
  );

  /// `DELETE /courses/{id}/` — 204. Owner or administrator.
  ///
  /// **This is not the same as unpublishing.** The row, its lessons and its
  /// resources are gone, and so is every student's enrolment in it. The grid
  /// asks for confirmation naming the course before calling this.
  Future<void> delete(int courseId) => _client.delete('/courses/$courseId/');
}

final myCoursesApiProvider = Provider<MyCoursesApi>(
  (ref) => MyCoursesApi(ref.watch(apiClientProvider)),
);
