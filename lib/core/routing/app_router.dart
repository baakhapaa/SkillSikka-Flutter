import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/navigation/presentation/app_shell.dart';
import '../../features/login_screen/presentation/forgot_password_page.dart';
import '../../features/login_screen/presentation/login_screen_page.dart';
import '../../features/splash/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/signup/presentation/signup_role_page.dart';
import '../../features/signup/presentation/signup_instructor_form_page.dart';
import '../../features/signup/presentation/signup_student_form_page.dart';
import '../../features/signup/presentation/signup_interests_page.dart';
import '../../features/signup/presentation/signup_verification_page.dart';
import '../../features/short/presentation/foryou_page.dart';
import '../../features/short/presentation/short_page.dart';
import '../../features/courses/data/course_builder_api.dart';
import '../../features/courses/data/course_summary.dart';
import '../../features/courses/presentation/course_builder_page.dart';
import '../../features/profile/data/profile_role.dart';
import '../../features/profile/data/user_profile.dart';
import '../../features/profile/presentation/instructor_course_insights.dart';
import '../../features/profile/presentation/my_courses_page.dart';
import '../../features/quiz/data/quiz_api.dart';
import '../network/session.dart';
import '../widgets/loading_skeleton.dart';

/// Routes reachable with no session.
///
/// A **deny-list**, deliberately. The alternative — naming the routes that
/// require auth — means a new route is protected only if someone remembers to
/// list it, and forgetting is a silently-public screen. Here, forgetting to add
/// a public route makes it protected, which is a bug someone reports rather than
/// a leak nobody notices.
///
/// `/splash` is on the list for a second reason beyond being unauthenticated: it
/// is the router's `initialLocation`, so it must not be redirected away from at
/// startup, or the app could never settle on a screen for a returning user.
const _publicRoutes = <String>{
  '/splash',
  '/onboarding',
  '/login-screen',
  '/forgot-password',
};

/// True for a route a signed-out user may reach.
///
/// Prefix-matched rather than compared exactly, so one entry covers a whole
/// family: `/signup` covers `/signup/role`, `/signup/student` and the rest, and
/// adding a signup step does not mean remembering to add it here too.
bool isPublicRoute(String path) {
  for (final route in _publicRoutes) {
    if (path == route || path.startsWith('$route/')) return true;
  }
  // Every signup step is reached before a session exists.
  return path == '/signup' || path.startsWith('/signup/');
}

/// Re-runs the router's `redirect` whenever the session appears or disappears.
///
/// `GoRouter` evaluates `redirect` on navigation and **not again** when the state
/// it reads changes. Without this the guard is evaluated once and then goes
/// stale: signing out would not move anyone, and a session adopted during signup
/// would not unlock the routes the user is now entitled to.
///
/// Bridges Riverpod to the `Listenable` `go_router` wants, and deliberately does
/// nothing but notify. `redirect` stays the single place that decides where a
/// user belongs, so the two cannot disagree about it.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    // Only the *presence* of a session matters. Notifying on every token
    // rotation would re-run `redirect` mid-request for no reason, and the access
    // token is replaced every 30 minutes.
    ref.listen<Session?>(sessionProvider, (previous, next) {
      if ((previous != null) != (next != null)) notifyListeners();
    });
    ref.listen<ProfileRole?>(
      userProfileProvider.select((profile) => profile.role),
      (previous, next) {
        if (previous != next) notifyListeners();
      },
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Held in a local so the listener outlives this provider body — a bare
  // temporary would be collectable while the router still pointed at it.
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = ref.read(sessionProvider) != null;

      // ---- Signed out ----
      //
      // Nothing here decides where a signed-out user *goes*; they are left where
      // they are if the route is public. That keeps the public screens navigable
      // between each other and removes the loop risk in this direction: a
      // signed-out user sent to `/login-screen` cannot be redirected again from
      // there, because that path is public.
      if (!signedIn) {
        return isPublicRoute(path) ? null : '/login-screen';
      }

      // ---- Signed in ----

      // Splash is where the app starts, and onboarding is the pre-signup pitch.
      // Neither has anything to show a signed-in user.
      if (path == '/splash' || path == '/onboarding') return '/';

      // Login and password recovery are meaningless with a session, and landing
      // on them signed in is how a user ends up in a loop.
      if (path == '/login-screen' || path == '/forgot-password') return '/';

      // Instructor screens. A known student is sent home. An unknown role
      // stays, and the page shows a checking state until `/me/` lands — a
      // real instructor is not bounced away for the moment before that.
      if (path == '/instructor' || path.startsWith('/instructor/')) {
        final role = ref.read(userProfileProvider).role;
        if (role != null && role != ProfileRole.instructor) return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login-screen',
        name: 'login-screen',
        builder: (context, state) => const LoginScreenPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/signup/role',
        name: 'signup-role',
        builder: (context, state) => const SignupRolePage(),
      ),
      GoRoute(
        path: '/signup/instructor',
        name: 'signup-instructor',
        builder: (context, state) => const SignupInstructorFormPage(),
      ),
      GoRoute(
        path: '/signup/student',
        name: 'signup-student',
        builder: (context, state) => const SignupStudentFormPage(),
      ),
      GoRoute(
        path: '/signup/interests',
        name: 'signup-interests',
        builder: (context, state) => const SignupInterestsPage(),
      ),
      GoRoute(
        path: '/signup/verify',
        name: 'signup-verify',
        builder: (context, state) => const SignupVerificationPage(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/instructor/courses/new',
        name: 'instructor-course-new',
        builder: (context, state) => _InstructorGate(
          child: _courseBuilder(context),
        ),
      ),
      GoRoute(
        path: '/instructor/courses/:id/edit',
        name: 'instructor-course-edit',
        redirect: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return '/instructor/courses';
          return null;
        },
        builder: (context, state) => _InstructorGate(
          child: _courseBuilder(
            context,
            courseId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/instructor/courses/:id',
        name: 'instructor-course',
        redirect: (context, state) {
          if (state.extra is! CourseSummary) return '/instructor/courses';
          return null;
        },
        builder: (context, state) => _InstructorGate(
          child: InstructorCourseDetailsPage(
            course: state.extra! as CourseSummary,
          ),
        ),
      ),
      GoRoute(
        path: '/instructor/courses',
        name: 'instructor-courses',
        builder: (context, state) =>
            const _InstructorGate(child: MyCoursesPage()),
      ),
      GoRoute(
        path: '/short',
        name: 'short',
        builder: (context, state) => const ShortPage(),
      ),
      GoRoute(
        path: '/short/for-you',
        name: 'short-for-you',
        builder: (context, state) => const ForyouPage(),
      ),
    ],
  );
});

CourseBuilderPage _courseBuilder(BuildContext context, {int? courseId}) {
  final container = ProviderScope.containerOf(context);
  return CourseBuilderPage(
    api: container.read(courseBuilderApiProvider),
    quizApi: container.read(quizApiProvider),
    instructorVerified: container.read(userProfileProvider).canPublish,
    courseId: courseId,
  );
}

/// Instructor pages wait here while the role is still unknown.
class _InstructorGate extends ConsumerWidget {
  const _InstructorGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userProfileProvider.select((profile) => profile.role));
    if (role == ProfileRole.instructor) return child;
    return const Scaffold(
      backgroundColor: Color(0xFFFAF9F6),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checking your account'),
            SizedBox(height: 16),
            CourseListSkeleton(rows: 3),
          ],
        ),
      ),
    );
  }
}
