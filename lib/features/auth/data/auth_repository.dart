import 'dart:typed_data';

import 'package:dio/dio.dart';
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
  /// Creates the account. **Does not sign the user in any more.**
  ///
  /// Registration now returns 201 with `email_verification_required: true` and
  /// no tokens, for both roles (confirmed live 2026-10-07 — this reverses the
  /// older contract, where registration *was* the authenticated step). The
  /// caller must therefore route to the OTP screen and let [verifyOtp] establish
  /// the session.
  ///
  /// The role is still adopted from the response here, before any token check,
  /// so the OTP screen knows which endpoint to use — see
  /// [DioAuthRepository._adopt].
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

  /// Downloads the signed-in user's avatar, or null when there is none or the
  /// fetch failed. See [AuthApi.fetchProfilePhoto] — the failure is deliberately
  /// silent, so nothing here throws for a missing picture.
  Future<({Uint8List bytes, String fileName})?> fetchProfilePhoto(String url);

  /// Writes the fields every role shares — `name`, `email`, `gender`, `dob`,
  /// `phone_country_code`, `phone_number`, `location` — and returns the profile
  /// as the server now holds it, or null when nothing was sent.
  ///
  /// **This is what makes an edit to those seven persist.** Until 2026-10-02 no
  /// endpoint accepted them, so Edit Profile could only write to its in-memory
  /// store and every change was gone by the next login.
  ///
  /// The [fields] map is the **wire body**, already encoded: wire keys, the
  /// lowercase gender, an ISO or `DD/MM/YYYY` date, the phone split in two. The
  /// encoding lives at the call site that owns the form values — see
  /// `ProfileUpdateRequest` — because the store is keyed by the form's keys, not
  /// the wire's.
  ///
  /// A blank `gender` or `dob` must be **omitted** rather than sent empty: the
  /// backend rejects `""` for both. See [AuthApi.updateProfile].
  ///
  /// Throws [ApiException] when the server rejects the body — a 400 naming the
  /// offending field, which the edit screen surfaces through the shared error
  /// helper. Unlike [completeProfile] there is no "route not built yet" case to
  /// absorb: the route is live and a failure is real.
  ///
  /// **[files] and [fileLists] carry the user's documents** and may be empty.
  /// Both may be empty while [fields] is empty too, in which case nothing is
  /// sent — but a **file alone is a valid save**: someone who changed only their
  /// photo sends no text at all, and that must not be mistaken for nothing to do.
  Future<MeProfile?> updateProfile(
    Map<String, String> fields, {
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
  });

  /// Confirms the emailed code. Returns the account when verification
  /// established a session, and null when it did not.
  ///
  /// **This is the step that signs the user in**, for both roles. Registration
  /// now returns 201 with `email_verification_required: true` and **no tokens**
  /// (confirmed live 2026-10-07), so until this call succeeds the app holds no
  /// session and every guarded route bounces the user back to login.
  ///
  /// [role] decides the endpoint — `/register/student/verify-otp/` or
  /// `/register/instructor/verify-otp/`. The two are separate paths, not one
  /// path with a role field, exactly like registration itself.
  ///
  /// Throws [ApiException] on a rejected code. The backend answers a single
  /// 400 `{"detail": "Invalid or expired OTP."}` for a wrong code, an expired
  /// one, and an unknown address alike, so the screen has one message to show
  /// and no way to be more specific than the server is.
  Future<RegisteredAccount?> verifyOtp({
    required ProfileRole role,
    required String email,
    required String code,
  });

  /// Asks for a fresh code.
  ///
  /// **Answers 200 whether or not anything was sent** — the backend replies
  /// with a fixed "if an eligible account exists…" sentence to avoid confirming
  /// which addresses are registered, and it says that even inside the 60-second
  /// cooldown. So a successful return here means *the request was accepted*, not
  /// that a mail went out, and the countdown on the screen is the only thing
  /// enforcing the cooldown. See [AuthApi.resendOtp].
  Future<void> resendOtp({required ProfileRole role, required String email});

  // ---------------------------------------------------------------------------
  // Password reset — three steps, and a different flow from signup
  // ---------------------------------------------------------------------------

  /// Step 1: asks the server to email a password-reset code.
  ///
  /// **Succeeds whether or not the address has an account.** The backend answers
  /// with a fixed "if an account exists…" sentence, so the screen advances to the
  /// code step either way; reporting "no such account" would turn the endpoint
  /// into an address-enumeration oracle. See [AuthApi.requestPasswordReset].
  ///
  /// Unlike signup's [resendOtp] there is **no server-side cooldown** here — each
  /// request mints a new code and kills the previous one — so the 60-second wait
  /// on the button is a client choice rather than a mirror of a server rule.
  Future<void> requestPasswordReset({required String email});

  /// Step 2: exchanges the code for a single-use reset token.
  ///
  /// Returns the token, or **null when the server sent none** — which the caller
  /// must treat as a failure, because nothing can authorise step 3 without it.
  ///
  /// Throws [ApiException] for a wrong, expired or used-up code. The backend
  /// sends one message for all three, and sends it as a **list** on this endpoint
  /// where signup sends a string; `ApiException` renders both.
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String code,
  });

  /// Step 3: sets the new password.
  ///
  /// **Does not sign the user in, and must not be treated as if it did.** The
  /// backend returns no tokens and invalidates **every** existing session for the
  /// account — stored refresh tokens stop working — so the caller ends this flow
  /// on the login screen.
  ///
  /// Throws [ApiException] for both failure kinds, and they need different
  /// handling:
  ///
  /// - **field errors** on `new_password` / `confirm_password` — the user can fix
  ///   this in place, so show them under the fields.
  /// - **a `detail` with no field errors** — the reset token is dead (used, over
  ///   10 minutes old, or tampered with). The only recovery is to start again, so
  ///   the screen sends the user back to step 1.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  });

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
    required ProfileRole role,
    required String email,
    required String code,
  }) async {
    final account = await _api.verifyOtp(role: role, email: email, code: code);
    if (account != null) _adopt(account);
    return account;
  }

  @override
  Future<void> resendOtp({required ProfileRole role, required String email}) =>
      _api.resendOtp(role: role, email: email);

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _api.requestPasswordReset(email: email);

  @override
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) => _api.verifyPasswordResetOtp(email: email, code: code);

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) => _api.resetPassword(
    resetToken: resetToken,
    newPassword: newPassword,
    confirmPassword: confirmPassword,
  );

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

  @override
  Future<({Uint8List bytes, String fileName})?> fetchProfilePhoto(String url) =>
      _api.fetchProfilePhoto(url);

  @override
  Future<MeProfile?> updateProfile(
    Map<String, String> fields, {
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
  }) => _api.updateProfile(fields, files: files, fileLists: fileLists);

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

  /// Whether registration returns a session.
  ///
  /// **Defaults to false, which is what the live backend does** — registration
  /// returns no tokens and the session arrives from [verifyOtp] instead. The
  /// flag is kept so the opposite shape can still be exercised without touching
  /// the flow, and it drives [RegisteredAccount.emailVerificationRequired]
  /// inversely, so the fake cannot claim "signed in" and "must verify" at once.
  bool tokenOnRegister;

  /// When set, every call throws this instead of succeeding.
  ApiException? failure;

  /// What the screens actually sent, so a test can assert on it.
  final List<RegistrationRequest> registrations = [];

  /// The code the screen submitted, **with the role that decided the endpoint**.
  /// Both are recorded because a wrong role is a silent mis-route: the request
  /// still looks correct and only the server would notice.
  final List<({ProfileRole role, String email, String code})> verifications =
      [];

  /// The addresses a resend was asked for, with the role.
  final List<({ProfileRole role, String email})> resends = [];

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
      // The live contract: registration withholds the session and asks for the
      // emailed code. Tied to [tokenOnRegister] so the one flag still selects
      // between "must verify" and "signed in on register", and the two cannot
      // contradict each other.
      emailVerificationRequired: !tokenOnRegister,
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
    required ProfileRole role,
    required String email,
    required String code,
  }) async {
    await _wait();
    _throwIfFailing();
    verifications.add((role: role, email: email, code: code));
    // Mirrors the backend answering with a session once the code is accepted —
    // and this is the *only* place a signup session comes from now, so the
    // adopted account has to carry the role for `_adopt` to write it.
    final account = RegisteredAccount(
      email: email,
      userId: 'fake-user-1',
      role: role,
      status: 'active',
      accessToken: 'fake-access-token',
      refreshToken: 'fake-refresh-token',
      emailVerified: true,
    );
    _adopt(account);
    return account;
  }

  @override
  Future<void> resendOtp({
    required ProfileRole role,
    required String email,
  }) async {
    await _wait();
    _throwIfFailing();
    resends.add((role: role, email: email));
  }

  /// The addresses a reset code was requested for.
  final List<String> resetRequests = [];

  /// The codes submitted to the reset step, in order.
  final List<({String email, String code})> resetVerifications = [];

  /// Every step-3 body, so a test can assert the token was carried through and
  /// the two passwords matched what the user typed.
  final List<({String resetToken, String newPassword, String confirmPassword})>
  passwordResets = [];

  /// What [verifyPasswordResetOtp] answers with.
  ///
  /// **Non-null by default**, unlike the other optional answers on this double:
  /// the real endpoint always returns a token on success, so a test that had to
  /// configure one before the flow would run at all would be testing its own
  /// setup. Set it to null to drive the "server sent no token" path.
  String? resetToken = 'fake-reset-token';

  /// Thrown by [resetPassword] when set, **independently of [failure]**, so a
  /// test can have a healthy code step and a rejected password — which is the
  /// case the screen has to survive, and the one where it must decide between
  /// "fix the password" and "start over".
  ApiException? resetFailure;

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _wait();
    _throwIfFailing();
    resetRequests.add(email);
  }

  @override
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) async {
    await _wait();
    _throwIfFailing();
    resetVerifications.add((email: email, code: code));
    return resetToken;
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _wait();
    _throwIfFailing();
    final error = resetFailure;
    if (error != null) throw error;
    passwordResets.add((
      resetToken: resetToken,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    ));
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

  /// What [fetchProfilePhoto] answers with. Null by default, matching a user who
  /// has never uploaded a photo.
  ({Uint8List bytes, String fileName})? photo;

  /// How many times the avatar was actually fetched. Lets a test assert the
  /// download is **skipped** when `/me/` carried no URL, which is the property
  /// that keeps a login from making a pointless request.
  int photoFetches = 0;

  /// Mirrors the real method's contract, which is the point: it **never
  /// throws**. A failed download is a null, so a test cannot accidentally pass
  /// by asserting on an exception the real path would have swallowed.
  @override
  Future<({Uint8List bytes, String fileName})?> fetchProfilePhoto(
    String url,
  ) async {
    await _wait();
    photoFetches++;
    return photo;
  }

  @override
  Future<MeProfile?> fetchMe() async {
    await _wait();
    meFetches++;
    final error = meFailure;
    if (error != null) throw error;
    return me;
  }

  /// Every `PATCH /me/` body the screens sent, so a test can assert on the wire
  /// keys rather than on the form values they were built from.
  final List<Map<String, String>> updates = [];

  /// The **slot names** of every file each `PATCH /me/` carried, flattened.
  ///
  /// Names rather than the `MultipartFile`s themselves: a test's real question is
  /// "did the right slot go out, and did the wrong one stay behind", and that is
  /// a question about keys. One entry per call, aligned with [updates] — so
  /// `uploads[0]` is the files that rode along with `updates[0]`.
  final List<List<String>> uploads = [];

  /// Thrown by [updateProfile] when set. Separate from [failure] so a test can
  /// have a healthy sign-in and a rejected save — which is the case the edit
  /// screen has to survive.
  ApiException? updateFailure;

  /// What [updateProfile] answers with. Null by default, matching a body the
  /// screen should treat as "nothing came back".
  MeProfile? updateResult;

  @override
  Future<MeProfile?> updateProfile(
    Map<String, String> fields, {
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
  }) async {
    await _wait();
    // Empty fields **with** files is still a save — someone who changed only
    // their photo sends no text. Matching the real repository's rule rather than
    // the old one, so a fake cannot paper over a caller that sends nothing.
    if (fields.isEmpty && files.isEmpty && fileLists.isEmpty) return null;
    final error = updateFailure;
    if (error != null) throw error;
    updates.add(fields);
    // Slot names only — a test's real question is "did the right slot go out,
    // and did the wrong one stay behind". A slot in [fileLists] appears once per
    // file, because that is what the wire looks like: two certificates are two
    // parts under one repeated name.
    uploads.add([
      ...files.keys,
      for (final entry in fileLists.entries)
        ...List.filled(entry.value.length, entry.key),
    ]);
    return updateResult;
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
