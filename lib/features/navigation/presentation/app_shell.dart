import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../challenge/presentation/challenge_page.dart';
import '../../home/presentation/home_page.dart';
import '../../learning/presentation/my_learning_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../short/presentation/short_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    ShortPage(),
    ChallengePage(),
    MyLearningPage(),
    ProfilePage(),
  ];

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SkillSikkaFooter(
        selectedIndex: _selectedIndex,
        onSelected: _selectPage,
      ),
    );
  }
}

class SkillSikkaFooter extends StatelessWidget {
  const SkillSikkaFooter({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_FooterItem>[
    _FooterItem(
      'Home',
      'assets/figma/footer/home.svg',
      'assets/figma/footer/home_inactive.svg',
    ),
    _FooterItem(
      'Short',
      'assets/figma/footer/short_active.svg',
      'assets/figma/footer/short.svg',
    ),
    _FooterItem(
      'Challenge',
      'assets/figma/footer/challenge_active.svg',
      'assets/figma/footer/challenge.svg',
    ),
    _FooterItem(
      'My Learning',
      'assets/figma/footer/learning_active.svg',
      'assets/figma/footer/learning.svg',
    ),
    _FooterItem(
      'Profile',
      'assets/figma/footer/profile_active.svg',
      'assets/figma/footer/profile.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('skill-sikka-footer'),
        height: 69,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF9F6),
          border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _FooterButton(
                  item: _items[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _FooterItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFE6B800) : const Color(0xFF666666);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: SvgPicture.asset(
                  selected ? item.activeAsset : item.inactiveAsset,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterItem {
  const _FooterItem(this.label, this.activeAsset, this.inactiveAsset);

  final String label;
  final String activeAsset;
  final String inactiveAsset;
}
