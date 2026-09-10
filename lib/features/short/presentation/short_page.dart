import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _openShareSheet() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close share sheet',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        const sharePopupBottomMargin = 14.0;
        final footerHeight =
            69.0 +
            MediaQuery.paddingOf(context).bottom +
            sharePopupBottomMargin;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: footerHeight),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: Material(
                color: const Color(0xFF1C1C1E),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: ShareSheet(video: _videoData),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(video: _videoData),
    );
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
        _ActionItem(
          icon: Icons.quiz,
          label: 'Quiz',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuizScreen()),
          ),
        ),
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
          onTap: _openComments,
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
        _ActionItem(icon: Icons.share, label: 'Share', onTap: _openShareSheet),
      ],
    );
  }
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({required this.video, super.key});

  final ShortVideoData video;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  String? _replyingTo;
  late final List<_CommentData> _comments = [
    const _CommentData(
      user: 'alex.dev',
      text: 'This is exactly what I needed. Thank you!',
      time: '2m',
      avatar: 'assets/figma/face/faace4.png',
    ),
    const _CommentData(
      user: 'codewithmaya',
      text: 'The explanation at the end was so helpful.',
      time: '8m',
      avatar: 'assets/figma/face/face2.png',
    ),
    const _CommentData(
      user: 'jordan_codes',
      text: 'Saving this for later 👏',
      time: '15m',
      avatar: 'assets/figma/face/face3.png',
    ),
    const _CommentData(
      user: 'nina.learns',
      text: 'Could you make a follow-up on the next topic?',
      time: '24m',
      avatar: 'assets/figma/face/face5.png',
    ),
    const _CommentData(
      user: 'dev_student',
      text: 'Short, clear, and easy to follow.',
      time: '31m',
      avatar: 'assets/figma/face/Rectangle.png',
    ),
    const _CommentData(
      user: 'sam.codes',
      text: 'Great tip — sharing this with my study group.',
      time: '42m',
      avatar: 'assets/figma/face/face2.png',
    ),
    const _CommentData(
      user: 'frontend.fan',
      text: 'The visual example made this much easier to understand.',
      time: '49m',
      avatar: 'assets/figma/face/faace4.png',
    ),
    const _CommentData(
      user: 'ravi.codes',
      text: 'I tried this right after watching and it works perfectly.',
      time: '1h',
      avatar: 'assets/figma/face/face3.png',
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(
        9,
        _CommentData(
          user: 'you',
          text: _replyingTo == null ? text : '@$_replyingTo $text',
          time: 'now',
          avatar: 'assets/figma/face/face5.png',
        ),
      );
      _commentController.clear();
      _replyingTo = null;
    });
  }

  void _replyTo(String user) {
    setState(() => _replyingTo = user);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments (${widget.video.commentCount + (_comments.length - 14)})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close comments',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _comments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return _CommentTile(
                      comment: comment,
                      onReply: () => _replyTo(comment.user),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipOval(
                    child: Image.asset(
                      widget.video.avatar,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Figtree',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: _replyingTo == null
                            ? 'Add a comment...'
                            : 'Reply to @$_replyingTo...',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2E),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addComment,
                    tooltip: 'Post comment',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD233),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentData {
  const _CommentData({
    required this.user,
    required this.text,
    required this.time,
    required this.avatar,
  });

  final String user;
  final String text;
  final String time;
  final String avatar;
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onReply});

  final _CommentData comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.asset(
            comment.avatar,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.user,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.time,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onReply,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Reply',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Figtree',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.favorite_border, color: Colors.white54, size: 16),
      ],
    );
  }
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({required this.video, super.key});

  final ShortVideoData video;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
            const SizedBox(height: 14),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      widget.video.image,
                      width: 42,
                      height: 42,
                      fit: widget.video.fit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.shareTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.video.creator.replaceFirst('@', '')} • ${widget.video.shareUrl}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Manrope',
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'SHARE TO APPS',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  _ShareOption(
                    asset: 'assets/figma/copy-check.svg',
                    label: _isCopied ? 'Copied' : 'Copy Link',
                    onTap: _copyLink,
                  ),
                  _ShareOption(
                    asset: 'assets/figma/message-circle.svg',
                    label: 'Messages',
                    onTap: () => _showUnavailable('Messages'),
                  ),
                  _ShareOption(
                    asset: 'assets/figma/message-circle2.svg',
                    label: 'WhatsApp',
                    onTap: () => _showUnavailable('WhatsApp'),
                  ),
                  _ShareOption(
                    asset: 'assets/figma/twitter.svg',
                    label: 'Twitter',
                    onTap: () => _showUnavailable('Twitter'),
                  ),
                  _ShareOption(
                    asset: 'assets/figma/camera.svg',
                    label: 'Instagram',
                    onTap: () => _showUnavailable('Instagram'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
      ClipboardData(text: 'https://${widget.video.shareUrl}'),
    );
    if (!mounted) return;
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
  }

  void _showUnavailable(String destination) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$destination sharing is not available yet')),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 66,
          child: Column(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A3B3F),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(asset, width: 24, height: 24),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Figtree',
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
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

