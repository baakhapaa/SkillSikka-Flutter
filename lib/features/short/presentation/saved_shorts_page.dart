import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../core/video/video_playback.dart';
import '../data/short.dart';
import '../data/shorts_api.dart';
import 'short_page.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);

/// Every short this account has saved, in the same two-column grid as the
/// profile shelf. Tapping a card opens that clip.
class SavedShortsPage extends ConsumerStatefulWidget {
  const SavedShortsPage({super.key});

  @override
  ConsumerState<SavedShortsPage> createState() => _SavedShortsPageState();
}

class _SavedShortsPageState extends ConsumerState<SavedShortsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(savedShortsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shorts = ref.watch(savedShortsProvider).shorts;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F6),
        foregroundColor: _ink,
        elevation: 0,
        title: Text(
          'Saved Shorts',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: shorts.isEmpty
          ? Center(
              child: Text(
                'No saved shorts yet.',
                style: GoogleFonts.figtree(fontSize: 14, color: _gray),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (var i = 0; i < shorts.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _tile(context, shorts, i)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: i + 1 < shorts.length
                            ? _tile(context, shorts, i + 1)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, List<ShortVideoData> shorts, int index) {
    return SavedShortCard(
      short: shorts[index],
      onTap: () async {
        await openSavedShort(context, shorts, index);
        if (mounted) ref.read(savedShortsProvider.notifier).refresh();
      },
    );
  }
}

Future<void> openSavedShort(
  BuildContext context,
  List<ShortVideoData> shorts,
  int index,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ShortFeedPage(playlist: shorts, initialIndex: index),
    ),
  );
}

/// One saved-short tile: thumbnail, length, title, and when it was saved.
class SavedShortCard extends StatelessWidget {
  const SavedShortCard({super.key, required this.short, required this.onTap});

  final ShortVideoData short;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = short.shareTitle.trim().isEmpty
        ? short.description
        : short.shareTitle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumb(short.image),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _LengthBadge(videoUrl: short.videoUrl),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    savedAgoLabel(short.savedAt),
                    style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Saved • 2h ago", matching the profile design. No time means just "Saved".
String savedAgoLabel(DateTime? when) {
  if (when == null) return 'Saved';
  final delta = DateTime.now().difference(when.toLocal());
  if (delta.isNegative || delta.inMinutes < 1) return 'Saved • just now';
  if (delta.inHours < 1) return 'Saved • ${delta.inMinutes}m ago';
  if (delta.inDays < 1) return 'Saved • ${delta.inHours}h ago';
  if (delta.inDays < 7) return 'Saved • ${delta.inDays}d ago';
  final weeks = delta.inDays ~/ 7;
  return 'Saved • ${weeks}w ago';
}

String shortLengthLabel(Duration duration) {
  final total = duration.inSeconds;
  if (total <= 0) return '';
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  return '$minutes:$seconds';
}

class _LengthBadge extends StatefulWidget {
  const _LengthBadge({required this.videoUrl});

  final String videoUrl;

  @override
  State<_LengthBadge> createState() => _LengthBadgeState();
}

class _LengthBadgeState extends State<_LengthBadge> {
  static final _known = <String, Duration>{};

  VideoPlayerController? _controller;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    final cached = _known[widget.videoUrl];
    if (cached != null) {
      _duration = cached;
      return;
    }
    final url = widget.videoUrl;
    if (!videoPlaybackSupported || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) {
            controller.dispose();
            return;
          }
          final length = controller.value.duration;
          _known[url] = length;
          setState(() => _duration = length);
          controller.dispose();
          if (identical(_controller, controller)) _controller = null;
        })
        .catchError((Object _) {
          controller.dispose();
          if (identical(_controller, controller)) _controller = null;
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = shortLengthLabel(_duration ?? Duration.zero);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.figtree(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

Widget _thumb(String image) {
  final broken = Container(
    color: const Color(0xFFE5E7EB),
    child: const Icon(
      Icons.video_library_outlined,
      color: Colors.white,
      size: 40,
    ),
  );
  if (image.startsWith('http') && !_looksLikeVideo(image)) {
    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => broken,
    );
  }
  if (image.startsWith('assets/')) {
    return Image.asset(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => broken,
    );
  }
  return broken;
}

bool _looksLikeVideo(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.webm') ||
      path.endsWith('.m3u8');
}
