import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// `DI` from "Design Thinking" — the letters the generated cover prints.
///
/// One implementation, because the builder previews this tile and the catalogue
/// draws it: two copies would eventually disagree about what a course with no
/// cover looks like.
String courseInitials(String title) {
  final words = title.trim().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return 'NEW';
  if (words.length == 1) {
    return words.first
        .substring(0, words.first.length.clamp(0, 2))
        .toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// The cover a course has **when the instructor has not uploaded one**.
///
/// The builder has always previewed this: a tinted tile with the title's
/// initials and the caption *"A generated tile is used until you add one."*
/// The catalogue did not — it swapped in a stock illustration matched by
/// keyword, so a course called `paytest` in the Coding category appeared with
/// the Python logo, which is a cover nobody uploaded. This tile is that
/// promise kept: no cover looks like no cover, and it looks the same on both
/// screens.
class CourseCoverTile extends StatelessWidget {
  const CourseCoverTile(this.title, {super.key, this.seed = 0});

  final String title;

  /// Picks the tint. Seeded with the course id, not a random number: a grid
  /// that reshuffles its colours on every rebuild reads as a loading state that
  /// never settles, and a course should look the same between launches.
  final int seed;

  /// Four tints, matching the palette the design uses for course covers. The
  /// first is the gold the builder previews, so an unsaved draft (id 0) is the
  /// colour the wizard shows it in.
  static const _tints = <({Color from, Color to, Color ink})>[
    (from: Color(0xFFFBE8A8), to: Color(0xFFEFCB63), ink: Color(0xFF6B5410)),
    (from: Color(0xFFCFE3F7), to: Color(0xFF9CC4E8), ink: Color(0xFF274B6B)),
    (from: Color(0xFFE7DCF7), to: Color(0xFFC3A9EA), ink: Color(0xFF4A3570)),
    (from: Color(0xFFD7EBD3), to: Color(0xFFA8D3A0), ink: Color(0xFF33512C)),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[seed.abs() % _tints.length];
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same tile has to read at 60pt (a list thumbnail) and at 210pt (a
        // course banner), so the letters scale with the box.
        final side = constraints.biggest.shortestSide;
        final fontSize = side.isFinite ? (side * 0.28).clamp(12.0, 40.0) : 20.0;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint.from, tint.to],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            courseInitials(title),
            maxLines: 1,
            style: GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: tint.ink,
            ),
          ),
        );
      },
    );
  }
}
