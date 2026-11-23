import 'package:flutter/material.dart';

const _block = Color(0xFFEDEBE6);
const _cardBorder = Color(0xFFF3F4F6);

/// A grey block standing in for content that is still loading.
///
/// Static on purpose: an animated shimmer keeps a frame scheduled, which makes
/// `pumpAndSettle` time out in widget tests.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _block,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Two columns of course-card outlines, the same shape as `CourseCardGrid`.
class CourseGridSkeleton extends StatelessWidget {
  const CourseGridSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row + 1 < rows ? 12 : 0),
            child: const Row(
              children: [
                Expanded(child: _CardSkeleton()),
                SizedBox(width: 12),
                Expanded(child: _CardSkeleton()),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(height: 98, radius: 0),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 60, height: 14),
                SizedBox(height: 10),
                SkeletonBlock(height: 12),
                SizedBox(height: 6),
                SkeletonBlock(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows of thumbnail-plus-text outlines, for list screens.
class CourseListSkeleton extends StatelessWidget {
  const CourseListSkeleton({super.key, this.rows = 4, this.thumb = 80});

  final int rows;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Container(
            margin: EdgeInsets.only(bottom: row + 1 < rows ? 12 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                SkeletonBlock(width: thumb, height: thumb, radius: 10),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(height: 14),
                      SizedBox(height: 8),
                      SkeletonBlock(width: 120, height: 12),
                      SizedBox(height: 14),
                      SkeletonBlock(width: 70, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
