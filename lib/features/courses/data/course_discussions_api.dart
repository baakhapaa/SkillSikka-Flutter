import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';

/// The Q&A tab's wire client.
///
/// **This endpoint existed before the tab did.** `GET/POST
/// /courses/{id}/discussions/` shipped with the bootcamp screens and refused
/// every other course type at the resolver, so the player rendered a hardcoded
/// thread from the demo catalogue and an empty state everywhere else. The
/// backend now accepts any published course (2026-10-29); this file is the
/// client half.
///
/// Three contract details, all read off `core/bootcamp_views.py`:
///
/// 1. The list answers a **paginated envelope** (`{count,next,previous,results}`),
///    unlike `/lessons/` and `/courses/{id}/reviews/`, which answer bare arrays.
/// 2. `replies` arrive **inline** on the parent (capped at 50) and are also
///    counted by `replies_count`, which counts only visible ones.
/// 3. Threads are **one level deep**. Posting `parent` with a reply's id answers
///    400 `DISCUSSION_NOT_FOUND`, not a third level.
class CourseDiscussionsApi {
  const CourseDiscussionsApi(this._client);

  final ApiClient _client;

  /// `GET /courses/{id}/discussions/`.
  ///
  /// [ordering] accepts `-created_at` (default), `created_at` or `-likes_count`;
  /// anything else is silently replaced by the server.
  Future<CourseThreadPage> list(
    int courseId, {
    String ordering = '-created_at',
    int page = 1,
    int pageSize = 20,
  }) async {
    final body = await _client.get<Object?>(
      '/courses/$courseId/discussions/',
      query: {'ordering': ordering, 'page': page, 'page_size': pageSize},
    );
    final parsed = CourseThreadPage.tryParse(body);
    if (parsed == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The discussion came back in an unexpected shape.',
      );
    }
    return parsed;
  }

  /// Fetches an absolute `next` URL exactly as the server sent it.
  Future<CourseThreadPage> nextPage(String url) async {
    final parsed = CourseThreadPage.tryParse(await _client.get<Object?>(url));
    if (parsed == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The discussion came back in an unexpected shape.',
      );
    }
    return parsed;
  }

  /// `POST /courses/{id}/discussions/` — a new thread, or a reply when
  /// [parentId] is set.
  ///
  /// Answers 201 with the created row, already carrying `is_mine`, the author
  /// block and an empty `replies` list, so the caller can insert it without a
  /// refetch. A student without access gets 403 `NOT_ENROLLED`; an empty body
  /// gets 400 `BODY_REQUIRED`.
  Future<CourseThread> post(
    int courseId, {
    required String body,
    int? parentId,
  }) async {
    final payload = await _client.post<Object?>(
      '/courses/$courseId/discussions/',
      data: {'body': body, 'parent': ?parentId},
    );
    final thread = CourseThread.tryParse(payload);
    if (thread == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'That comment came back in an unexpected shape.',
      );
    }
    return thread;
  }

  /// `DELETE /courses/{id}/discussions/{threadId}/` — 204.
  ///
  /// Allowed for the author or an administrator. Deleting a thread cascades its
  /// replies and their likes.
  Future<void> remove(int courseId, int threadId) =>
      _client.delete('/courses/$courseId/discussions/$threadId/');

  /// `POST` / `DELETE /courses/{id}/discussions/{threadId}/like/`.
  ///
  /// **Idempotent in both directions** — liking twice still answers
  /// `likes_count: 1`. The response carries the authoritative count, so the
  /// caller can replace its optimistic guess rather than adding to it.
  Future<CourseLike> setLiked(
    int courseId,
    int threadId, {
    required bool liked,
  }) async {
    final path = '/courses/$courseId/discussions/$threadId/like/';
    final body = liked
        ? await _client.post<Object?>(path)
        : await _client.deleteOptionalBody(path);
    final parsed = CourseLike.tryParse(body);
    if (parsed == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'That reaction came back in an unexpected shape.',
      );
    }
    return parsed;
  }
}

/// One message, top-level or a reply.
class CourseThread {
  const CourseThread({
    required this.id,
    required this.body,
    required this.authorName,
    required this.when,
    this.parentId,
    this.authorRole,
    this.authorPhotoUrl,
    this.likesCount = 0,
    this.isLiked = false,
    this.isMine = false,
    this.repliesCount = 0,
    this.replies = const <CourseThread>[],
  });

  final int id;
  final int? parentId;
  final String body;
  final String authorName;

  /// `Instructor`, `Student`, `Grade 6 Student`, `Administrator` — the server's
  /// own label, or null for a role it does not name.
  final String? authorRole;

  final String? authorPhotoUrl;

