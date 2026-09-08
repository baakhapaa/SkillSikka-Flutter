import 'package:flutter/material.dart';

class ShortPage extends StatelessWidget {
  const ShortPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShortFeedPage();
  }
}

class ShortFeedPage extends StatefulWidget {
  const ShortFeedPage({super.key, this.initialTab = ShortFeedTab.stem});

  final ShortFeedTab initialTab;

  @override
  State<ShortFeedPage> createState() => _ShortFeedPageState();
}

class _ShortFeedPageState extends State<ShortFeedPage> {
  static const brandYellow = Color(0xFFFFD233);

  late ShortFeedTab _selectedTab = widget.initialTab;
  bool _isLiked = false;
  bool _isSaved = false;
  double _progressValue = 0.56;

  bool get _isForYou => _selectedTab == ShortFeedTab.forYou;

  void _selectTab(ShortFeedTab tab) {
    if (tab == _selectedTab) return;
    setState(() {
      _selectedTab = tab;
      _isLiked = false;
      _isSaved = false;
      _progressValue = tab == ShortFeedTab.forYou ? 0.42 : 0.56;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final isEnteringForYou =
                  (child.key as ValueKey<ShortFeedTab>).value ==
                  ShortFeedTab.forYou;
              final begin = Offset(isEnteringForYou ? 1 : -1, 0);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: _buildVideo(
              key: ValueKey(_selectedTab),
              image: _isForYou
                  ? 'assets/images/react1.png'
                  : 'assets/images/video-background.png',
              fit: _isForYou ? BoxFit.contain : BoxFit.cover,
            ),
          ),
          _buildTopNavigation(),
        ],
      ),
    );
  }

  Widget _buildVideo({
    required Key key,
    required String image,
    required BoxFit fit,
  }) {
    final creator = _isForYou ? '@sam_codes' : '@sarah_codes';
    final role = _isForYou ? 'SAM Educator' : 'Adobe Certified Instructor';
    final description = _isForYou
        ? 'React Hooks Crash Course in 45s ⚛️\n'
              'useState vs useEffect explained! #coding #reactjs\n'
              '#tutorial'
        : 'Master CSS Flexbox in 60 seconds! No crew,\n'
              'just precision layouts ⚡ #coding #webdev\n'
              '#tutorial';
    final course = _isForYou ? 'React Masterclass' : 'CSS Masterclass Course';

    return KeyedSubtree(
      key: key,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Image.asset(image, fit: fit, alignment: Alignment.center),
          Positioned(
            left: 16,
            right: 14,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildCreatorDetails(
                    creator: creator,
                    role: role,
                    description: description,
                    course: course,
                  ),
                ),
                const SizedBox(width: 12),
                _buildActionRail(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _progressValue =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0);
                      });
                    },
                    onTapDown: (details) {
                      setState(() {
                        _progressValue =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0);
                      });
                    },
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.25)),
                        FractionallySizedBox(
                          widthFactor: _progressValue,
                          child: Container(color: brandYellow),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 12, 0),
          child: Row(
            children: [
              _TopNavItem(
                label: 'STEM',
                isSelected: !_isForYou,
                onTap: () => _selectTab(ShortFeedTab.stem),
              ),
              _TopNavItem(
                label: 'For you',
                isSelected: _isForYou,
                onTap: () => _selectTab(ShortFeedTab.forYou),
              ),
              const _TopNavItem(label: 'Challenge'),
              const Spacer(),
              IconButton(
                onPressed: () {},
                tooltip: 'Search',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorDetails({
    required String creator,
    required String role,
    required String description,
    required String course,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/saracodes.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    color: brandYellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          maxLines: 3,
          style: const TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/book.png',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              Text(
                course,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ActionItem(icon: Icons.quiz, label: 'Quiz'),
        const SizedBox(height: 14),
        _ActionItem(
          asset: 'assets/images/hearticon.png',
          label: _isLiked
              ? (_isForYou ? '128' : '25')
              : (_isForYou ? '127' : '24'),
          isActive: _isLiked,
          activeColor: const Color(0xFFF70303),
          onTap: () => setState(() => _isLiked = !_isLiked),
        ),
        const SizedBox(height: 18),
        _ActionItem(
          asset: 'assets/images/commenticon.png',
          label: _isForYou ? '46' : '14',
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.bookmark,
          label: _isSaved ? 'Saved' : 'Save',
          isActive: _isSaved,
          activeColor: brandYellow,
          onTap: () => setState(() => _isSaved = !_isSaved),
        ),
        const SizedBox(height: 18),
        const _ActionItem(icon: Icons.share, label: 'Share'),
      ],
    );
  }
}

enum ShortFeedTab { stem, forYou }

class _TopNavItem extends StatelessWidget {
  const _TopNavItem({required this.label, this.isSelected = false, this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Figtree',
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 20,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD233),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    this.icon,
    this.asset,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  }) : assert(icon != null || asset != null),
       assert(icon == null || asset == null);

  final IconData? icon;
  final String? asset;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? (activeColor ?? Colors.white) : Colors.white;
    final visual = asset != null
        ? Image.asset(
            asset!,
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            color: iconColor,
            colorBlendMode: BlendMode.srcIn,
          )
        : Icon(icon!, color: iconColor, size: 30);

    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: visual),
                    ),
                  )
                : visual,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
