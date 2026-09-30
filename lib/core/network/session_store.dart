import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Where the signed-in session lives between app launches.
///
/// Deliberately three methods and nothing else. This layer does not know when to
/// save, when to restore, or what a session means — that is
/// `lib/core/session_persistence.dart` and `sessionProvider`'s job. It moves one
/// value to and from the platform's secure store, and that is all.
///
/// **None of these methods throw.** Every failure mode degrades instead: a read
/// that fails reports "no session", a write that fails leaves the running session
/// alone. The reason is that there is no useful thing a caller could do with the
/// error — the app has to keep working either way, and an exception thrown out of a
/// restore path at startup would leave the user on a blank screen for a reason they
/// can neither see nor fix. The cost is honest and worth stating: **a broken store
/// silently signs the user out, and a failed write silently means their session
/// does not survive a restart.**
///
/// **What "secure" means is not the same on every platform**, and the difference
/// matters:
///
/// - **Android / iOS** — backed by the Keystore and the Keychain. The OS holds the
///   key, the app can use it but cannot read it, and a copy of the app's data
///   directory is not enough to decrypt anything. This is the case the app targets
///   and it is genuinely strong.
/// - **Web** — there is no equivalent, and there cannot be: the page's own
///   JavaScript has to decrypt the token on every load, so the key must be
///   reachable by that JavaScript. `flutter_secure_storage` ends up putting it in
///   LocalStorage behind WebCrypto, which its own docs call experimental and "use
///   at your own risk". It defeats a casual snoop reading LocalStorage; it does not
///   defeat injected JavaScript. **Web is not a target platform for this app**, so
///   this is recorded rather than designed around.
abstract interface class SessionStore {
  /// The stored session, or null when there is none or it cannot be read.
  ///
  /// A payload that cannot be parsed is **cleared** rather than merely ignored, so
  /// the same broken value cannot fail on every launch.
  Future<Session?> read();

  /// Persists [session]. Best effort — see the class doc.
  Future<void> write(Session session);

  /// Removes the stored session. Best effort — see the class doc.
  Future<void> clear();
}

/// The narrow slice of `flutter_secure_storage` that [SecureSessionStore] needs.
///
/// Exists so the store can be tested without a platform channel. The alternative —
/// subclassing the package's own `FlutterSecureStorage` in a test — would depend on
/// a type this codebase does not control staying subclassable, and it would make
/// the *resilience* tests (a store that throws on read, which is the entire reason
/// [SessionStore.read] never throws) depend on that too.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The real backend: `flutter_secure_storage`, Keystore on Android, Keychain on
/// iOS.
///
/// No options are passed, deliberately. The package's own docs deprecate
/// `encryptedSharedPreferences` on Android and now default to RSA-OAEP for the key
/// cipher with AES-GCM for storage, which is what we want; pinning the old option
/// would opt back into the deprecated path.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The real [SessionStore], over a [SecureKeyValueStore].
class SecureSessionStore implements SessionStore {
  SecureSessionStore({SecureKeyValueStore? backend})
    : _backend = backend ?? const FlutterSecureKeyValueStore();

  final SecureKeyValueStore _backend;

  /// **One key holding one JSON object**, rather than an `access` key and a
  /// `refresh` key. One key means one write, so the store cannot be left holding a
  /// half-session — an access token whose refresh token never landed, which would
  /// present as a session that mysteriously cannot renew. See [Session.toJson].
  static const key = 'session';

  @override
  Future<Session?> read() async {
    final String raw;
    try {
      final value = await _backend.read(key);
      if (value == null || value.isEmpty) return null;
      raw = value;
    } on Object {
      // The store itself is unavailable — a platform failure, or on Android a
      // Keystore key that did not survive a device restore. There is nothing to
      // clear, because nothing was read.
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Stored session is not a JSON object.');
      }
      return Session.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      // The blob is unusable: corrupt, truncated, or written by an older format.
      // Clear it so the same value cannot fail again on the next launch — which is
      // exactly the state a device restore used to produce before
      // `android:allowBackup="false"` was set in the manifest.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    try {
      await _backend.write(key, jsonEncode(session.toJson()));
    } on Object {
      // Swallowed on purpose. The user is signed in and the app must keep working;
      // the only consequence is that this session will not survive a restart, and
      // nothing in the UI could act on that.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _backend.delete(key);
    } on Object {
      // Swallowed so a failed delete cannot block a sign-out. Worth knowing why
      // that is safe rather than merely convenient: on sign-out the backend also
      // blacklists the refresh token, so a session that survived here could not be
      // renewed anyway, and the next refresh would 401 and clear it.
    }
  }
}

/// An in-memory [SessionStore] for tests.
///
/// Shipped in `lib/` rather than `test/` to match `FakeAuthRepository` in
/// `lib/features/auth/data/auth_repository.dart`, which is there for the same
/// reason: a widget test has no platform channels, so a test that pumps the real
/// app needs a store that behaves like the real one without touching Keystore or
/// Keychain.
///
/// It records counts because the interesting assertions are usually about *how
/// often* the store was touched — that a restore does not immediately write back
/// what it just read, for instance.
class FakeSessionStore implements SessionStore {
  FakeSessionStore({this.stored});

  /// What is "on disk". Public so a test can seed a launch with an existing
  /// session, or read back what was persisted.
  Session? stored;

  int reads = 0;
  int writes = 0;
  int clears = 0;

  @override
  Future<Session?> read() async {
    reads++;
    return stored;
  }

  @override
  Future<void> write(Session session) async {
    writes++;
    stored = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
  }
}

/// The store the app uses. Override it in a test with [FakeSessionStore].
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);
