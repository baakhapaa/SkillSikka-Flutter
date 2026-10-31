import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../../core/widgets/course_image.dart';
import '../../../core/widgets/video_transport_controls.dart';
import '../../courses/data/course_api.dart';
import '../../courses/data/course_discussions_api.dart';
import '../../learning/data/learning_api.dart';
import '../data/bootcamp.dart';
import '../data/bootcamp_api.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _softGray = Color(0xFF737D8C);

/// The ICT & AI Bootcamp screen — the design, fed by `GET /courses/{id}/`.
///
/// **A bootcamp is created by an administrator in the Django dashboard**, never
/// in the app: the builder has no bootcamp type and the API answers
/// `403 ADMIN_ONLY` to an instructor. This screen only reads it.
///
/// **It enrols the viewer before it loads.** A bootcamp is free, and the server
/// withholds `content_url` from a student without an active enrolment — so
/// without this the curriculum would render fully locked for someone who just
/// tapped the card. A paid camp is left alone (`enroll` parks it in
/// `pending_payment`) and the page degrades to a read-only curriculum.
class IctBootcampPage extends ConsumerStatefulWidget {
  const IctBootcampPage({super.key, required this.courseId});

  /// `Course.id` — the card that opened this screen already has it.
  final int courseId;

  @override
  ConsumerState<IctBootcampPage> createState() => _IctBootcampPageState();
}

class _IctBootcampPageState extends ConsumerState<IctBootcampPage> {
  int _selectedDay = 1;
  int _selectedTab = 0;
  bool _autoPlay = true;
  bool _autoNext = true;
  bool _descriptionExpanded = false;
  bool _showAllDiscussions = false;
  bool _showEmojiPicker = false;

  bool _loading = true;
  String? _error;
  BootcampDetail? _detail;

  List<CourseThread> _threads = const [];
  int _threadCount = 0;
  bool _threadsLoading = false;
  bool _threadsLoaded = false;
  String? _threadsError;

  /// The lesson whose video is on the hero, or null for the camp's own trailer.
  int? _activeLessonId;

