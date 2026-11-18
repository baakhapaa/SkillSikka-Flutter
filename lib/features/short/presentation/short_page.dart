import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/network/api_error.dart';
import '../../../core/video/video_playback.dart';
import '../../courses/data/course_api.dart';
import '../../courses/presentation/course_details_page.dart';
import '../data/short.dart';
import '../data/shorts_api.dart';

enum ShortFeedTab { stem, forYou, challenge }

class ShortPage extends StatelessWidget {
  const ShortPage({super.key, this.active = true});

  /// False while another bottom tab is showing. The feed stays mounted, so
  /// this is what stops the clip from playing under Home or Profile.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ShortFeedPage(active: active);
  }
}

class ShortFeedPage extends ConsumerStatefulWidget {
  const ShortFeedPage({
    super.key,
    this.initialTab = ShortFeedTab.stem,
    this.active = true,
  });

  final ShortFeedTab initialTab;
  final bool active;

  @override
  ConsumerState<ShortFeedPage> createState() => _ShortFeedPageState();
}

class _ShortFeedPageState extends ConsumerState<ShortFeedPage>
    with SingleTickerProviderStateMixin {
  static const brandYellow = Color(0xFFFFD233);

  late ShortFeedTab _selectedTab = widget.initialTab;
  List<ShortVideoData> _items = const [];
  var _index = 0;
  var _loading = true;
  String? _error;
  String? _search;
  final _seen = <int>{};
  CancelToken? _loadToken;
  PageController? _pageController;
  late final AnimationController _doubleTapLikeController;
  late final Animation<double> _doubleTapLikeScale;
  Offset? _doubleTapPosition;
  bool _showDoubleTapLike = false;

  @override
  void initState() {
    super.initState();
    _doubleTapLikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _doubleTapLikeScale = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(
        parent: _doubleTapLikeController,
        curve: Curves.easeOutBack,
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _loadToken?.cancel();
    _pageController?.dispose();
    _doubleTapLikeController.dispose();
    super.dispose();
  }

  ShortVideoData? get _videoData =>
      _items.isEmpty ? null : _items[_index.clamp(0, _items.length - 1)];

  String get _feedQuery => switch (_selectedTab) {
    ShortFeedTab.forYou => 'for_you',
    ShortFeedTab.challenge => 'challenge',
    ShortFeedTab.stem => 'stem',
  };

  Future<void> _load() async {
    if (runningWidgetTests) {
      setState(() => _loading = false);
      return;
    }
    _loadToken?.cancel();
    final token = CancelToken();
    _loadToken = token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(shortsApiProvider)
          .list(feed: _feedQuery, search: _search, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      _pageController?.dispose();
      _pageController = PageController();
      setState(() {
        _items = items;
        _index = 0;
        _loading = false;
      });
      _recordView();
    } on ApiException catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _loading = false;
        _error = error.displayMessage;
        _items = const [];
      });
      _pageController?.dispose();
      _pageController = null;
    }
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _recordView();
  }

  void _recordView() {
    final id = _videoData?.id;
    if (id == null || !_seen.add(id)) return;
    ref.read(shortsApiProvider).recordView(id);
  }

  int _indexOf(ShortVideoData data) {
    final id = data.id;
    if (id == null) return -1;
    return _items.indexWhere((item) => item.id == id);
  }

  void _selectTab(ShortFeedTab tab) {
    if (tab == _selectedTab) return;
    setState(() => _selectedTab = tab);
    _load();
  }

  Future<void> _toggleLike([ShortVideoData? target]) async {
    final data = target ?? _videoData;
    if (data == null) return;
    final index = _indexOf(data);
    if (index < 0) return;
    final current = _items[index];
    final id = current.id;
    final next = !current.isLiked;
    final nextCount = current.likeCount + (next ? 1 : -1);
    final optimistic = nextCount < 0 ? 0 : nextCount;
    setState(() {
      _items[index] = current.copyWith(isLiked: next, likeCount: optimistic);
    });
    if (id == null) return;
    try {
      final result = await ref.read(shortsApiProvider).toggleLike(id);
      if (!mounted || index >= _items.length || _items[index].id != id) {
        return;
      }
      setState(() {
        _items[index] = _items[index].copyWith(
          isLiked: result.isLiked,
          likeCount: result.likeCount,
        );
      });
    } on ApiException {
      if (!mounted || index >= _items.length || _items[index].id != id) {
        return;
      }
      setState(() => _items[index] = current);
    }
  }

  Future<void> _toggleSave([ShortVideoData? target]) async {
    final data = target ?? _videoData;
    if (data == null) return;
    final index = _indexOf(data);
    if (index < 0) return;
    final current = _items[index];
    final id = current.id;
    if (id == null) {
      await _openSaveSheet();
      return;
    }
    final next = !current.isSaved;
    setState(() {
      _items[index] = current.copyWith(isSaved: next);
    });
    try {
      final api = ref.read(shortsApiProvider);
      if (next) {
        await api.save(id);
      } else {
        await api.unsave(id);
      }
    } on ApiException {
      if (!mounted || index >= _items.length || _items[index].id != id) {
        return;
      }
      setState(() => _items[index] = current);
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    if (_videoData?.isLiked != true) _toggleLike();
    setState(() => _showDoubleTapLike = true);
    _doubleTapLikeController.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 720), () {
      if (!mounted) return;
      setState(() => _showDoubleTapLike = false);
    });
  }

  Future<void> _openCourse(int courseId) async {
    try {
      final detail = await ref.read(courseApiProvider).detail(courseId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseDetailPage(course: detail)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _search ?? '');
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search shorts'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Title, caption, or name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !mounted) return;
    setState(() => _search = query.trim().isEmpty ? null : query.trim());
    await _load();
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
      final data = _videoData;
      if (data != null) {
        final index = _indexOf(data);
        if (index >= 0) {
          setState(() {
            _items[index] = _items[index].copyWith(isSaved: true);
          });
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $selectedCollection'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onCommentAdded() {
    final data = _videoData;
    if (data == null) return;
    final index = _indexOf(data);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(
        commentCount: _items[index].commentCount + 1,
      );
    });
  }

  Future<void> _openShareSheet() async {
    final video = _videoData;
    if (video == null) return;
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
                child: ShareSheet(video: video),
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
    final video = _videoData;
    if (video == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          CommentsSheet(video: video, onCommentAdded: _onCommentAdded),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(
              child: Text(
                'Loading shorts…',
                style: TextStyle(color: Colors.white),
              ),
            )
          else if (_items.isEmpty || _pageController == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error ?? 'No shorts in this feed yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _buildPage(index),
            ),
          _buildTopNavigation(),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final data = _items[index];
    final current = index == _index;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        _ShortStage(
          key: ValueKey('${data.id}-${data.videoUrl}'),
          videoUrl: data.videoUrl.isNotEmpty ? data.videoUrl : data.shareUrl,
          poster: data.image,
          posterFit: data.fit,
          active: widget.active && current,
          warm: (index - _index).abs() <= 1,
          onDoubleTapDown: current ? _handleDoubleTapDown : null,
          onDoubleTap: current ? _handleDoubleTap : null,
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
          ),
        ),
        if (current && _showDoubleTapLike && _doubleTapPosition != null)
          Positioned(
            left: _doubleTapPosition!.dx - 42,
            top: _doubleTapPosition!.dy - 42,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showDoubleTapLike ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: ScaleTransition(
                  scale: _doubleTapLikeScale,
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFF70303),
                    size: 84,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 10,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildCreatorDetails(data: data)),
              const SizedBox(width: 8),
              _buildActionRail(data),
            ],
          ),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(
            children: [
              _TopNavItem(
                label: 'STEM',
                isSelected: _selectedTab == ShortFeedTab.stem,
                onTap: () => _selectTab(ShortFeedTab.stem),
              ),
              _TopNavItem(
                label: 'For you',
                isSelected: _selectedTab == ShortFeedTab.forYou,
                onTap: () => _selectTab(ShortFeedTab.forYou),
              ),
              _TopNavItem(
                label: 'Challenge',
                isSelected: _selectedTab == ShortFeedTab.challenge,
                onTap: () => _selectTab(ShortFeedTab.challenge),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openSearch,
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
            IgnorePointer(
              child: ClipOval(
                child: _shortImage(
                  data.avatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.creator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (data.role.isNotEmpty)
                      Text(
                        data.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: brandYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          child: Text(
            data.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Figtree',
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (data.course.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: data.courseId == null
                ? null
                : () => _openCourse(data.courseId!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: brandYellow, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/book-open.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      data.course,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRail(ShortVideoData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.quizId != null)
          _ActionItem(
            icon: Icons.question_mark_rounded,
            label: 'Quiz',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data.quizTitle ?? 'Quiz'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        if (data.quizId != null) const SizedBox(height: 16),
        _ActionItem(
          icon: data.isLiked ? Icons.favorite : Icons.favorite_border,
          label: _countLabel(data.likeCount),
          isActive: data.isLiked,
          activeColor: const Color(0xFFF70303),
          onTap: () => _toggleLike(data),
        ),
        const SizedBox(height: 16),
        _ActionItem(
          icon: Icons.chat_bubble_outline,
          label: _countLabel(data.commentCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 16),
        _ActionItem(
          icon: data.isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: data.isSaved ? 'Saved' : 'Save',
          isActive: data.isSaved,
          activeColor: brandYellow,
          onTap: () => _toggleSave(data),
        ),
        const SizedBox(height: 16),
        _ActionItem(icon: Icons.share, label: 'Share', onTap: _openShareSheet),
      ],
    );
  }
}

Widget _shortImage(
  String source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final url = _mediaUrl(source);
  if (url.startsWith('http')) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => ColoredBox(
        color: const Color(0xFF1F2937),
        child: SizedBox(width: width, height: height),
      ),
    );
  }
  if (url.startsWith('assets/')) {
    return Image.asset(url, width: width, height: height, fit: fit);
  }
  return ColoredBox(
    color: const Color(0xFF1F2937),
    child: SizedBox(width: width, height: height),
  );
}

/// A stored photo is often `profile-photos/...`, not an app asset and not a
/// full URL. Point it at the API host's media folder.
String _mediaUrl(String source) {
  final value = source.trim();
  if (value.isEmpty ||
      value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('assets/')) {
    return value;
  }
  final base = AppConfig.fromDefines().apiBaseUrl;
  final origin = base.replaceFirst(RegExp(r'/api/v1/?$'), '');
  final path = value.startsWith('/') ? value : '/media/$value';
  return '$origin$path';
}

/// 1,428 stays grouped. 24,500 becomes 24.5K, matching the shorts rail.
String _countLabel(int value) {
  final safe = value < 0 ? 0 : value;
  if (safe >= 1000000) {
    final scaled = safe / 1000000;
    final digits = scaled >= 10 ? 0 : 1;
    return '${scaled.toStringAsFixed(digits)}M'.replaceAll('.0M', 'M');
  }
  if (safe >= 10000) {
    final scaled = safe / 1000;
    final digits = scaled >= 100 ? 0 : 1;
    return '${scaled.toStringAsFixed(digits)}K'.replaceAll('.0K', 'K');
  }
  final digits = safe.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Plays [videoUrl] full-bleed. The poster stays up until the first frame is
/// ready. Widget tests never build a controller: `video_player` has no
/// platform implementation there and a live one keeps a frame scheduled.
class _ShortStage extends StatefulWidget {
  const _ShortStage({
    super.key,
    required this.videoUrl,
    required this.poster,
    required this.posterFit,
    required this.active,
    this.warm = false,
    this.onDoubleTapDown,
    this.onDoubleTap,
  });

  final String videoUrl;
  final String poster;
  final BoxFit posterFit;

  /// This page is the one on screen, so the clip should be playing.
  final bool active;

  /// A neighbour page. Load it so the next swipe starts immediately.
  final bool warm;
  final GestureTapDownCallback? onDoubleTapDown;
  final GestureTapCallback? onDoubleTap;

  @override
  State<_ShortStage> createState() => _ShortStageState();
}

class _ShortStageState extends State<_ShortStage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final _progress = ValueNotifier<double>(0);
  var _generation = 0;
  var _ready = false;
  var _failed = false;
  var _pausedByUser = false;
  var _backgrounded = false;
  var _routeCurrent = true;

  bool get _shouldLoad => widget.active || widget.warm;

  bool get _shouldPlay =>
      widget.active && _routeCurrent && !_pausedByUser && !_backgrounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_shouldLoad) _open();
  }

  @override
  void didUpdateWidget(_ShortStage old) {
    super.didUpdateWidget(old);
    final shouldLoad = widget.active || widget.warm;
    if (old.videoUrl != widget.videoUrl) {
      _pausedByUser = false;
      _failed = false;
      _progress.value = 0;
      if (shouldLoad) {
        _open();
      } else {
        _release();
      }
      return;
    }
    if (shouldLoad && _controller == null && !_failed) {
      _open();
      return;
    }
    if (!shouldLoad) {
      _release();
      return;
    }
    _applyPlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current == _routeCurrent) return;
    _routeCurrent = current;
    _applyPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _backgrounded = true;
      _controller?.pause();
      return;
    }
    _backgrounded = false;
    _applyPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _release();
    _progress.dispose();
    super.dispose();
  }

  void _release() {
    final previous = _controller;
    _controller = null;
    _ready = false;
    previous?.removeListener(_onTick);
    previous?.dispose();
  }

  void _open() {
    final generation = ++_generation;
    _release();
    final url = _mediaUrl(widget.videoUrl);
    if (!videoPlaybackSupported || !url.startsWith('http')) return;
    final player = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = player;
    player.initialize().then(
      (_) {
        if (!mounted || generation != _generation || _controller != player) {
          if (_controller == player) {
            _controller = null;
            player.dispose();
          }
          return;
        }
        player
          ..setLooping(true)
          ..setVolume(1)
          ..addListener(_onTick);
        setState(() {
          _ready = true;
          _failed = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _controller != player) return;
          _applyPlay();
        });
      },
      onError: (Object error) {
        debugPrint('short video failed: $error');
        if (_controller == player) {
          _controller = null;
          player.dispose();
        }
        if (!mounted || generation != _generation) return;
        setState(() => _failed = true);
      },
    );
  }

  void _applyPlay() {
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    if (_shouldPlay) {
      if (!player.value.isPlaying) player.play();
    } else if (player.value.isPlaying) {
      player.pause();
    }
  }

  void _onTick() {
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    if (player.value.hasError) {
      debugPrint('short video: ${player.value.errorDescription}');
      _generation++;
      _release();
      if (mounted) setState(() => _failed = true);
      return;
    }
    final duration = player.value.duration.inMilliseconds;
    if (duration <= 0) return;
    final next = (player.value.position.inMilliseconds / duration).clamp(
      0.0,
      1.0,
    );
    if ((next - _progress.value).abs() < 0.008) return;
    _progress.value = next;
  }

  void _seek(double fraction) {
    final next = fraction.clamp(0.0, 1.0);
    _progress.value = next;
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    final ms = (player.value.duration.inMilliseconds * next).round();
    player.seekTo(Duration(milliseconds: ms));
  }

  void _togglePause() {
    if (_failed || (_controller == null && !_ready)) {
      setState(() => _failed = false);
      _open();
      return;
    }
    if (!_ready) return;
    setState(() => _pausedByUser = !_pausedByUser);
    _applyPlay();
  }

  @override
  Widget build(BuildContext context) {
    final player = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePause,
          onDoubleTapDown: widget.onDoubleTapDown,
          onDoubleTap: widget.onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_ready) _shortImage(widget.poster, fit: widget.posterFit),
              if (_ready && player != null)
                Positioned.fill(child: _cover(player)),
              if (_pausedByUser || _failed)
                Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(0, 0, 0, 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(
                        _failed
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) =>
                    _seek(details.localPosition.dx / constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _seek(details.localPosition.dx / constraints.maxWidth),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, progress, _) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              color: Color.fromRGBO(255, 255, 255, 0.35),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              alignment: Alignment.centerLeft,
                              child: const ColoredBox(color: Color(0xFFFFD233)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cover(VideoPlayerController player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = player.value.size;
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (size.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
          return VideoPlayer(player);
        }
        final widthScale = maxWidth / size.width;
        final heightScale = maxHeight / size.height;
        final scale = widthScale > heightScale ? widthScale : heightScale;
        final width = size.width * scale;
        final height = size.height * scale;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(player),
            ),
          ),
        );
      },
    );
  }
}

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({required this.video, this.onCommentAdded, super.key});

  final ShortVideoData video;
  final VoidCallback? onCommentAdded;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  String? _replyingTo;
  int? _replyParentId;
  final List<_CommentThread> _threads = [];
  var _loadingComments = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  int get _commentTotal =>
      _threads.fold<int>(0, (sum, thread) => sum + 1 + thread.replies.length);

  Future<void> _loadComments() async {
    final id = widget.video.id;
    if (id == null) return;
    setState(() => _loadingComments = true);
    try {
      final api = ref.read(shortsApiProvider);
      final top = await api.comments(id);
      final threads = <_CommentThread>[];
      for (final comment in top) {
        final replies = comment.replyCount > 0
            ? await api.replies(comment.id)
            : const <ShortComment>[];
        threads.add(
          _CommentThread(_fromComment(comment), [
            for (final reply in replies) _fromComment(reply),
          ]),
        );
      }
      if (!mounted) return;
      setState(() {
        _threads
          ..clear()
          ..addAll(threads);
        _loadingComments = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  _CommentData _fromComment(ShortComment comment) {
    return _CommentData(
      id: comment.id,
      parentId: comment.parentId,
      user: comment.author,
      text: comment.text,
      time: _commentAge(comment.createdAt),
      isCreator: comment.isCreator,
      isLiked: comment.isLiked,
      likeCount: comment.likeCount,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final shortId = widget.video.id;
    if (shortId == null) return;
    try {
      await ref
          .read(shortsApiProvider)
          .postComment(shortId, text: text, parentId: _replyParentId);
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _replyingTo = null;
        _replyParentId = null;
      });
      widget.onCommentAdded?.call();
      await _loadComments();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  /// A reply always joins the top comment's thread. Replying to a reply
  /// names that person, and the new row stays under the same comment.
  void _replyTo(_CommentData root, {String? mention}) {
    setState(() {
      _replyingTo = mention ?? root.user;
      _replyParentId = root.id;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyParentId = null;
    });
  }

  Future<void> _toggleCommentLike(_CommentData comment) async {
    final id = comment.id;
    if (id == null) return;
    final liked = comment.isLiked;
    final count = comment.likeCount;
    _setLike(id, !liked, count + (liked ? -1 : 1));
    try {
      final result = await ref.read(shortsApiProvider).toggleCommentLike(id);
      if (!mounted) return;
      _setLike(id, result.isLiked, result.likeCount);
    } on ApiException {
      if (!mounted) return;
      _setLike(id, liked, count);
    }
  }

  void _setLike(int id, bool liked, int count) {
    setState(() {
      for (final thread in _threads) {
        if (thread.comment.id == id) {
          thread.comment = thread.comment.copyWith(
            isLiked: liked,
            likeCount: count,
          );
          return;
        }
        final index = thread.replies.indexWhere((reply) => reply.id == id);
        if (index >= 0) {
          thread.replies[index] = thread.replies[index].copyWith(
            isLiked: liked,
            likeCount: count,
          );
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomInset = rawBottomInset < 0 ? 0.0 : rawBottomInset;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    'Comments ($_commentTotal)',
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
              Expanded(child: _buildList()),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.only(top: 8, bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to $_replyingTo',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontFamily: 'Figtree',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelReply,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipOval(
                          child: _shortImage(
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
                            focusNode: _commentFocusNode,
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
                                  : 'Reply to $_replyingTo...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                              ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loadingComments && _threads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD233)),
      );
    }
    if (_threads.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTile(
              comment: thread.comment,
              onReply: () => _replyTo(thread.comment),
              onLike: () => _toggleCommentLike(thread.comment),
            ),
            for (final reply in thread.replies)
              _CommentTile(
                comment: reply,
                isReply: true,
                onReply: () => _replyTo(thread.comment, mention: reply.user),
                onLike: () => _toggleCommentLike(reply),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          const Text(
            'No comments yet',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Be the first to share your thoughts.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CommentThread {
  _CommentThread(this.comment, List<_CommentData> replies)
    : replies = List.of(replies);

  _CommentData comment;
  final List<_CommentData> replies;
}

class _CommentData {
  const _CommentData({
    this.id,
    this.parentId,
    required this.user,
    required this.text,
    required this.time,
    this.isCreator = false,
    this.isLiked = false,
    this.likeCount = 0,
  });

  final int? id;
  final int? parentId;
  final String user;
  final String text;
  final String time;
  final bool isCreator;
  final bool isLiked;
  final int likeCount;

  _CommentData copyWith({bool? isLiked, int? likeCount}) {
    return _CommentData(
      id: id,
      parentId: parentId,
      user: user,
      text: text,
      time: time,
      isCreator: isCreator,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
    );
  }
}

String _commentAge(DateTime? when) {
  if (when == null) return 'now';
  final delta = DateTime.now().difference(when);
  if (delta.inMinutes < 1) return 'now';
  if (delta.inHours < 1) return '${delta.inMinutes}m';
  if (delta.inDays < 1) return '${delta.inHours}h';
  return '${delta.inDays}d';
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onLike,
    this.isReply = false,
  });

  final _CommentData comment;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final size = isReply ? 28.0 : 36.0;
    final initial = comment.user.trim().isEmpty
        ? '?'
        : comment.user.trim()[0].toUpperCase();
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 46 : 0, top: 12, right: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: const Color(0xFF374151),
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: isReply ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comment.user,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (comment.isCreator)
                        const TextSpan(
                          text: '  Creator',
                          style: TextStyle(
                            color: Color(0xFFFFD233),
                            fontFamily: 'Figtree',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(
                        text: '  ${comment.text}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      comment.time,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLike,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 36,
              child: Column(
                children: [
                  Icon(
                    comment.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: comment.isLiked
                        ? const Color(0xFFFF2D55)
                        : Colors.white,
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      _countLabel(comment.likeCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
                    child: _shortImage(
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
      ClipboardData(
        text: widget.video.shareUrl.startsWith('http')
            ? widget.video.shareUrl
            : 'https://${widget.video.shareUrl}',
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Figtree',
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.62),
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 3,
              width: isSelected ? 36 : 0,
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
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? (activeColor ?? Colors.white) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromRGBO(255, 255, 255, 0.18),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.45),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Figtree',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
            ),
          ),
        ],
      ),
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

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
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
  late final Timer _countdownTimer;
  int _remainingSeconds = 165;

  QuizQuestion get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
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
    _questionSlide =
        Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _questionController,
            curve: Curves.easeOutCubic,
          ),
        );
    _indicatorScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeOutBack),
    );
    _indicatorFade = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOut,
    );
    _shake = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    _questionController.forward();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _indicatorController.dispose();
    _shakeController.dispose();
    _countdownTimer.cancel();
    super.dispose();
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
                final shouldShake =
                    _selectedIndex == entry.key &&
                    !_question.options[entry.key].isCorrect;
                return Transform.translate(
                  offset: Offset(shouldShake ? _shake.value : 0, 0),
                  child: child,
                );
              },
              child: _buildOptionCard(index: entry.key, option: entry.value),
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

  Widget _buildOptionCard({required int index, required AnswerOption option}) {
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
          color: onTap == null
              ? const Color(0xFFEAEAEA)
              : const Color(0xFFFFD233),
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
