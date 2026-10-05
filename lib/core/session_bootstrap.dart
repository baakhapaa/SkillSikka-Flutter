import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/me_profile.dart';
import '../features/profile/data/reference_data.dart';
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
      // Resolved **before** `_apply`, and separately from it, so a reference-data
      // failure can cost the geographic fields alone. Applying first and
      // resolving after would mean the merge happened before the names existed.
      final locationNames = await _resolveLocationNames(profile);
      _apply(profile, locationNames);
      // After `_apply`, and separately from it: the avatar is a second request
      // that can fail on its own, and it must not be able to undo the fields
      // already merged above.
      await _applyPhoto(profile);
      return true;
    } on Object {
      // Swallowed on purpose — see the class doc. Logged nowhere because the app
      // has no logger and this is not actionable for the user.
      return false;
    }
  }

  /// Downloads the avatar `/me/` points at and writes it into the store.
  ///
  /// **This is what makes a photo survive a re-login.** Until 2026-10-05
  /// `/me/` returned no photo field, so [UserProfile.photoBytes] was only ever
  /// filled by the signup that set it — every later session showed the
  /// placeholder, and the user's uploaded photo simply vanished.
  ///
  /// **Costs nothing when there is no photo.** [MeProfile.profilePhotoUrl] is
  /// null unless the user uploaded one, so a user without an avatar makes no
  /// request — the same guard as the geographic resolution, for the same reason.
  ///
  /// **A failed download is not fatal and is not even logged.** The repository
  /// already answers null rather than throwing; this adds the second half, which
  /// is to leave whatever the store already holds alone. Overwriting a photo
  /// that is on screen with nothing because one image request failed would be a
  /// worse outcome than a stale avatar.
  Future<void> _applyPhoto(MeProfile profile) async {
    final url = profile.profilePhotoUrl;
    if (url == null || url.trim().isEmpty) return;

    final photo = await _ref
        .read(authRepositoryProvider)
        .fetchProfilePhoto(url);
    if (photo == null) return;

    // `photoFileName` is stored alongside the bytes because dio infers an
    // upload's content type from the extension. It is empty when the response
    // carried no usable content type, which is better than a wrong guess.
    _ref
        .read(userProfileProvider.notifier)
        .setPhoto(photo.bytes, photo.fileName);
  }

  /// Turns the geographic and grade **ids** `/me/` returns into the **names** the
  /// profile store is keyed by, or an empty map.
  ///
  /// **Costs nothing today.** Every id is null until the backend ships the
  /// completion fields — requested in
  /// `backend-ask-profile-completion-fields-2026-10-05.md` §A1 — so this returns
  /// immediately and makes no requests. That check is the whole reason it is
  /// written as a guard rather than left to fail: an unconditional fetch would
  /// add five round trips to every cold boot to learn nothing.
  ///
  /// **A failure here costs the geographic fields and nothing else.** They are
  /// five of twenty-odd profile fields, and losing the whole `/me/` result
  /// because one lookup endpoint was down would be a far worse outcome than a
  /// province that is briefly blank.
  Future<Map<String, String>> _resolveLocationNames(MeProfile profile) async {
    final hasAnyId = {
      profile.gradeId,
      profile.provinceId,
      profile.districtId,
      profile.municipalityId,
      profile.schoolId,
    }.any((id) => id != null && id.trim().isNotEmpty);
    if (!hasAnyId) return const {};

    try {
      final api = _ref.read(referenceDataApiProvider);
      final resolved = resolveLocationNames(
        grades: await api.grades(),
        provinces: await api.provinces(),
        districts: await api.districts(),
        municipalities: await api.municipalities(),
        schools: await api.schools(),
        gradeId: profile.gradeId,
        provinceId: profile.provinceId,
        districtId: profile.districtId,
        municipalityId: profile.municipalityId,
        schoolId: profile.schoolId,
      );
      final locations = resolved.locations;
      return {
        if ((resolved.gradeName ?? '').isNotEmpty) 'grade': resolved.gradeName!,
        if ((locations.province ?? '').isNotEmpty)
          'province': locations.province!,
        if ((locations.district ?? '').isNotEmpty)
          'district': locations.district!,
        if ((locations.municipality ?? '').isNotEmpty)
          'municipality': locations.municipality!,
        if ((locations.school ?? '').isNotEmpty) 'school': locations.school!,
      };
    } on Object {
      return const {};
    }
  }

  /// Writes what `/me/` told us into the profile store.
  ///
  /// Merged, never replaced: [UserProfile] also holds the photo, documents and
  /// the location detected at signup, and overwriting it would throw those away
  /// to set a name.
  ///
  /// Only non-blank values are written. [MeProfile.profileValues] omits the
  /// blanks, so a server that sends `name: ""` cannot erase a name the user
  /// typed. [locationNames] is the resolved form of the geographic ids and
  /// follows the same rule.
  ///
  /// One save rather than two, so a field present in both cannot be half
  /// applied — the second call would win, and the ordering would then decide
  /// which source was authoritative for no reason.
  void _apply(
    MeProfile profile, [
    Map<String, String> locationNames = const {},
  ]) {
    final notifier = _ref.read(userProfileProvider.notifier);
    final values = {...profile.profileValues, ...locationNames};
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
