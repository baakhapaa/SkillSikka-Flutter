import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'my_learning.dart';

/// The student dashboard endpoints.
///
/// Separate from `CourseApi` because `/my-learning/` is its own resource: it
/// answers one composed payload rather than a course, and it is the only place
/// the server names a specific lesson (`continue_learning.next_lesson`).
class LearningApi {
  const LearningApi(this._client);

  final ApiClient _client;

  /// `GET /my-learning/` — hero, in-progress, completed, stats, certificates.
  ///
  /// **Students only.** An instructor or admin gets a `403` from this endpoint;
  /// the screen shows its empty state rather than an error, because "you have no
  /// courses in progress" is true for them.
  Future<MyLearning> myLearning() async {
    final body = await _client.get<Map<String, dynamic>>('/my-learning/');
    final learning = MyLearning.tryParse(body);
    if (learning == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'My Learning came back in an unexpected shape.',
      );
    }
    return learning;
  }
}

final learningApiProvider = Provider<LearningApi>(
  (ref) => LearningApi(ref.watch(apiClientProvider)),
);

/// The dashboard, fetched once per invalidation.
///
/// A `FutureProvider` rather than a notifier: the screen has no optimistic
/// writes of its own — completing a lesson happens in the player, which
/// invalidates this when it returns.
final myLearningProvider = FutureProvider<MyLearning>(
  (ref) => ref.watch(learningApiProvider).myLearning(),
);
