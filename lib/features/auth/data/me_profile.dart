import 'package:flutter/foundation.dart';

import '../../profile/data/profile_role.dart';

/// What `GET /me/` returns for the signed-in user.
///
/// **Shape confirmed against the live backend on 2026-09-28**, not inferred:
///
/// ```json
/// {"id":"12","email":"...","name":"Me Probe","role":"student",
///  "verification_status":"not_applicable","onboarding_completed":false,
///  "is_active":true}
/// ```
///
/// **Flat, unlike the auth responses.** `/register/` and `/login/` nest the user
/// under `user` and add `tokens`; `/me/` puts the fields at the top level and has
/// no tokens at all — it is a read of the current user, not a session. The
/// tolerant wrappers below accept either, so one model covers both, but the
/// flat form is what this endpoint actually sends.
///
/// The backend's own schema documents this endpoint as having **no response
/// body**, which is wrong — it returns the object above. Do not trust that
/// description when changing anything here; the live response is in the doc
/// comment above for exactly that reason.
@immutable
class MeProfile {
  const MeProfile({
    this.userId,
    this.email,
    this.name,
    this.role,
    this.verificationStatus,
    this.onboardingCompleted,
    this.isActive,
  });

  final String? userId;
  final String? email;
  final String? name;

  /// Null when the server sent a role we do not recognise.
  ///
  /// Deliberately not coerced to `student`, for the same reason as
  /// `RegisteredAccount.role`: an unrecognised role means the contract drifted,
  /// and silently showing a student's screens to an instructor hides it.
  final ProfileRole? role;

  /// `not_applicable` / `pending` / `verified` / `rejected`. Instructors are
  /// `pending` until an admin reviews them.
  final String? verificationStatus;

  /// True once the user has finished the onboarding the backend tracks. Not the
  /// same thing as this app's profile-completion gate, which is computed
  /// client-side from [UserProfile.values] — keep the two apart.
  final bool? onboardingCompleted;

  final bool? isActive;

  /// Parses the `/me/` body, or returns null when it carries no identity.
  ///
  /// Null rather than a half-filled object, matching `RegisteredAccount`: a body
  /// with neither an id nor an email is a contract mismatch, and returning it
  /// would let the caller overwrite a good profile with blanks.
  static MeProfile? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<String, dynamic>();

    // `/me/` is flat but a `user` wrapper costs nothing to accept, and the same
    // model then also reads an auth response's user object if it is ever handed
    // one.
    final nested = json['user'];
    final user = nested is Map ? nested.cast<String, dynamic>() : json;

    final userId = _firstString([user['id'], user['pk'], user['user_id']]);
    final email = _firstString([user['email']]);

    // No id and no email means this is not a user object.
    if (userId == null && email == null) return null;

    return MeProfile(
      userId: userId,
      email: email,
      name: _firstString([user['name'], user['full_name'], user['fullname']]),
      role: ProfileRole.tryParse(_firstString([user['role']])),
      verificationStatus: _firstString([
        user['verification_status'],
        // The older name, kept as a fallback so a drift here degrades instead
        // of dropping the status.
        user['status'],
      ]),
      onboardingCompleted: _firstBool(user['onboarding_completed']),
      isActive: _firstBool(user['is_active']),
    );
  }

  /// Only the fields that map onto [UserProfile.values], for merging.
  ///
  /// Blank values are **omitted**, not written as empty strings: the caller
  /// merges this over an existing profile, and an empty string would erase a
  /// value the user typed. Absent keys leave those fields alone.
  Map<String, String> get profileValues => {
    if ((name ?? '').isNotEmpty) 'name': name!,
    if ((email ?? '').isNotEmpty) 'email': email!,
  };

  @override
  String toString() =>
      'MeProfile(id: $userId, email: $email, role: ${role?.wireValue}, '
      'verification: $verificationStatus)';
}

/// The first non-blank scalar in [candidates], as a string, or null.
///
/// Duplicated from `registered_account.dart` rather than shared: it is six lines,
/// and a shared "json helpers" module for one function would be a bigger
/// dependency than the duplication. Numbers are stringified because a Django
/// `AutoField` id arrives as a JSON **number** — accepting only strings drops
/// the id silently.
String? _firstString(List<Object?> candidates) {
  for (final candidate in candidates) {
    if (candidate is num) return candidate.toString();
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return null;
}

/// A bool, or null when the value is absent or not a bool.
///
/// Not `value as bool?`: a JSON `"false"` or `0` would throw on the cast, and a
/// wrong type in one optional field should not fail the whole parse.
bool? _firstBool(Object? value) => value is bool ? value : null;
