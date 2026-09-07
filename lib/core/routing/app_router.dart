import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/login_screen/presentation/login_screen_page.dart';
import '../../features/splash/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/signup/presentation/signup_role_page.dart';
import '../../features/signup/presentation/signup_instructor_form_page.dart';
import '../../features/signup/presentation/signup_student_form_page.dart';
import '../../features/signup/presentation/signup_interests_page.dart';
import '../../features/signup/presentation/signup_verification_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
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
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});
