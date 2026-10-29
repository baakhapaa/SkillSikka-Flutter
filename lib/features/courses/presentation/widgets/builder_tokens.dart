import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours lifted from `profile_page.dart`, so the builder cannot drift away
/// from the tab it is pushed from. Named `builder*` rather than `_`-prefixed
/// because four files share them.
const builderBg = Color(0xFFFAF9F6);
const builderInk = Color(0xFF111827);
const builderGray = Color(0xFF4B5563);
const builderMuted = Color(0xFF9CA3AF);
const builderBorder = Color(0xFFEAEAEA);
const builderCardBorder = Color(0xFFF3F4F6);
const builderYellow = Color(0xFFE6B800);
const builderAddFill = Color(0xFFFFFBEB);
const builderCream = Color(0xFFFFFBF0);
const builderBrown = Color(0xFF2F2600);
const builderPillFill = Color(0xFFFFF4CC);
const builderFieldBorder = Color(0xFFE5E7EB);
const builderDanger = Color(0xFFEF4444);
const builderSuccess = Color(0xFF16A34A);

/// The dashed gold "add something" tile from the profile grid.
///
/// Reused here for *Add module* and *Add lesson* because the instructor has just
/// tapped the same affordance to open the builder — teaching it once is cheaper
/// than teaching it twice.
class BuilderAddTile extends StatelessWidget {
  const BuilderAddTile({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: builderAddFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: builderYellow, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: builderYellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: builderYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker, drawn to match `LabeledTextField`'s
/// box so a form of both does not look like two different forms.
///
/// Exists instead of `LabeledTextField(onTap:)` because that widget needs a
/// `TextEditingController` to display the value, and a picker has no text to
/// own — the value lives in the draft.
class BuilderPickerField extends StatelessWidget {
  const BuilderPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.requiredField = false,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: GoogleFonts.manrope(
              color: builderInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: label),
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: builderDanger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: builderFieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: hasValue ? builderInk : builderMuted,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: builderMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