  /// `just now`, `3h ago`, `2d ago` — formatted here because the server sends
  /// an ISO timestamp and the card prints one short line.
  final String when;

  final int likesCount;
  final bool isLiked;
  final bool isMine;

  /// Visible replies only; a hidden reply is excluded from both this and
  /// [replies].
  final int repliesCount;

  final List<CourseThread> replies;

  /// The instructor and admin badges. Matched on the label the server sends
  /// rather than on a role id, because that is all the payload carries.
  bool get isStaff =>
      authorRole == 'Instructor' || authorRole == 'Administrator';

  /// A thread is immutable, and a like or a reply changes exactly one of these
  /// fields — copying beats refetching the page to re-render one row.
  CourseThread copyWith({
    int? likesCount,
    bool? isLiked,
    int? repliesCount,
    List<CourseThread>? replies,
  }) => CourseThread(
    id: id,
    parentId: parentId,
    body: body,
    authorName: authorName,
    when: when,
    authorRole: authorRole,
    authorPhotoUrl: authorPhotoUrl,
    likesCount: likesCount ?? this.likesCount,
    isLiked: isLiked ?? this.isLiked,
    isMine: isMine,
    repliesCount: repliesCount ?? this.repliesCount,
    replies: replies ?? this.replies,
  );

  static CourseThread? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    if (id is! int) return null;

    final author = value['author'];
    final authorMap = author is Map ? author : const <String, dynamic>{};

    final replies = <CourseThread>[];
    final rawReplies = value['replies'];
    if (rawReplies is List) {
      for (final row in rawReplies) {
        final parsed = tryParse(row);
        if (parsed != null) replies.add(parsed);
      }
    }

    return CourseThread(
      id: id,
      parentId: value['parent'] is int ? value['parent'] as int : null,
      body: value['body'] is String ? value['body'] as String : '',
      authorName: _str(authorMap['name'], fallback: 'Someone'),
      authorRole: _str(authorMap['role_label']).isEmpty
          ? null
          : _str(authorMap['role_label']),
      authorPhotoUrl: _str(authorMap['profile_photo_url']).isEmpty
          ? null
          : _str(authorMap['profile_photo_url']),
      when: relativeWhen(value['created_at']),
      likesCount: value['likes_count'] is int ? value['likes_count'] as int : 0,
      isLiked: value['is_liked'] == true,
      isMine: value['is_mine'] == true,
      repliesCount: value['replies_count'] is int
          ? value['replies_count'] as int
          : replies.length,
      replies: replies,
    );
  }
}

/// One page of `GET /courses/{id}/discussions/`.
class CourseThreadPage {
  const CourseThreadPage({
    required this.count,
    required this.threads,
    this.next,
  });

  /// The total across every page — what the tab's badge prints.
  final int count;

  final List<CourseThread> threads;

  /// The server's absolute `next` URL, or null on the last page.
  final String? next;

  static CourseThreadPage? tryParse(Object? body) {
    if (body is! Map) return null;
    final results = body['results'];
    if (results is! List) return null;
    final next = body['next'];
    return CourseThreadPage(
      count: body['count'] is int ? body['count'] as int : results.length,
      next: next is String && next.trim().isNotEmpty ? next.trim() : null,
      threads: [for (final row in results) ?CourseThread.tryParse(row)],
    );
  }
}

/// What a like/unlike answers.
class CourseLike {
  const CourseLike({
    required this.threadId,
    required this.isLiked,
    required this.likesCount,
  });

  final int threadId;
  final bool isLiked;
  final int likesCount;

  static CourseLike? tryParse(Object? body) {
    if (body is! Map) return null;
    final id = body['discussion_id'];
    if (id is! int) return null;
    return CourseLike(
      threadId: id,
      isLiked: body['is_liked'] == true,
      likesCount: body['likes_count'] is int ? body['likes_count'] as int : 0,
    );
  }
}

/// `just now`, `12m ago`, `3h ago`, `2d ago`, `3w ago`, `4mo ago`, `2y ago`.
///
/// Deliberately finer than `CourseMapper`'s review formatter, which stops at
/// days: a Q&A thread is read within the hour, and `today` on a message posted
/// two minutes ago reads as broken.
String relativeWhen(Object? value, {DateTime? now}) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) return '';
  final elapsed = (now ?? DateTime.now()).difference(parsed.toLocal());
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  if (elapsed.inDays < 30) return '${elapsed.inDays ~/ 7}w ago';
  if (elapsed.inDays < 365) return '${elapsed.inDays ~/ 30}mo ago';
  return '${elapsed.inDays ~/ 365}y ago';
}

String _str(Object? value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

final courseDiscussionsApiProvider = Provider<CourseDiscussionsApi>(
  (ref) => CourseDiscussionsApi(ref.watch(apiClientProvider)),
);
