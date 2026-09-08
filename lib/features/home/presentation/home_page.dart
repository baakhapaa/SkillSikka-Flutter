import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Skill Sikka'),
      ),
      body: const Center(child: Text('Learn. Practice. Grows.')),
    );
  }
}
