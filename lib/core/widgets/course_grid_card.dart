import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/core/widgets/course_image.dart';

const _titleInk = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _hairline = Color(0xFFF3F4F6);

/// The catalogue card, shared by the home rail and the Courses tab.
///
/// **One widget, because there were two.** The home rail drew its own card —
/// subject tag, star and rating above the title — and the Courses tab drew a
/// second one that printed the title first and left the rating stranded under
/// it. Same data, two different cards, and the "See All" grid looked like a
/// different app. Anything that changes here changes both screens, which is the
/// point.
///
/// The two rows above the title are each optional and each dropped when the
/// data is missing rather than rendered empty:
///
/// * the **tag** is `CourseDetailData.category` — the subject for an academic
///   course, the skill category otherwise. A skill course with no category has
///   no tag, and an empty grey pill reads as a loading glitch.
/// * the **rating** is blank until the course has a review (`average_rating`
///   is `null` on the wire). A bare star with no number beside it looks
///   broken, so the star goes with the number.
class CourseGridCard extends StatelessWidget {
  const CourseGridCard({
    super.key,
    required this.course,
    this.onTap,
    this.imageHeight = 98,
  });

  final CourseDetailData course;
  final VoidCallback? onTap;

  /// Fixed so the home rail and the Courses grid line up row for row.
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final tag = course.category.trim();
    final rating = course.rating.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                // Asset path from the bundled catalogue, http URL from the API
                // — `CourseImage` is the one place that branch lives.
                child: CourseImage(
                  course.image,
                  fallback: CourseThumbPlaceholder(label: tag),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag.isNotEmpty || rating.isNotEmpty) ...[
                    Row(
                      children: [
                        // The tag takes the free space and ellipsises, so a long
                        // subject cannot push the rating off the card.
                        Expanded(
                          child: tag.isEmpty
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: _tag(tag),
                                ),
                        ),
                        if (rating.isNotEmpty) ...[
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFBBF24),
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: GoogleFonts.figtree(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _titleInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: _titleInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.figtree(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: _gray,
        ),
      ),
    );
  }
}

/// The cover a course shows when it has no thumbnail.
///
/// **Every course in the dev database has `thumbnail_url: ''`** — the column
/// exists but nothing fills it, because the backend has no asset upload yet
/// (`backend-contract.md`). So this is not a rare error path on the Courses
/// tab, it is *every* card, and the old grey box with a white picture glyph
/// made the whole grid look like it had failed to load.
///
/// Instead of one grey box, a soft tint and a subject glyph, picked from the
/// subject tag. It is deliberately an illustration and not a photo: the point
/// is to look composed, never to imply there is an image we could not fetch.
class CourseThumbPlaceholder extends StatelessWidget {
  const CourseThumbPlaceholder({super.key, this.label = ''});

  /// The subject or skill category the cover stands in for.
  final String label;

  /// Light two-stop tint plus the glyph ink for each subject family. Kept pale
  /// on purpose — the real covers in the catalogue are light illustrations, so
  /// a saturated panel would read as a different kind of card.
  static const _families = <({List<String> keys, IconData icon, int tint, int ink})>[
    (
      keys: ['geometry', 'algebra', 'math', 'trigonometr', 'fraction', 'arithmetic'],
      icon: Icons.square_foot,
      tint: 0xFFE7EFFC,
      ink: 0xFF6B93D6,
    ),
    (
      keys: ['biolog', 'life', 'botany'],
      icon: Icons.biotech,
      tint: 0xFFE4F5EA,
      ink: 0xFF5CA47B,
    ),
    (
      keys: ['chem', 'matter', 'reaction', 'lab'],
      icon: Icons.science_outlined,
      tint: 0xFFF0EAFB,
      ink: 0xFF8B7BC4,
    ),
    (
      keys: ['physic', 'force', 'motion', 'newton', 'energy'],
      icon: Icons.bolt,
      tint: 0xFFFDF1E0,
      ink: 0xFFD2A04A,
    ),
    (
      keys: ['read', 'writ', 'english', 'language', 'literature'],
      icon: Icons.menu_book_outlined,
      tint: 0xFFFCEAEC,
      ink: 0xFFCB7F88,
    ),
    (
      keys: ['draw', 'art', 'paint', 'design'],
      icon: Icons.brush_outlined,
      tint: 0xFFFDECE4,
      ink: 0xFFD08C67,
    ),
    (
      keys: ['music', 'rhythm', 'melody', 'sing'],
      icon: Icons.music_note_outlined,
      tint: 0xFFE8F1F6,
      ink: 0xFF6E93A8,
    ),
    (
      keys: ['python', 'code', 'web', 'programming', 'comput'],
      icon: Icons.code,
      tint: 0xFFE8EEF7,
      ink: 0xFF64809E,
    ),
  ];

  static const _neutralTint = Color(0xFFF1F0EC);
  static const _neutralInk = Color(0xFF9A948B);

  @override
  Widget build(BuildContext context) {
    final value = label.trim().toLowerCase();
    final match = _families.where(
      (family) => family.keys.any(value.contains),
    );

    final tint = match.isEmpty ? _neutralTint : Color(match.first.tint);
    final ink = match.isEmpty ? _neutralInk : Color(match.first.ink);
    final icon = match.isEmpty ? Icons.auto_stories_outlined : match.first.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Color.alphaBlend(Colors.white.withValues(alpha: 0.55), tint)],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 34,
          color: ink.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
