import 'package:flutter/material.dart';

import 'short_video_data.dart';

enum ShortFeedTab { stem, forYou }

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
  late double _progressValue;

  @override
  void initState() {
    super.initState();
    _progressValue = _videoData.initialProgress;
  }

  ShortVideoData get _videoData =>
      _selectedTab == ShortFeedTab.forYou ? forYouVideo : kStemVideo;

  void _selectTab(ShortFeedTab tab) {
    if (tab == _selectedTab) return;
    setState(() {
      _selectedTab = tab;
      _isLiked = false;
      _isSaved = false;
      _progressValue = _videoData.initialProgress;
    });
  }

  Future<void> _openSaveSheet() async {
    final selectedCollection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const SaveToCollectionSheet(),
    );

    if (selectedCollection != null && mounted) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $selectedCollection'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
            child: _buildVideo(key: ValueKey(_selectedTab)),
          ),
          _buildTopNavigation(),
        ],
      ),
    );
  }

  Widget _buildVideo({required Key key}) {
    final data = _videoData;
    return KeyedSubtree(
      key: key,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Image.asset(data.image, fit: data.fit, alignment: Alignment.center),
          Positioned(
            left: 16,
            right: 14,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildCreatorDetails(data: data)),
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
                isSelected: _selectedTab != ShortFeedTab.forYou,
                onTap: () => _selectTab(ShortFeedTab.stem),
              ),
              _TopNavItem(
                label: 'For you',
                isSelected: _selectedTab == ShortFeedTab.forYou,
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

  Widget _buildCreatorDetails({required ShortVideoData data}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                data.avatar,
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
                  data.creator,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  data.role,
                  style: const TextStyle(
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
          data.description,
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
                data.course,
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
    final data = _videoData;
    final likedLabel = data.likeCount.toString();
    final unlikedLabel = (data.likeCount - 1).toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ActionItem(icon: Icons.quiz, label: 'Quiz'),
        const SizedBox(height: 14),
        _ActionItem(
          asset: 'assets/images/hearticon.png',
          label: _isLiked ? likedLabel : unlikedLabel,
          isActive: _isLiked,
          activeColor: const Color(0xFFF70303),
          onTap: () => setState(() => _isLiked = !_isLiked),
        ),
        const SizedBox(height: 18),
        _ActionItem(
          asset: 'assets/images/commenticon.png',
          label: data.commentCount.toString(),
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.bookmark,
          label: _isSaved ? 'Saved' : 'Save',
          isActive: _isSaved,
          activeColor: brandYellow,
          onTap: _openSaveSheet,
        ),
        const SizedBox(height: 18),
        const _ActionItem(icon: Icons.share, label: 'Share'),
      ],
    );
  }
}

class SaveToCollectionSheet extends StatefulWidget {
  const SaveToCollectionSheet({super.key});

  @override
  State<SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<SaveToCollectionSheet> {
  String? _selectedCollection;

  final List<Map<String, String>> collections = const [
    {
      'title': 'CSS Tutorials',
      'count': '12 videos',
      'image': 'assets/images/Rectangle.png',
    },
    {
      'title': 'Web Dev Basics',
      'count': '48 videos',
      'image': 'assets/images/Rectangle (1).png',
    },
    {
      'title': 'Challenge Set',
      'count': '3 videos',
      'image': 'assets/images/rec.png',
    },
    {
      'title': 'Watch Later',
      'count': '15 videos',
      'image': 'assets/images/rec.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Save to Collection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD233),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'New',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: 12,
                      left: index == 0 ? 0 : 0,
                    ),
                    child: InkWell(
                      onTap: () => setState(
                        () => _selectedCollection = collection['title'],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 140,
                        height: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          border: Border.all(
                            color: _selectedCollection == collection['title']
                                ? const Color(0xFFFFD233)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                collection['image']!,
                                width: double.infinity,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              collection['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Manrope',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              collection['count']!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color.fromRGBO(255, 255, 255, 0.7),
                                fontFamily: 'Manrope',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedCollection == null
                    ? null
                    : () => Navigator.pop(context, _selectedCollection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD233),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF3A3A3C),
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save collection',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
