import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/network/session_store.dart';

/// A [SecureKeyValueStore] answering from memory, which can be told to fail.
///
/// Being able to make it fail is the point: the real store's contract is that
/// *none* of its methods throw, and that contract only exists because the
/// underlying storage can. Without a backend that throws there is no way to test
/// the rule that matters most.
class _FakeBackend implements SecureKeyValueStore {
  _FakeBackend({this.value});

  /// Stands in for what is on disk — a raw string, not a `Session`, so a test can
  /// put genuine garbage there.
  String? value;

  bool failOnRead = false;
  bool failOnWrite = false;
  bool failOnDelete = false;

  int reads = 0;
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    if (failOnRead) throw StateError('backend read failed');
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failOnWrite) throw StateError('backend write failed');
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    if (failOnDelete) throw StateError('backend delete failed');
    value = null;
  }
}

void main() {
  const session = Session(access: 'access-abc', refresh: 'refresh-abc');
  const accessOnly = Session(access: 'access-abc');

  group('Session JSON', () {
    test('round-trips both tokens', () {
      final restored = Session.fromJson(session.toJson());

      expect(restored, session);
      expect(restored.access, 'access-abc');
      expect(restored.refresh, 'refresh-abc');
      expect(restored.canRefresh, isTrue);
    });

    test('omits refresh entirely when there is none', () {
      // Omitted rather than written as `null`, so a blob from a session that never
      // had a refresh token stays distinguishable from one that did.
      expect(accessOnly.toJson().containsKey('refresh'), isFalse);
      expect(accessOnly.toJson(), {'access': 'access-abc'});
    });

    test('a session with no refresh token still round-trips', () {
      final restored = Session.fromJson(accessOnly.toJson());

      expect(restored.access, 'access-abc');
      expect(restored.refresh, isNull);
      expect(restored.canRefresh, isFalse);
    });

    test('rejects a payload with no access token', () {
      // Throws rather than returning null: this parses what we ourselves wrote, so
      // a payload like this means corruption, not "signed out".
      expect(
        () => Session.fromJson({'refresh': 'refresh-abc'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-string access token', () {
      expect(
        () => Session.fromJson({'access': 42}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a blank access token', () {
      expect(
        () => Session.fromJson({'access': '   '}),
        throwsA(isA<FormatException>()),
      );
    });

    test('treats a blank refresh as absent rather than an error', () {
      // Not corruption — just a session that cannot renew, which is exactly what
      // the field's nullability is for.
      final restored = Session.fromJson({'access': 'a', 'refresh': '  '});

      expect(restored.access, 'a');
      expect(restored.refresh, isNull);
    });

    test('trims surrounding whitespace', () {
      final restored = Session.fromJson({
        'access': '  access-abc  ',
        'refresh': ' refresh-abc ',
      });

      expect(restored.access, 'access-abc');
      expect(restored.refresh, 'refresh-abc');
    });
  });

  group('SecureSessionStore', () {
    test('reads back what it wrote', () async {
      final backend = _FakeBackend();
      final store = SecureSessionStore(backend: backend);

      await store.write(session);

      expect(await store.read(), session);
      expect(backend.writes, 1);
      expect(backend.reads, 1);
    });

    test('writes one key, not two', () async {
      // One key means one write, so the store cannot be left holding an access
      // token whose refresh token never landed.
      final backend = _FakeBackend();

      await SecureSessionStore(backend: backend).write(session);

      final decoded = jsonDecode(backend.value!) as Map<String, dynamic>;
      expect(decoded.keys.toSet(), {'access', 'refresh'});
    });

    test('reports no session when nothing is stored', () async {
      final backend = _FakeBackend();
      final store = SecureSessionStore(backend: backend);

      expect(await store.read(), isNull);
      // Nothing to clean up, so it must not spend a delete on it.
      expect(backend.deletes, 0);
    });

    test('reports no session when the stored value is empty', () async {
      final backend = _FakeBackend(value: '');

      expect(await SecureSessionStore(backend: backend).read(), isNull);
    });

    test('a read failure reports no session instead of throwing', () async {
      // The contract that keeps a broken store from becoming a blank screen at
      // startup.
      final backend = _FakeBackend()..failOnRead = true;
      final store = SecureSessionStore(backend: backend);

      expect(await store.read(), isNull);
      // Nothing was read, so there is nothing to clear.
      expect(backend.deletes, 0);
    });

    test('a corrupt payload is cleared and reported as no session', () async {
      final backend = _FakeBackend(value: 'not json at all');

      expect(await SecureSessionStore(backend: backend).read(), isNull);

      // Cleared, not merely ignored — otherwise the same bad value fails on every
      // single launch, which is precisely what a device restore used to produce
      // before `android:allowBackup="false"`.
      expect(backend.value, isNull);
      expect(backend.deletes, 1);
    });

    test('a JSON payload that is not an object is cleared', () async {
      final backend = _FakeBackend(value: '["access"]');

      expect(await SecureSessionStore(backend: backend).read(), isNull);
      expect(backend.deletes, 1);
    });

    test('a payload missing its access token is cleared', () async {
      final backend = _FakeBackend(value: jsonEncode({'refresh': 'r'}));

      expect(await SecureSessionStore(backend: backend).read(), isNull);
      expect(backend.deletes, 1);
    });

    test('a write failure does not throw', () async {
      // The user is signed in and the app has to keep working. The only cost is
      // that this session will not survive a restart.
      final backend = _FakeBackend()..failOnWrite = true;

      await expectLater(
        SecureSessionStore(backend: backend).write(session),
        completes,
      );
    });

    test('a delete failure does not throw', () async {
      // A failed delete must not block a sign-out. It is survivable because the
      // backend blacklists the refresh token too, so a session that outlived the
      // delete could not renew anyway.
      final backend = _FakeBackend(value: 'x')..failOnDelete = true;

      await expectLater(
        SecureSessionStore(backend: backend).clear(),
        completes,
      );
    });

    test('clear removes a stored session', () async {
      final backend = _FakeBackend();
      final store = SecureSessionStore(backend: backend);
      await store.write(session);

      await store.clear();

      expect(await store.read(), isNull);
      expect(backend.value, isNull);
    });
  });
}
