import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/app.dart';
import 'package:skillsikka/core/location/location_service.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/network/session_store.dart';
import 'package:skillsikka/core/routing/app_router.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/data/my_courses_api.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';
import 'package:skillsikka/features/learning/data/learning_api.dart';
import 'package:skillsikka/features/learning/data/my_learning.dart';
import 'package:skillsikka/features/learning/presentation/my_learning_page.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/my_courses_page.dart';
import 'package:skillsikka/features/signup/presentation/signup_instructor_form_page.dart';
import 'package:skillsikka/features/signup/presentation/signup_role_page.dart';
import 'package:skillsikka/features/signup/presentation/signup_student_form_page.dart';
import 'package:skillsikka/features/signup/presentation/signup_verification_page.dart';

import 'support/home_page_font_harness.dart';

/// A 1x1 PNG the photo picker can decode.
final _onePixelPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAF'
    'AAH/q842iQAAAABJRU5ErkJggg==',
  ),
);

class _StubLocationService extends LocationService {
  const _StubLocationService();

  @override
  Future<bool> hasPermission() async => false;
}

/// Walks the real login screen, the real router, and both signup forms the way
/// a student and an instructor would.
void main() {
  installHomePageFontHarness();

  testWidgets('a student signs in and cannot open instructor screens', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester, startAt: '/login-screen');

    await _signIn(tester, 'sita@example.com');

    expect(harness.path, '/');
    expect(harness.auth.logins.single.email, 'sita@example.com');
    expect(
      harness.container.read(sessionProvider)?.role,
      'student',
      reason: 'login must store the role with the tokens',
    );
    expect(find.text('My Learning'), findsWidgets);
    expect(find.text('My Courses'), findsNothing);

    await tester.tap(find.text('My Learning'));
    await tester.pump();
    expect(find.byType(MyLearningPage), findsOneWidget);

    for (final path in [
      '/instructor/courses',
      '/instructor/courses/new',
      '/instructor/courses/5/edit',
      '/instructor/courses/5',
    ]) {
      harness.router.go(path);
      await tester.pumpAndSettle();
      drainUnrelatedOverflows(tester);
      expect(harness.path, '/', reason: 'a student must leave $path');
    }

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Log Out'),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
      ),
    );
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(harness.container.read(sessionProvider), isNull);
    expect(harness.path, '/login-screen');
  });

  testWidgets('an instructor signs in and reaches their courses', (
    tester,
  ) async {
    final harness = _Harness()..loginRole = ProfileRole.instructor;
    await harness.pump(tester, startAt: '/login-screen');

    await _signIn(tester, 'teach@example.com');

    expect(harness.path, '/');
    expect(harness.container.read(sessionProvider)?.role, 'instructor');
    expect(find.text('My Courses'), findsWidgets);
    expect(find.text('My Learning'), findsNothing);

    await tester.tap(find.text('My Courses'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);
    expect(find.byType(MyCoursesPage), findsWidgets);

    harness.router.go('/instructor/courses');
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);
    expect(harness.path, '/instructor/courses');
    expect(find.text('Checking your account'), findsNothing);
  });

  testWidgets('a saved instructor session opens the instructor shell', (
    tester,
  ) async {
    const stored = Session(
      access: 'access-abc',
      refresh: 'refresh-abc',
      role: 'instructor',
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => FakeAuthRepository(
            session: ref.read(sessionProvider.notifier),
            profile: ref.read(userProfileProvider.notifier),
          ),
        ),
        sessionStoreProvider.overrideWithValue(FakeSessionStore(stored: stored)),
        myLearningProvider.overrideWith((ref) async => const MyLearning()),
        bootcampsProvider.overrideWith((ref) async => const <BootcampCard>[]),
        homeAcademicCoursesProvider.overrideWith(
          (ref, classIndex) async => const [],
        ),
        homePremiumCoursesProvider.overrideWith((ref) async => const []),
        skillCatalogueProvider.overrideWith((ref) async => const []),
        myCoursesProvider.overrideWith((ref, id) async => const []),
        nearbyEventsProvider.overrideWith((ref) async => EventPage.empty),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillSikkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(container.read(userProfileProvider).role, ProfileRole.instructor);
    expect(find.text('My Courses'), findsWidgets);
    expect(find.byType(MyLearningPage), findsNothing);
  });

  testWidgets('signup lets a student and an instructor each create an account', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) {
          return FakeAuthRepository(
            session: ref.read(sessionProvider.notifier),
            profile: ref.read(userProfileProvider.notifier),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final liveAuth =
        container.read(authRepositoryProvider) as FakeAuthRepository;

    final router = GoRouter(
      initialLocation: '/signup/role',
      routes: [
        GoRoute(
          path: '/signup/role',
          builder: (_, _) => const SignupRolePage(),
        ),
        GoRoute(
          path: '/signup/student',
          builder: (_, _) => const SignupStudentFormPage(
            locationService: _StubLocationService(),
          ),
        ),
        GoRoute(
          path: '/signup/instructor',
          builder: (_, _) => const SignupInstructorFormPage(
            locationService: _StubLocationService(),
          ),
        ),
        GoRoute(
          path: '/signup/verify',
          builder: (_, _) => const SignupVerificationPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('I am a Student'), findsOneWidget);
    expect(find.text('I am an Instructor'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupStudentFormPage), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    container
        .read(userProfileProvider.notifier)
        .setPhoto(_onePixelPng, 'avatar.png');
    await tester.pump();
    await _fillAccountForm(tester);
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(liveAuth.registrations.single.role, ProfileRole.student);
    expect(find.text('Verify Your Account'), findsOneWidget);
    expect(
      container.read(sessionProvider),
      isNull,
      reason: 'signup does not sign the student in before the code',
    );

    router.go('/signup/role');
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am an Instructor'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupInstructorFormPage), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await _fillAccountForm(tester, email: 'teach@example.com');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(liveAuth.registrations.last.role, ProfileRole.instructor);
    expect(container.read(userProfileProvider).role, ProfileRole.instructor);
    expect(container.read(sessionProvider), isNull);
    expect(find.text('Verify Your Account'), findsOneWidget);
  });
}

class _Harness {
  late final ProviderContainer container;
  late final GoRouter router;
  FakeAuthRepository? _auth;
  ProfileRole loginRole = ProfileRole.student;

  FakeAuthRepository get auth => _auth!;

  String get path => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> pump(WidgetTester tester, {required String startAt}) async {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) {
          final created = FakeAuthRepository(
            session: ref.read(sessionProvider.notifier),
            profile: ref.read(userProfileProvider.notifier),
          );
          created.loginRole = loginRole;
          return _auth ??= created;
        }),
        nearbyEventsProvider.overrideWith((ref) async => EventPage.empty),
        bootcampsProvider.overrideWith((ref) async => const <BootcampCard>[]),
        homeAcademicCoursesProvider.overrideWith(
          (ref, classIndex) async => const [],
        ),
        homePremiumCoursesProvider.overrideWith((ref) async => const []),
        skillCatalogueProvider.overrideWith((ref) async => const []),
        myLearningProvider.overrideWith((ref) async => const MyLearning()),
        myCoursesProvider.overrideWith((ref, id) async => const []),
      ],
    );
    addTearDown(container.dispose);
    router = container.read(appRouterProvider);
    router.go(startAt);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);
  }
}

Future<void> _signIn(WidgetTester tester, String email) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), 'Passw0rd');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
  drainUnrelatedOverflows(tester);
}

Future<void> _fillAccountForm(
  WidgetTester tester, {
  String email = 'sita@example.com',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Sita Rai');
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), 'Passw0rd');
  await tester.enterText(fields.at(3), 'Passw0rd');
  await tester.ensureVisible(fields.at(4));
  await tester.tap(fields.at(4));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Female').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(fields.at(5));
  await tester.tap(fields.at(5));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
