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
  static const _photoField = 'profile_photo';

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
        _photoField: filePart(
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

  /// `POST /auth/verify-otp`.
  ///
  /// **This endpoint does not exist.** The backend response is explicit that
  /// signup email verification is not implemented and that registration returns
  /// the session immediately; `/auth/verify-otp` and `/auth/resend-otp` below
  /// were ours. Both calls are left in place only until the signup flow is
  /// rewired — see `student-signup-backend-spec.md` §B. Do not treat either as
  /// part of the contract.
  ///
  /// Returns the account when verification established a session, and null when
  /// it did not. The body is optional, so this uses
  /// [ApiClient.postOptionalBody]: a successful verification has no reason to
  /// carry a payload.
  Future<RegisteredAccount?> verifyOtp({
    required String email,
    required String code,
  }) async {
    final body = await _client.postOptionalBody(
      '/auth/verify-otp',
      data: {'email': email, 'code': code},
    );
    return RegisteredAccount.tryParse(body);
  }

  /// `POST /auth/resend-otp`. **Does not exist** — see [verifyOtp].
  Future<void> resendOtp({required String email}) async {
    await _client.postOptionalBody('/auth/resend-otp', data: {'email': email});
  }
}
