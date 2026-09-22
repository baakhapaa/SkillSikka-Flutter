import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom sheet used by the signup and edit-profile forms for their dropdown
/// fields (gender, class, province, …). Returns the chosen option, or `null`
/// when the user dismisses it.
///
/// The signup forms keep a private copy of this (`_pickOption`); new screens
/// should use this one.
Future<String?> showOptionPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          ...options.map(
            (option) => ListTile(
              title: Text(option),
              onTap: () => Navigator.pop(context, option),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
