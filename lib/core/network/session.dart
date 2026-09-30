import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A signed-in session: the access token every request carries, and the refresh
/// token used to replace it when it expires.
///
/// The backend's numbers are what make this two fields rather than one: an access
/// token lasts **30 minutes** and a refresh token lasts **7 days**, so a client
/// holding only the access token is signed out half an hour in with no way back
/// except a full sign-in.
///
/// **The 7 days are absolute, not sliding** — confirmed by the backend on
/// 2026-09-30. `REFRESH_TOKEN_LIFETIME` is a fixed window from the moment the
/// token is issued at login, and refreshing the *access* token does not extend it.
/// `ROTATE_REFRESH_TOKENS` is `False`, so no new refresh token is ever issued
/// mid-session. A user who opens the app every day is still signed out on day 7.
/// Anyone reasoning about how much persistence is worth needs that: it buys up to
/// seven days, never an indefinite session.
///
/// Persisted across restarts by `SessionStore`, which writes it to the platform's
/// secure store — Keystore on Android, Keychain on iOS. This class stays a plain
/// value type and knows nothing about that: [toJson] and [fromJson] live here only
/// so the storage format sits next to the fields it describes. Everything else
/// about persistence belongs to `session_store.dart`.
///
/// What that buys is **up to seven days**, never an indefinite session — see the
/// absolute-lifetime note above before writing any UI copy about staying signed in.
@immutable
class Session {
  const Session({required this.access, this.refresh});

  /// Sent as `Authorization: Bearer <access>`.
  final String access;

  /// Exchanged at `POST /token/refresh/` for a new [access].
  ///
  /// **The server always sends this.** Confirmed 2026-09-30: both
  /// `RegistrationResponseMixin` and `LoginAPIView` unconditionally call
  /// `RefreshToken.for_user(user)`, so every success response carries a `refresh`
  /// and there is no code path that omits it.
  ///
  /// It stays nullable anyway, and that is a deliberate choice rather than an
  /// oversight. A `Session` is also built by tests and by hand, and the tolerant
  /// parsing means a malformed body degrades to "signed in but cannot renew"
  /// instead of throwing on the login screen. `canRefresh` is the honest question
  /// to ask; `refresh != null` is not, because it is always true in production.
  final String? refresh;

  /// True when this session can be renewed without a new sign-in.
  bool get canRefresh => refresh != null && refresh!.isNotEmpty;

  /// The same session with a fresh access token, keeping the refresh token.
  Session withAccess(String newAccess) =>
      Session(access: newAccess, refresh: refresh);

  /// The stored form of this session.
  ///
  /// **One map, not two storage keys.** A single value is written in a single call,
  /// so a write cannot leave a half-session behind — an access token whose refresh
  /// token went missing, which would look like a session that silently cannot
  /// renew. It also gives the format room to grow (an expiry, a server id) without
  /// adding keys.
  ///
  /// `refresh` is omitted when absent rather than written as `null`, so a blob from
  /// a session that never had one stays distinguishable from one that did.
  Map<String, dynamic> toJson() => {
    'access': access,
    if (refresh != null) 'refresh': refresh,
  };

  /// Rebuilds a session from [toJson]'s output.
  ///
  /// **Throws [FormatException] when the payload is unusable** — a missing or
  /// non-string access token. That is a deliberate throw rather than a null return:
  /// this parses what we ourselves wrote, so a bad payload means the stored blob is
  /// corrupt or written by an older format, which is an exceptional condition, not
  /// an ordinary "signed out". The caller decides what to do about it, and
  /// `SessionStore.read` is the layer that does — it swallows the throw and clears
  /// the bad value.
  ///
  /// A missing or blank `refresh` is *not* an error: it degrades to a session that
  /// is signed in but cannot renew, which is exactly what the field's nullability
  /// is for.
  factory Session.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    if (access is! String || access.trim().isEmpty) {
      throw const FormatException('Stored session has no usable access token.');
    }
    final refresh = json['refresh'];
    return Session(
      access: access.trim(),
      refresh: refresh is String && refresh.trim().isNotEmpty
          ? refresh.trim()
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Session && other.access == access && other.refresh == refresh;

  @override
  int get hashCode => Object.hash(access, refresh);

  /// Reports only whether the tokens are present. A `toString` that printed them
  /// would put a bearer token into any log or crash report that formats a
  /// provider's state.
  @override
  String toString() =>
      'Session(access: ${access.isEmpty ? 'empty' : 'set'}, '
      'refresh: ${canRefresh ? 'set' : 'absent'})';
}

/// The current session, or null when signed out.
///
/// The single source of truth for authentication. The Dio interceptor reads it to
/// set the `Authorization` header and writes it when a refresh succeeds or fails,
/// so nothing else needs to know how renewal works.
final sessionProvider = StateProvider<Session?>((ref) => null);
