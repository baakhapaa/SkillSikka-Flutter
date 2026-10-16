import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../data/enrollment.dart';

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

  /// Discussions the user has reacted to in this session. Local, because there
  /// is no endpoint to send a reaction to.
  final Set<int> _reacted = <int>{};

  /// Comments posted from the composer on this screen, newest first.
  final List<CourseDiscussion> _localComments = <CourseDiscussion>[];

  /// How many comments show before `View more`, and whether it has been tapped.
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
  /// The null branch is the one every catalogue lecture takes, and it is what
  /// keeps `video_player` — which has no platform implementation under
  /// `flutter test` — off the path of any test that renders this screen.
  void _syncVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;

    final asset = _lessons.isEmpty ? null : _lessons[_currentIndex].videoAsset;
    if (asset == null) return;

    final controller = VideoPlayerController.asset(asset);
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _videoReady = true);
      if (_autoPlay) controller.play();
    });
    controller.addListener(_onVideoTick);
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
      store.markComplete(_course, leaving);
    }
  }

  /// This course's row in the store, or null when it is not enrolled.
  ///
  /// Watches the **state**, not the notifier: progress is written from this
  /// screen, so the lesson rows have to rebuild when it changes or a finished
  /// lecture would keep its play icon until something else happened to rebuild.
  Enrollment? get _enrollment {
    for (final enrollment in ref.watch(enrolledCoursesProvider)) {
      if (enrollment.course.title == _course.title) return enrollment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildVideoArea(),
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

  Widget _buildVideoArea() {
    final controller = _videoController;
    final lesson = _lessons.isEmpty ? null : _lessons[_currentIndex];

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && _videoReady)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              // The lecture's still. Every catalogue lecture has a null video,
              // so this is what actually renders — the course's own thumbnail,
              // dimmed, with the lecture's title over it.
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_course.image, fit: BoxFit.cover),
                  const ColoredBox(color: Color(0x8C0B0B0B)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            lesson?.title ?? _course.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                onTap: () => setState(() => _tabIndex = index),
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

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: rows);
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
    final complete = _enrollment?.completed.contains(index) ?? false;

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
    final resources = _course.resources;

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
                '${resources.length} files',
                style: GoogleFonts.inter(fontSize: 11, color: _softGray),
              ),
            ],
          ),
        ),
        if (resources.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: _EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No files for this course',
              body: 'The instructor has not attached any resources yet.',
            ),
          )
        else
          for (final resource in resources) _buildResourceRow(resource),
      ],
    );
  }

  Widget _buildResourceRow(CourseResource resource) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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
                      resource.type.label,
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
                child: const Icon(
                  Icons.file_download_outlined,
                  size: 15,
                  color: _gray,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Q&A
  // ─────────────────────────────────────────────────────────────

  Widget _buildQaTab() {
    // Comments posted on this screen sit on top of the course's thread, newest
    // first. See `_postComment` for why they are held here and not in the store.
    final discussions = <CourseDiscussion>[
      ..._localComments,
      ..._course.discussions,
    ];
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
              // Derived from the thread, like every other count on this screen.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _fill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${discussions.length}',
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
            child: Row(
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
                      hintText: 'Add to the discussion...',
                      hintStyle: GoogleFonts.figtree(
                        fontSize: 12.5,
                        color: _softGray,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _postComment,
                  icon: const Icon(Icons.send, size: 18),
                  color: _ink,
                  tooltip: 'Post',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: discussions.isEmpty
              ? const _EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No discussions yet',
                  body: 'Be the first to ask something about this course.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      _buildDiscussionCard(discussions[i], i),
                    if (!_showAllComments &&
                        discussions.length > _commentPreview)
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _showAllComments = true),
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
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDiscussionCard(CourseDiscussion discussion, int index) {
    final reacted = _reacted.contains(index);
    final reactions = discussion.reactions + (reacted ? 1 : 0);

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
                icon: reacted ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: reactions == 0 ? 'React' : '$reactions',
                active: reacted,
                onTap: () => setState(() {
                  if (!_reacted.remove(index)) _reacted.add(index);
                }),
              ),
              const SizedBox(width: 18),
              _CardAction(
                icon: Icons.chat_bubble_outline,
                label: 'Reply',
                // Not a dead control: replying is what the composer above is
                // for, so this puts the cursor in it and names who is being
                // answered.
                onTap: () {
                  _composer.text = '@${discussion.author} ';
                  _composer.selection = TextSelection.collapsed(
                    offset: _composer.text.length,
                  );
                  _composerFocus.requestFocus();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Posts the composer's text as a new comment.
  ///
  /// **Local only.** There is no discussions endpoint, so the message is held in
  /// this screen's state and is gone when it closes. It is not written to the
  /// store, because the store is not persisted either — a comment that survived
  /// one screen and not the next would be worse than one that does not survive
  /// at all.
  void _postComment() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _localComments.add(CourseDiscussion('You', 'Student', 'Just now', text));
      _composer.clear();
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
