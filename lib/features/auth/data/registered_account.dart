import 'package:flutter/foundation.dart';

import '../../profile/data/profile_role.dart';

/// What the auth endpoints told us about an account — returned by registration,
/// and by OTP verification when the backend issues the session there.
///
/// **This class is where the one open backend question lives.** The handover doc
/// (§6.1) asks whether `POST /auth/register` returns a token or whether the user
/// has to pass OTP first. Both models are parsed here and nowhere else, so when
/// the answer arrives this file is the only one that has to change.
@immutable
class RegisteredAccount {
  const RegisteredAccount({
    required this.email,
    this.userId,
    this.role,
    this.status,
    this.accessToken,
  });

  /// The address the account was created for. The OTP screen needs it, and it
  /// is the one field the rest of the flow cannot proceed without.
  final String email;

  final String? userId;

  /// Null when the response carried a role we do not recognise.
  ///
  /// Deliberately not coerced to `student`: an unrecognised role means the
  /// contract has drifted, and showing a student's field set to an instructor
  /// would hide that rather than surface it.
  final ProfileRole? role;

  /// e.g. `pending` while an instructor awaits admin review (doc §11).
  final String? status;

  /// Null when the backend verifies by OTP before issuing a session.
  final String? accessToken;

  /// True when this response established a session, so the client can stop
  /// treating the user as signed out.
  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;

  /// Parses either response model, or returns null when the body does not
  /// describe an account at all.
  ///
  /// Tolerant on purpose: the user object may be nested under `user` or be the
  /// body itself, and the token appears as `access_token` (SimpleJWT), `token`,
  /// or `access`. None of that is guesswork we can avoid — it is the question
  /// we have asked and not yet had answered — so the cost of tolerating it here
  /// is one file instead of every call site.
  ///
  /// Null rather than a half-filled object: a body with no identity in it is a
  /// contract mismatch, and [AuthApi] turns that into an error rather than
  /// letting the flow continue with empty strings.
  static RegisteredAccount? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<String, dynamic>();

    // `{"user": {...}}` or the user's fields at the top level.
    final nested = json['user'];
    final user = nested is Map ? nested.cast<String, dynamic>() : json;

    final email = _firstString([user['email'], json['email']]);
    final userId = _firstString([
      user['id'],
      user['pk'],
      user['user_id'],
      json['id'],
    ]);
    final accessToken = _firstString([
      json['access_token'],
      json['accessToken'],
      json['token'],
      json['access'],
      user['access_token'],
      user['token'],
    ]);

    // An identity or a session, or this is not an account. Checked so that a
    // 200 carrying `{"detail": "ok"}` cannot be mistaken for a registration.
    if (email == null && userId == null && accessToken == null) return null;

    return RegisteredAccount(
      email: email ?? '',
      userId: userId,
      role: ProfileRole.tryParse(_firstString([user['role'], json['role']])),
      status: _firstString([user['status'], json['status']]),
      accessToken: accessToken,
    );
  }

  @override
  String toString() =>
      'RegisteredAccount(email: $email, role: ${role?.wireValue}, '
      'status: $status, hasSession: $hasSession)';
}

/// The first non-blank string in [candidates], or null.
///
/// Values are trimmed and blanks treated as absent, so `{"token": ""}` reads as
/// "no token" rather than as a session that is not there.
String? _firstString(List<Object?> candidates) {
  for (final candidate in candidates) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return null;
}