  /// Lessons finished in this session. The server's `is_completed` is the
  /// starting state; this is what the player adds to it, so a tick appears the
  /// moment a video ends rather than after the next fetch.
  final Set<int> _completed = <int>{};

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  final TextEditingController _commentController = TextEditingController();
  final Set<int> _expandedReplies = <int>{};
  final Map<int, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _videoController?.dispose();
    super.dispose();
  }

  // ── loading ───────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _ensureEnrolled();
      final detail = await ref
          .read(bootcampApiProvider)
          .detail(widget.courseId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _selectedDay = detail.days.isEmpty ? 1 : detail.days.first.number;
        _loading = false;
      });
      // Deliberately no `_syncVideo()` here: the camp opens on its poster and
      // waits for a tap. The hero builds the controller on demand.
      _resumeFrom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message ?? 'This bootcamp could not be loaded.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This bootcamp could not be loaded.';
      });
    }
  }

  /// Joins the camp so the lessons and files open.
  ///
  /// A failure is **not** fatal: the screen still renders the curriculum and
  /// the Q&A thread (reading a published course's discussions needs no
  /// enrolment), just with the lesson bodies withheld by the server.
  Future<void> _ensureEnrolled() async {
    final api = ref.read(courseApiProvider);
    try {
      final existing = await api.enrollmentFor(widget.courseId);
      if (existing != null) return;
      await api.enroll(widget.courseId);
    } on ApiException catch (error) {
      // A double tap can race the first request; that is not a failure.
      if (error.code == 'ALREADY_ENROLLED') return;
      debugPrint(
        'bootcamp: enrolment skipped — ${error.code} ${error.message}',
      );
    }
  }

  /// Points the player at the lesson the student stopped on — selected, not
  /// playing.
  ///
  /// The course player opens on `/my-learning/`'s `next_lesson`; this is the
  /// same idea, without starting a video nobody asked for. It is best effort: a
  /// camp that is not enrolled yet, or a failed read, simply opens on the poster.
  Future<void> _resumeFrom() async {
    final lessons = _flatLessons;
    if (lessons.isEmpty) return;
    try {
      final id = await ref
          .read(courseApiProvider)
          .nextLessonId(widget.courseId);
      if (!mounted || id == null) return;
      for (final lesson in lessons) {
        if (lesson.id != id || !lesson.isPlayable) continue;
        // The viewer may have picked something while this was in flight.
        if (_activeLessonId != null) return;
        setState(() {
          _activeLessonId = lesson.id;
          _selectedDay = lesson.dayNumber;
        });
        return;
      }
    } on ApiException {
      // Not enrolled, or the read failed: the poster is a fine place to start.
    }
  }

  Future<void> _loadThreads() async {
    if (_threadsLoading) return;
    setState(() {
      _threadsLoading = true;
      _threadsError = null;
    });
    try {
      final page = await ref
          .read(courseDiscussionsApiProvider)
          .list(widget.courseId);
      if (!mounted) return;
      setState(() {
        _threads = page.threads;
        _threadCount = page.count;
        _threadsLoading = false;
        _threadsLoaded = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _threadsLoading = false;
        _threadsLoaded = true;
        _threadsError = error.message ?? 'The discussion could not be loaded.';
      });
    }
  }

  // ── video ─────────────────────────────────────────────────────────────────

  /// The camp's trailer, or the video of the lesson the viewer tapped.
  ///
  /// **No controller when there is no URL** — that is what keeps `video_player`
  /// (no platform implementation under `flutter test`) off the path of every
  /// test that mounts this screen.
  /// What the hero would play right now: the selected lesson's video, or the
  /// camp's own trailer when nothing is selected.
  String get _sourceUrl {
    final detail = _detail;
    if (detail == null) return '';
    final lesson = _activeLesson;
    if (lesson != null && lesson.kind == CourseLessonKind.video) {
      final url = (lesson.contentUrl ?? '').trim();
      if (url.isNotEmpty) return url;
    }
    return detail.heroVideoUrl.trim();
  }

  /// Builds the controller for [_sourceUrl]. **Plays only when asked.**
  ///
  /// The screen used to call this on load and play immediately, so opening a
  /// camp started a video — and its audio — that nobody had asked for. It now
  /// opens on the poster and waits for a tap, the way the course player waits
  /// for a lesson.
  ///
  /// **No controller when there is no URL** — that is what keeps `video_player`
  /// (no platform implementation under `flutter test`) off the path of every
  /// test that mounts this screen.
  void _syncVideo({bool autoplay = false}) {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;

    final remote = _sourceUrl;
    if (remote.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(remote));
    _videoController = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _videoReady = true);
          if (autoplay) controller.play();
        })
        .catchError((Object error) {
          debugPrint('bootcamp: video failed to load: $error');
          if (!mounted) return;
          setState(() => _videoReady = false);
        });
    controller.addListener(_onVideoTick);
  }

  /// Starts whatever the hero is showing — from the top if it had finished.
  Future<void> _togglePlay() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      _syncVideo(autoplay: true);
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    final value = controller.value;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  /// Back to the camp's own poster — what `Prev` does from the first lesson.
  void _backToTrailer() {
    setState(() => _activeLessonId = null);
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
  }

  /// One tick listener does two jobs: mark a lesson finished when its video is,
  /// and follow it with `Auto Next`. The play/pause glyph is the transport
  /// bar's own business — it listens to the controller itself.
  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;

    final finished =
        value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying;
    if (!finished) return;

    final lesson = _activeLesson;
    if (lesson != null) _markComplete(lesson);
    if (!_autoNext) return;
    // Deferred: advancing disposes this controller from inside its own
    // listener, and the last lesson clamps back to itself — which would restart
    // the video and fire this again, forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _go(1);
    });
  }

  // ── curriculum ────────────────────────────────────────────────────────────

  List<BootcampLesson> get _flatLessons => [
    for (final day in _detail?.days ?? const <BootcampDay>[])
      for (final section in day.sections) ...section.lessons,
  ];

  BootcampLesson? get _activeLesson {
    final id = _activeLessonId;
    if (id == null) return null;
    for (final lesson in _flatLessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  BootcampDay? get _selectedDayData {
    for (final day in _detail?.days ?? const <BootcampDay>[]) {
      if (day.number == _selectedDay) return day;
    }
    return null;
  }

  void _openLesson(BootcampLesson lesson) {
    if (!lesson.isPlayable) {
      _snack('Enrol in this bootcamp to open this lesson.');
      return;
    }
    if (lesson.kind == CourseLessonKind.video) {
      _selectLesson(lesson);
      return;
    }
    if (lesson.kind.isInlineText) {
      _showTextLesson(lesson);
      return;
    }
    _openUrl(lesson.contentUrl!);
  }

  /// The flow: the hero becomes the lesson, the Day chip follows it, and the
  /// lesson being left is recorded as finished — the same rule the course
  /// player uses, where leaving a lecture is this product's playback-completed
  /// signal.
  void _selectLesson(BootcampLesson lesson) {
    final leaving = _activeLesson;
    setState(() {
      _activeLessonId = lesson.id;
      _selectedDay = lesson.dayNumber;
    });
    if (leaving != null && leaving.id != lesson.id) _markComplete(leaving);
    // After the id moves, so it picks up the new lesson's URL.
    _syncVideo(autoplay: _autoPlay);
  }

  /// Previous / next across the whole camp, not within the selected day.
  ///
  /// `Prev` from the first lesson goes back to the trailer and `Next` from the
  /// trailer starts the camp, so neither button is ever a dead tap.
  void _go(int delta) {
    final lessons = _flatLessons;
    if (lessons.isEmpty) return;
    final current = lessons.indexWhere(
      (lesson) => lesson.id == _activeLessonId,
    );

    if (current < 0) {
      if (delta > 0) _openLesson(lessons.first);
      return;
    }
    final next = current + delta;
    if (next < 0) {
      _backToTrailer();
      return;
    }
    if (next >= lessons.length) {
      // The end of the camp: the lesson stays, and its video has just ended.
      _markComplete(lessons[current]);
      return;
    }
    _openLesson(lessons[next]);
  }

  bool _isComplete(BootcampLesson lesson) =>
      lesson.isCompleted ||
      (lesson.id != null && _completed.contains(lesson.id));

  /// Ticked locally first, posted after — a failure is a snack, not a rollback.
  void _markComplete(BootcampLesson lesson) {
    final id = lesson.id;
    if (id == null || lesson.isCompleted || _completed.contains(id)) return;
    setState(() => _completed.add(id));
    _postCompletion(id);
  }

  Future<void> _postCompletion(int lessonId) async {
    try {
      await ref.read(courseApiProvider).completeLesson(lessonId);
      // My Learning is server-driven and cached: without this its percentage
      // and resume point stay at whatever they were when the tab loaded, so the
      // bootcamp would still read `2 of 20` after finishing a third lesson.
      ref.invalidate(myLearningProvider);
    } on ApiException catch (error) {
      _snack(error.message ?? 'That lesson could not be marked complete.');
    }
  }

  void _showTextLesson(BootcampLesson lesson) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lesson.title,
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            lesson.contentText ?? '',
            style: GoogleFonts.figtree(fontSize: 13, height: 1.5, color: _ink),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Q&A ───────────────────────────────────────────────────────────────────

  TextEditingController _replyController(int threadId) =>
      _replyControllers.putIfAbsent(threadId, () => TextEditingController());

  void _replaceThread(CourseThread updated) {
    _threads = [
      for (final thread in _threads)
        if (thread.id == updated.id) updated else thread,
    ];
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    try {
      final thread = await ref
          .read(courseDiscussionsApiProvider)
          .post(widget.courseId, body: text);
      if (!mounted) return;
      setState(() {
        _threads = [thread, ..._threads];
        _threadCount += 1;
        _commentController.clear();
        _showEmojiPicker = false;
        _showAllDiscussions = false;
      });
      FocusScope.of(context).unfocus();
    } on ApiException catch (error) {
      _snack(error.message ?? 'That comment could not be posted.');
    }
  }

  Future<void> _submitReply(CourseThread thread) async {
    final controller = _replyControllers[thread.id];
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    try {
      final reply = await ref
          .read(courseDiscussionsApiProvider)
          .post(widget.courseId, body: text, parentId: thread.id);
      if (!mounted) return;
      setState(() {
        controller?.clear();
        _replaceThread(
          thread.copyWith(
            replies: [...thread.replies, reply],
            repliesCount: thread.repliesCount + 1,
          ),
        );
      });
    } on ApiException catch (error) {
      _snack(error.message ?? 'That reply could not be posted.');
    }
  }

  /// Optimistic, then replaced by the server's authoritative count.
  Future<void> _toggleLike(CourseThread thread) async {
    final liked = !thread.isLiked;
    setState(() {
      _replaceThread(
        thread.copyWith(
          isLiked: liked,
          likesCount: (thread.likesCount + (liked ? 1 : -1)).clamp(0, 1 << 31),
        ),
      );
    });
    try {
      final result = await ref
          .read(courseDiscussionsApiProvider)
          .setLiked(widget.courseId, thread.id, liked: liked);
      if (!mounted) return;
      setState(() {
        _replaceThread(
          thread.copyWith(
            isLiked: result.isLiked,
            likesCount: result.likesCount,
          ),
        );
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _replaceThread(thread));
    }
  }

  // ── shell ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    final detail = _detail;
    if (detail == null) return _buildError();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(detail),
                  _buildVideoProgress(),
                  _buildNowPlaying(),
                  _buildPlayerControls(),
                  _buildCourseInfoSection(detail),
                  _buildCourseNavigationTabs(),
                  if (_selectedTab == 0) ...[
                    const SizedBox(height: 8),
                    _buildLessonsModuleContainer(),
                  ],
                  if (_selectedTab == 1) ...[
                    const SizedBox(height: 8),
                    _buildResourcesTab(detail),
                  ],
                  if (_selectedTab == 2) ...[
                    const SizedBox(height: 8),
                    _buildQaTab(detail),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 34, color: _gray),
              const SizedBox(height: 12),
              Text(
                _error ?? 'This bootcamp could not be loaded.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(fontSize: 13, color: _gray),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Try again')),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────────────────────────
  Widget _buildHero(BootcampDetail detail) {
    final controller = _videoController;
    final ready = _videoReady && controller != null;
    final poster = detail.heroPosterUrl.isNotEmpty
        ? detail.heroPosterUrl
        : detail.image;

    return Container(
      height: 222,
      color: const Color(0xFF1F1F1F),
      child: Stack(
        children: [
          Positioned.fill(
            child: ready
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : CourseImage(
                    poster,
                    fallback: Image.asset(
                      'assets/figma/bootcamp/course-poster.png',
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
          // Once there is a controller the transport bar owns play/pause, seek,
          // mute and fullscreen — the same widget the course player uses, so the
          // two players cannot drift apart. Before that, a plain play button
          // starts whatever the hero is showing.
          if (ready)
            VideoTransportControls(
              key: ValueKey(controller),
              controller: controller,
              title: _activeLesson?.title ?? detail.title,
              onFullscreen: () => _openFullscreen(controller),
            )
          else if (_sourceUrl.isNotEmpty)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Image.asset(
                  'assets/figma/bootcamp/play.png',
                  width: 52,
                  height: 52,
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The same fullscreen route the course player opens: landscape, immersive,
  /// and sharing this controller so playback continues across the push.
  Future<void> _openFullscreen(VideoPlayerController controller) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPage(
          controller: controller,
          title: _activeLesson?.title ?? _detail?.title ?? 'Bootcamp',
        ),
      ),
    );
    // The route restores orientation and system UI in its own `dispose`.
    if (mounted) setState(() {});
  }

  Widget _buildVideoProgress() {
    final controller = _videoController;
    return SizedBox(
      height: 6,
      child: _videoReady && controller != null
          ? VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: _yellow,
                bufferedColor: Color(0xFFD1D1D1),
                backgroundColor: Color(0xFFE5E7EB),
              ),
            )
          : const ColoredBox(color: Color(0xFFD1D1D1)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NOW PLAYING
  // ─────────────────────────────────────────────────────────────
  /// Which lesson the hero is showing, and which day it belongs to.
  ///
  /// The design has no such row, and without it the player had no way to say
  /// that a lesson had been picked — the video simply changed. It collapses to
  /// nothing while the camp's own trailer is on screen.
  Widget _buildNowPlaying() {
    final lesson = _activeLesson;
    if (lesson == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _buildMetaTag('DAY ${lesson.dayNumber}', highlighted: true),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          if (lesson.duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              lesson.duration,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _softGray,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PLAYER CONTROLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildPlayerControls() {
    final lessons = _flatLessons;
    final index = lessons.indexWhere((lesson) => lesson.id == _activeLessonId);
    // A selected lesson can always step back — to the lesson before it, or to
    // the trailer. `Next` is live from the trailer (it starts the camp) and
    // dead on the last lesson, which is the only real end of the list.
    final canGoBack = index >= 0;
    final canGoForward = lessons.isNotEmpty && index < lessons.length - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // `Flexible` + an ellipsised label: two toggles, two buttons and a
          // spacer leave ~86pt per toggle at 360, which is fine at 1.0× text
          // scale and not at 1.3×. Shrinking the label is better than painting
          // the yellow overflow stripe across the controls.
          Flexible(
            flex: 2,
            child: _buildToggle(
              label: 'Auto Play',
              value: _autoPlay,
              onChanged: (v) => setState(() => _autoPlay = v),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: _buildToggle(
              label: 'Auto Next',
              value: _autoNext,
              onChanged: (v) => setState(() => _autoNext = v),
            ),
          ),
          const Spacer(),
          _buildPlayerButton(
            label: 'Prev',
            onTap: canGoBack ? () => _go(-1) : null,
          ),
          const SizedBox(width: 12),
          _buildPlayerButton(
            label: 'Next',
            onTap: canGoForward ? () => _go(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            value
                ? 'assets/figma/bootcamp/greentick.png'
                : 'assets/figma/bootcamp/greytick.png',
            width: 13,
            height: 13,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    // Disabled is a greyed label, not a hidden one: the design keeps both
    // buttons in place, and a control that disappears reads as a layout jump.
    final color = onTap == null ? const Color(0xFFC3C8CE) : _gray;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            label == 'Prev'
                ? 'assets/figma/bootcamp/prev.png'
                : 'assets/figma/bootcamp/next.png',
            width: 14,
            height: 14,
            color: onTap == null ? const Color(0xFFC3C8CE) : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSE INFO
  // ─────────────────────────────────────────────────────────────
  Widget _buildCourseInfoSection(BootcampDetail detail) {
    final expandedBody = detail.description.isNotEmpty
        ? detail.description
        : detail.lede;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 130,
                  height: 178,
                  child: CourseImage(
                    detail.image,
                    fallback: Image.asset(
                      'assets/figma/bootcamp/course-poster.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.image, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(text: '${detail.runLabel}\n'),
                          TextSpan(
                            text: detail.title,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail.studentsLabel,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                    if (detail.qualityLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildMetaTag(detail.qualityLabel, highlighted: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _descriptionExpanded ? expandedBody : detail.lede,
            style: GoogleFonts.figtree(fontSize: 13, height: 1.5, color: _gray),
          ),
          if (_descriptionExpanded) ...[
            const SizedBox(height: 12),
            _buildMetaRow('Instructor:', detail.instructorLine),
            const SizedBox(height: 6),
            _buildMetaRow('Runs:', detail.dateRangeLabel),
            const SizedBox(height: 6),
            _buildMetaRow('Released:', detail.releasedLabel),
            const SizedBox(height: 6),
            _buildMetaRow(
              'Status:',
              detail.statusLabel,
              valueColor: detail.isLive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Text(
              _descriptionExpanded ? '[less]' : '[more]',
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x26F59E0B)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: highlighted ? const Color(0xFFF59E0B) : _ink,
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _softGray,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.figtree(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFFF59E0B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildCourseNavigationTabs() {
    const tabs = ['Lessons', 'Resources', 'Q&A'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTab = i);
                  // Lazy: a viewer who never opens the tab never pays for it.
                  if (i == 2 && !_threadsLoaded) _loadThreads();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedTab == i ? _yellow : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedTab == i ? _ink : _gray,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LESSONS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildLessonsModuleContainer() {
    final days = _detail?.days ?? const <BootcampDay>[];
    final day = _selectedDayData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (days.isNotEmpty)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = days[index];
                  final selected = tab.number == _selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = tab.number),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _yellow : const Color(0xFFEAEAEA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          tab.label,
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (days.isNotEmpty) const SizedBox(height: 12),
          if (day == null || day.lessonCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'The curriculum for this camp has not been published yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(fontSize: 12, color: _gray),
              ),
            ),
          if (day != null)
            for (final section in day.sections) ...[
              if (section.title.isNotEmpty)
                _buildChapterHeader(
                  section.title,
                  section.lessons.length,
                  'lessons',
                ),
              for (final lesson in section.lessons) _buildLessonRow(lesson),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Widget _buildChapterHeader(String title, int count, String countLabel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Text(
            '$count $countLabel',
            style: GoogleFonts.figtree(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF737D8C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonRow(BootcampLesson lesson) {
    final active = lesson.id != null && lesson.id == _activeLessonId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openLesson(lesson),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDBDBDB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (_isComplete(lesson))
              Image.asset(
                'assets/figma/bootcamp/greentick.png',
                width: 20,
                height: 20,
              )
            else
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: Text(
                    '${lesson.number}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                  if (lesson.duration.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lesson.duration,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667080),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              lesson.isPlayable
                  ? Icons.play_circle_outline
                  : Icons.lock_outline,
              size: 20,
              color: _ink,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RESOURCES TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildResourcesTab(BootcampDetail detail) {
    final sections = detail.fileSections;
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Text(
          'No files have been added to this camp yet.',
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(fontSize: 12, color: _gray),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections) ...[
            if (section.title.isNotEmpty)
              _buildChapterHeader(section.title, section.files.length, 'files'),
            const SizedBox(height: 10),
            for (final resource in section.files) ...[
              _buildResourceRow(resource),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildResourceRow(CourseResource resource) {
    final colors = _formatColors(resource.type);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openResource(resource),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                _formatIcon(resource.type),
                width: 20,
                height: 20,
                errorBuilder: (_, _, _) =>
                    Icon(resource.type.icon, size: 20, color: colors.badgeText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resource.type.label,
                      style: GoogleFonts.figtree(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: colors.badgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openResource(resource),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/figma/bootcamp/download.png',
                  width: 16,
                  height: 16,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.download_outlined,
                    size: 16,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Q&A TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildQaTab(BootcampDetail detail) {
    const visibleCount = 6;
    final threads = _showAllDiscussions
        ? _threads
        : _threads.take(visibleCount).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDiscussionHeader(detail),
          const SizedBox(height: 12),
          _buildInputComposer(),
          const SizedBox(height: 12),
          if (_threadsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_threadsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    _threadsError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(fontSize: 12, color: _gray),
                  ),
                  TextButton(
                    onPressed: _loadThreads,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No questions yet. Start the discussion.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(fontSize: 12, color: _gray),
              ),
            )
          else
            for (final thread in threads) ...[
              _buildCommentPost(thread),
              const SizedBox(height: 12),
            ],
          if (_threads.length > visibleCount)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _showAllDiscussions = !_showAllDiscussions),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _showAllDiscussions ? 'View less' : 'View more',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF171717),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDiscussionHeader(BootcampDetail detail) {
    return Row(
      children: [
        Text(
          'Discussions',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDDDCDB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_threadCount',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _gray,
            ),
          ),
        ),
        const Spacer(),
        if (detail.episodeNo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: _yellow,
            child: Text(
              'Episode ${detail.episodeNo}',
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: null,
                  minLines: 1,
                  style: GoogleFonts.figtree(fontSize: 13, color: _ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Add to the strategy discussion...',
                    hintStyle: GoogleFonts.figtree(fontSize: 12, color: _gray),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _showEmojiPicker = !_showEmojiPicker),
                child: Icon(
                  Icons.sentiment_satisfied_alt_outlined,
                  size: 20,
                  color: _showEmojiPicker ? _yellow : _gray,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _submitComment,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.send, size: 14, color: _ink),
                ),
              ),
            ],
          ),
          if (_showEmojiPicker) ...[
            const SizedBox(height: 8),
            _buildEmojiPicker(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final emoji in _emojiPalette)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _insertEmoji(emoji),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, emoji);
    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Widget _buildCommentPost(CourseThread thread) {
    final repliesOpen = _expandedReplies.contains(thread.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CourseImage(
                    thread.authorPhotoUrl ?? '',
                    fallback: Image.asset(
                      'assets/figma/instructors/instructor.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.authorName,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (thread.when.isNotEmpty) thread.when,
                        if (thread.authorRole != null) thread.authorRole!,
                      ].join(' • '),
                      style: GoogleFonts.figtree(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            thread.body,
            style: GoogleFonts.figtree(fontSize: 14, height: 1.4, color: _ink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleLike(thread),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      thread.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 12,
                      color: thread.isLiked ? const Color(0xFFEF4444) : _gray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      thread.likesCount > 0 ? '${thread.likesCount}' : 'Like',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: thread.isLiked ? const Color(0xFFEF4444) : _gray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  if (repliesOpen) {
                    _expandedReplies.remove(thread.id);
                  } else {
                    _expandedReplies.add(thread.id);
                  }
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 12,
                      color: _gray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      thread.replies.isEmpty
                          ? 'Reply'
                          : 'Reply · ${thread.replies.length}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _gray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (repliesOpen) ...[
            const SizedBox(height: 12),
            for (final reply in thread.replies) ...[
              _buildReplyTile(reply),
              const SizedBox(height: 8),
            ],
            _buildReplyComposer(thread),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyTile(CourseThread reply) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CourseImage(
                reply.authorPhotoUrl ?? '',
                fallback: Image.asset(
                  'assets/figma/instructors/instructor.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(
                      Icons.person,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.authorName,
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reply.when,
                      style: GoogleFonts.figtree(fontSize: 9, color: _gray),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.body,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer(CourseThread thread) {
    final controller = _replyController(thread.id);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.figtree(fontSize: 12, color: _ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Write a reply...',
                hintStyle: GoogleFonts.figtree(fontSize: 12, color: _gray),
              ),
              onSubmitted: (_) => _submitReply(thread),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _submitReply(thread),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.send, size: 14, color: _ink),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED
  // ─────────────────────────────────────────────────────────────
  Future<void> _openResource(CourseResource resource) async {
    final url = resource.url;
    if (url == null) return;
    await _openUrl(url);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _snack('That file has no address.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _snack('No app on this device can open that file.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.figtree(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMAT HELPERS
  // ─────────────────────────────────────────────────────────────
  String _formatIcon(CourseResourceType type) {
    switch (type) {
      case CourseResourceType.pdf:
        return 'assets/figma/bootcamp/pdf.png';
      case CourseResourceType.doc:
        return 'assets/figma/bootcamp/doc.png';
      case CourseResourceType.xls:
        return 'assets/figma/bootcamp/xls.png';
      case CourseResourceType.figma:
        return 'assets/figma/bootcamp/figma.png';
      case CourseResourceType.image:
        return 'assets/figma/bootcamp/svg.png';
      case CourseResourceType.zip:
        return 'assets/figma/bootcamp/zip.png';
      case CourseResourceType.link:
      case CourseResourceType.other:
        return '';
    }
  }

  _FormatColors _formatColors(CourseResourceType type) {
    switch (type) {
      case CourseResourceType.pdf:
        return const _FormatColors(
          iconBg: Color(0xFFFEE2E2),
          badgeBg: Color(0xFFFEE2E2),
          badgeText: Color(0xFF991B1B),
        );
      case CourseResourceType.doc:
        return const _FormatColors(
          iconBg: Color(0xFFDBEAFE),
          badgeBg: Color(0xFFDBEAFE),
          badgeText: Color(0xFF1E40AF),
        );
      case CourseResourceType.xls:
        return const _FormatColors(
          iconBg: Color(0xFFD1FAE5),
          badgeBg: Color(0xFFD1FAE5),
          badgeText: Color(0xFF065F46),
        );
      case CourseResourceType.figma:
        return const _FormatColors(
          iconBg: Color(0xFFF3E8FF),
          badgeBg: Color(0xFFF3E8FF),
          badgeText: Color(0xFF6B21A8),
        );
      case CourseResourceType.image:
        return const _FormatColors(
          iconBg: Color(0xFFFEF3C7),
          badgeBg: Color(0xFFFEF3C7),
          badgeText: Color(0xFF92400E),
        );
      case CourseResourceType.zip:
        return const _FormatColors(
          iconBg: Color(0xFFF3F4F6),
          badgeBg: Color(0xFFF3F4F6),
          badgeText: Color(0xFF374151),
        );
      case CourseResourceType.link:
      case CourseResourceType.other:
        return const _FormatColors(
          iconBg: Color(0xFFF3F4F6),
          badgeBg: Color(0xFFF3F4F6),
          badgeText: Color(0xFF374151),
        );
    }
  }

  static const _emojiPalette = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '🤔',
    '🙌',
    '🔥',
    '💯',
    '🚀',
    '✨',
    '🎯',
    '👏',
    '😅',
    '🙏',
    '💡',
    '📚',
    '⭐',
    '❤️',
  ];
}

class _FormatColors {
  const _FormatColors({
    required this.iconBg,
    required this.badgeBg,
    required this.badgeText,
  });

  final Color iconBg;
  final Color badgeBg;
  final Color badgeText;
}
