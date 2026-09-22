import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Avatar with a camera badge, used by the signup and edit-profile forms.
///
/// Takes the picked photo as **bytes**, not a `File`: `Image.file` asserts
/// `!kIsWeb`, so a `File`-based version crashes the moment a photo is chosen on
/// Flutter web. `XFile.readAsBytes()` works on every platform.
class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.photoBytes,
    required this.onTap,
    this.emptyLabel = 'Upload Profile Photo',
    this.pickedLabel = 'Change Profile Photo',
    this.hint = 'Clear face photo (JPG, PNG • Max 5MB)',
  });

  /// The chosen photo, or null for the empty state.
  final Uint8List? photoBytes;

  final VoidCallback onTap;
  final String emptyLabel;
  final String pickedLabel;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoBytes != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFFBF0), width: 2),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 244, 240, 230),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.memory(
                      photoBytes!,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset('assets/figma/signup_camera.svg'),
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasPhoto ? pickedLabel : emptyLabel,
            style: GoogleFonts.manrope(
              color: const Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: const Color(0xFF6F7175),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
