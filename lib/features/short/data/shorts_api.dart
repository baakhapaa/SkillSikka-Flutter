import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'short.dart';

/// Reads and writes the Shorts feed.
///
/// `GET /shorts/` is a plain list. `feed` is `stem`, `for_you`, or `challenge`.
/// Likes, bookmarks, views, and comments are the student routes from the
/// shorts feed contract.
class ShortsApi {
  const ShortsApi(this._client);

  final ApiClient _client;

  Future<List<ShortVideoData>> list({
    String? feed,
    String? search,
    CancelToken? cancelToken,
  }) async {
    final body = await _client.get<Object>(
      '/shorts/',
      query: {'feed': ?feed, 'search': ?_query(search)},
      cancelToken: cancelToken,
    );
    final rows = body is List
        ? body
        : body is Map && body['results'] is List
        ? body['results'] as List
        : const [];
    return [for (final row in rows) ?ShortVideoData.tryParse(row)];
  }

  /// Toggle. The body reports the new like state and count.
  Future<({bool isLiked, int likeCount})> toggleLike(int shortId) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/shorts/$shortId/like/',
    );
    return (
      isLiked: body['is_liked'] == true,
      likeCount: body['like_count'] is int
          ? body['like_count'] as int
          : (body['like_count'] as num?)?.round() ?? 0,
    );
  }

  Future<bool> save(int shortId) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/shorts/$shortId/save/',
    );
    return body['is_saved'] != false;
  }

  Future<void> unsave(int shortId) async {
    await _client.delete('/student/shorts/$shortId/save/');
  }

  /// Best effort. Instructors are not allowed to record a view.
  Future<void> recordView(int shortId) async {
    try {
      await _client.post<Object?>('/student/shorts/$shortId/view/');
    } on Object {
      // A view is not required for the rest of the screen.
    }
  }

  Future<List<ShortComment>> comments(int shortId) async {
    final body = await _client.get<Object>(
      '/student/shorts/$shortId/comments/',
    );
    return _comments(body);
  }

  Future<List<ShortComment>> replies(int commentId) async {
    final body = await _client.get<Object>(
      '/shorts/comments/$commentId/replies/',
    );
    return _comments(body);
  }

  Future<ShortComment?> postComment(
    int shortId, {
    required String text,
    int? parentId,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/shorts/$shortId/comments/',
      data: {'text': text, 'parent': ?parentId},
    );
    return ShortComment.tryParse(body);
  }

  Future<({bool isLiked, int likeCount})> toggleCommentLike(
    int commentId,
  ) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/shorts/comments/$commentId/like/',
    );
    return (
      isLiked: body['is_liked'] == true,
      likeCount: body['like_count'] is int
          ? body['like_count'] as int
          : (body['like_count'] as num?)?.round() ?? 0,
    );
  }

  static String? _query(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static List<ShortComment> _comments(Object? body) {
    final rows = body is List
        ? body
        : body is Map && body['results'] is List
        ? body['results'] as List
        : const [];
    return [for (final row in rows) ?ShortComment.tryParse(row)];
  }
}

final shortsApiProvider = Provider<ShortsApi>(
  (ref) => ShortsApi(ref.watch(apiClientProvider)),
);
