import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// A labelled input in the signup-form style: the label (with an optional red
/// asterisk) above a filled, 12pt-rounded field whose focused border is the
/// brand gold.
///
/// The two signup forms each keep their own near-identical private copy of this
/// (`_Field` and `_FormField`); new screens should use this one so the third
/// copy never appears.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.leading,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.enabled = true,
    this.obscureText = false,
    this.hintFontSize = 14,
    this.maxLines = 1,
  });

  /// Label above the field.
  final String label;

  /// Placeholder text.
  final String hint;

  final TextEditingController controller;

  /// Appends a red `*` to the label.
  final bool requiredField;

  /// SVG asset drawn inside the field on the left.
  final String? leading;

  /// SVG asset drawn on the right; tapping it calls [onTap].
  final String? trailing;

  /// Replaces [trailing] when the right-hand affordance is not a plain icon.
  final Widget? trailingWidget;

  /// Makes the field read-only and opens a picker instead of the keyboard.
  final VoidCallback? onTap;

  final bool enabled;
  final bool obscureText;

  /// Smaller hints for the two-up rows, where space is tight.
  final double hintFontSize;

  /// Use > 1 for free text such as a biography.
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: label),
            if (requiredField)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        enabled: enabled,
        readOnly: onTap != null,
        onTap: onTap,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            color: const Color(0xFF9CA3AF),
            fontSize: hintFontSize,
          ),
          prefixIcon: leading == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(14),
                  child: SvgPicture.asset(leading!, width: 16, height: 16),
                ),
          suffixIcon:
              trailingWidget ??
              (trailing == null
                  ? null
                  : IconButton(
                      onPressed: onTap,
                      icon: SvgPicture.asset(trailing!, width: 16, height: 16),
                    )),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF2F1F7),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE6B800)),
          ),
        ),
      ),
    ],
  );
}
