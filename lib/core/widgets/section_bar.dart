import 'package:flutter/material.dart';

/// The thin vertical accent bar that sits to the left of a section heading.
///
/// This used to be a `Text('|')` in a 21pt font. That made the bar's height and
/// vertical position a by-product of the font's line box: the line box is ~28px
/// tall for 21pt Manrope while the heading's cap band is only ~12px, so the bar
/// landed several pixels above the heading's optical centre — and it drifted
/// again whenever the row used `CrossAxisAlignment.end` or the font changed.
///
/// Drawing it as a sized box makes the alignment explicit: centred against the
/// heading's line box (which for Manrope coincides with the cap-height centre),
/// so the bar reads as optically centred on the heading text.
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    this.height = 16,
    this.width = 3,
    this.color = const Color(0x1F282828),
  });

  /// Bar height. 16pt pairs with a 16pt Manrope heading, whose cap height is
  /// ~12pt, so the bar overhangs the cap band by ~2pt top and bottom.
  final double height;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}
