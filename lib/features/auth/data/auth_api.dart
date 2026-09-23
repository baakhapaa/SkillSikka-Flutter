import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
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
  static const _photoField = 'photo';

  /// `POST /auth/register`, as `multipart/form-data`.
  ///
  /// One request rather than "create the account, then upload the photo",
  /// because the photo is mandatory for both roles: a two-step flow would leave
  /// an account and an orphaned upload behind every abandoned signup.
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    final body = await _client.postMultipart<Map<String, dynamic>>(
      '/auth/register',
      fields: {'role': request.role.wireValue, ...request.fields},
      files: {
        _photoField: filePart(
          bytes: request.photo.bytes,
          fileName: request.photo.fileName,
        ),
        // Keyed by the slot name, which is already the multipart field name the
        // contract proposes (`cv_resume`, `certificates`, `student_id_card`).
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

  /// `POST /auth/verify-otp`.
  ///
  /// Returns the account when verification established a session, and null when
  /// it did not — the backend may issue the token here or not at all (§6.1).
  /// The body is optional, so this uses [ApiClient.postOptionalBody]: a
  /// successful verification has no reason to carry a payload.
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

  /// `POST /auth/resend-otp`. The body carries nothing the caller needs.
  Future<void> resendOtp({required String email}) async {
    await _client.postOptionalBody('/auth/resend-otp', data: {'email': email});
  }
}
