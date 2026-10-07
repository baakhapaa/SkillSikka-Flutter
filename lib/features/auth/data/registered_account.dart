import 'package:flutter/foundation.dart';

import '../../profile/data/profile_role.dart';

/// What the auth endpoints told us about an account — returned by registration,
/// and by OTP verification when the backend issues the session there.
///
/// The shape is now **confirmed**, not guessed. Registration returns
/// `{"user": {...}, "tokens": {"refresh": ..., "access": ...}}` and the user
/// object carries `verification_status`, not `status` (backend response §1).
///
/// The tolerant fallbacks below are kept deliberately: they cost nothing and
/// they are the difference between a contract drift showing up as a missing
/// token and it showing up as an exception. But the confirmed paths are checked
/// **first**, and they are what the code should be read as expecting.
@immutable
class RegisteredAccount {
  const RegisteredAccount({
    required this.email,
    this.userId,
    this.role,
    this.status,
    this.accessToken,
    this.refreshToken,
    this.emailVerificationRequired = false,
    this.emailVerified,
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

  /// From `user.verification_status` — e.g. `pending` while an instructor awaits
  /// admin review, and one of `not_applicable` / `pending` / `verified` /
  /// `rejected`.
  final String? status;

  /// Null when the backend verifies by OTP before issuing a session.
  final String? accessToken;

  /// From `tokens.refresh`. Exchanged for a new access token when the 30-minute
  /// one expires (handoff §10); without it the session cannot be renewed.
  final String? refreshToken;

  /// True when the server created the account but **withheld the session** until
  /// the emailed code is confirmed.
  ///
  /// Shipped 2026-10-07. Both roles now register this way — the response is a
  /// 201 whose body is
  ///
  /// ```json
  /// {"user": {"id":"25","email":"…","name":"…","role":"student",
  ///           "verification_status":"not_applicable","email_verified":false},
  ///  "detail": "Verify your email to complete signup.",
  ///  "email_verification_required": true}
  /// ```
  ///
  /// — measured live, for a student (id 25) and an instructor (id 26). Note
  /// there is **no `tokens` key at all**, which is why [hasSession] is false
  /// here and why the signup screens must route to the OTP step rather than
  /// into the app.
  ///
  /// Read from the top level **and** from under `user`: the live response puts
  /// it at the top, but the flag is about the user, so both are checked and the
  /// cost of the second lookup is nil.
  final bool emailVerificationRequired;

  /// From `user.email_verified`. Null when the response did not say, which is
  /// the case for `/login/` and for any endpoint that predates the flag.
  final bool? emailVerified;

  /// True when this account still has to clear the email gate before it can be
  /// used for anything.
  ///
  /// **The session test is the load-bearing half, not the flag.** The backend
  /// documents `email_verification_required`, but the invariant that actually
  /// matters is "registration did not hand us a usable session" — and an
  /// account with no token cannot be used whatever the reason. Reading it that
  /// way means this stays correct even if a future response omits the flag, and
  /// it cannot route a session-carrying response to the OTP screen.
  ///
  /// For `/login/` this is always false: a login either issues a session (so
  /// `hasSession` holds) or fails outright — an unverified account is refused
  /// with a 400 rather than a tokenless 200.
  bool get needsEmailVerification => emailVerificationRequired || !hasSession;

  /// True when this response established a session, so the client can stop
  /// treating the user as signed out.
  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;

  /// Parses the confirmed response shape, or returns null when the body does
  /// not describe an account at all.
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

    // `{"tokens": {"access": ..., "refresh": ...}}` is the confirmed nesting.
    // Reading only the top level here was a real bug: the token was one level
    // down, so a *successful* registration parsed as "registered but not signed
    // in" and the user was left on the OTP step with no session.
    final nestedTokens = json['tokens'];
    final tokens = nestedTokens is Map
        ? nestedTokens.cast<String, dynamic>()
        : const <String, dynamic>{};

    final email = _firstString([user['email'], json['email']]);
    final userId = _firstString([
      user['id'],
      user['pk'],
      user['user_id'],
      json['id'],
    ]);
    final accessToken = _firstString([
      tokens['access'],
      json['access_token'],
      json['accessToken'],
      json['token'],
      json['access'],
      user['access_token'],
      user['token'],
    ]);
    final refreshToken = _firstString([
      tokens['refresh'],
      json['refresh_token'],
      json['refreshToken'],
      json['refresh'],
      user['refresh_token'],
    ]);

    // An identity or a session, or this is not an account. Checked so that a
    // 200 carrying `{"detail": "ok"}` cannot be mistaken for a registration.
    if (email == null && userId == null && accessToken == null) return null;

    return RegisteredAccount(
      email: email ?? '',
      userId: userId,
      role: ProfileRole.tryParse(_firstString([user['role'], json['role']])),
      // `verification_status` is the real field name; `status` is the older
      // guess, kept as a fallback.
      status: _firstString([
        user['verification_status'],
        json['verification_status'],
        user['status'],
        json['status'],
      ]),
      accessToken: accessToken,
      refreshToken: refreshToken,
      // Top level first, matching the live response, then under `user` as the
      // plausible alternative. See [emailVerificationRequired].
      emailVerificationRequired:
          _firstBool(json['email_verification_required']) ??
          _firstBool(user['email_verification_required']) ??
          false,
      emailVerified:
          _firstBool(user['email_verified']) ??
          _firstBool(json['email_verified']),
    );
  }

  @override
  String toString() =>
      'RegisteredAccount(email: $email, role: ${role?.wireValue}, '
      'status: $status, hasSession: $hasSession, '
      'needsVerification: $needsEmailVerification)';
}

/// The first non-blank scalar in [candidates], as a string, or null.
///
/// Numbers are accepted and stringified, because `user.id` is a Django
/// `AutoField` and so arrives as a JSON **number** (`42`), not a string.
/// Accepting only strings would silently drop the id — and a silently absent id
/// is exactly the kind of contract drift that is hard to notice, since the
/// account still parses and the flow still runs.
///
/// Values are trimmed and blanks treated as absent, so `{"token": ""}` reads as
/// "no token" rather than as a session that is not there.
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
/// wrong type in one optional flag should not fail the whole parse. Same helper
/// as `me_profile.dart`, duplicated for the same reason `_firstString` is.
bool? _firstBool(Object? value) => value is bool ? value : null;
