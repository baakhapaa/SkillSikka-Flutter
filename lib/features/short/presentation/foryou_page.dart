import 'package:flutter/material.dart';

import 'short_page.dart';

class ForyouPage extends StatelessWidget {
  const ForyouPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShortFeedPage(initialTab: ShortFeedTab.forYou);
  }
}
