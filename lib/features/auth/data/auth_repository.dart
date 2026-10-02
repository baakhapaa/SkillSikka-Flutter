import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/session.dart';
import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';
import 'auth_api.dart';
import 'me_profile.dart';
import 'registered_account.dart';
import 'registration_request.dart';

/// What the signup screens talk to.
///
/// An interface rather than the concrete class for two reasons: a screen can be
/// pumped in a widget test with [FakeAuthRepository] and no HTTP at all, and the
/// flow can be exercised by hand before the backend exists.
///
/// Every method throws [ApiException] on failure — never a `DioException`, and
/// never a bare socket error. That is what lets a screen decide what to show
/// without knowing what a `DioException` is.
abstract interface class AuthRepository {
  /// Creates the account and adopts the session the backend returns with it.
  ///
  /// There is no email-verification step: registration returns JWT tokens
  /// immediately (backend handoff §1), so this is the authenticated step.
  Future<RegisteredAccount> register(RegistrationRequest request);

  /// Signs in with email and password, and adopts the session.
  ///
  /// Throws [ApiException] on bad credentials — the backend answers 400 with a
  /// JSON `detail`, not an HTML page.
  Future<RegisteredAccount> logIn({
    required String email,
    required String password,
  });

  /// Ends the session, server-side and locally.
  ///
  /// Best effort on the network call: the backend blacklists the refresh token
  /// (handoff §11), but the user asked to be signed out, so a failed request must
  /// not leave them signed in on this device. The local session is cleared either
  /// way.
  Future<void> logOut();

  /// The signed-in user, as the server knows them, or null when the server did
  /// not describe one.
  ///
  /// Called right after adopting a session, because the auth responses carry
  /// only an id, email and role — not the name the profile screens render.
  /// Without it the app is signed in but anonymous, and every screen showing the
  /// user's own details falls back to placeholder data.
  ///
  /// Throws [ApiException] when the request fails, including a 401 from an
  /// expired access token. Callers are expected to treat failure as
  /// non-fatal — see `SessionBootstrap`.
  Future<MeProfile?> fetchMe();

  /// Confirms the emailed code. Returns the account when verification
  /// established a session, and null when it did not.
  ///
  /// **The endpoint does not exist.** Kept only until the signup flow is rewired;
  /// see [AuthApi.verifyOtp].
  Future<RegisteredAccount?> verifyOtp({
    required String email,
    required String code,
  });

  /// **Does not exist** — see [verifyOtp].
  Future<void> resendOtp({required String email});

  /// Sends the deferred half of the profile to the completion endpoint, when
  /// there is anything to send.
  ///
  /// This is what makes the signup trim real. Both roles now register with
  /// identity only and collect the rest on Edit Profile — but until this method
  /// exists those answers never leave the device, so the user fills in a form
  /// that changes nothing. Half the change is worse than none of it.
  ///
  /// **Best effort, by design.** Returns whether anything was sent:
  ///
  /// - An empty [fields] map is a no-op that resolves `false`. The user opened
  ///   Edit Profile and changed nothing; there is no request to make and nothing
  ///   went wrong.
  /// - A `404` is also a no-op. The endpoint is a **granted request, not a
  ///   confirmed contract** — see [AuthApi.completeProfile] — so "not built yet"
  ///   must not read to the user as a failure of their edit.
  ///
  /// Throws [ApiException] for everything else. A `400` on a body the server
  /// rejected is a real bug in our payload and has to be visible, which is why
  /// the swallow is narrowed to the missing route rather than applied to the
  /// whole call.
  Future<bool> completeProfile({
    required ProfileRole role,
    required Map<String, String> fields,
  });
}

/// The real one. Talks HTTP and adopts a session when the backend offers one.
class DioAuthRepository implements AuthRepository {
  DioAuthRepository({
    required ApiClient client,
    required StateController<Session?> session,
    UserProfileNotifier? profile,
  }) : _api = AuthApi(client),
       _session = session,
       _profile = profile;

  final AuthApi _api;
  final StateController<Session?> _session;

  /// Where the role is written when an auth response carries one.
  ///
  /// Optional only so a unit test can build this repository without standing up
  /// a profile store; the app always supplies it. Null therefore means "adopt
  /// the session but forget the role", which is the old broken behaviour — see
  /// [_adopt] for why that matters.
  final UserProfileNotifier? _profile;

