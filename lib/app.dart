import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/routing/app_router.dart';
import 'core/session_bootstrap.dart';
import 'core/session_persistence.dart';

class SkillSikkaApp extends ConsumerWidget {
  const SkillSikkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Restores a session saved on a previous launch, and saves every change after
    // that. Watched here for the same reason as the loader below: the provider does
    // nothing at all until something watches it, and this is the single place that
    // should.
    //
    // Watched before the loader so a restored session is in place as early as
    // possible. The order is not load-bearing — the restore is async, so the loader
    // is registered long before a session arrives, and its own listener catches it
    // whenever it lands.
    ref.watch(sessionPersistenceProvider);

    // Loads the signed-in user's own details whenever a session appears, and
    // clears them when it ends. Watched here so it is alive for the whole app —
    // the provider does nothing until something watches it, and this is the
    // single place that should.
    //
    // Deliberately not in `main.dart` or a login callback: the session appears
    // from three places (sign-in, registration, token refresh) and only one of
    // them is a screen that could call it.
    ref.watch(sessionProfileLoaderProvider);

    // A session that ends *without the user asking* — the server rejected the
    // refresh token — used to be handled here, by listening for the transition
    // to null and navigating. That now lives in the router's `redirect`, which
    // is the better home for it: it is declarative, it runs on every navigation
    // rather than only while this widget is mounted, and it holds the refresh
    // listener that makes it re-evaluate. Two places deciding where a user
    // belongs is how they end up disagreeing, so this is deliberately empty.
    return MaterialApp.router(
      title: 'Skill Sikka',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE6B800)),
        textTheme: GoogleFonts.manropeTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
