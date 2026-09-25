import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A signed-in session: the access token every request carries, and the refresh
/// token used to replace it when it expires.
///
/// The backend's numbers (handoff §10) are what make this two fields rather than
/// one: an access token lasts **30 minutes** and a refresh token lasts **7 days**,
/// so a client holding only the access token is signed out half an hour in with
/// no way back except a full sign-in.
///
/// In-memory only, like the single token it replaces. Persisting a session across
/// restarts is separate work, and a real answer needs a platform decision
/// (Keychain / Keystore / `flutter_secure_storage`) that this layer should not
/// make on its own — but it is now worth doing, since a 7-day refresh token is
/// something a user would expect to survive a restart.
@immutable
class Session {
  const Session({required this.access, this.refresh});

  /// Sent as `Authorization: Bearer <access>`.
  final String access;

  /// Exchanged at `POST /token/refresh/` for a new [access].
  ///
  /// Nullable because the response parsing is deliberately tolerant and a body
  /// carrying only an access token still leaves the user signed in — they simply
  /// cannot renew. Recording that honestly beats inventing a refresh token.
  final String? refresh;

  /// True when this session can be renewed without a new sign-in.
  bool get canRefresh => refresh != null && refresh!.isNotEmpty;

  /// The same session with a fresh access token, keeping the refresh token.
  Session withAccess(String newAccess) =>
      Session(access: newAccess, refresh: refresh);

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
