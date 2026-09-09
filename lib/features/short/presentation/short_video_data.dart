import 'package:flutter/material.dart';

class ShortVideoData {
  const ShortVideoData({
    required this.image,
    required this.fit,
    required this.creator,
    required this.avatar,
    required this.role,
    required this.description,
    required this.course,
    required this.likeCount,
    required this.commentCount,
    required this.shareTitle,
    required this.shareUrl,
    this.initialProgress = 0.0,
  });

  final String image;
  final BoxFit fit;
  final String creator;
  final String avatar;
  final String role;
  final String description;
  final String course;
  final int likeCount;
  final int commentCount;
  final String shareTitle;
  final String shareUrl;
  final double initialProgress;
}

const ShortVideoData kStemVideo = ShortVideoData(
  image: 'assets/images/video-background.png',
  fit: BoxFit.cover,
  creator: '@sarah_codes',
  avatar: 'assets/images/saracodes.png',
  role: 'Adobe Certified Instructor',
  description:
      'Master CSS Flexbox in 60 seconds! No crew,\n'
      'just precision layouts ⚡ #coding #webdev\n'
      '#tutorial',
  course: 'CSS Masterclass Course',
  likeCount: 25,
  commentCount: 6,
  shareTitle: 'Master CSS Flexbox in 60s',
  shareUrl: 'stemshorts.com/c/css-flex',
  initialProgress: 0.56,
);

const ShortVideoData forYouVideo = ShortVideoData(
  image: 'assets/images/react1.png',
  fit: BoxFit.contain,
  creator: '@sam_codes',
  avatar: 'assets/images/saracodes.png',
  role: 'SAM Educator',
  description:
      'React Hooks Crash Course in 45s ⚛️\n'
      'useState vs useEffect explained! #coding #reactjs\n'
      '#tutorial',
  course: 'React Masterclass',
  likeCount: 128,
  commentCount: 46,
  shareTitle: 'React Hooks Crash Course in 45s',
  shareUrl: 'stemshorts.com/c/react-hooks',
  initialProgress: 0.42,
);
