import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/course_image.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../courses/data/course_api.dart';
import '../../courses/data/course_discussions_api.dart';
import '../../courses/data/course_resources_api.dart';
import '../../courses/presentation/widgets/review_sheet.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../data/enrollment.dart';
import '../data/learning_api.dart';
import '../../../core/widgets/video_transport_controls.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF9CA3AF);
const _border = Color(0xFFEAEAEA);
const _fill = Color(0xFFF3F4F6);
const _gold = Color(0xFFE6B800);
const _previewGreen = Color(0xFF16A34A);

/// The screen a course opens into once the user is enrolled in it.
///
/// Three tabs over one video: **Lessons**, **Resources**, **Q&A**. The lecture
/// list is the course's own curriculum, flattened — see [Enrollment.lessonOrder]
/// — so Prev/Next, the highlighted row and the progress the My Learning tab
/// shows all read one sequence instead of three counters that could disagree.
///
/// **A `ConsumerStatefulWidget`, unlike the detail pages.** Those are plain
/// widgets because suites pump them with no `ProviderScope` above them; nothing
/// pumps this one bare, and it genuinely needs the store — selecting a lecture
/// records progress. Its tests install a scope.
///
/// **No Day pills.** The design has a `Day 1…4` row between the tabs and the
/// first section; it is deliberately not built, because the catalogue has no
/// day axis and inventing one would be a model change for a decoration.
class CoursePlayerPage extends ConsumerStatefulWidget {
  /// Identifies the top stage — player, reading pane or document card.
  ///
  /// Public so tests can scope to it; see `_buildStage`.
  static const stageKey = ValueKey('lesson-stage');

  const CoursePlayerPage({
    super.key,
    required this.course,
    this.startIndex = 0,
  });

  final CourseDetailData course;

  /// Which lecture to open on. `Continue Learning` passes the one the user
  /// stopped at; a fresh enrolment passes 0.
  final int startIndex;

  @override
  ConsumerState<CoursePlayerPage> createState() => _CoursePlayerPageState();
}

class _CoursePlayerPageState extends ConsumerState<CoursePlayerPage> {
  /// 0 Lessons · 1 Resources · 2 Q&A.
  int _tabIndex = 0;

  late int _currentIndex;
  late final List<CourseLesson> _lessons;

  /// The design shows both of these on. They are real state, and `Auto Next` is
  /// wired to the video's completion callback below — but **no lecture in the
  /// catalogue has a video** (see [CourseLesson.videoAsset]), so with the demo
  /// content neither toggle has anything to act on yet. They are not decorative:
  /// the code path they drive exists and runs the moment a lecture has a file.
  bool _autoPlay = true;
  bool _autoNext = true;

  /// The reaction this screen is showing for a card, keyed by [_QaCard.key].
  ///
  /// **A replacement, not an increment.** `GET .../discussions/` reports both
  /// `likes_count` and `is_liked`, and the like endpoint answers the
  /// authoritative count, so an entry here overrides the card's own numbers.
  /// That is also what makes an optimistic tap safe to undo: the previous entry
  /// is all that has to be put back.
  ///
  /// Keyed by [_QaCard.key], not by list position: a card's index moves the
  /// moment a newer comment is posted above it, and a reaction that jumped to
  /// a different message would be worse than one that is forgotten.
  final Map<String, _Like> _likes = <String, _Like>{};

  /// The course's real threads, newest first.
  ///
  /// **Null means "not a server course"**, not "empty": a catalogue entry has
  /// no `id`, so its Q&A stays the hardcoded [CourseDetailData.discussions]
  /// list and nothing here ever loads.
  List<CourseThread>? _threads;

  /// The server's total, which is what the tab badge prints — the loaded list
  /// may be a single page of it.
  int _threadCount = 0;

  /// The absolute `next` page URL, or null on the last page.
  String? _threadNext;

  bool _loadingThreads = false;
  String? _threadError;
  bool _posting = false;

  /// The course's real resource rows, or null before the tab is opened.
  ///
  /// **Null means "use the fallback"**, not "empty": [CourseDetailData.resources]
  /// already carries the `pdf`/`ebook` lessons the adapter lifted out of the
  /// curriculum, and a catalogue entry has nothing else. The server list wins
  /// whenever it answers a non-empty array.
  List<CourseResource>? _resources;

  /// Whether the fetch has already happened — **not** whether it found rows.
  ///
  /// A course with no resource rows answers `[]`, which leaves [_resources]
  /// null so the fallback still renders. Without this flag the tab would treat
  /// that as "never loaded" and refetch on every visit.
  bool _resourcesLoaded = false;

  bool _loadingResources = false;
  String? _resourceError;

  /// Top-level comments posted from the composer, newest first.
  final List<_QaCard> _localComments = <_QaCard>[];

  /// Replies posted from this screen, grouped by the card they answer.
  ///
  /// Replies are **not** in the main list. A reply that renders as the next
  /// message in the thread is not a reply — it is a second question that
  /// happens to start with an `@`.
  final Map<String, List<CourseDiscussion>> _replies =
      <String, List<CourseDiscussion>>{};

  /// Which card the composer is currently answering, or null when it is
  /// posting a new top-level comment.
  _ReplyTarget? _replyTarget;

  int _nextLocalKey = 0;

  /// How many **cards** show before `View more`, and whether it has been
  /// tapped. Replies do not count — they live inside their card.
  ///
  /// Three rather than five because the catalogue authors four per course, so
  /// the control always has something behind it — a `View more` that expands to
  /// nothing is the dead chevron the curriculum accordion used to have.
  static const _commentPreview = 3;
  bool _showAllComments = false;

  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  /// Set when `initialize()` rejects.
  ///
  /// Without it a failed video is indistinguishable from one that has not
  /// started yet: the poster stays up, no transport bar appears, and the reason
  /// is only in logcat. That is how a blocked cleartext request looked on device
  /// — a poster and a play glyph, forever (2026-10-28).
  String? _videoError;

