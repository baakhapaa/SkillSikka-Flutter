import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/courses/data/course_summary.dart';
import 'package:skillsikka/features/courses/data/my_courses_api.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/my_courses_page.dart';

/// What the profile tab's **See All (25)** opens.
///
/// The link was `onTap: () {}` until 2026-10-30 — a tappable label with a real
/// count beside it and no destination.
void main() {
  const draft = CourseSummary(
    id: 1,
    title: 'Digital Illustration',
    isPublished: false,
    isPaid: false,
  );
  const live = CourseSummary(
    id: 2,
    title: 'Portrait Lighting',
    isPublished: true,
    isPaid: true,
    price: '1299.00',
  );

  Widget app({List<CourseSummary> courses = const [], bool fail = false}) =>
      ProviderScope(
        overrides: [
          myCoursesApiProvider.overrideWithValue(
            _FakeCourses(courses, fail: fail),
          ),
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..setRole(ProfileRole.instructor)
              ..setId('7')
              ..setVerificationStatus('verified'),
          ),
        ],
        child: const MaterialApp(home: MyCoursesPage()),
      );

  testWidgets('lists every course with its state and price', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(courses: const [draft, live]));
    await tester.pumpAndSettle();

    expect(find.text('Digital Illustration'), findsOneWidget);
    expect(find.text('Portrait Lighting'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Rs 1,299'), findsOneWidget);
    // A free course states that it is free (product decision, 2026-10-31) —
    // the row used to carry an empty price slot.
    expect(find.text('Free'), findsOneWidget);
    // The heading count agrees with the list.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('an empty shelf says so', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('You have not created a course yet.'), findsOneWidget);
  });

  testWidgets('a failed fetch offers a retry', (tester) async {
    await tester.pumpWidget(app(fail: true));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('You have not created a course yet.'), findsNothing);
  });
}

class _FakeCourses implements MyCoursesApi {
  _FakeCourses(this.courses, {this.fail = false});

  final List<CourseSummary> courses;
  final bool fail;

  @override
  Future<List<CourseSummary>> list(String instructorId) async {
    if (fail) {
      throw const ApiException(kind: ApiErrorKind.network, message: 'offline');
    }
    return courses;
  }
}
