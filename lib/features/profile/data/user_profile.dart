import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_role.dart';

/// Upload slots held in [UserProfile.documents].
///
/// Named constants rather than bare strings because the same slot has to be
/// written by a form and later read by the multipart assembly — a typo in one
/// of those two places would drop a file silently rather than fail.
abstract final class ProfileDocumentSlot {
  static const cvResume = 'cv_resume';
  static const certificates = 'certificates';
  static const studentIdCard = 'student_id_card';
}

/// A file the user picked, held in memory until there is an API to send it to.
///
/// Bytes rather than a path: the app runs on Flutter web, where a picked file's
/// path is a blob URL that nothing else can read.
@immutable
class PickedDocument {
  const PickedDocument({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  bool operator ==(Object other) =>
      other is PickedDocument &&
      other.fileName == fileName &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(fileName, Object.hashAll(bytes));
}

/// What the app knows about the signed-in user.
///
/// Signup fills part of it; Edit Profile completes the rest. Session-scoped and
/// in-memory on purpose — it stands in for the API until `POST /auth/register`
/// and `PATCH /users/me` exist, at which point it becomes the request body
/// rather than a competing source of truth.
///
/// Text fields live in a map keyed the way the form controllers are, so one key
/// list drives the edit form, the completeness check and the eventual JSON. A
/// field therefore cannot be added to the form and missed by the check.
///
/// Known keys: `name`, `email`, `phone`, `gender`, `dob`, `location`, `grade`,
/// `province`, `district`, `school`, `qualification`, `expertise`, `experience`.
///
/// Three things are *not* in [values], because they are not text fields and
/// putting them there would force the edit form and the completeness check to
/// special-case them: [role], [documents] and [interests].
@immutable
class UserProfile {
  const UserProfile({
    this.photoBytes,
    this.photoFileName,
    this.role,
    this.values = const {},
    this.documents = const {},
    this.interests = const [],
  });

  final Uint8List? photoBytes;

  /// The picked file's own name, kept alongside [photoBytes].
  ///
  /// Not cosmetic. The multipart part's content type is inferred from the
  /// extension (`package:mime`), so a JPEG sent as `avatar.png` is uploaded
  /// labelled `image/png`. Null only when there is no photo.
  final String? photoFileName;

  /// Null until the user picks one at the first signup step. A fresh launch and
  /// a deep link both legitimately have no role yet, so this stays nullable and
  /// [effectiveRole] covers the display case.
  final ProfileRole? role;

  /// Treat as immutable: go through [withValues] / [withPhoto] so the state
  /// object actually changes.
  final Map<String, String> values;

  /// Upload slots other than the avatar, keyed by [ProfileDocumentSlot]. The
  /// avatar keeps its own field so the existing pickers and their tests are
  /// untouched.
  final Map<String, PickedDocument> documents;

  /// Topic names picked at the last signup step. Order is the user's tap order.
  final List<String> interests;

  String valueFor(String key) => values[key] ?? '';

  /// Read outside the edit form, so it gets a name of its own.
  String get email => valueFor('email');

  /// The role to render before one has been chosen.
  ProfileRole get effectiveRole => role ?? ProfileRole.student;

  PickedDocument? documentFor(String slot) => documents[slot];

  UserProfile _copy({
    Uint8List? photoBytes,
    ProfileRole? role,
    Map<String, String>? values,
    Map<String, PickedDocument>? documents,
    List<String>? interests,
  }) {
    return UserProfile(
      photoBytes: photoBytes ?? this.photoBytes,
      // Carried with the bytes, always. The name describes the photo, so a text
      // update has no business clearing it — and dropping it here would leave a
      // photo that cannot be uploaded under the right content type. Only
      // [withPhoto] sets it, which is why this is not a parameter.
      photoFileName: photoFileName,
      role: role ?? this.role,
      values: values ?? this.values,
      documents: documents ?? this.documents,
      interests: interests ?? this.interests,
    );
  }

  UserProfile withValues(Map<String, String> next) =>
      _copy(values: {...values, ...next});

  /// Replaces the photo and its filename together.
  ///
  /// Built directly rather than through [_copy]: that helper keeps the previous
  /// value when handed null, which is right for a field that is simply absent
  /// but wrong here — a new photo with an unknown name would silently keep the
  /// old name, and upload under the wrong content type.
  UserProfile withPhoto(Uint8List bytes, String fileName) => UserProfile(
    photoBytes: bytes,
    photoFileName: fileName,
    role: role,
    values: values,
    documents: documents,
    interests: interests,
  );

  UserProfile withRole(ProfileRole next) => _copy(role: next);

  UserProfile withDocument(String slot, PickedDocument document) =>
      _copy(documents: {...documents, slot: document});

  /// Drops one upload slot. The screen's Remove action needs this: the bytes are
  /// copied into the store at pick time, so forgetting the slot here would leave
  /// the file the user just deleted still queued for upload.
  UserProfile withoutDocument(String slot) =>
      _copy(documents: {...documents}..remove(slot));

  UserProfile withInterests(List<String> next) =>
      _copy(interests: List<String>.unmodifiable(next));
}

/// Holds the signed-in user's profile. In-memory only: it is a stand-in for the
/// backend, so it starts empty on every launch.
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile());

  /// Records the avatar and the name of the file it came from. See
  /// [UserProfile.photoFileName] for why the name travels with the bytes.
  void setPhoto(Uint8List bytes, String fileName) =>
      state = state.withPhoto(bytes, fileName);

  /// Records the role chosen at the first signup step, and the one the profile
  /// screens branch on afterwards.
  void setRole(ProfileRole role) => state = state.withRole(role);

  /// Stores a file for an upload slot. See [ProfileDocumentSlot] for the slots.
  void setDocument(String slot, PickedDocument document) =>
      state = state.withDocument(slot, document);

  /// Forgets a file the user removed. Paired with [setDocument] at the same call
  /// sites — a Remove that only cleared the widget would still upload the old
  /// bytes, because the store has held them since the file was picked.
  void clearDocument(String slot) => state = state.withoutDocument(slot);

  void setInterests(List<String> interests) =>
      state = state.withInterests(interests);

  /// Merges one form's worth of values. Blank values are kept, so clearing a
  /// field really does clear it.
  void save(Map<String, String> values) => state = state.withValues(values);

  /// The signup popup writes here. A blank value is ignored so a dismissed or
  /// failed lookup can never wipe a location that was already captured.
  void setLocation(String value) {
    if (value.trim().isEmpty) return;
    state = state.withValues({'location': value});
  }

  void clear() => state = const UserProfile();
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
      (ref) => UserProfileNotifier(),
    );
