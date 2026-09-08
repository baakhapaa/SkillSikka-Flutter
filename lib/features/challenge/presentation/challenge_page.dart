import 'package:flutter/material.dart';

import '../../navigation/presentation/destination_page.dart';

class ChallengePage extends StatelessWidget {
  const ChallengePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Challenge',
      subtitle: 'Test your skills and keep your streak going.',
      icon: Icons.track_changes_outlined,
    );
  }
}
