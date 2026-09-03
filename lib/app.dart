import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/routing/app_router.dart';

class SkillSikkaApp extends ConsumerWidget {
  const SkillSikkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SkillSikka',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE6B800)),
        textTheme: GoogleFonts.manropeTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
