import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/features/courses/data/course_summary.dart';
import 'package:skillsikka/features/courses/data/my_courses_api.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';

class _FakeCourses implements MyCoursesApi {
  _FakeCourses(this.courses);

  final List<CourseSummary> courses;
  int calls = 0;

  @override
  Future<List<CourseSummary>> list(String instructorId) async {
    calls += 1;
    return courses;
  }
}

const _draft = CourseSummary(  id: 1,
  title: 'Digital Illustration',
  isPublished: false,
  isPaid: false,
);

const _live = CourseSummary(
  id: 2,
  title: 'Portrait Lighting',
  isPublished: true,
  isPaid: true,
  price: '1299.00',
);

Widget _app(_FakeCourses api) => ProviderScope(  overrides: [
    myCoursesApiProvider.overrideWithValue(api),
    userProfileProvider.overrideWith(
      (ref) => UserProfileNotifier()
        ..setRole(ProfileRole.instructor)
        ..setId('7')
        ..setVerificationStatus('verified'),
    ),
  ],
  child: const MaterialApp(home: ProfilePage()),
);

void main() {
  group('MyCoursesApi.list', () {
    /// Answers each request with the next canned body, and records the URLs.
    ///
    /// The bug this covers lived one level below the widget: the grid swallows a
    /// failed fetch and falls back to its fixture cards, so a wrong parse looked
    /// exactly like an instructor who had authored nothing.
    test('reads the paginated envelope and follows next', () async {
      final adapter = _StubAdapter([
        jsonEncode({
          'count': 3,
          'next': 'http://test/api/v1/courses/?instructor=7&page=2',
          'previous': null,
          'results': [_row(1, 'Draft one'), _row(2, 'Live one')],
        }),
        jsonEncode({
          'count': 3,
          'next': null,
          'previous': null,
          'results': [_row(3, 'Third')],
        }),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
        ..httpClientAdapter = adapter;

      final courses = await MyCoursesApi(ApiClient(dio)).list('7');

      expect(courses.map((course) => course.id), [1, 2, 3]);
      expect(adapter.urls, hasLength(2));
      expect(adapter.urls.first.queryParameters['instructor'], '7');
      // The whole list, not the server's default 20-row page.
      expect(adapter.urls.first.queryParameters['page_size'], '50');
      // The second call is the `next` URL verbatim, filters and all.
      expect(adapter.urls.last.queryParameters['page'], '2');
    });

    test('a bare array is a contract change, not an empty list', () async {
      final adapter = _StubAdapter(['[]']);
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
        ..httpClientAdapter = adapter;

      // Loud on purpose: silently returning [] would hide the same class of bug
      // this whole group exists for.
      expect(
        () => MyCoursesApi(ApiClient(dio)).list('7'),
        throwsA(isA<Object>()),
      );
    });
  });

  testWidgets('the grid shows the instructor\'s real courses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = _FakeCourses(const [_draft, _live]);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(api.calls, greaterThan(0));
    expect(find.text('Digital Illustration'), findsOneWidget);
    expect(find.text('Portrait Lighting'), findsOneWidget);
    // The mock fixtures must be gone once real data has arrived, or the grid
    // would show six courses for an instructor who has two.
    expect(find.text('Adobe Certified Foundations'), findsNothing);
  });

  testWidgets('both states are labelled, not just drafts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_FakeCourses(const [_draft, _live])));
    await tester.pumpAndSettle();

    // The regression: a chip was drawn only when `!isPublished`, so a published
    // course carried no marker at all.
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('the price reads the way the card prints it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_FakeCourses(const [_draft, _live])));
    await tester.pumpAndSettle();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Rs 1,299'), findsOneWidget);
  });
}

/// A `GET /courses/` row, in the server's own field names.
Map<String, dynamic> _row(int id, String title) => {
  'id': id,
  'title': title,
  'is_published': id.isEven,
  'is_paid': false,
  'price': null,
  'thumbnail_url': '',
  'lessons_count': 3,
};

/// Answers each request with the next canned JSON body.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.bodies);

  final List<String> bodies;
  final List<Uri> urls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri);
    final body = bodies[(urls.length - 1).clamp(0, bodies.length - 1)];
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