  @override
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    final account = await _api.register(request);
    _adopt(account);
    return account;
  }

  @override
  Future<RegisteredAccount> logIn({
    required String email,
    required String password,
  }) async {
    final account = await _api.logIn(email: email, password: password);
    _adopt(account);
    return account;
  }

  @override
  Future<void> logOut() async {
    final refresh = _session.state?.refresh;
    try {
      // Only worth telling the server when there is a refresh token to
      // blacklist. Without one the session is local-only and clearing it is the
      // whole job.
      if (refresh != null && refresh.isNotEmpty) {
        await _api.logOut(refresh: refresh);
      }
    } on ApiException {
      // Swallowed deliberately. See the interface doc: the user asked to be
      // signed out, and a 401 or a dropped connection here must not leave them
      // signed in on this device. The token is left to expire on its own.
    } finally {
      _session.state = null;
    }
  }

  @override
  Future<RegisteredAccount?> verifyOtp({
    required String email,
    required String code,
  }) async {
    final account = await _api.verifyOtp(email: email, code: code);
    if (account != null) _adopt(account);
    return account;
  }

  @override
  Future<void> resendOtp({required String email}) =>
      _api.resendOtp(email: email);

  @override
  Future<bool> completeProfile({
    required ProfileRole role,
    required Map<String, String> fields,
  }) async {
    // Nothing to say, so nothing to send — and no way to fail either.
    if (fields.isEmpty) return false;

    try {
      await _api.completeProfile(role: role, fields: fields);
      return true;
    } on ApiException catch (error) {
      // The route is a request we made, not a contract we have. See
      // [AuthApi.completeProfile]: a 404 means the backend has not built it yet,
      // and the user's edit must still be saved locally without an error they
      // cannot act on. Every other status is ours to report.
      //
      // **This is the only place that decides it.** `AuthApi` deliberately lets
      // the 404 throw rather than swallowing it; when it swallowed it too, this
      // clause was unreachable and the method reported success for a request
      // that never happened.
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  @override
  Future<MeProfile?> fetchMe() => _api.fetchMe();

  /// Stores the session the response carried, and the role that came with it.
  ///
  /// **The role is written here, and that is the fix for a real bug.** `/login/`
  /// and `/register/` both return the user's role; it was parsed and then
  /// dropped. That left `GET /me/` as the *only* source of the role, so the
  /// profile tab depended on a second request for data the first one had already
  /// handed us — and the fetch fails silently by design (see `SessionBootstrap`),
  /// so an instructor whose `/me/` was slow, 404ing or rejected was rendered as a
  /// student with nothing logged anywhere. Writing it here means the role is in
  /// the store before the screen that reads it is built, with no network in the
  /// path.
  ///
  /// Written **before** the token check, deliberately: the role is known whether
  /// or not the response carried a session, and registration with no token is a
  /// supported shape (`tokenOnRegister: false` in the double).
  ///
  /// Both tokens are kept. The access token lasts 30 minutes (backend handoff
  /// §10), so a session holding only that is signed out half an hour in with no
  /// way to renew — the refresh token is the difference between "session expires"
  /// and "user is logged out".
  ///
  /// Persisting this across launches is separate work, and wants a platform
  /// decision this layer should not make on its own.
  void _adopt(RegisteredAccount account) {
    final role = account.role;
    if (role != null) _profile?.setRole(role);

    final access = account.accessToken;
    if (access == null || access.isEmpty) return;
    _session.state = Session(access: access, refresh: account.refreshToken);
  }
}

/// An [AuthRepository] that answers from memory.
///
/// For widget tests, and for driving the signup flow before the backend is up.
/// Deliberately **not** wired in by default: a fake that switches itself on is
/// how "it worked on my machine" happens. Tests override
/// [authRepositoryProvider] with it.
///
/// **[session] is not optional in practice.** The interface promises that
/// `logIn`/`register`/`verifyOtp` *adopt the session* they return, and a fake
/// that only returns the account breaks that promise silently: a screen calls
/// `logIn`, gets a valid-looking account, and then finds `sessionProvider` still
/// null — so every guarded route bounces it back to the login screen with no
/// error anywhere. Pass the same `StateController<Session?>` the real repository
/// would write, i.e. `ref.read(sessionProvider.notifier)`.
///
/// Leaving it null stays legal for a test that only cares about what was *sent*
/// (the recorded lists below still fill), and it is asserted here rather than
/// left to chance, so a test that expects a session fails loudly instead of
/// quietly sitting on the login screen.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.latency = Duration.zero,
    this.tokenOnRegister = false,
    StateController<Session?>? session,
    UserProfileNotifier? profile,
  }) : _session = session,
       _profile = profile;

  /// Where an adopted session is written. Null means "record the call, adopt
  /// nothing" — see the class doc.
  final StateController<Session?>? _session;

  /// Where an adopted role is written. Null means the role is dropped, which is
  /// the real repository's old bug — see [DioAuthRepository._adopt]. Pass
  /// `ref.read(userProfileProvider.notifier)` when a test asserts on the role a
  /// screen ends up rendering.
  final UserProfileNotifier? _profile;

  /// How long each call takes, so a test can observe the submitting state.
  Duration latency;

  /// Whether registration returns a session — i.e. which of the two backend
  /// models to imitate. Flip it to exercise both without touching the flow.
  bool tokenOnRegister;

  /// When set, every call throws this instead of succeeding.
  ApiException? failure;

  /// What the screens actually sent, so a test can assert on it.
  final List<RegistrationRequest> registrations = [];
  final List<({String email, String code})> verifications = [];
  final List<String> resends = [];
  final List<({String email, String password})> logins = [];

  /// How many times [logOut] was called. A count rather than a list because
  /// there is nothing to record beyond the fact.
  int logOuts = 0;

  @override
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    await _wait();
    _throwIfFailing();
    registrations.add(request);
    final account = RegisteredAccount(
      email: request.fields['email'] ?? '',
      userId: 'fake-user-${registrations.length}',
      role: request.role,
      status: 'pending',
      accessToken: tokenOnRegister ? 'fake-access-token' : null,
    );
    _adopt(account);
    return account;
  }

  @override
  Future<RegisteredAccount> logIn({
    required String email,
    required String password,
  }) async {
    await _wait();
    _throwIfFailing();
    logins.add((email: email, password: password));
    // A real session, unlike [register]'s optional token: the backend always
    // issues one on sign-in.
    final account = RegisteredAccount(
      email: email,
      userId: 'fake-user-1',
      role: ProfileRole.student,
      status: 'not_applicable',
      accessToken: 'fake-access-token',
      refreshToken: 'fake-refresh-token',
    );
    _adopt(account);
    return account;
  }

  /// Deliberately does **not** honour [failure], because neither does the real
  /// implementation: a failed logout call must not stop the local session being
  /// cleared. The best-effort behaviour is tested against `DioAuthRepository`
  /// with a failing transport, not through this double.
  ///
  /// Clears the session like the real one does — see the class doc. A fake that
  /// left the session in place after a logout would make every "logout returns
  /// you to login" test pass for the wrong reason.
  @override
  Future<void> logOut() async {
    await _wait();
    logOuts++;
    _session?.state = null;
  }

  @override
  Future<RegisteredAccount?> verifyOtp({
    required String email,
    required String code,
  }) async {
    await _wait();
    _throwIfFailing();
    verifications.add((email: email, code: code));
    // Mirrors the backend answering with a session once the code is accepted.
    final account = RegisteredAccount(
      email: email,
      userId: 'fake-user-1',
      status: 'active',
      accessToken: 'fake-access-token',
    );
    _adopt(account);
    return account;
  }

  @override
  Future<void> resendOtp({required String email}) async {
    await _wait();
    _throwIfFailing();
    resends.add(email);
  }

  /// Every completion body the screens sent, so a test can assert on it.
  ///
  /// Records the **role and fields as handed over**, not the wire body: the
  /// encoding lives in `AuthApi.completeProfile`, and a fake that re-implemented
  /// it could agree with itself while disagreeing with the real client.
  final List<({ProfileRole role, Map<String, String> fields})> completions = [];

  /// What [completeProfile] answers. Defaults to "sent" when the fields were
  /// non-empty, matching `DioAuthRepository` — a fake that invented a different
  /// answer would make the "profile saved" path untested.
  bool? completionResult;

  /// Thrown by [completeProfile] when set, so a test can exercise the failure
  /// path that must **not** be swallowed (anything except a 404).
  ApiException? completionFailure;

  @override
  Future<bool> completeProfile({
    required ProfileRole role,
    required Map<String, String> fields,
  }) async {
    await _wait();
    if (fields.isEmpty) return false;
    final error = completionFailure;
    if (error != null) throw error;
    completions.add((role: role, fields: fields));
    return completionResult ?? true;
  }

  /// What [fetchMe] answers with, and how many times it was asked.
  ///
  /// Null by default rather than a hardcoded profile: a test that does not care
  /// about the fetch should see it *not* overwrite the store, and a fake that
  /// invented a name would make the "profile is populated" assertion pass
  /// without the production path being wired at all.
  MeProfile? me;

  int meFetches = 0;

  /// Thrown by [fetchMe] when set, **independently of [failure]**, so a test can
  /// have a successful login followed by a failed profile fetch — which is the
  /// case the login screen has to survive.
  ApiException? meFailure;

  @override
  Future<MeProfile?> fetchMe() async {
    await _wait();
    meFetches++;
    final error = meFailure;
    if (error != null) throw error;
    return me;
  }

  /// Stores the session the account carried, and the role alongside it — the
  /// same rule as `DioAuthRepository._adopt`, so the two cannot disagree about
  /// what a sign-in leaves in the store.
  ///
  /// Silently does nothing when no [session] controller was supplied. That is
  /// the documented way to use this double for "what was sent" assertions only.
  void _adopt(RegisteredAccount account) {
    final role = account.role;
    if (role != null) _profile?.setRole(role);

    final access = account.accessToken;
    if (access == null || access.isEmpty) return;
    _session?.state = Session(access: access, refresh: account.refreshToken);
  }

  /// Only waits when there is something to wait for. A zero delay would still
  /// schedule a timer, and a pending timer fails a widget test that has
  /// finished pumping.
  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _throwIfFailing() {
    final error = failure;
    if (error != null) throw error;
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

/// The repository the screens use. Override it in a test with
/// [FakeAuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(
    client: ref.watch(apiClientProvider),
    // `.notifier` rather than the value: the repository writes the session, and
    // watching the notifier does not rebuild this provider when it changes.
    session: ref.watch(sessionProvider.notifier),
    // Same reason: the repository writes the role on sign-in, so this is a
    // handle to write through, not a value to read. See `_adopt` for why the
    // role is written at sign-in instead of waiting for `GET /me/`.
    profile: ref.watch(userProfileProvider.notifier),
  ),
);
