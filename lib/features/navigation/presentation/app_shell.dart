import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/network/session.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../challenge/presentation/challenge_page.dart';
import '../../home/presentation/home_page.dart';
import '../../learning/presentation/my_learning_page.dart';
import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';
import '../../profile/presentation/my_courses_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../short/presentation/short_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  /// Tabs that have been opened. Home is built at once; the others wait until
  /// they are tapped, so signing in does not start every tab's requests.
  /// A visited tab stays in the stack, so coming back to it is instant.
  final Set<int> _visited = {0};

  void _selectPage(int index) {
    if (index == _selectedIndex && _visited.contains(index)) return;
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }

  Widget _page(
    int index, {
    required ProfileRole? role,
    required bool signedIn,
  }) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => HomePage(),
      1 => ShortPage(active: _selectedIndex == 1),
      2 => const ChallengesPage(),
      3 => _learningPage(role: role, signedIn: signedIn),
      _ => ProfilePage(active: _selectedIndex == 4),
    };
  }

  Widget _learningPage({
    required ProfileRole? role,
    required bool signedIn,
  }) {
    if (signedIn && role == null) return const _TabSkeleton();
    if (role == ProfileRole.instructor) {
      return const MyCoursesPage(showBack: false);
    }
    return const MyLearningPage();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userProfileProvider.select((profile) => profile.role));
    final signedIn = ref.watch(sessionProvider) != null;
    final instructor = role == ProfileRole.instructor;
    final pages = <Widget>[
      for (var index = 0; index < 5; index++)
        _page(index, role: role, signedIn: signedIn),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _selectedIndex,
        // **`expand` is load-bearing.** A `Scaffold` body is laid out with
        // *loose* constraints, and `StackFit.loose` (the default) then sizes each
        // page to its own content. A page whose root is a coloured box therefore
        // painted only as far as its content reached: measured 2026-10-28, the
        // body was 360x715 while `MyLearningPage` laid out at **360x683**, so a
        // 32pt strip of the theme's amber surface showed below it — and on a
        // device whose text wraps narrower, the seam ran down the right edge too,
        // making the page look like a white card floating on cream.
        //
        // Every page here is a full-screen destination, so tight constraints are
        // what they all want.
        sizing: StackFit.expand,
        children: pages,
      ),
      bottomNavigationBar: SkillSikkaFooter(
        selectedIndex: _selectedIndex,
        onSelected: _selectPage,
        learningLabel: instructor ? 'My Courses' : 'My Learning',
      ),
    );
  }
}

class SkillSikkaFooter extends StatelessWidget {
  const SkillSikkaFooter({
    required this.selectedIndex,
    required this.onSelected,
    this.learningLabel = 'My Learning',
    this.backgroundColor = const Color(0xFFFAF9F6),
    this.isDarkBackground = false,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String learningLabel;
  final Color backgroundColor;
  final bool isDarkBackground;

  @override
  Widget build(BuildContext context) {
    final items = <_FooterItem>[
      const _FooterItem(
        'Home',
        'assets/figma/footer/home.svg',
        'assets/figma/footer/home_inactive.svg',
      ),
      const _FooterItem(
        'Short',
        'assets/figma/footer/short_active.svg',
        'assets/figma/footer/short.svg',
      ),
      const _FooterItem(
        'Challenge',
        'assets/figma/footer/challenge_active.svg',
        'assets/figma/footer/challenge.svg',
      ),
      _FooterItem(
        learningLabel,
        'assets/figma/footer/learning_active.svg',
        'assets/figma/footer/learning.svg',
      ),
      const _FooterItem(
        'Profile',
        'assets/figma/footer/profile_active.svg',
        'assets/figma/footer/profile.svg',
      ),
    ];
    return Container(
      key: const ValueKey('skill-sikka-footer'),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDarkBackground
                ? const Color(0xFF333333)
                : const Color(0xFFEAEAEA),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 84,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _FooterButton(
                      item: items[index],
                      selected: selectedIndex == index,
                      isDarkBackground: isDarkBackground,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
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
    this.isDarkBackground = false,
  });

  final _FooterItem item;
  final bool selected;
  final bool isDarkBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDarkBackground
        ? const Color(0xFFFAF9F6)
        : const Color(0xFF666666);
    final color = selected ? const Color(0xFFE6B800) : inactiveColor;

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
                  colorFilter: (!selected && isDarkBackground)
                      ? ColorFilter.mode(inactiveColor, BlendMode.srcIn)
                      : null,
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

/// Shown on the learning tab until a signed-in user's role is known, so an
/// instructor is not briefly given the student list and its request.
class _TabSkeleton extends StatelessWidget {
  const _TabSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFAF9F6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: CourseListSkeleton(rows: 4),
      ),
    );
  }
}
