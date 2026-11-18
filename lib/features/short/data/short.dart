import 'package:flutter/material.dart';

/// One Short from `GET /shorts/`.
class ShortVideoData {
  const ShortVideoData({
    this.id,
    required this.image,
    this.fit = BoxFit.cover,
    required this.creator,
    required this.avatar,
    required this.role,
    required this.description,
    required this.course,
    this.courseId,
    this.quizId,
    this.quizTitle,
    required this.likeCount,
    required this.commentCount,
    required this.shareTitle,
    required this.shareUrl,
    this.videoUrl = '',
    this.isLiked = false,
    this.isSaved = false,
    this.initialProgress = 0.0,
  });

  final int? id;
  final String image;
  final BoxFit fit;
  final String creator;
  final String avatar;
  final String role;
  final String description;
  final String course;
  final int? courseId;
  final int? quizId;
  final String? quizTitle;
  final int likeCount;
  final int commentCount;
  final String shareTitle;
  final String shareUrl;
  final String videoUrl;
  final bool isLiked;
  final bool isSaved;
  final double initialProgress;

  bool get hasNetworkImage => image.startsWith('http');
  bool get hasNetworkAvatar => avatar.startsWith('http');

  ShortVideoData copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return ShortVideoData(
      id: id,
      image: image,
      fit: fit,
      creator: creator,
      avatar: avatar,
      role: role,
      description: description,
      course: course,
      courseId: courseId,
      quizId: quizId,
      quizTitle: quizTitle,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareTitle: shareTitle,
      shareUrl: shareUrl,
      videoUrl: videoUrl,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      initialProgress: initialProgress,
    );
  }

  static ShortVideoData? tryParse(Object? row) {
    if (row is! Map) return null;
    final id = _int(row['id']);
    if (id == null) return null;
    final title = _str(row['title']);
    final caption = _str(row['caption']);
    final name = _str(row['instructor_name']);
    return ShortVideoData(
      id: id,
      image: _str(row['thumbnail_url']).isNotEmpty
          ? _str(row['thumbnail_url'])
          : _str(row['video_url']),
      creator: name.isEmpty ? 'Instructor' : name,
      avatar: _str(row['instructor_photo_url']),
      role: _str(row['instructor_title']),
      description: caption.isNotEmpty ? caption : title,
      course: _str(row['course_title']),
      courseId: _int(row['course']),
      quizId: _int(row['quiz']),
      quizTitle: _nullable(row['quiz_title']),
      likeCount: _int(row['like_count']) ?? 0,
      commentCount: _int(row['comment_count']) ?? 0,
      shareTitle: title.isEmpty ? 'Short' : title,
      shareUrl: _str(row['video_url']),
      videoUrl: _str(row['video_url']),
      isLiked: row['is_liked'] == true,
      isSaved: row['is_saved'] == true,
    );
  }
}

class ShortComment {
  const ShortComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.isCreator = false,
  });

  final int id;
  final String author;
  final String text;
  final DateTime? createdAt;
  final int? parentId;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool isCreator;

  static ShortComment? tryParse(Object? row) {
    if (row is! Map) return null;
    final id = _int(row['id']);
    if (id == null) return null;
    return ShortComment(
      id: id,
      author: _str(row['student_name']).isEmpty
          ? 'Student'
          : _str(row['student_name']),
      text: _str(row['text']),
      createdAt: row['created_at'] is String
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      parentId: _int(row['parent']),
      likeCount: _int(row['like_count']) ?? 0,
      replyCount: _int(row['reply_count']) ?? 0,
      isLiked: row['is_liked'] == true,
      isCreator: row['is_creator'] == true,
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return null;
}

String _str(Object? value) => value is String ? value.trim() : '';

String? _nullable(Object? value) {
  final text = _str(value);
  return text.isEmpty ? null : text;
}
