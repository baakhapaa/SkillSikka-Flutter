import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../profile/data/profile_role.dart';
import 'me_profile.dart';
import 'registered_account.dart';
import 'registration_request.dart';

/// The auth endpoints: paths and payload shapes, and nothing else.
///
/// No navigation, no state, no token storage — those belong to
/// `AuthRepository` and the screens. Keeping this layer thin is what lets the
/// wire contract be tested on its own, without a widget tree.
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  /// The multipart name for the avatar.
  ///
  /// Not a `ProfileDocumentSlot`: the avatar has its own field on `UserProfile`
  /// rather than living in `documents`, so it is not one of those slots.
  ///
  /// **Public because registration and Edit Profile both send it**, and a second
  /// copy of the string in the edit screen is a rename nobody would notice. The
  /// value is a wire contract: a typo here is a file the server never receives.
  static const photoField = 'profile_photo';

  /// Registration is **two endpoints**, not one with a `role` field.
  ///
  /// Confirmed by the backend response (§1): the role is expressed by the path
  /// you post to, and neither endpoint takes a `role` form field.
  static const _registerPaths = <ProfileRole, String>{
    ProfileRole.student: '/register/student/',
    ProfileRole.instructor: '/register/instructor/',
  };

  /// `POST /register/student/` or `/register/instructor/`, as
  /// `multipart/form-data`.
  ///
  /// One request rather than "create the account, then upload the photo",
  /// because the photo is mandatory for both roles: a two-step flow would leave
  /// an account and an orphaned upload behind every abandoned signup.
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    final body = await _client.postMultipart<Map<String, dynamic>>(
      _registerPaths[request.role]!,
      fields: request.fields,
      files: {
        photoField: filePart(
          bytes: request.photo.bytes,
          fileName: request.photo.fileName,
        ),
        // Keyed by the slot name, which is already the multipart field name the
        // contract uses (`cv_resume`, `certificates_and_recommendations`,
        // `student_id_card`).
        for (final entry in request.documents.entries)
          entry.key: filePart(
            bytes: entry.value.bytes,
            fileName: entry.value.fileName,
          ),
      },
    );

    final account = RegisteredAccount.tryParse(body);
    if (account == null) {
      // A 2xx whose body does not describe an account. Worth its own message:
      // the alternative is a flow that carries on with an empty email and
      // fails somewhere less obvious.
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message:
            'The server accepted the registration but its response did not '
            'contain an account.',
      );
    }
    return account;
  }

  /// `POST /login/`. Email and password only — the backend uses email as
  /// `USERNAME_FIELD` and looks the user up by it (handoff §8).
  ///
  /// The response carries the same `{user, tokens}` shape as registration, so it
  /// parses with the same code. A wrong password comes back as a 400 with JSON,
  /// never an HTML page.
  Future<RegisteredAccount> logIn({
    required String email,
    required String password,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/login/',
      data: {'email': email, 'password': password},
    );

    final account = RegisteredAccount.tryParse(body);
    if (account == null) {
      // A 2xx whose body does not describe an account. Its own message, because
      // the alternative is a flow that carries on with no session and fails
      // somewhere less obvious.
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message:
            'The server accepted the sign-in but its response did not contain '
            'an account.',
      );
    }
    return account;
  }

  /// `POST /logout/`, which blacklists the refresh token server-side
  /// (handoff §11) — so this is what stops the token being usable for the rest
  /// of its 7 days.
  ///
  /// The body is optional from our side: the backend answers with a message
  /// rather than a payload, and there is nothing here to read.
  Future<void> logOut({required String refresh}) async {
    await _client.postOptionalBody('/logout/', data: {'refresh': refresh});
  }

  /// `GET /me/` — the signed-in user, as the server knows them.
  ///
  /// Confirmed live 2026-09-28: returns a **flat** object
  /// (`{"id","email","name","role","verification_status","onboarding_completed",
  /// "is_active"}`), needs a Bearer token (**401** without one), and **needs the
  /// trailing slash** — without it Django answers **301** and dio does not follow
  /// a redirect onto a different method/path for us. The path below is written
  /// with the slash for that reason; do not "tidy" it away.
  ///
  /// This is what makes the app know *who* is signed in. The auth responses
  /// carry an id, email and role, but nothing the profile screens can render —
  /// so without this call the profile tab and Edit Profile have no name to show.
  Future<MeProfile?> fetchMe() async {
    final body = await _client.get<Map<String, dynamic>>('/me/');
    return MeProfile.tryParse(body);
  }

  /// `PATCH /me/` — the write path for the fields every role shares.
  ///
  /// **Added 2026-10-02, after the backend shipped it.** Until then `/me/` was
  /// documented `get`-only in the OpenAPI schema and there was nowhere to send an
  /// edit: `name`, `email`, `gender` and `dob` were accepted by no serializer and
  /// silently discarded by both completion routes, so a save reported success
  /// having changed nothing.
  ///
  /// **Exactly seven fields, measured by probe on 2026-10-02** — sending a key
  /// with an invalid value gets the key named back in a 400, and a key the
  /// serializer does not know produces no error at all:
  ///
  /// | Field | Accepted values |
  /// |---|---|
  /// | `name` | string |
  /// | `email` | a valid email address |
  /// | `gender` | **`male` / `female` / `other`, lowercase only** — `Male` is a 400 |
  /// | `dob` | `DD/MM/YYYY` or `YYYY-MM-DD` |
  /// | `phone_country_code` | string |
  /// | `phone_number` | string |
  /// | `location` | string |
  ///
  /// Two consequences the caller has to respect, both verified live:
  ///
  /// - **`gender` and `dob` cannot be cleared.** `{"gender": ""}` is a 400
  ///   (`"" is not a valid choice`) and `{"dob": ""}` is a 400 (wrong format).
  ///   `location` and both phone fields *do* accept `""` and clear. So a blank
  ///   gender or DOB must be **omitted from the body**, not sent empty — the
  ///   field keeps its server value instead of erroring the whole save.
  /// - The nine instructor completion fields (`qualification`,
  ///   `subject_expertise`, `experience_years`, the geographic ids) are **not**
  ///   on this serializer: posting them returns 200 and changes nothing. They
  ///   still go through [completeProfile]. A 200 here is therefore *not* proof
  ///   the deferred half was saved.
  ///
  /// Returns the updated profile — the same shape [fetchMe] reads — so the
  /// caller can refresh from the server's own answer instead of trusting what it
  /// sent. Falls back to null if the body is not a recognisable user object.
  ///
  /// **Accepts `multipart/form-data` as well as JSON, since 2026-10-05.** The
  /// same route now takes the user's documents under the registration field
  /// names — `profile_photo`, `student_id_card`, `cv_resume`,
  /// `certificates_and_recommendations` — and mixing them with text fields in
  /// one request is explicitly allowed. The content type is chosen here rather
  /// than by the caller because the two are the same endpoint with the same
  /// semantics; only the encoding differs.
  ///
  /// **The slot names are a wire contract.** They are
  /// [ProfileDocumentSlot]'s values, and a rename on either side would make the
  /// upload a silent no-op — the field would be ignored exactly as an unknown
  /// key is.
  ///
  /// **Certificates go in [fileLists], not [files].** That slot is additive
  /// server-side and accepts several files under one repeated field name, and a
  /// `Map` holds one value per key — so a second certificate has to arrive as a
  /// second part or it would replace the first.
  Future<MeProfile?> updateProfile(
    Map<String, String> fields, {
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
  }) async {
    // A user who changed **only** their photo has no text to send, and that is
    // a real save. Returning early on empty fields alone would swallow it.
    final hasFiles = files.isNotEmpty || fileLists.isNotEmpty;
    if (fields.isEmpty && !hasFiles) return null;

    final body = hasFiles
        ? await _client.patchMultipart<Map<String, dynamic>>(
            '/me/',
            fields: fields,
            files: files,
            fileLists: fileLists,
          )
        : await _client.patch<Map<String, dynamic>>('/me/', data: fields);
    return MeProfile.tryParse(body);
  }

  /// The completion routes — **one per role, and getting this wrong is a 403.**
  ///
  /// Verified against the live backend on 2026-10-02 by posting a real
  /// instructor token to both:
  ///
  /// - `/me/complete-profile/` → **403** `{"detail": "Only students can complete
  ///   this profile step."}`. This is what the client used to call for *both*
  ///   roles, so every instructor save that had anything to send was rejected
  ///   there and the fields never left the device.
  /// - `/instructor/complete-profile/` → **400** listing the nine fields it
  ///   requires, which are exactly the nine this client sends.
  ///
  /// Both routes are in the OpenAPI schema (`/api/schema/?format=json` on the
  /// dev host), which is how they were found. The schema documents neither
  /// body — both views are bare `APIView`s with no serializer — so the field
  /// set below was measured with probe requests instead.
  static const _completeProfilePaths = <ProfileRole, String>{
    ProfileRole.student: '/me/complete-profile/',
    ProfileRole.instructor: '/instructor/complete-profile/',
  };

  /// `POST /me/complete-profile/` or `/instructor/complete-profile/`, by role.
  ///
  /// **What the instructor route accepts, measured rather than assumed.** The
  /// nine required fields are `phone_country_code`, `phone_number`, `location`,
  /// `province_id`, `district_id`, `municipality_id`, `qualification`,
  /// `subject_expertise` and `experience_years`; `school_id` is accepted and
  /// optional. Those are the keys this client already sends.
  ///
  /// **`name`, `email`, `gender` and `dob` are fields on NEITHER serializer.** A
  /// probe body carrying all four came back with no error for any of them, which
  /// is how DRF reports a key it does not recognise — so there is no route that
  /// writes them, and `GET /me/` returns none of them either. A user's edit to
  /// those four cannot be persisted today; that is a backend gap, recorded in
  /// `.workbuddy-ai/memory/backend-contract.md`, not something this client can
  /// fix by choosing a different encoding.
  ///
  /// `role` still rides along in the body. The serializer ignores it — the route
  /// is what discriminates now — but it costs nothing and the test double
  /// records the role alongside the fields.
  ///
  /// **The 404 is left to throw here on purpose.** `throwOnMissingResource` is
  /// `true` (the default), so a 404 arrives at the repository as an
  /// [ApiException] — which is the single place that decides a missing route is
  /// not a failure. Swallowing it *here* as well looked harmless and was not: the
  /// repository's `on ApiException` clause could never fire, so it returned
  /// `true` for a request that had not happened, and the user was told their
  /// profile was saved. Two layers disagreeing about who owns a condition is
  /// worse than either owning it.
  ///
  /// The response is not read. Whatever it returns — the updated profile, a
  /// `{"detail": …}`, or nothing — this call's job is to have happened.
  Future<void> completeProfile({
    required ProfileRole role,
    required Map<String, String> fields,
  }) async {
    await _client.postOptionalBody(
      _completeProfilePaths[role]!,
      data: {'role': role.wireValue, ...fields},
    );
  }

  /// Downloads the signed-in user's avatar.
  ///
  /// **Added 2026-10-05, when `/me/` grew `profile_photo_url`.** Until then the
  /// avatar existed only in memory, from the signup that set it, so every later
  /// login showed the placeholder — the user uploaded a photo and it was gone on
  /// the next launch.
  ///
  /// Returns null when there is no photo, and the bytes plus a **filename**
  /// otherwise. The filename is not decoration: `UserProfile.photoFileName`
  /// exists because dio infers a part's content type from the extension, so the
  /// store has to keep a name that matches the bytes or a later re-upload is
  /// mislabelled. A document URL is `/me/documents/<id>/` and carries no
  /// extension, so the name comes from the response's own content type.
  ///
  /// **Returns null rather than throwing.** A missing avatar is cosmetic, and it
  /// must not be able to take the rest of the profile with it — the bootstrap
  /// would otherwise lose the user's name to a failed image fetch.
  Future<({Uint8List bytes, String fileName})?> fetchProfilePhoto(
    String url,
  ) async {
    try {
      final file = await _client.getBytes(url);
      return (
        bytes: file.bytes,
        fileName: 'profile_photo${_extensionOf(file.contentType)}',
      );
    } on ApiException {
      return null;
    }
  }

  /// `.jpg` / `.png` for a content type, or an empty string when it is unknown.
  ///
  /// An unknown type yields **no extension**, never a guess, because the
  /// extension is what decides the upload's content type: guessing `.jpg` for a
  /// PNG would upload it labelled `image/jpeg`.
  static String _extensionOf(String? contentType) {
    final mime = contentType?.split(';').first.trim().toLowerCase();
    return switch (mime) {
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '',
    };
  }

  /// The signup-OTP routes — **one pair per role**, exactly like registration.
  ///
  /// Confirmed against the live schema on 2026-10-07 (123 paths). This is no
  /// longer an instructor-only step: the backend added student signup OTP, so
  /// **both** roles register without a session and then verify by email.
  static const _verifyOtpPaths = <ProfileRole, String>{
    ProfileRole.student: '/register/student/verify-otp/',
    ProfileRole.instructor: '/register/instructor/verify-otp/',
  };

  static const _resendOtpPaths = <ProfileRole, String>{
    ProfileRole.student: '/register/student/resend-otp/',
    ProfileRole.instructor: '/register/instructor/resend-otp/',
  };

  /// `POST /register/student/verify-otp/` or `/register/instructor/verify-otp/`.
  ///
  /// The body is the schema's `SignupVerify`: **`{"email": ..., "otp": ...}`**.
  /// The code field is **`otp`, not `code`** — and it is constrained to
  /// `^[0-9]{4}$`, so the four boxes on the screen map to exactly one wire
  /// field. All four measured live on 2026-10-07:
  ///
  /// | Sent | Answer |
  /// |---|---|
  /// | valid-shaped but wrong/expired/unknown | **400** `{"detail": "Invalid or expired OTP."}` |
  /// | `otp` missing | **400** `{"otp": ["This field is required."]}` |
  /// | `otp` not 4 digits | **400** `{"otp": ["This value does not match the required pattern."]}` |
  ///
  /// **The first row is one message for three causes, deliberately.** The
  /// backend does not tell the client whether the code was wrong, expired, or
  /// belonged to no account, so the screen cannot say either — it shows the
  /// server's sentence and nothing more specific.
  ///
  /// Success is the step that issues the session, so the body is read with the
  /// same tolerant parser registration and login use. It returns null when the
  /// response carried no recognisable account.
  Future<RegisteredAccount?> verifyOtp({
    required ProfileRole role,
    required String email,
    required String code,
  }) async {
    final body = await _client.postOptionalBody(
      _verifyOtpPaths[role]!,
      data: {'email': email, 'otp': code},
    );
    return RegisteredAccount.tryParse(body);
  }

  /// `POST /register/student/resend-otp/` or `/register/instructor/resend-otp/`.
  ///
  /// The body is the schema's `SignupEmail`: `{"email": ...}`.
  ///
  /// **It answers 200 whatever happens.** An unknown address, an address with
  /// no account, and a call inside the 60-second cooldown all return the same
  /// fixed sentence — *"If an eligible account exists and the resend cooldown
  /// has elapsed, a signup OTP has been sent."* Verified live 2026-10-07, for
  /// both a real account and a made-up one.
  ///
  /// That is account-enumeration defence, and it has two consequences the
  /// caller has to live with:
  ///
  /// - **A resend can never be reported as failed from the response.** The only
  ///   way this throws is a transport failure, a 4xx from a malformed body, or
  ///   a 5xx.
  /// - **The cooldown is ours to enforce.** The server will not refuse, so the
  ///   countdown on the screen is the only thing stopping a tap-storm — which
  ///   is why its length is a client constant that has to match the server's.
  Future<void> resendOtp({
    required ProfileRole role,
    required String email,
  }) async {
    await _client.postOptionalBody(
      _resendOtpPaths[role]!,
      data: {'email': email},
    );
  }

  // ---------------------------------------------------------------------------
  // Password reset — a separate OTP flow from signup, and a different one
  // ---------------------------------------------------------------------------
  //
  // Three steps, three endpoints, and **not** interchangeable with the signup
  // pair above: different paths, a `reset_token` in the middle, and a reset
  // endpoint at the end. The backend's integration guide is explicit that the
  // signup and reset OTP purposes stay separate, so the 4-digit length is the
  // only thing the two flows share.

  /// `POST /forgot-password/` — asks for a reset code.
  ///
  /// Body `{"email": ...}`.
  ///
  /// **Answers 200 whether or not the address has an account**, with a fixed
  /// sentence: `{"detail": "If an account exists with this email, a password
  /// reset OTP has been sent."}` So the caller cannot tell whether anything was
  /// sent, and the screen must advance to the code step either way — saying "no
  /// such account" here would turn the endpoint into an address-enumeration
  /// oracle.
  ///
  /// **There is no server-side cooldown on this one**, unlike signup resend:
  /// every request mints a fresh code and **kills the previous one**, so only the
  /// newest email's code works. The 60-second wait on the button is therefore a
  /// pure client affordance, not a mirror of a server rule.
  Future<void> requestPasswordReset({required String email}) async {
    await _client.postOptionalBody('/forgot-password/', data: {'email': email});
  }

  /// `POST /forgot-password/verify-otp/` — exchanges the code for a reset token.
  ///
  /// Body `{"email": ..., "otp": ...}`, the code again as a **string**.
  ///
  /// Returns the opaque `reset_token`, or null when the response carried none.
  /// **The token is the whole point of this call**: it is the only thing that
  /// authorises [resetPassword], it is single-use, and it expires in 10 minutes.
  /// Kept in memory by the caller and never persisted.
  ///
  /// Failures — note the shapes differ from the signup verify endpoint:
  /// - **400** `{"detail": ["Invalid or expired OTP."]}` — a **list** here,
  ///   where signup sends a plain string. Covers a wrong, expired or used-up code.
  /// - **400** `{"otp": ["Enter exactly 4 numeric digits."]}` — bad format.
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) async {
    final body = await _client.postOptionalBody(
      '/forgot-password/verify-otp/',
      data: {'email': email, 'otp': code},
    );
    if (body is! Map) return null;
    final token = body['reset_token'];
    if (token is String && token.trim().isNotEmpty) return token.trim();
    return null;
  }

  /// `POST /forgot-password/reset/` — sets the new password.
  ///
  /// Body `{"reset_token": ..., "new_password": ..., "confirm_password": ...}`.
  ///
  /// **Returns no tokens, and that is the contract rather than an omission.** The
  /// backend signs every existing session for the account out when the password
  /// changes — stored refresh tokens stop working, and already-issued access
  /// tokens die within their 30 minutes — so the user has to log in again. The
  /// caller therefore ends this flow on the login screen, not in the app.
  ///
  /// Failures, and the distinction the caller needs:
  /// - **400** `{"new_password": [...]}` or `{"confirm_password": [...]}` — the
  ///   password rules, as **field errors**. The user can fix this in place.
  /// - **400** `{"detail": ["Invalid or expired reset token."]}` — the token was
  ///   used, is over 10 minutes old, or was tampered with. **A `detail` with no
  ///   field errors**, which is how the screen tells "restart the flow" from
  ///   "correct the password" without matching prose.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.postOptionalBody(
      '/forgot-password/reset/',
      data: {
        'reset_token': resetToken,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }
}
