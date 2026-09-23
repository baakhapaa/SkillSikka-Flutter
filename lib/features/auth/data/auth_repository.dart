import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'auth_api.dart';
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
  /// Creates the account. The returned account may or may not carry a session,
  /// depending on whether the backend issues a token here (handover doc §6.1).
  Future<RegisteredAccount> register(RegistrationRequest request);

  /// Confirms the emailed code. Returns the account when verification
  /// established a session, and null when it did not.
  Future<RegisteredAccount?> verifyOtp({
    required String email,
    required String code,
  });

  Future<void> resendOtp({required String email});
}

/// The real one. Talks HTTP and adopts a session when the backend offers one.
class DioAuthRepository implements AuthRepository {
  DioAuthRepository({
    required ApiClient client,
    required StateController<String?> authToken,
  }) : _api = AuthApi(client),
       _authToken = authToken;

  final AuthApi _api;
  final StateController<String?> _authToken;

  @override
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    final account = await _api.register(request);
    _adopt(account);
    return account;
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

  /// Keeps the session when the response carried one, and does nothing when it
  /// did not.
  ///
  /// This is the whole of the "does registration return a token" question from
  /// the client's side: adopting a token if it is there makes the flow work
  /// under either backend model, so the answer changes nothing here. Persisting
  /// it across launches is separate work.
  void _adopt(RegisteredAccount account) {
    final token = account.accessToken;
    if (token != null && token.isNotEmpty) {
      _authToken.state = token;
    }
  }
}

/// An [AuthRepository] that answers from memory.
///
/// For widget tests, and for driving the signup flow before the backend is up.
/// Deliberately **not** wired in by default: a fake that switches itself on is
/// how "it worked on my machine" happens. Tests override
/// [authRepositoryProvider] with it.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.latency = Duration.zero,
    this.tokenOnRegister = false,
  });

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

  @override
  Future<RegisteredAccount> register(RegistrationRequest request) async {
    await _wait();
    _throwIfFailing();
    registrations.add(request);
    return RegisteredAccount(
      email: request.fields['email'] ?? '',
      userId: 'fake-user-${registrations.length}',
      role: request.role,
      status: 'pending',
      accessToken: tokenOnRegister ? 'fake-access-token' : null,
    );
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
    return RegisteredAccount(
      email: email,
      userId: 'fake-user-1',
      status: 'active',
      accessToken: 'fake-access-token',
    );
  }

  @override
  Future<void> resendOtp({required String email}) async {
    await _wait();
    _throwIfFailing();
    resends.add(email);
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
    // `.notifier` rather than the value: the repository writes the token, and
    // watching the notifier does not rebuild this provider when it changes.
    authToken: ref.watch(authTokenProvider.notifier),
  ),
);