class AnswerOption {
  const AnswerOption({
    required this.text,
    required this.isCorrect,
    this.explanation,
  });

  final String text;
  final bool isCorrect;
  final String? explanation;
}

class QuizQuestion {
  const QuizQuestion({required this.questionText, required this.options});

  final String questionText;
  final List<AnswerOption> options;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {
  static const _questions = [
    QuizQuestion(
      questionText: 'What is the SI unit of force?',
      options: [
        AnswerOption(
          text: 'Newton',
          isCorrect: true,
          explanation: 'A newton is the SI unit of force.',
        ),
        AnswerOption(text: 'Joule', isCorrect: false),
        AnswerOption(text: 'Watt', isCorrect: false),
        AnswerOption(text: 'Pascal', isCorrect: false),
      ],
    ),
    QuizQuestion(
      questionText: 'Which quantity measures how fast velocity changes?',
      options: [
        AnswerOption(text: 'Distance', isCorrect: false),
        AnswerOption(
          text: 'Acceleration',
          isCorrect: true,
          explanation: 'Acceleration is the rate of change of velocity.',
        ),
        AnswerOption(text: 'Mass', isCorrect: false),
        AnswerOption(text: 'Momentum', isCorrect: false),
      ],
    ),
    QuizQuestion(
      questionText: 'What happens to kinetic energy when speed increases?',
      options: [
        AnswerOption(text: 'It decreases', isCorrect: false),
        AnswerOption(text: 'It stays the same', isCorrect: false),
        AnswerOption(
          text: 'It increases',
          isCorrect: true,
          explanation: 'Kinetic energy is proportional to the square of speed.',
        ),
        AnswerOption(text: 'It becomes zero', isCorrect: false),
      ],
    ),
  ];

  late final AnimationController _questionController;
  late final AnimationController _indicatorController;
  late final AnimationController _shakeController;
  late final Animation<double> _questionFade;
  late final Animation<Offset> _questionSlide;
  late final Animation<double> _indicatorScale;
  late final Animation<double> _indicatorFade;
  late final Animation<double> _shake;

  int _questionIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  bool _isComplete = false;
  late final Timer _clockTimer;
  late final Timer _countdownTimer;
  String _currentTime = '';
  int _remainingSeconds = 165;

  QuizQuestion get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
    _questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _questionFade = CurvedAnimation(
      parent: _questionController,
      curve: Curves.easeOut,
    );
    _questionSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _questionController, curve: Curves.easeOutCubic),
    );
    _indicatorScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeOutBack),
    );
    _indicatorFade = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOut,
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    _questionController.forward();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _indicatorController.dispose();
    _shakeController.dispose();
    _clockTimer.cancel();
    _countdownTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  String get _formattedCountdown {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int index) {
    if (_selectedIndex != null || _isComplete) return;
    final option = _question.options[index];
    setState(() {
      _selectedIndex = index;
      if (option.isCorrect) _score++;
    });
    _indicatorController.forward(from: 0);
    if (!option.isCorrect) _shakeController.forward(from: 0);
  }

  void _nextQuestion() {
    if (_selectedIndex == null) return;
    if (_questionIndex == _questions.length - 1) {
      setState(() => _isComplete = true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedIndex = null;
    });
    _indicatorController.reset();
    _questionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentTime,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_4_bar, size: 20),
                      const SizedBox(width: 6),
                      Icon(Icons.signal_cellular_4_bar, size: 20),
                      const SizedBox(width: 6),
                      Icon(Icons.battery_full, size: 20),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(Icons.arrow_back, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Physics Quiz',
                              style: GoogleFonts.lexendDeca(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0xFFEAEAEA)),
                          ),
                          child: Text(
                            _isComplete
                                ? 'Complete'
                                : '${_questionIndex + 1} of ${_questions.length}',
                            style: GoogleFonts.figtree(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAEAEA),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _isComplete
                                  ? 1
                                  : (_questionIndex + 1) / _questions.length,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD233),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formattedCountdown,
                                style: GoogleFonts.figtree(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _questionFade,
                      child: SlideTransition(
                        position: _questionSlide,
                        child: _isComplete
                            ? _buildCompletionContent()
                            : _buildQuestionContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${_questionIndex + 1}',
                style: GoogleFonts.figtree(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _question.questionText,
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: const Color(0xFF111827),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._question.options.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == _question.options.length - 1 ? 0 : 10,
            ),
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final shouldShake = _selectedIndex == entry.key &&
                    !_question.options[entry.key].isCorrect;
                return Transform.translate(
                  offset: Offset(shouldShake ? _shake.value : 0, 0),
                  child: child,
                );
              },
              child: _buildOptionCard(
                index: entry.key,
                option: entry.value,
              ),
            ),
          ),
        ),
        if (_selectedIndex != null) ...[
          const SizedBox(height: 16),
          _buildFeedback(),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: _questionIndex == _questions.length - 1
              ? 'See Results'
              : 'Next Question',
          onTap: _selectedIndex == null ? null : _nextQuestion,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required int index,
    required AnswerOption option,
  }) {
    final isSelected = _selectedIndex == index;
    final isAnswered = _selectedIndex != null;
    final isCorrectAnswer = isAnswered && option.isCorrect;
    final color = isSelected
        ? (option.isCorrect ? const Color(0xFFE9F8EF) : const Color(0xFFFFEEEE))
        : isCorrectAnswer
            ? const Color(0xFFE9F8EF)
            : Colors.white;
    final borderColor = isSelected
        ? (option.isCorrect ? const Color(0xFF22A05A) : const Color(0xFFE34D59))
        : isCorrectAnswer
            ? const Color(0xFF22A05A)
            : const Color(0xFFEAEAEA);
    final label = String.fromCharCode(65 + index);

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isAnswered,
      label: option.text,
      child: GestureDetector(
        onTap: isAnswered ? null : () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: borderColor,
              width: isSelected || isCorrectAnswer ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (option.isCorrect
                                  ? const Color(0xFFBDEBCF)
                                  : const Color(0xFFFFC7CC))
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.figtree(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        option.text,
                        style: GoogleFonts.figtree(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildRadioIndicator(index: index, isSelected: isSelected),
              if (isAnswered && (isSelected || isCorrectAnswer)) ...[
                const SizedBox(width: 8),
                Icon(
                  option.isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: option.isCorrect
                      ? const Color(0xFF22A05A)
                      : const Color(0xFFE34D59),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioIndicator({required int index, required bool isSelected}) {
    final indicator = Container(
      height: 18,
      width: 18,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD233) : Colors.white,
        border: isSelected
            ? null
            : Border.all(color: const Color(0xFFEAEAEA), width: 1.5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: isSelected
          ? const SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
    return isSelected
        ? FadeTransition(
            opacity: _indicatorFade,
            child: ScaleTransition(scale: _indicatorScale, child: indicator),
          )
        : indicator;
  }

  Widget _buildFeedback() {
    final selected = _question.options[_selectedIndex!];
    final isCorrect = selected.isCorrect;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFE9F8EF) : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.info,
            color: isCorrect
                ? const Color(0xFF22A05A)
                : const Color(0xFFE34D59),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCorrect
                  ? (selected.explanation ?? 'Correct answer!')
                  : 'Not quite. Try the next question.',
              style: GoogleFonts.figtree(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFEAEAEA) : const Color(0xFFFFD233),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: onTap == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: onTap == null
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionContent() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.emoji_events, size: 72, color: Color(0xFFFFD233)),
        const SizedBox(height: 20),
        Text(
          'Quiz complete!',
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You scored $_score out of ${_questions.length}',
          style: GoogleFonts.figtree(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label: 'Back to Shorts',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