  CourseDetailData get _course => widget.course;

  @override
  void initState() {
    super.initState();
    _lessons = _course.modules
        .expand((module) => module.lessons)
        .toList(growable: false);
    _currentIndex = _lessons.isEmpty
        ? 0
        : widget.startIndex.clamp(0, _lessons.length - 1);
    _syncVideo();
    _loadServerProgress();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  /// Points the controller at the current lecture's video, or tears it down when
  /// the lecture has none.
  ///
  /// **Two sources, two constructors.** An API lesson carries `contentUrl` — an
  /// http URL — and needs `networkUrl`; a catalogue lesson would carry a bundled
  /// `videoAsset`. Neither is set on most lessons, and the null branch is what
  /// keeps `video_player` — which has no platform implementation under
  /// `flutter test` — off the path of any test that renders this screen.
  ///
  /// Non-video lessons never reach here: a `text` lecture renders its body and a
  /// `pdf`/`ebook` renders a document panel, both in `_buildStage`.
  void _syncVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _videoError = null;

    if (_lessons.isEmpty) return;
    final lesson = _lessons[_currentIndex];
    if (lesson.kind != CourseLessonKind.video) return;

    final remote = lesson.contentUrl?.trim() ?? '';
    final asset = lesson.videoAsset?.trim() ?? '';
    final VideoPlayerController? controller;
    if (remote.isNotEmpty) {
      controller = VideoPlayerController.networkUrl(Uri.parse(remote));
    } else if (asset.isNotEmpty) {
      controller = VideoPlayerController.asset(asset);
    } else {
      controller = null;
    }
    if (controller == null) return;

    // Promoted to a non-null local: the closure below captures it, and
    // null-promotion does not survive into a closure.
    final player = controller;
    _videoController = player;
    player
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _videoReady = true);
          if (_autoPlay) player.play();
        })
        .catchError((Object error) {
          // A platform video error carries no user-facing message, so the frame is
          // the only place the failure can surface. The detail goes to logcat.
          debugPrint('course player: video failed to load: $error');
          if (!mounted) return;
          setState(() => _videoError = 'This video could not be loaded.');
        });
    player.addListener(_onVideoTick);
  }

  /// `Auto Next` lives here: the lecture is finished when its video is.
  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final finished =
        value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying;
    if (finished && _autoNext) _go(1, countPrevious: true);
  }

  /// Moves to the lecture [delta] away, clamped to the course.
  ///
  /// `countPrevious` marks the lecture being left as finished. That is this
  /// demo's stand-in for a playback-completed event — there is no video to
  /// finish, and without it the progress on the My Learning tab could never
  /// move off zero.
  void _go(int delta, {bool countPrevious = true}) {
    final next = (_currentIndex + delta).clamp(0, _lessons.length - 1);
    if (next == _currentIndex) return;
    _select(next, countPrevious: countPrevious);
  }

  void _select(int index, {bool countPrevious = true}) {
    if (index < 0 || index >= _lessons.length) return;
    final leaving = _currentIndex;

    setState(() => _currentIndex = index);
    // After the index moves, so it picks up the new lecture's video — and
    // outside `setState`, because it only reassigns the controller and the
    // rebuild above has already been scheduled.
    _syncVideo();

    final store = ref.read(enrolledCoursesProvider.notifier);
    store.setLast(_course, index);
    if (countPrevious && leaving != index) {
      final finished = _lessons[leaving];
      // The store keys on the lesson's id, not its position — see
      // `lessonProgressKey`. It is handed the lesson so no caller can get that
      // wrong.
      store.markComplete(_course, finished, leaving);
      _postCompletion(finished);
    }
  }

  /// This course's row in the store, or null when it is not enrolled.
  ///
  /// Watches the **state**, not the notifier: progress is written from this
  /// screen, so the lesson rows have to rebuild when it changes or a finished
  /// lecture would keep its play icon until something else happened to rebuild.
  Enrollment? get _enrollment {
    for (final enrollment in ref.watch(enrolledCoursesProvider)) {
      final a = enrollment.course;
      final b = _course;
      // Id first, title only for a catalogue entry that has none — the same
      // rule the store itself uses. Two courses may share a title.
      final same = a.id != null && b.id != null
          ? a.id == b.id
          : a.title == b.title;
      if (same) return enrollment;
    }
    return null;
  }

  /// Marks the lecture being watched as finished.
  ///
  /// **This is the only way to complete the last lecture.** `_select` records a
  /// completion for the lecture being *left*, so the final one — which has no
  /// `Next` — could never be finished, and a course could never reach 100%.
  void _markCurrentComplete() {
    final lesson = _currentLesson;
    if (lesson == null) return;
    ref
        .read(enrolledCoursesProvider.notifier)
        .markComplete(_course, lesson, _currentIndex);
    _postCompletion(lesson);
  }

  /// True once every lecture in an API-backed course is finished.
  ///
  /// The review card hangs off this. A catalogue course has no id and no
  /// endpoint, so it never offers one.
  bool get _isCourseComplete {
    if (_course.id == null) return false;
    final enrollment = _enrollment;
    return enrollment != null &&
        enrollment.total > 0 &&
        enrollment.done >= enrollment.total;
  }

  Future<void> _openReview() async {
    final id = _course.id;
    if (id == null) return;
    await openCourseReview(
      context,
      api: ref.read(courseApiProvider),
      courseId: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildStage(),
            _buildPlaybackBar(),
            _buildTabBar(),
            Expanded(
              child: switch (_tabIndex) {
                1 => _buildResourcesTab(),
                2 => _buildQaTab(),
                _ => _buildLessonsTab(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VIDEO
  // ─────────────────────────────────────────────────────────────

  /// Hands the same controller to a black landscape page.
  ///
  /// **The controller is not re-created and not disposed here.** It stays owned
  /// by this screen, so playback continues across the route and the lecture is
  /// still playing when the user comes back — the alternative is a re-init gap
  /// and a second controller briefly existing for the same video.
  Future<void> _openFullscreen(
    VideoPlayerController controller,
    CourseLesson? lesson,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPage(
          controller: controller,
          title: lesson?.title ?? _course.title,
        ),
      ),
    );
    // The route restores orientation and system UI in its own `dispose`.
    if (mounted) setState(() {});
  }

  Widget _buildVideoArea() {
    final lesson = _lessons.isEmpty ? null : _lessons[_currentIndex];
    // One non-null local rather than a `controller != null && _videoReady`
    // check repeated three times: the type has to be promoted for `VideoPlayer`
    // and the transport bar, and a bool cannot carry that.
    final controller = _videoReady ? _videoController : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              _buildPosterOrLock(lesson),
            // The transport layer sits over the picture but under the back
            // pill, so leaving the screen is always the easiest thing to hit.
            // No controller means nothing to transport: a poster or a gated
            // lesson gets no bar.
            if (controller != null)
              VideoTransportControls(
                // Keyed by controller so switching lecture rebuilds the bar
                // against the new one instead of reusing the old State.
                key: ValueKey(controller),
                controller: controller,
                title: lesson?.title ?? _course.title,
                onFullscreen: () => _openFullscreen(controller, lesson),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, size: 19, color: _ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SERVER PROGRESS
  // ─────────────────────────────────────────────────────────────

  /// Seeds the local store from what the server already knows, and resumes
  /// where the server says.
  ///
  /// **The prefix inference is exact, not an estimate.** The server picks
  /// `next_lesson` as the first lesson in `order` that is not complete, so every
  /// lesson before it *is* complete. What this cannot see is a completion
  /// *after* that point — no endpoint lists completed lesson ids, so a user who
  /// skipped ahead shows ticks only up to the gap. That is a backend ask, not a
  /// guess we can fix here.
  ///
  /// A catalogue course has no id, so nothing is fetched and the local store
  /// stays the only source.
  Future<void> _loadServerProgress() async {
    final id = _course.id;
    if (id == null) return;
    final api = ref.read(courseApiProvider);
    try {
      final progress = await api.progress(id);
      final nextId = await api.nextLessonId(id);
      if (!mounted) return;

      final nextIndex = nextId == null
          ? -1
          : _lessons.indexWhere((lesson) => lesson.id == nextId);

      // Without a next lesson the course is either finished or absent from My
      // Learning; fall back to the count the progress endpoint reported.
      final doneCount = nextIndex >= 0
          ? nextIndex
          : progress.completedLessons.clamp(0, _lessons.length);

      final completed = <int>{};
      for (var index = 0; index < doneCount; index++) {
        final lesson = _lessons[index];
        if (lesson.id != null) completed.add(lesson.id!);
      }

      final resumeIndex = nextIndex >= 0 ? nextIndex : 0;
      ref
          .read(enrolledCoursesProvider.notifier)
          .adoptProgress(_course, completed: completed, lastIndex: resumeIndex);

      // Only move the cursor if the caller did not ask for a specific lecture —
      // an explicit `startIndex` is a deliberate destination.
      if (nextIndex > 0 && widget.startIndex == 0 && _currentIndex == 0) {
        setState(() => _currentIndex = nextIndex);
        _syncVideo();
      }
    } on ApiException {
      // Not enrolled, or the read failed: the local state is still usable and
      // the screen has already rendered. Nothing to show the user.
    }
  }

  /// `POST /lessons/{id}/complete/`.
  ///
  /// The tick is already drawn, so a failure is a snack rather than a rollback:
  /// un-ticking a lecture the user just finished would be a worse lie than a
  /// server row that is one request behind.
  Future<void> _postCompletion(CourseLesson lesson) async {
    final id = lesson.id;
    if (id == null) return;
    try {
      await ref.read(courseApiProvider).completeLesson(id);
      // My Learning reads its numbers from the server and caches them, so a
      // lesson finished here would otherwise leave the tab showing the progress
      // it had when it was first opened.
      ref.invalidate(myLearningProvider);
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STAGE — a player, a reading pane, or a document card
  // ─────────────────────────────────────────────────────────────

  CourseLesson? get _currentLesson =>
      _lessons.isEmpty ? null : _lessons[_currentIndex];

  /// A lecture whose content the server withheld.
  ///
  /// `Lesson.content_url` is null for a student who is not enrolled — that is
  /// the paywall — so on a course that came from the API a missing source is a
  /// **lock**, not an empty lesson. A catalogue course has no id and no URLs at
  /// all, and there the still poster is the right thing.
  bool _isGated(CourseLesson lesson) {
    if (_course.id == null) return false;
    if (lesson.kind.isInlineText) return false;
    final url = lesson.contentUrl?.trim() ?? '';
    return url.isEmpty;
  }

  Widget _buildStage() {
    final lesson = _currentLesson;
    final Widget stage;
    if (lesson == null) {
      stage = _buildVideoArea();
    } else if (lesson.kind.isInlineText) {
      stage = _buildTextStage(lesson);
    } else if (lesson.kind.isDocument) {
      stage = _buildDocumentStage(lesson);
    } else {
      stage = _buildVideoArea();
    }
    // Keyed so a test can scope an icon assertion to the stage: the lesson rows
    // below it draw the same play/lock glyphs, so an unscoped `find.byIcon`
    // cannot tell the stage apart from the list.
    return KeyedSubtree(key: CoursePlayerPage.stageKey, child: stage);
  }

  /// A `text` lecture: the prose is the lesson, so it replaces the video.
  Widget _buildTextStage(CourseLesson lesson) {
    final body = lesson.contentText?.trim() ?? '';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150, maxHeight: 260),
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.fromLTRB(52, 12, 16, 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body.isEmpty ? 'This lesson has no text yet.' : body,
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A `pdf` or `ebook` lecture.
  ///
  /// **There is no document viewer in this app.** No PDF package, no
  /// `url_launcher`, no webview — so this panel names the lesson and says so
  /// rather than pretending a button will open it. Adding a viewer is its own
  /// piece of work; the shape here is what that work plugs into.
  Widget _buildDocumentStage(CourseLesson lesson) {
    final gated = _isGated(lesson);
    final isPdf = lesson.kind == CourseLessonKind.pdf;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gated
                        ? Icons.lock_outline
                        : (isPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.menu_book_outlined),
                    size: 40,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    gated
                        ? 'Enrol to open this lesson'
                        : (isPdf ? 'PDF lesson' : 'Ebook lesson'),
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  if (!gated) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        lesson.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _explainNoDocumentViewer,
                      child: const Text('Open document'),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(left: 12, top: 12, child: _buildBackButton()),
          ],
        ),
      ),
    );
  }

  void _explainNoDocumentViewer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Opening documents needs a viewer that is not in the app yet.',
        ),
      ),
    );
  }

  /// The still, with a play affordance — or a lock when the paywall withheld
  /// the lecture.
  Widget _buildPosterOrLock(CourseLesson? lesson) {
    final gated = lesson != null && _isGated(lesson);
    final failure = gated ? null : _videoError;
    final tint = Colors.white.withValues(alpha: 0.92);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Asset for the catalogue, http URL from the API.
        CourseImage(
          _course.image,
          fallback: const ColoredBox(color: Color(0xFF1F1F1F)),
        ),
        const ColoredBox(color: Color(0x8C0B0B0B)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failure != null
                    ? Icons.error_outline
                    : (gated ? Icons.lock_outline : Icons.play_circle_outline),
                size: 44,
                color: tint,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  failure ??
                      (gated
                          ? 'Enrol to watch this lesson'
                          : (lesson?.title ?? _course.title)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tint,
                  ),
                ),
              ),
              if (failure != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _syncVideo,
                  style: TextButton.styleFrom(foregroundColor: _gold),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() => GestureDetector(
    onTap: () => Navigator.of(context).maybePop(),
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.arrow_back, size: 19, color: _ink),
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // PLAYBACK BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildPlaybackBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _ToggleDot(
            label: 'Auto Play',
            on: _autoPlay,
            onTap: () => setState(() => _autoPlay = !_autoPlay),
          ),
          const SizedBox(width: 14),
          _ToggleDot(
            label: 'Auto Next',
            on: _autoNext,
            onTap: () => setState(() => _autoNext = !_autoNext),
          ),
          const Spacer(),
          _SkipButton(
            label: 'Prev',
            icon: Icons.skip_previous,
            onTap: _currentIndex > 0 ? () => _go(-1) : null,
          ),
          const SizedBox(width: 10),
          _SkipButton(
            label: 'Next',
            icon: Icons.skip_next,
            onTap: _currentIndex < _lessons.length - 1 ? () => _go(1) : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABS
  // ─────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          for (final (index, label) in const [
            (0, 'Lessons'),
            (1, 'Resources'),
            (2, 'Q&A'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTab(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        label,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          fontWeight: _tabIndex == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _tabIndex == index ? _ink : _softGray,
                        ),
                      ),
                    ),
                    Container(
                      height: 2,
                      color: _tabIndex == index ? _gold : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LESSONS
  // ─────────────────────────────────────────────────────────────

  Widget _buildLessonsTab() {
    if (_lessons.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No lectures yet',
        body: 'This course has no curriculum to play.',
      );
    }

    var flatIndex = 0;
    final rows = <Widget>[];
    for (final module in _course.modules) {
      rows.add(_buildSectionHeader(module));
      for (final lesson in module.lessons) {
        rows.add(_buildLessonRow(lesson, flatIndex));
        flatIndex++;
      }
    }
    if (_isCourseComplete) rows.add(_buildCourseCompletedCard());

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: rows);
  }

  /// Shown under the curriculum once the last lecture is ticked.
  ///
  /// The design has no equivalent — it is the missing half of "a student can
  /// review a course": the detail page can be reached any time, but the moment a
  /// student is actually *finished* is here, and this is where the review is
  /// worth asking for.
  Widget _buildCourseCompletedCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1E4B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF4CC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: Color(0xFFE6B800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You finished this course',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'How was it? Your review helps other students pick a course.',
            style: GoogleFonts.figtree(fontSize: 12, color: _gray, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openReview,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Write a review',
                style: GoogleFonts.figtree(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(CourseModule module) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          // Derived from the list, never authored — a section header that
          // disagrees with the lectures under it is a bug, and the curriculum
          // accordion already learned that once.
          Text(
            '${module.lessons.length} lessons',
            style: GoogleFonts.inter(fontSize: 11, color: _softGray),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonRow(CourseLesson lesson, int index) {
    final current = index == _currentIndex;
    // Keyed by the lesson's id, not its position — the store keys completions
    // that way, so comparing against `index` ticked the wrong rows (and never
    // ticked a server lesson, whose id is a primary key).
    final complete =
        _enrollment?.completed.contains(lessonProgressKey(lesson, index)) ??
        false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _select(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: current ? _fill : Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _softGray,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // The design colours the preview lecture's icon green and
                // leaves the rest grey — the same `isPreview` flag the detail
                // screen renders as a `Preview` tag.
                Icon(
                  lesson.isPreview
                      ? Icons.play_circle_fill
                      : complete
                      ? Icons.check_circle
                      : Icons.play_circle_outline,
                  size: 17,
                  color: lesson.isPreview
                      ? _previewGreen
                      : complete
                      ? _previewGreen
                      : _softGray,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 12.5,
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lesson.duration,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: _softGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // **The lecture you are watching is the one you can finish.**
                // Moving away through Prev/Next ticks the lecture being left,
                // but the *last* one is never left — so without this control a
                // course could not reach 100% and the review prompt could never
                // appear. Every other row keeps the design's play badge.
                if (current && !complete)
                  _MarkCompleteButton(onTap: _markCurrentComplete)
                else
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RESOURCES
  // ─────────────────────────────────────────────────────────────

  Widget _buildResourcesTab() {
    final resources = _visibleResources;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _episodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                // A one-file pack used to read `1 files`.
                '${resources.length} '
                '${resources.length == 1 ? 'file' : 'files'}',
                style: GoogleFonts.inter(fontSize: 11, color: _softGray),
              ),
            ],
          ),
        ),
        if (_loadingResources && _resources == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_resourceError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _ThreadErrorState(
              message: _resourceError!,
              title: 'Could not load the files',
              onRetry: () {
                setState(() {
                  _resources = null;
                  _resourcesLoaded = false;
                });
                _loadResources();
              },
            ),
          ),
        if (resources.isEmpty && !_loadingResources && _resourceError == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: _EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No files for this lesson',
              body: 'The instructor has not attached any resources here.',
            ),
          )
        else
          for (final resource in resources) _buildResourceRow(resource),
      ],
    );
  }

  /// The rows this tab prints: the current lesson's files plus the course-wide
  /// ones.
  ///
  /// **A null [CourseResource.lessonId] is course-wide, not orphaned.** Every
  /// bootcamp pack predates per-lesson attachment and has no lesson at all, so
  /// those rows have to stay visible on every lesson. Before the tab is opened
  /// there is no server list and [_course]'s fallback pack is course-wide too,
  /// which is why the fallback path returns everything.
  List<CourseResource> get _visibleResources {
    final all = _resources ?? _course.resources;
    if (_resources == null) return all;
    final lessonId = _currentLesson?.id;
    if (lessonId == null) return all;
    return [
      for (final resource in all)
        if (resource.lessonId == null || resource.lessonId == lessonId)
          resource,
    ];
  }

  /// Opens a resource in the phone's browser.
  ///
  /// A row with no URL is a demo-catalogue entry; it keeps the decoration it
  /// always had rather than throwing a "cannot open" snackbar at a tap the user
  /// was never invited to make.
  Future<void> _openResource(CourseResource resource) async {
    final url = resource.url;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _resourceSnack('That file has no address.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _resourceSnack('No app on this device can open that file.');
    }
  }

  void _resourceSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.figtree(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildResourceRow(CourseResource resource) {
    final openable = resource.isOpenable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: openable ? () => _openResource(resource) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(resource.type.icon, size: 22, color: resource.type.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resource.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resource.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: resource.type.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: Icon(
                    Icons.file_download_outlined,
                    size: 15,
                    color: openable ? _gray : _border,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DISCUSSIONS (wire)
  // ─────────────────────────────────────────────────────────────

  /// Switches tabs, and fetches the thread the first time Q&A is opened.
  ///
  /// **Lazy on purpose.** The tab's count badge lives inside the Q&A body, not
  /// on the tab strip, so nothing needs the thread until the user asks for it —
  /// and a player opened to watch one lecture should not spend a request on a
  /// panel nobody looked at.
  void _selectTab(int index) {
    setState(() => _tabIndex = index);
    if (index == 1) {
      if (_course.id == null || _resourcesLoaded || _loadingResources) return;
      _loadResources();
      return;
    }
    if (index != 2) return;
    if (_course.id == null || _threads != null || _loadingThreads) return;
    _loadThreads();
  }

  /// `GET /courses/{id}/resources/` — the first time the Resources tab opens.
  ///
  /// A failure is **not** the same as an empty pack. A student without access
  /// gets 403 `NOT_ENROLLED`, and printing "the instructor has not attached any
  /// resources" over that would be a lie; the tab says what happened instead and
  /// keeps the adapter's fallback list underneath.
  Future<void> _loadResources() async {
    final courseId = _course.id;
    if (courseId == null) return;
    setState(() {
      _loadingResources = true;
      _resourceError = null;
    });
    try {
      final rows = await ref.read(courseResourcesApiProvider).list(courseId);
      if (!mounted) return;
      setState(() {
        _loadingResources = false;
        _resourcesLoaded = true;
        // An empty answer keeps the fallback: a seeded course's `pdf` lessons
        // are still the only files it has, and the server has no rows for them.
        if (rows.isNotEmpty) _resources = rows;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingResources = false;
        _resourceError = error.displayMessage;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingResources = false;
        _resourceError = 'The files could not be loaded.';
      });
    }
  }

  /// Loads the first page, or the next one when [more] is set.
  ///
  /// A catalogue course has no `id` and returns immediately: its thread is the
  /// hardcoded list the detail page already carries, and there is no server to
  /// ask. That null check is the whole reason this screen has two modes.
  Future<void> _loadThreads({bool more = false}) async {
    final courseId = _course.id;
    if (courseId == null) return;
    if (more && _threadNext == null) return;
    setState(() {
      _loadingThreads = true;
      _threadError = null;
    });
    try {
      final api = ref.read(courseDiscussionsApiProvider);
      final page = more
          ? await api.nextPage(_threadNext!)
          : await api.list(courseId, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _threads = <CourseThread>[...?_threads, ...page.threads];
        _threadCount = page.count;
        _threadNext = page.next;
        _loadingThreads = false;
      });
      _fileReplies();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingThreads = false;
        _threadError = error.displayMessage;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingThreads = false;
        _threadError = 'The discussion could not be loaded.';
      });
    }
  }

  /// Moves each thread's inline replies into [_replies].
  ///
  /// The list endpoint already returns up to 50 replies per thread, so the tab
  /// needs no per-thread fetch. Overwriting is correct: after a reload the
  /// server's copy is the one that includes what was just posted.
  void _fileReplies() {
    for (final thread in _threads ?? const <CourseThread>[]) {
      if (thread.replies.isEmpty) continue;
      _replies['remote:${thread.id}'] = [
        for (final reply in thread.replies) _asDiscussion(reply),
      ];
    }
  }

  /// The wire row as the card the design draws.
  CourseDiscussion _asDiscussion(CourseThread thread) => CourseDiscussion(
    thread.authorName,
    thread.authorRole ?? 'Student',
    thread.when,
    thread.body,
    isStaff: thread.isStaff,
    reactions: thread.likesCount,
    id: thread.id,
    isMine: thread.isMine,
    isLiked: thread.isLiked,
  );

  /// What the card should show right now: the local override if there is one,
  /// otherwise the row's own numbers.
  _Like _likeFor(_QaCard card) =>
      _likes[card.key] ??
      _Like(liked: card.comment.isLiked, count: card.comment.reactions);

  /// Flips a reaction, then reconciles with the server's answer.
  ///
  /// **The tap is applied first.** The endpoint is idempotent in both
  /// directions and answers the authoritative count, so the optimistic value is
  /// only a placeholder for the ~200ms before the response replaces it — and
  /// the previous entry is restored if the call fails.
  Future<void> _toggleLike(_QaCard card) async {
    final current = _likeFor(card);
    final next = _Like(
      liked: !current.liked,
      count: current.count + (current.liked ? -1 : 1),
    );
    setState(() => _likes[card.key] = next);

    final id = card.comment.id;
    final courseId = _course.id;
    // Catalogue card, or a course with no server row: the tap stays local,
    // exactly as it did before this tab had an endpoint.
    if (id == null || courseId == null) return;

    try {
      final result = await ref
          .read(courseDiscussionsApiProvider)
          .setLiked(courseId, id, liked: next.liked);
      if (!mounted) return;
      setState(
        () => _likes[card.key] = _Like(
          liked: result.isLiked,
          count: result.likesCount,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _likes[card.key] = current);
      showApiErrorSnack(context, error);
    } on Object {
      if (!mounted) return;
      setState(() => _likes[card.key] = current);
    }
  }

  /// The server id the composer's next post should answer, or null for a new
  /// thread.
  ///
  /// A `local:` key can only exist on a catalogue course, and this branch is
  /// only reached on a server one, so an unparseable key means "new thread"
  /// rather than an error.
  int? _parentIdFor(_ReplyTarget? target) {
    if (target == null) return null;
    const prefix = 'remote:';
    if (!target.key.startsWith(prefix)) return null;
    return int.tryParse(target.key.substring(prefix.length));
  }

  Future<void> _confirmDelete(_QaCard card) async {
    final id = card.comment.id;
    final courseId = _course.id;
    if (id == null || courseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text(
          'It will be removed for everyone, along with any replies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(courseDiscussionsApiProvider).remove(courseId, id);
      if (!mounted) return;
      setState(() {
        _threads = [
          for (final thread in _threads ?? const <CourseThread>[])
            if (thread.id != id) thread,
        ];
        _threadCount = _threadCount > 0 ? _threadCount - 1 : 0;
        _replies.remove(card.key);
        _likes.remove(card.key);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      showApiErrorSnack(context, error);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Q&A
  // ─────────────────────────────────────────────────────────────

  Widget _buildQaTab() {
    // Server rows for an API course, the hardcoded catalogue thread otherwise;
    // plus anything posted here that has not been reloaded yet. See [_qaCards].
    final discussions = _qaCards;
    final visible = _showAllComments
        ? discussions
        : discussions.take(_commentPreview).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Text(
                'Discussions',
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 8),
              // Counts cards, not messages: a reply is part of the discussion
              // it answers, so it does not start one. This is why replying
              // leaves the badge alone — that is the correct behaviour, not a
              // missed rebuild.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _fill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_discussionCount',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _gray,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Episode ${_currentIndex + 1}',
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only while a reply is in progress. Without it the composer
                // looks identical whether it will post a new discussion or
                // answer an existing one — and the nesting is the only other
                // clue, which is too late.
                if (_replyTarget case final target?) _buildReplyBanner(target),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        focusNode: _composerFocus,
                        minLines: 1,
                        maxLines: 3,
                        style: GoogleFonts.figtree(fontSize: 12.5, color: _ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: _replyTarget == null
                              ? 'Add to the discussion...'
                              : 'Write a reply...',
                          hintStyle: GoogleFonts.figtree(
                            fontSize: 12.5,
                            color: _softGray,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      // Disabled in flight: a second tap would post the same
                      // text twice, and the server has no dedupe.
                      onPressed: _posting ? null : _postComment,
                      icon: _posting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
                      color: _ink,
                      tooltip: _replyTarget == null ? 'Post' : 'Reply',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildThreadBody(visible)),
      ],
    );
  }

  /// The list under the composer: spinner, retry, empty state, or cards.
  ///
  /// The first load is the only one that hides the list. A **reload** after the
  /// list is on screen keeps it there — replacing a thread the user is reading
  /// with a spinner because a "load more" failed would lose their place.
  Widget _buildThreadBody(List<_QaCard> visible) {
    if (_loadingThreads && _threads == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    if (_threadError != null && _threads == null) {
      return _ThreadErrorState(message: _threadError!, onRetry: _loadThreads);
    }
    if (visible.isEmpty) {
      return const _EmptyState(
        icon: Icons.forum_outlined,
        title: 'No discussions yet',
        body: 'Be the first to ask something about this course.',
      );
    }
    // Two different controls, and they must not both show: `View more` reveals
    // cards already fetched, `Load more` fetches the next page.
    final showViewMore = !_showAllComments && _qaCards.length > _commentPreview;
    final showLoadMore = _showAllComments && _threadNext != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        for (final card in visible) _buildDiscussionCard(card),
        if (showViewMore)
          Center(
            child: TextButton(
              onPressed: _showMoreThread,
              child: Text(
                'View more',
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
            ),
          ),
        if (showLoadMore)
          Center(
            child: TextButton(
              onPressed: _loadingThreads
                  ? null
                  : () => _loadThreads(more: true),
              child: Text(
                _loadingThreads ? 'Loading...' : 'Load more',
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Expands the preview, and pulls the next page when the loaded one is all
  /// that is on screen.
  ///
  /// Without the second half, `View more` on a 60-message thread would reveal
  /// the 20 that were fetched and then stop — which looks like the thread ends
  /// there.
  void _showMoreThread() {
    setState(() => _showAllComments = true);
    if (_threadNext != null) _loadThreads(more: true);
  }

  Widget _buildDiscussionCard(_QaCard card) {
    final discussion = card.comment;
    final replies = _replies[card.key] ?? const <CourseDiscussion>[];
    final like = _likeFor(card);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _fill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  discussion.initial,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _gray,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            discussion.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (discussion.isStaff) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: _gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${discussion.when} • ${discussion.role}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            discussion.body,
            style: GoogleFonts.figtree(
              fontSize: 12,
              height: 1.35,
              color: _gray,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CardAction(
                icon: like.liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: like.count == 0 ? 'React' : '${like.count}',
                active: like.liked,
                onTap: () => _toggleLike(card),
              ),
              const SizedBox(width: 18),
              _CardAction(
                icon: Icons.chat_bubble_outline,
                label: 'Reply',
                // Not a dead control, and no longer a shortcut to a flat
                // comment: this targets the card, so the composer posts
                // underneath it instead of at the top of the list.
                onTap: () => _startReply(card.key, discussion.author),
              ),
              // Only your own server rows can be deleted, and only the server
              // can delete them — a catalogue card has no id to address.
              if (discussion.isMine && discussion.id != null) ...[
                const SizedBox(width: 18),
                _CardAction(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: () => _confirmDelete(card),
                ),
              ],
            ],
          ),
          if (replies.isNotEmpty) _buildReplyList(card.key, replies),
        ],
      ),
    );
  }

  /// The replies to one card, indented behind a thread rule.
  ///
  /// One level deep, deliberately. A reply to a reply joins this same list and
  /// carries an `@mention` instead of a third indent — deeper nesting buys
  /// nothing on a 360pt screen and costs the reader the whole column.
  Widget _buildReplyList(String threadKey, List<CourseDiscussion> replies) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _border, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reply in replies) _buildReplyRow(threadKey, reply),
        ],
      ),
    );
  }

  Widget _buildReplyRow(String threadKey, CourseDiscussion reply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _fill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  reply.initial,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _gray,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reply.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              if (reply.isStaff) ...[
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '${reply.when} • ${reply.role}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 10, color: _softGray),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply.body,
            style: GoogleFonts.figtree(
              fontSize: 12,
              height: 1.35,
              color: _gray,
            ),
          ),
          const SizedBox(height: 4),
          _CardAction(
            icon: Icons.chat_bubble_outline,
            label: 'Reply',
            // Replies to a reply stay in this list, so the mention is what
            // says who is being answered.
            onTap: () => _startReply(threadKey, reply.author, mention: true),
          ),
        ],
      ),
    );
  }

  /// Points the composer at [threadKey] and says who it is answering.
  ///
  /// The mention is only written for a reply-to-a-reply: answering the card
  /// itself is already unambiguous from the nesting, and prefilling `@Author`
  /// there is what made a threaded answer look like a new message. Existing
  /// text is never clobbered.
  void _startReply(String threadKey, String author, {bool mention = false}) {
    setState(() {
      _replyTarget = _ReplyTarget(key: threadKey, author: author);
      if (mention && !_composer.text.startsWith('@$author')) {
        _composer.text = '@$author ${_composer.text}';
        _composer.selection = TextSelection.collapsed(
          offset: _composer.text.length,
        );
      }
    });
    _composerFocus.requestFocus();
  }

  Widget _buildReplyBanner(_ReplyTarget target) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 6),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 13, color: _softGray),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Replying to ${target.author}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _gray,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTarget = null),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 13, color: _softGray),
            ),
          ),
        ],
      ),
    );
  }

  /// The thread as it renders: what was posted here, then the course's own.
  ///
  /// **Two sources, chosen by whether the course has a server id.** An API
  /// course reads [_threads]; a catalogue entry has none, so it keeps the
  /// hardcoded [CourseDetailData.discussions] list it has always shown. The two
  /// are never mixed — a catalogue course cannot have server rows.
  List<_QaCard> get _qaCards => [
    ..._localComments,
    if (_threads case final threads?)
      for (final thread in threads)
        _QaCard(key: 'remote:${thread.id}', comment: _asDiscussion(thread))
    else
      for (var i = 0; i < _course.discussions.length; i++)
        _QaCard(key: 'course:$i', comment: _course.discussions[i]),
  ];

  /// The number the tab's badge prints.
  ///
  /// The server's `count` is the whole thread, not the page that is loaded, so
  /// a badge of `20` on a course with 300 messages would be wrong — and the
  /// list behind it would look complete.
  int get _discussionCount =>
      _threads == null ? _qaCards.length : _threadCount + _localComments.length;

  /// Posts the composer's text — under the card being answered, or as a new
  /// discussion when nothing is targeted.
  ///
  /// **Server course:** the message is written to the endpoint and the row it
  /// returns is inserted, so the card carries the real id (and can be liked or
  /// deleted). A failed post leaves the text in the composer and says why —
  /// clearing it would throw away what the user wrote.
  ///
  /// **Catalogue course:** local only, as before. There is no course id to post
  /// against, so the message is held in this screen's state and is gone when it
  /// closes.
  Future<void> _postComment() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _posting) return;
    final target = _replyTarget;
    final courseId = _course.id;

    if (courseId != null) {
      setState(() => _posting = true);
      try {
        final thread = await ref
            .read(courseDiscussionsApiProvider)
            .post(courseId, body: text, parentId: _parentIdFor(target));
        if (!mounted) return;
        setState(() {
          _posting = false;
          _composer.clear();
          _replyTarget = null;
          _showAllComments = true;
          if (thread.parentId == null) {
            _threads = <CourseThread>[thread, ...?_threads];
            _threadCount += 1;
          } else {
            _replies
                .putIfAbsent(
                  'remote:${thread.parentId}',
                  () => <CourseDiscussion>[],
                )
                .add(_asDiscussion(thread));
          }
        });
        _composerFocus.unfocus();
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() => _posting = false);
        showApiErrorSnack(context, error);
      } on Object {
        if (!mounted) return;
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That did not send. Check your connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      final comment = CourseDiscussion('You', 'Student', 'Just now', text);
      if (target != null) {
        _replies
            .putIfAbsent(target.key, () => <CourseDiscussion>[])
            .add(comment);
      } else {
        _localComments.insert(
          0,
          _QaCard(key: 'local:${_nextLocalKey++}', comment: comment),
        );
      }
      _composer.clear();
      _replyTarget = null;
      // The answered card has to be on screen, so posting a reply opens the
      // rest of the thread the same way posting a comment does.
      _showAllComments = true;
    });
    _composerFocus.unfocus();
  }

  /// `EP. 2 Defining the Product Strategy Grid` — the design's header, built
  /// from the lecture that is playing rather than authored.
  String get _episodeLabel {
    if (_lessons.isEmpty) return _course.title;
    return 'EP. ${_currentIndex + 1} ${_lessons[_currentIndex].title}';
  }
}

