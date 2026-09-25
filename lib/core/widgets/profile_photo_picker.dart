import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// The photo types and size the backend accepts.
///
/// Confirmed by the backend handoff §6: JPG, JPEG or PNG, maximum 5 MB, and an
/// oversized or wrong-typed file comes back as a 400. Checked here so the user is
/// told before the upload rather than after a round trip — the backend stays
/// authoritative, this is only the courtesy.
const kProfilePhotoExtensions = <String>{'jpg', 'jpeg', 'png'};
const kProfilePhotoMaxBytes = 5 * 1024 * 1024;

/// Why a picked photo cannot be uploaded, or null when it is acceptable.
///
/// [fileName] is checked because the backend rejects by type and a renamed file
/// would otherwise sail through the picker. [byteCount] is the size of what would
/// actually be sent, not of the file on disk — `image_picker` re-encodes, so the
/// two differ, and it is the sent bytes that the server measures.
String? profilePhotoRejection({
  required String fileName,
  required int byteCount,
}) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  if (!kProfilePhotoExtensions.contains(extension)) {
    return 'Profile photo must be a JPG or PNG.';
  }
  if (byteCount > kProfilePhotoMaxBytes) {
    // The backend's own wording for this case, so the message does not change
    // depending on whether the client or the server caught it.
    return 'Profile photo must not exceed 5 MB.';
  }
  return null;
}

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
