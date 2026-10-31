import 'package:flutter/material.dart';

import 'course_cover_tile.dart';

/// An image whose source may be a bundled asset **or** a server URL.
///
/// Every course image in this app used to be an asset path, and `Image.asset`
/// was correct everywhere. The API changed that: `thumbnail_url`,
/// `profile_photo_url` and `avatar` are http URLs, and `Image.asset` on a URL
/// does not throw — it fails to resolve and falls through to `errorBuilder`, so
/// **every card renders its grey placeholder** and the screen looks like the
/// content is missing rather than the code being wrong.
///
/// So the branch lives in one place. Anything that renders a course or
/// instructor image goes through here and stops caring which it has.
class CourseImage extends StatelessWidget {
  const CourseImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
    this.title = '',
    this.coverSeed = 0,
  });

  /// An asset path (`assets/figma/…`) or an http(s) URL. Empty means neither.
  final String path;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Shown when there is no usable image. Each call site keeps its own, because
  /// a 40px avatar and a 210px banner need different placeholders.
  ///
  /// Ignored when [title] is set — see below.
  final Widget? fallback;

  /// A course's title, when this is a **course cover** rather than an avatar.
  ///
  /// With a title and no image, the placeholder is [CourseCoverTile]: the gold
  /// initials tile the builder previews. A course the instructor never gave a
  /// cover to should look like a course without a cover — not like a stock
  /// illustration of whatever subject its title happened to match, which is
  /// what the catalogue used to draw.
  final String title;

  /// The course id the generated tile tints from. Ignored without [title].
  final int coverSeed;

  bool get _isRemote {
    final value = path.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final source = path.trim();
    if (source.isEmpty) return _placeholder();

    if (_isRemote) {
      return Image.network(
        source,
        fit: fit,
        width: width,
        height: height,
        // A broken URL and a missing asset both land here, which is the point:
        // the screen degrades to the same placeholder either way.
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(),
      );
    }

    return Image.asset(
      source,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    if (title.trim().isNotEmpty) {
      return CourseCoverTile(title, seed: coverSeed);
    }
    if (fallback != null) return fallback!;
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Icon(Icons.image, color: Colors.white, size: 28),
    );
  }
}
