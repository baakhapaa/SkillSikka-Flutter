import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/network/session_store.dart';
import 'package:skillsikka/core/session_persistence.dart';

/// The wiring between [sessionProvider] and the device's secure store.
///
/// Every test here goes through the provider rather than calling the store
/// directly, because the thing that can actually go wrong is the *wiring*: a
/// change that never reaches disk, or a restore that is immediately written back.
/// The store's own behaviour is covered in `session_store_test.dart`.
void main() {
  const session = Session(access: 'access-abc', refresh: 'refresh-abc');
  const rotated = Session(access: 'rotated-access', refresh: 'refresh-abc');

  /// A container with the fake store, and the persistence provider running.
  ///
  /// `listen` is not incidental: [sessionPersistenceProvider] is a `Provider<void>`
  /// that does nothing at all until something watches it, so without this line
  /// nothing under test would run.
  ({ProviderContainer container, FakeSessionStore store}) running({
    Session? stored,
  }) {
    final store = FakeSessionStore(stored: stored);
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.listen(sessionPersistenceProvider, (_, _) {});
    return (container: container, store: store);
  }

  group('restore at startup', () {
    test('puts a stored session into the provider', () async {
      final (:container, :store) = running(stored: session);

      await pumpEventQueue();

      expect(container.read(sessionProvider), session);
      expect(store.reads, 1);
    });

    test('does not write back what it just restored', () async {
      // The listener fires when the restore assigns the session it read. Without
      // the `known` guard that echo would write the identical value straight back
      // to the Keystore on every single launch — and, worse, it would make the
      // write count meaningless as an assertion in every other test here.
      final (:container, :store) = running(stored: session);

      await pumpEventQueue();

      expect(container.read(sessionProvider), session);
      expect(store.writes, 0, reason: 'the restore must not echo to disk');
    });

    test('stays signed out when nothing is stored', () async {
      final (:container, :store) = running();

      await pumpEventQueue();

      expect(container.read(sessionProvider), isNull);
      expect(store.writes, 0);
      // A failed or empty read is not a sign-out, so it must not clear anything.
      expect(store.clears, 0);
    });

    test('restores an access-only session', () async {
      // Possible in principle even though the server always sends both, and it
      // must not be mistaken for corruption.
      const accessOnly = Session(access: 'access-abc');
      final (:container, store: _) = running(stored: accessOnly);

      await pumpEventQueue();

      expect(container.read(sessionProvider), accessOnly);
      expect(container.read(sessionProvider)?.canRefresh, isFalse);
    });
  });

  group('writing changes', () {
    test('persists a session adopted after startup', () async {
      // The login and registration path: `_adopt` sets the provider, and this is
      // what puts it on disk.
      final (:container, :store) = running();
      await pumpEventQueue();

      container.read(sessionProvider.notifier).state = session;
      await pumpEventQueue();

      expect(store.stored, session);
      expect(store.writes, 1);
    });

    test('persists a rotated access token', () async {
      // The interceptor replaces the access token every 30 minutes. The refresh
      // token stays the same, because the backend does not rotate it.
      final (:container, :store) = running(stored: session);
      await pumpEventQueue();

      container.read(sessionProvider.notifier).state = rotated;
      await pumpEventQueue();

      expect(store.stored, rotated);
      expect(store.stored?.refresh, 'refresh-abc');
    });

    test('clears the store on sign-out', () async {
      final (:container, :store) = running(stored: session);
      await pumpEventQueue();

      container.read(sessionProvider.notifier).state = null;
      await pumpEventQueue();

      expect(store.stored, isNull);
      expect(store.clears, 1);
      // Cleared, not overwritten with an empty session.
      expect(store.writes, 0);
    });

    test('writes once per distinct change, not once per assignment', () async {
      final (:container, :store) = running();
      await pumpEventQueue();

      container.read(sessionProvider.notifier).state = session;
      await pumpEventQueue();
      container.read(sessionProvider.notifier).state = session;
      await pumpEventQueue();

      expect(store.writes, 1, reason: 'an identical value is not a new change');
    });
  });

  group('teardown', () {
    test('a restore finishing after disposal does not throw', () async {
      // A real race: the app closing, or a test tearing down, while the disk read
      // is still in flight. Without the `disposed` guard this would call
      // `ref.read` on a dead container from inside an unawaited future, which
      // surfaces as an unhandled async error rather than a clean failure.
      final store = FakeSessionStore(stored: session);
      final container = ProviderContainer(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
      );
      container.listen(sessionPersistenceProvider, (_, _) {});

      // Disposed before the restore's `await store.read()` can resume.
      container.dispose();

      await expectLater(pumpEventQueue(), completes);
    });
  });
}
