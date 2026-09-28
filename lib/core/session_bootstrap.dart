import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/me_profile.dart';
import '../features/profile/data/user_profile.dart';
import 'network/session.dart';

/// Loads the signed-in user's own details whenever a session appears.
///
/// **Why this exists.** Adopting a session gives the app a token, not an
/// identity: `/register/` and `/login/` return an id, email and role, but nothing
/// the profile screens can render. Without this, the app is signed in and
/// anonymous — the profile tab shows a placeholder name and Edit Profile opens
/// with demo values, because nothing ever filled [userProfileProvider].
///
/// **Why a provider and not a call in the login screen.** The session appears
/// from three places — sign-in, registration, and a token refresh — and only two
/// of them are screens we control. Watching the session covers all three with one
/// implementation. It also means the profile is loaded *before* anything reads
/// it, rather than after a screen remembers to ask.
///
/// **Failure is deliberately not fatal.** A failed fetch leaves the session
/// intact and the profile empty. The alternative — restoring the profile or
/// dropping the session — would sign a user out because one endpoint was down,
/// and a 401 here is already handled properly by
/// [AuthRefreshInterceptor], which renews and retries before this ever sees an
/// error.
///
/// Nothing here is awaited by the UI. The screens that show profile data read
/// [userProfileProvider] as they always have; they simply re-render when it
/// fills, because it is a provider.
class SessionBootstrap {
  SessionBootstrap(this._ref);

  final Ref _ref;

  /// Fetches `/me/` and merges it into the profile store.
  ///
  /// Returns true when the profile was updated, false when the server sent
  /// nothing usable or the request failed. The return value is for tests; the
  /// app ignores it.
  Future<bool> loadProfile({bool force = false}) async {
    final session = _ref.read(sessionProvider);
    if (session == null) return false;

    // Skip a repeat fetch for the same session. Keyed on the refresh token: the
    // access token is replaced every 30 minutes, so keying on that would refetch
    // the profile on every rotation for no reason.
    final key = session.refresh ?? session.access;
    if (!force && _loadedFor == key) return false;

    try {
      final profile = await _ref.read(authRepositoryProvider).fetchMe();
      if (profile == null) return false;
      _loadedFor = key;
      _apply(profile);
      return true;
    } on Object {
      // Swallowed on purpose — see the class doc. Logged nowhere because the app
      // has no logger and this is not actionable for the user.
      return false;
    }
  }

  /// Writes what `/me/` told us into the profile store.
  ///
  /// Merged, never replaced: [UserProfile] also holds the photo, documents and
  /// the location detected at signup, and overwriting it would throw those away
  /// to set a name.
  ///
  /// Only non-blank values are written. `MeProfile.profileValues` omits the
  /// blanks, so a server that sends `name: ""` cannot erase a name the user
  /// typed.
  void _apply(MeProfile profile) {
    final notifier = _ref.read(userProfileProvider.notifier);
    final values = profile.profileValues;
    if (values.isNotEmpty) notifier.save(values);
    final role = profile.role;
    if (role != null) notifier.setRole(role);
  }

  /// Identifies the session `/me/` was last loaded for.
  ///
  /// The **refresh token**, not the access token: the access token is replaced
  /// every 30 minutes, so keying on it would refetch the profile on every
  /// rotation for no reason. The refresh token is what actually distinguishes one
  /// session from another — it survives rotation and changes when someone else
  /// signs in.
  ///
  /// Falls back to the access token for a session with no refresh token, which
  /// is the only identifier such a session has.
  String? _loadedFor;
}

/// The bootstrap, as a provider so it is a single instance per container.
final sessionBootstrapProvider = Provider<SessionBootstrap>(
  (ref) => SessionBootstrap(ref),
);

/// Watches the session and loads the profile whenever one appears.
///
/// A provider rather than a widget's `initState`, so it exists for the whole
/// life of the app and cannot be unmounted out from under a fetch. Must be
/// **watched** to run — see `app.dart`, which is the single place that does.
///
/// It also clears the profile when the session ends. That matters: without it, a
/// user who signs out and back in as someone else would briefly see the previous
/// user's name on the profile tab.
final sessionProfileLoaderProvider = Provider<void>((ref) {
  final bootstrap = ref.watch(sessionBootstrapProvider);

  ref.listen<Session?>(sessionProvider, (previous, next) {
    if (next == null) {
      // Signed out: forget whose profile this was.
      ref.read(userProfileProvider.notifier).clear();
      return;
    }
    // Signed in, or the token rotated. `loadProfile` itself decides whether the
    // latter is worth a request.
    bootstrap.loadProfile();
  });

  // A session may already be set when this is first read (a test, or a session
  // restored from storage later). Load for it rather than waiting for a change.
  if (ref.read(sessionProvider) != null) bootstrap.loadProfile();
});
