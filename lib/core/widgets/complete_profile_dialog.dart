import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/profile/data/profile_completeness.dart';
import 'location_prompt_dialog.dart';

/// Shows the "finish your profile before you enrol" popup.
///
/// Returns `true` only when the user chose to complete their profile now.
/// Dismissal and "Not Now" both return `false`, and the caller must not enrol
/// in either case.
Future<bool> showCompleteProfileDialog(
  BuildContext context, {
  required ProfileCompleteness completeness,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Complete your profile',
    barrierColor: const Color(0x66101828),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        _CompleteProfileDialog(completeness: completeness),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _CompleteProfileDialog extends StatelessWidget {
  const _CompleteProfileDialog({required this.completeness});

  final ProfileCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A111827),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Badge(),
                const SizedBox(height: 18),
                Text(
                  'Complete your profile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppPalette.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to finish your profile before you can enrol in '
                  'this course.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppPalette.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _MissingFields(fields: completeness.missing),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.accent,
                      foregroundColor: AppPalette.ink,
                      elevation: 4,
                      shadowColor: const Color(0x40E6B800),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Complete Profile',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.inkSoft,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Not Now',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.inkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppPalette.accentSoft,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.person_outline_rounded,
      size: 34,
      color: AppPalette.brownInk,
    ),
  );
}

/// The specific fields still to fill. Naming them is the whole point — a
/// generic "your profile is incomplete" would send the user hunting.
class _MissingFields extends StatelessWidget {
  const _MissingFields({required this.fields});

  final List<ProfileField> fields;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: AppPalette.cream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x33E6B800)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fields.length == 1
              ? '1 field still needed'
              : '${fields.length} fields still needed',
          style: GoogleFonts.manrope(
            color: AppPalette.brownInk.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final field in fields)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.accentSoft,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  field.label,
                  style: GoogleFonts.manrope(
                    color: AppPalette.brownInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
