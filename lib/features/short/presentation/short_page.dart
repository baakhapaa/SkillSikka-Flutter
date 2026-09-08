import 'package:flutter/material.dart';

import '../../navigation/presentation/destination_page.dart';

class ShortPage extends StatelessWidget {
  const ShortPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Short',
      subtitle: 'Quick lessons for focused learning.',
      icon: Icons.play_circle_outline,
    );
  }
}
