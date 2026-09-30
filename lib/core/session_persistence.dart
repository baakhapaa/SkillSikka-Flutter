import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/session.dart';
import 'network/session_store.dart';

/// Keeps [sessionProvider] and the device's secure store in step, in both
/// directions.
///
/// **Restore, once, at startup.** A session written on a previous launch is read
/// back and put into [sessionProvider]. A returning user therefore skips the
/// welcome screen entirely: `/splash` is a public route, so the guard leaves a
/// signed-out user there, but the moment a session lands the router's
/// `refreshListenable` re-evaluates and moves them to `/`. Nothing here navigates —
/// that stays the guard's single job.
///
/// **Write, on every change after that.** One `ref.listen` covers all of it: the
/// five `_adopt` call sites in `DioAuthRepository`, the interceptor's two writes,
/// and the null written on sign-out. Instrumenting those sites individually would
/// be six places to keep in step and one to forget; watching the provider cannot
/// miss a change.
///
/// **Why a provider and not `main()`.** Restoring in an async `main` would make
/// `main` async and hold up the first frame for a disk read. Doing it here means
/// the app paints immediately and settles a moment later — and because
/// `refreshListenable` is already wired, no navigation code is needed to act on it.
/// The trade is that a restored session arrives a frame or two late, which the
/// splash screen covers.
///
/// **What this is worth.** Up to seven days, and no more: the refresh token's
/// lifetime is absolute, measured from login, and refreshing the access token does
/// not extend it. See [Session]'s own docs before promising a user anything.
///
/// Must be **watched** to run — `lib/app.dart` is the single place that does.
final sessionPersistenceProvider = Provider<void>((ref) {
  final store = ref.watch(sessionStoreProvider);

  // Tracked so a teardown mid-restore does not write into a dead container.
  var disposed = false;
  ref.onDispose(() => disposed = true);

  // What we believe is already on the device. Starts as the current in-memory
  // session, because a container can be built with one already set (a test, or a
  // future restore that happens elsewhere).
  var known = ref.read(sessionProvider);

  ref.listen<Session?>(sessionProvider, (previous, next) {
    // The restore below assigns the session it just read, which fires this
    // listener. Without this guard that echo would write the identical value
    // straight back to the Keystore — harmless, but a wasted platform call on
    // every single launch, and it would make the store's write count a misleading
    // thing to assert on.
    if (next == known) return;
    known = next;

    if (next == null) {
      unawaited(store.clear());
    } else {
      unawaited(store.write(next));
    }
  });

  Future<void> restore() async {
    final stored = await store.read();
    // `read` never throws and never returns a half-session: a payload it cannot
    // parse comes back as null, having been cleared. So there is nothing to
    // validate here.
    if (disposed || stored == null) return;

    // Assigned *before* the state below, so the listener sees this as already
    // known and does not echo it to disk.
    known = stored;
    ref.read(sessionProvider.notifier).state = stored;
  }

  unawaited(restore());
});