// ─────────────────────────────────────────────────────────────
// THREAD PARTS
// ─────────────────────────────────────────────────────────────

/// One top-level card: a message, and the key its replies are filed under.
///
/// [key] is a string rather than the id because three kinds of card share this
/// list and only one of them has a server id: a server thread is `remote:<id>`,
/// a catalogue thread is `course:<index>`, and one posted on a catalogue course
/// is `local:<n>`. Keying a map by [CourseDiscussion] itself would merge two
/// real threads with the same text, and keying by list position would move a
/// reaction whenever a newer comment is posted above it.
class _QaCard {
  const _QaCard({required this.key, required this.comment});

  final String key;
  final CourseDiscussion comment;
}

/// The reaction a card is showing: the user's own state and the count.
///
/// Held as one value rather than two maps so an optimistic tap and its rollback
/// can never disagree about which half was applied.
class _Like {
  const _Like({required this.liked, required this.count});

  final bool liked;
  final int count;
}

/// The card the composer is answering, and the name to show it is answering.
class _ReplyTarget {
  const _ReplyTarget({required this.key, required this.author});

  final String key;
  final String author;
}

// ─────────────────────────────────────────────────────────────
// SMALL PARTS
// ─────────────────────────────────────────────────────────────

class _ToggleDot extends StatelessWidget {
  const _ToggleDot({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? _gold : Colors.transparent,
              border: Border.all(color: on ? _gold : _softGray),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// `Mark complete` on the lecture currently being watched.
///
/// Deliberately quiet — outlined, 10.5pt — because it sits where the design puts
/// the play badge, and the row's job is still to name the lecture.
class _MarkCompleteButton extends StatelessWidget {
  const _MarkCompleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 12, color: _ink),
            const SizedBox(width: 3),
            Text(
              'Mark complete',
              style: GoogleFonts.figtree(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;

  /// Null at either end of the course — the button greys out rather than
  /// wrapping around, which would be a surprise mid-lecture.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? _ink : _softGray;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _gold : _softGray;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Q&A tab when the first load failed.
///
/// Separate from [_EmptyState] because a failure is not an empty thread: it
/// needs a way back, and `No discussions yet` on a course with 300 of them
/// would be a lie.
class _ThreadErrorState extends StatelessWidget {
  const _ThreadErrorState({
    required this.message,
    required this.onRetry,
    this.title = 'Could not load the discussion',
  });

  final String message;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 34, color: _softGray),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.35,
                color: _gray,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: GoogleFonts.figtree(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: _softGray),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.35,
                color: _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
