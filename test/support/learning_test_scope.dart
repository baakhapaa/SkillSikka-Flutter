import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/learning/data/learning_api.dart';
import 'package:skillsikka/features/learning/data/my_learning.dart';

/// Wraps [child] in a scope whose My Learning payload is fixed.
///
/// **Why this exists.** `MyLearningPage` reads `GET /my-learning/` as of
/// 2026-10-27, and `AppShell` mounts it inside an `IndexedStack` — so *every*
/// test that pumps the shell now fires that request, including ones that only
/// measure the footer. dio answers 400 under `flutter test`, which arrives as an
/// error state and a logged exception rather than a clean pass.
///
/// Overriding the provider rather than the API is deliberate: it is the single
/// seam the screen reads, so one override removes the request and leaves the
/// screen's own empty/loaded rendering under test.
///
/// The default is an **empty** dashboard, which makes the screen render its
/// "nothing in progress" state — the right thing for a test that is not about
/// My Learning.
///
/// [failure] makes the provider throw instead, which is how the failure screen
/// is reached. It takes an `Object?` rather than an `ApiException` because the
/// page must cope with whatever arrives, including a plain [FormatException].
///
/// [auth] replaces the auth repository for the "Sign in again" action — the page
/// ends the session through it, and the real one would open a socket.
Widget learningTestScope({
  required Widget child,
  MyLearning? learning,
  Object? failure,
  AuthRepository? auth,
}) {
  return ProviderScope(
    overrides: [
      myLearningProvider.overrideWith((ref) async {
        if (failure != null) throw failure;
        return learning ?? const MyLearning();
      }),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
    child: child,
  );
}
