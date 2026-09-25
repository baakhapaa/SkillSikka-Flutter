import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/network/session.dart';
import 'core/routing/app_router.dart';

class SkillSikkaApp extends ConsumerWidget {
  const SkillSikkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A session that ends *without the user asking* — the server rejected the
    // refresh token — has to put them back on the login screen. Screens navigate
    // deliberately when someone signs out; this covers the involuntary case,
    // which would otherwise leave them on a screen that can no longer load
    // anything, watching every request fail with no way forward.
    //
    // Listening for the transition rather than reacting to a null session means
    // the signed-out start-up state does not fire it: there is no previous
    // session to lose.
    ref.listen(sessionProvider, (previous, next) {
      if (previous != null && next == null) {
        ref.read(appRouterProvider).go('/login-screen');
      }
    });

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
