import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/data/auth_repository.dart';
import '../data/profile_role.dart';
import '../data/user_profile.dart';
import 'complete_profile_gate.dart';
import 'edit_profile_page.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _streakBorder = Color(0xFFE2E8F0);
const _streakIconBg = Color(0xFFF8FAFC);

/// Course-card hairline and the "Edit" pill's fill — the same value, which is
/// why the reference's chip reads as a slightly darker patch on white.
const _cardBorder = Color(0xFFF3F4F6);

/// Fill of the dashed "Add New Course" tile. Sampled from the reference
/// (amber-50) — it is the only warm surface on the page.
const _addTileFill = Color(0xFFFFFBEB);

/// The two inactive tab glyphs. Sampled, not guessed: the active tab and its
/// underline are `_yellow`, the idle pair is this grey.
const _inactiveTab = Color(0xFF9CA3AF);

/// Identifies the header avatar — the photo when there is one, the placeholder
/// otherwise.
///
/// Public so a test can address the avatar directly. The page renders five other
/// `Image` widgets (streak, pencil, chevron icons), so `find.byType(Image)` is
/// ambiguous and cannot prove which one is the user's face.
const avatarKey = ValueKey<String>('profile-avatar');

/// Public profile destination used by the app shell and navigation tests.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('destination-Profile'),
      color: _bg,
      child: const InstructorProfilePage(),
    );
  }
}

class InstructorProfilePage extends StatefulWidget {
  const InstructorProfilePage({super.key});

  @override
  State<InstructorProfilePage> createState() => _InstructorProfilePageState();
}

class _InstructorProfilePageState extends State<InstructorProfilePage> {
  /// Which of the three icon tabs under About Me is showing.
  ///
  /// The reference only draws the first tab's panel (My Courses), so the other
  /// two keep the carousels that were already on this page rather than being
  /// dead. Defaults to 0, which is what the design shows.
  int _tabIndex = 0;

  /// The container this page listens to, and the subscription that makes the
  /// role arrive.
  ///
  /// **Why a subscription rather than a `ConsumerStatefulWidget`.** [_readOwnProfile]
  /// reads the store with `.read`, which does not subscribe — so this page used
  /// to work out its role once, at first build, and keep that answer forever.
  /// That is fine when the role is already known (signup writes it before the
  /// tab is ever built) and wrong after a sign-in, where the role lands a moment
  /// *after* the first build. The page then computed `effectiveRole` from a null
  /// role, got `student` from the fallback, and never rebuilt: an instructor was
  /// shown the student profile for the rest of the session.
  ///
  /// A `ConsumerStatefulWidget` would subscribe, but it requires a
  /// `ProviderScope` above it and several tests pump this page without one
  /// (`navigation_test` mounts the whole shell bare, and [_readOwnProfile]
  /// documents the same constraint). Listening through
  /// [ProviderScope.containerOf] keeps that degradation exactly as it was: no
  /// scope, no subscription, and the page behaves as it did before.
  ProviderContainer? _profileContainer;
  ProviderSubscription<UserProfile>? _profileSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchProfileStore();
  }

  @override
  void dispose() {
    // Ours to close: `container.listen` is not tied to this widget's lifecycle
    // the way `ref.listen` would be.
    _profileSubscription?.close();
    super.dispose();
  }

  /// Subscribes to the profile store, once per container.
  ///
  /// `didChangeDependencies` can run more than once, so the identity check keeps
  /// this from stacking subscriptions. The listener rebuilds on **any** profile
  /// change rather than only a role change: the header reads the name and avatar
  /// from the same store, and those arrive on the same fetch.
  void _watchProfileStore() {
    final ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      // No scope above this page — nothing to subscribe to. Same honest
      // degradation as [_readOwnProfile].
      return;
    }
    if (identical(container, _profileContainer)) return;

    _profileSubscription?.close();
    _profileContainer = container;
    _profileSubscription = container.listen<UserProfile>(userProfileProvider, (
      previous,
      next,
    ) {
      if (mounted) setState(() {});
    });
  }

  /// The instructor's own course list, as drawn in the reference: five cards
  /// plus the "Add New Course" tile, laid out two per row.
  ///
  /// **The artwork is not the obvious pairing.** The reference's
  /// "Adobe Certified Foundations" card shows a monitor on a desk with a window
  /// behind it — that is `adobe.png`, not `adobe-certified.png` (a monitor on a
  /// blue field). Its "The Art of Problem Solving" card shows a woman at a
  /// drawing table — `art.png`, not `problem.png` (a notebook and coffee).
  /// Both were checked against the reference crops pixel-for-pixel; see
  /// `.workbuddy-ai/tmp/art_match.png`.
  ///
  /// Do **not** reach for `ds.png` anywhere on this page: the file on disk is
  /// `DS.png`, and `Image.asset` matches the manifest key case-sensitively.
  static const _myCourses = <_MyCourse>[
    _MyCourse(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Adobe Certified Foundations',
      price: 'Rs.19.99',
    ),
    _MyCourse(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'The Art of Problem Solving',
      price: 'Rs.24.99',
    ),
    _MyCourse(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Adobe Certified Foundations',
      price: 'Rs.19.99',
    ),
    _MyCourse(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'The Art of Problem Solving',
      price: 'Rs.24.99',
    ),
    _MyCourse(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Adobe Certified Foundations',
      price: 'Rs.19.99',
    ),
  ];

  /// Stands in the instructor's "Add New Course" slot on a student's grid.
  ///
  /// Placeholder data like everything in [_myCourses] — it exists so the grid is
  /// the same shape for both roles, not because a sixth course is meaningful.
  static const _studentCourseSlot = _MyCourse(
    image: 'assets/figma/instructorprofile/art.png',
    title: 'Design Systems Fundamentals',
    price: 'Rs.21.99',
  );

  static const _savedShorts = <_SavedShort>[
    _SavedShort(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Quick UI Layout Tips',
      duration: '4:12',
      savedAgo: 'Saved • 2h ago',
    ),
    _SavedShort(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'Figma Auto Layout Tricks',
      duration: '3:08',
      savedAgo: 'Saved • 3d ago',
    ),
    _SavedShort(
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'Typography for Beginners',
      duration: '2:30',
      savedAgo: 'Saved • 5d ago',
    ),
  ];

  static const _savedCourses = <_SavedCourse>[
    _SavedCourse(
      image: 'assets/figma/instructorprofile/adobe.png',
      title: 'Advanced Illustrator',
      progress: '65% Complete',
      instructor: 'Prof. Karki',
    ),
    _SavedCourse(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'UI Design Systems',
      progress: '32% Complete',
      instructor: 'Prof. Karki',
    ),
    _SavedCourse(
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'Motion Graphics 101',
      progress: '12% Complete',
      instructor: 'Prof. Karki',
    ),
  ];

  static const _settings = <_SettingItem>[
    _SettingItem(label: 'Personal Information', trailingText: 'Verified'),
    _SettingItem(label: 'Notification Settings'),
    // Present in the reference between Notifications and Privacy, with the
    // balance as its trailing value. The reference writes it with a period
    // after "Rs" — "Rs.12,450.00", not "Rs 12,450.00".
    _SettingItem(label: 'Payment & Earnings', trailingText: 'Rs.12,450.00'),
    _SettingItem(label: 'Privacy Settings'),
    _SettingItem(label: 'Help & Support'),
    _SettingItem(label: 'Log Out', isDestructive: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(),
              _buildStreakRow(),
              _buildAboutMe(),
              _buildCourseTabs(),
              _buildTabContent(),
              _buildAccountSettings(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COURSE TABS  (icon row + gold underline on the active tab)
  //   Measured off the reference at a 390pt-wide frame:
  //     icon glyph 18–19pt  →  size 22
  //     icon box → underline gap 6, underline 56 × 4, radius 2
  //     underline → section heading 15
  //   The row is deliberately full-bleed: the reference's three tabs are
  //   spaced wider than the 358pt content column, so padding them by 16
  //   would pull the outer two inward and break the rhythm.
  // ─────────────────────────────────────────────────────────────
  static const _tabs = <_CourseTab>[
    _CourseTab(icon: Icons.menu_book_outlined, label: 'My Courses'),
    _CourseTab(icon: Icons.play_circle_outline, label: 'Saved Shorts'),
    _CourseTab(icon: Icons.bookmark_border, label: 'Saved Courses'),
  ];

  Widget _buildCourseTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
      child: Row(
        children: [
          for (int i = 0; i < _tabs.length; i++)
            Expanded(
              child: Semantics(
                label: _tabs[i].label,
                button: true,
                selected: _tabIndex == i,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tabIndex = i),
                  child: Column(
                    children: [
                      Icon(
                        _tabs[i].icon,
                        size: 22,
                        color: _tabIndex == i ? _yellow : _inactiveTab,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 56,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _tabIndex == i ? _yellow : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The panel under the tab row. The reference only shows tab 0.
  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 1:
        return _buildSavedShorts();
      case 2:
        return _buildSavedCourses();
      default:
        return _buildMyCourses();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MY COURSES  (2-column grid; instructors also get a dashed
  // "Add New Course" tile — see _buildCourseGrid)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMyCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Courses',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Text(
                  'See All (40)',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCourseGrid(),
        ],
      ),
    );
  }

  /// Lays the tiles out two per row.
  ///
  /// Not a `GridView`: a fixed `childAspectRatio` would pin the card to the
  /// reference's 163×144 and then clip the title/price block on any narrower
  /// device. Instead the photo is a fixed 90pt and the text block is
  /// content-sized, with `IntrinsicHeight` equalising the row so the dashed
  /// tile matches the height of the card beside it.
  ///
  /// **Why `Expanded`, and why the earlier `Flexible` was wrong.** Both tiles are
  /// `Expanded`, so each gets exactly half the row: `(width - 32) / 2`. That is
  /// **148pt** at the 360pt target and **163pt** at the 390pt reference — and 163
  /// is the number the design draws, which is what pins the geometry.
  ///
  /// `Flexible` (the default loose fit) looks equivalent and is not.
  /// `RenderFlex._constraintsForFlexChild` gives a loose child `minWidth: 0.0`,
  /// so a tile whose content is *narrower* than its share simply shrinks to fit
  /// its content. The dashed "Add New Course" tile's widest child is its 90pt
  /// label, so it collapsed to roughly that beside a 148pt course card and left
  /// **72pt of dead space** at the end of the row. Tight constraints are what
  /// make the two tiles equal, and the label needs no cap of its own: 90pt sits
  /// in 148pt with 58pt to spare, so it stays on one line — which is what the
  /// reference draws.
  ///
  /// The comment that used to sit here claimed `Flexible` "keeps them equal,
  /// because both children ask for the same basis". They do not: the card holds
  /// a `SizedBox(width: double.infinity)` and takes its whole share, while the
  /// dashed tile takes only its content width. Read from the SDK source, not
  /// inferred — see `rendering/flex.dart`, `_constraintsForFlexChild`.
  Widget _buildCourseGrid() {
    // The first slot is role-specific. An instructor gets the dashed "Add New
    // Course" tile; a student gets a course card in its place, because a student
    // cannot author a course — and drawing the tile for both meant a student
    // tapping it was sent through a profile-completion flow for an action they
    // can never take. Filling the slot rather than dropping it also keeps the
    // grid at a full three rows for both roles.
    return _buildTwoColumnGrid(<Widget>[
      if (_isInstructor)
        _buildAddCourseTile()
      else
        _buildMyCourseCard(_studentCourseSlot),
      for (final course in _myCourses) _buildMyCourseCard(course),
    ]);
  }

  /// Two tiles per row, 32pt between columns, 12pt between rows.
  ///
  /// Not a `GridView`: a fixed `childAspectRatio` would pin the cards to the
  /// reference's 163×145 and then clip their text block on any narrower device.
  /// Instead the photo is a fixed height and the text block is content-sized,
  /// with `IntrinsicHeight` equalising the row so a tile carrying less content
  /// (the dashed "Add New Course" slot) still matches its neighbour.
  ///
  /// **Width and height are equalised by two different mechanisms, and both are
  /// needed.** Width comes from `Expanded` — a tight constraint of
  /// `(available - 32) / 2` each. Height comes from `IntrinsicHeight` plus
  /// `CrossAxisAlignment.stretch`. Drop the first and the dashed tile collapses
  /// to its label's width; drop the second and it stops matching the card's
  /// height. Neither substitutes for the other.
  Widget _buildTwoColumnGrid(List<Widget> tiles) {
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `Expanded`, not `Flexible` — see [_buildCourseGrid]. A loose
              // `Flexible` child may be narrower than its share, which is what
              // let the dashed tile collapse to the width of its own label.
              Expanded(child: tiles[i]),
              const SizedBox(width: 32),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  /// The dashed gold tile: 30pt gold disc with a white plus, then the label,
  /// the pair centred vertically in the tile.
  Widget _buildAddCourseTile() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openAddCourse,
      child: CustomPaint(
        painter: const _DashedRoundedBorder(color: _yellow, radius: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _addTileFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _yellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),
              // **No `ConstrainedBox` here, and removing it is the fix.** The
              // label was capped at `maxWidth: 76`, which forced it onto two
              // lines. The reference draws it on **one**. Measured off the Figma
              // capture: the label is 117px inside a 198px tile — a ratio of
              // 0.59 — and this label at 12pt is 89.6pt inside a 148pt tile, a
              // ratio of 0.61. Same proportion, same single line, so the type
              // size was already right and the cap was the only thing breaking
              // it.
              //
              // The cap was added to stop an overflow that was itself a symptom.
              // The grid then used `Flexible` (a loose fit), so this tile
              // collapsed to its content width, the 89.6pt label overflowed it,
              // and the cap then *became* the tile's width — the wrap defined the
              // width that caused the wrap. With `Expanded` the tile is a fixed
              // 148pt and the label sits in it with ~58pt to spare.
              //
              // The tile's own width is the constraint now: a `Text` in a
              // `Column` lays out within the incoming `maxWidth`, so a narrow
              // device wraps it without help. `maxLines` and the ellipsis stay as
              // the guard for exactly that case.
              Text(
                'Add New Course',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _yellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCourseCard(_MyCourse course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            width: double.infinity,
            child: Image.asset(
              course.image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFE5E7EB),
                child: const Icon(Icons.image, color: Colors.white, size: 32),
              ),
            ),
          ),
          // 10 / 10 / 9, not 12: the reference's title ink starts 9.6pt from the
          // card's left edge, its price 10.3pt, and the Edit pill's right edge
          // sits 10.4pt in from the card's right; the pill's own baseline leaves
          // 9pt below it. That budget also decides the truncation — at 12pt
          // "Adobe Certified Found…" needs 140.7pt of the 141pt available and
          // fits, which is what the reference shows.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                // 3, not 5: the title's line box ends 3.5pt above the Edit pill
                // in the reference, and the whole text block is only 54pt tall.
                const SizedBox(height: 3),
                Row(
                  children: [
                    // `Flexible` + ellipsis rather than a bare `Text`: this row
                    // shares a narrow column with a right-aligned badge, and an
                    // unbounded price is what overflowed it by 13pt. The price is
                    // the thing that can afford to lose a character; the badge is
                    // not, so the badge keeps its natural width.
                    Flexible(
                      child: Text(
                        course.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _yellow,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _cardBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.figtree(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _gray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROFILE HEADER  (avatar + camera badge + name + stats + edit)
  // ─────────────────────────────────────────────────────────────

  /// The signed-in user's own profile, filled by `SessionBootstrap` from
  /// `GET /me/`. Read once per build rather than per label so the two texts
  /// cannot disagree.
  ///
  /// **Watched, not read-and-forgotten.** `containerOf` with its default
  /// `listen: true` registers a dependency on the scope, so this page rebuilds
  /// when the fetch lands. Reading it once with no dependency — or passing
  /// `listen: false` — would render the placeholder and never update, which
  /// looks exactly like the hardcoded name this replaced.
  ///
  /// **Returns an empty profile when there is no scope above this widget**
  /// rather than throwing. `main.dart` always provides one, so the app is
  /// unaffected, but this page is pumped bare by `navigation_test` and by
  /// `edit_profile_test`, and crashing a whole screen because a provider is
  /// absent turns a missing test harness into a fake app failure. An empty
  /// profile is the honest degradation: the header shows its neutral
  /// placeholders, which is what it did before any of this existed.
  UserProfile _readOwnProfile() {
    // `containerOf` throws when no scope is found — it has no nullable form —
    // so the absence has to be caught rather than tested for.
    try {
      return ProviderScope.containerOf(context).read(userProfileProvider);
    } on StateError {
      return const UserProfile();
    }
  }

  /// Which of the two profiles this page is rendering.
  ///
  /// **The student and instructor profiles are separate screens** that share most
  /// of their chrome. They diverge in exactly two places:
  ///
  /// * the header's three stats — a learner counts badges and challenges, a
  ///   teacher counts students and a rating (the same figures the public
  ///   instructor profile shows);
  /// * the first slot of the My Courses grid — the dashed "Add New Course" tile
  ///   for an instructor, a course card for a student, who cannot author one.
  ///
  /// Everything else — avatar, name, streak, About Me, saved shorts, saved
  /// courses, account settings — is deliberately shared. Two near-identical
  /// copies of this body would drift apart the first time either was edited,
  /// which is why the divergence is expressed here rather than duplicated.
  bool get _isInstructor =>
      _readOwnProfile().effectiveRole == ProfileRole.instructor;

  /// Opens the edit screen for this user's role.
  ///
  /// Read at tap time rather than hardcoding student: an instructor has to land
  /// on the instructor field set, and the role is only known once signup has
  /// recorded it.
  ///
  /// Uses [_readOwnProfile]'s container lookup so a missing scope degrades to
  /// the student field set instead of throwing — see that method for why.
  void _openEditProfile() {
    final role = _readOwnProfile().effectiveRole;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditProfilePage(role: role)));
  }

  /// The "Add New Course" tile. Publishing needs a complete instructor profile,
  /// so the gate runs first and names whatever is still missing.
  ///
  /// **Reads the container defensively rather than taking a `ref`.** This page is
  /// a plain `StatefulWidget` because several tests pump it with no
  /// `ProviderScope` above it, so it cannot become a `ConsumerStatefulWidget`
  /// without crashing those pumps. With no scope there is nothing to gate
  /// against and the tap does nothing — the same honest degradation
  /// [_readOwnProfile] already makes for the header.
  ///
  /// The required fields come from the signed-in role, so an instructor is asked
  /// for qualification and expertise rather than a class and a school.
  Future<void> _openAddCourse() async {
    final ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return;
    }
    if (!mounted) return;

    final allowed = await ensureCanAddCourse(context, container);
    if (!allowed || !mounted) return;

    // There is no course-creation screen yet. The gate is what this tile owes
    // the user today; this is the seam the real screen drops into.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course creation is coming soon.')),
    );
  }

  /// The user's own photo, or a neutral placeholder when there is none.
  ///
  /// **This used to be a hardcoded `Image.asset`**
  /// (`assets/figma/instructorprofile/adobe-certified.png`), so every account —
  /// student or instructor, photo picked or not — saw the same stock portrait.
  /// The name beside it was fixed at the same time; this is the other half of
  /// that bug.
  ///
  /// Rendered from [UserProfile.photoBytes] with `Image.memory`, matching
  /// [ProfilePhotoPicker]. Not a URL and not a `File`:
  /// - `GET /me/` returns **no photo field at all** (confirmed live and against
  ///   the OpenAPI schema, where `profile_photo` appears only in the two
  ///   *registration* schemas), so there is no server URL to load yet.
  /// - `Image.file` asserts `!kIsWeb`, and this app ships to Flutter web.
  ///
  /// The bytes are the ones picked at signup, carried in the store, or set by
  /// Edit Profile — so this is the same photo the user chose, and it appears
  /// without a round trip.
  Widget _buildAvatar(UserProfile profile) {
    final bytes = profile.photoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        key: avatarKey,
        width: 107,
        height: 107,
        fit: BoxFit.cover,
        // A truncated or corrupt image must not blank the whole header — and
        // this builder is also what keeps a decode failure from surfacing as a
        // test failure: Flutter sets `reportErrors: errorBuilder == null`
        // (`widgets/image.dart:1233`), so supplying it *suppresses* the error.
        // `logout_clears_session_test` stores `[1, 2, 3]` as a photo, which is
        // not a decodable image, and relies on exactly that.
        errorBuilder: (_, _, _) => _buildAvatarPlaceholder(),
      );
    }
    return _buildAvatarPlaceholder();
  }

  /// What an account with no photo shows: a neutral silhouette, not someone
  /// else's face.
  Widget _buildAvatarPlaceholder() {
    return Container(
      key: avatarKey,
      width: 107,
      height: 107,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person, size: 48, color: Colors.white),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _readOwnProfile();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          // ── Avatar + name + stats row ─────────────────────
          SizedBox(
            height: 107,
            child: Stack(
              children: [
                // Avatar
                Positioned(
                  top: 0,
                  left: 0,
                  child: ClipOval(child: _buildAvatar(profile)),
                ),
                // Camera badge
                Positioned(
                  top: 63,
                  left: 81,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Opens the same editor the button below does, because that
                    // is where the photo is actually changed. It used to be
                    // `onTap: () {}` — a badge that looks pressable and does
                    // nothing is worse than no badge.
                    onTap: _openEditProfile,
                    child: Container(
                      width: 26,
                      height: 27,
                      decoration: BoxDecoration(
                        color: _yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x21000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Name + Class
                const Positioned(top: 12, left: 136, child: SizedBox.shrink()),
                Positioned(
                  top: 12,
                  left: 136,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The signed-in user, from `GET /me/`. Falls back to a
                        // neutral label rather than a placeholder name: this
                        // used to be the hardcoded 'Shuvanga Karki', which meant
                        // every account saw a stranger's name on their own
                        // profile. A real name appears once the fetch lands.
                        profile.valueFor('name').isNotEmpty
                            ? profile.valueFor('name')
                            : 'Your profile',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // The grade the user picked, or the role while it is
                        // still empty — 'Class 9' here was hardcoded too.
                        profile.valueFor('grade').isNotEmpty
                            ? profile.valueFor('grade')
                            : profile.effectiveRole.label,
                        style: GoogleFonts.figtree(fontSize: 10, color: _gray),
                      ),
                    ],
                  ),
                ),
                // Stats, role-specific: a learner counts badges, courses and
                // challenges; a teacher counts students, courses and a rating —
                // the same figures the public instructor profile shows.
                //
                // **A `Row` of three equal columns, not three `Positioned`s.**
                // The old version hardcoded `left: 107 / 203 / 279` for boxes of
                // 80 / 77 / 80, which does not fit the space it has: 80 + 16 + 77
                // + 16 + 80 = 269pt in the 267pt between the avatar's edge (107)
                // and the right padding (390 - 16). The compromise was `left: 279`
                // — so the third box began **1pt before the second one ended**.
                // The boxes overlapped and the gaps came out 16pt then -1pt.
                // `Expanded` divides whatever width is actually there, so the
                // spacing is even and cannot overlap at any screen size.
                //
                // Measured off the reference: its stat ink sits at 176.8 / 255.0 /
                // 319.5 with the dividers at 217.4 and 293.0, and its three
                // columns are 75.6pt each. Equal thirds across the 251pt here
                // (123 to 374) gives 83pt columns and puts the ink at 164.5 /
                // 248.5 / 332.5 — within ~13pt on the outer two, and the dividers
                // at 206.5 / 290.5 against 217.4 / 293.0. That residual is inside
                // the reference's own irregularity: its column centres are 78.2pt
                // then 64.5pt apart, so it is not evenly divided either, and equal
                // columns is the version that survives a different screen width.
                Positioned(
                  top: 64,
                  left: 107,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          _isInstructor ? '915.2K' : '45',
                          _isInstructor ? 'Students' : 'Badges',
                        ),
                      ),
                      _statDivider(),
                      Expanded(child: _buildMiniStat('40', 'Courses')),
                      _statDivider(),
                      Expanded(
                        child: _buildMiniStat(
                          _isInstructor ? '4.9' : '25',
                          _isInstructor ? 'Rating' : 'Challenge',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openEditProfile,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1F363636), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/figma/instructorprofile/pencil.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF363636),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profile Settings',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF363636),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One stat: the value over its label, centred in whatever box it is handed.
  ///
  /// **No width of its own.** It used to carry `SizedBox(width: 80)` — 80 for the
  /// outer two, unconstrained for the middle — which is what forced the row onto
  /// hardcoded positions and produced the overlap. `Expanded` supplies the width.
  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 2),
        // 10, not 11: "Students" measures 42.2pt of ink in the reference and
        // Figtree w400 @10pt gives 41.8. @11pt would be 45.2.
        Text(label, style: GoogleFonts.figtree(fontSize: 10, color: _gray)),
      ],
    );
  }

  /// The hairline between two stats.
  ///
  /// A fixed-height `Container`, not a [VerticalDivider]: that widget takes its
  /// height from the row it sits in — which here is the whole header — so the
  /// line would run from the name down past the button. The reference draws it
  /// 43pt tall, spanning the value and its label with a few points either side.
  Widget _statDivider() => Container(width: 1, height: 43, color: _border);

  // ─────────────────────────────────────────────────────────────
  // STREAK / RANK ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildStreakRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStreakCard(
              iconPath: 'assets/figma/instructorprofile/flame.png',
              fallbackIcon: Icons.local_fire_department_outlined,
              label: 'Daily Streak',
              value: '12 Days',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStreakCard(
              iconPath: 'assets/figma/instructorprofile/award.png',
              fallbackIcon: Icons.emoji_events_outlined,
              label: 'Current Rank',
              value: '#5',
              trailing: 'Active',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard({
    required String iconPath,
    required IconData fallbackIcon,
    required String label,
    required String value,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _streakBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _streakIconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _streakBorder),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              iconPath,
              width: 16,
              height: 16,
              errorBuilder: (_, _, _) =>
                  Icon(fallbackIcon, size: 16, color: const Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 1),
                // A stat can be a long token — `915.2K` measures 44.6pt in the
                // font the test runner substitutes, against the 84pt this column
                // gets at a 360pt viewport, and a three-digit value with a `+`
                // suffix is longer still. Both children are `Flexible` so neither
                // is allowed to push the row past its box; the value gives ground
                // first because the suffix is short and carries meaning.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          trailing,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ABOUT ME
  //   The 40pt bottom gap is measured, not stylistic: in the reference the
  //   last bio line's box ends 41pt above the tab icons, and the icon row
  //   itself carries no top padding.
  // ─────────────────────────────────────────────────────────────
  Widget _buildAboutMe() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'About Me',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Image.asset(
                    'assets/figma/instructorprofile/pencil.png',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.edit_outlined, size: 14, color: _gray),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // The reference's instructor bio, not a student's. w400, not w500:
            // line 1 measures 351.8pt of ink and only w400 @14pt produces that
            // (w500 would be 359pt and would not fit the 358pt column, so it
            // would wrap a word earlier than the reference does).
            'Prof. Karki is an expert illustrator and digital arts certified '
            'educator with over 12 years of teaching design theory, UI '
            'concepts, and logical visual structures to over 900k pupils '
            'world-wide.',
            style: GoogleFonts.figtree(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SAVED SHORTS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSavedShorts() {
    return Padding(
      // Symmetric, unlike the carousel this used to be. A horizontal list runs
      // its last card off the screen edge, so it carried no right padding of its
      // own and added one to the header instead. A grid has a real right edge.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    'Saved Shorts',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // **A two-column grid, not the horizontal carousel this used to be.**
          // The reference draws four cards in two visible rows, which a
          // horizontally-scrolling list cannot produce — the same finding that
          // already converted `_buildSavedCourses`, and the same fix.
          //
          // The `SizedBox(height: 277)` that used to wrap the list is gone with
          // it: that box existed to give the carousel a bounded height to flex
          // its thumbnails into, and a grid row takes its height from its content
          // instead. See `_buildShortCard` for what replaced the `Expanded`.
          _buildTwoColumnGrid(<Widget>[
            for (final short in _savedShorts) _buildShortCard(short),
          ]),
        ],
      ),
    );
  }

  Widget _buildShortCard(_SavedShort short) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: 163,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A **fixed 220pt**, not the `Expanded` this used to be.
            //
            // `Expanded` was right in the old horizontal carousel, which wrapped
            // the list in a `SizedBox(height: 277)` and so handed the card a
            // bounded height to flex into. A two-column grid row is an
            // `IntrinsicHeight`, which measures its children with an *unbounded*
            // height, and a flex child on an unbounded main axis is a hard error —
            // "RenderFlex children have non-zero flex but incoming height
            // constraints are unbounded". `_buildSavedCourseCard` and
            // `_buildMyCourseCard` both use a fixed image height for this reason.
            //
            // 220 is the design's thumbnail, measured off the reference at 275px
            // against a 1.256 px/pt scale. Nothing overflows as a result, because
            // the card now takes its height from its content rather than from a
            // fixed box — which is what `Expanded` was originally working around.
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    short.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.video_library_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        short.duration,
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    short.title,
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
                    short.savedAgo,
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

  // ─────────────────────────────────────────────────────────────
  // SAVED COURSES
  //   A two-column grid, not the horizontal carousel this used to be: the
  //   reference shows a second row of cards starting 160pt below the first
  //   (card 148 + 12 gutter), which a horizontal list cannot produce.
  // ─────────────────────────────────────────────────────────────
  Widget _buildSavedCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    'Saved Courses',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTwoColumnGrid(<Widget>[
            for (final course in _savedCourses) _buildSavedCourseCard(course),
          ]),
        ],
      ),
    );
  }

  Widget _buildSavedCourseCard(_SavedCourse course) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: 163,
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
              height: 90,
              width: double.infinity,
              child: Image.asset(
                course.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(Icons.image, color: Colors.white, size: 32),
                ),
              ),
            ),
            // 9 / 12pt title / 7 gap — measured: the title's ink starts 103.5pt
            // from the card top (image 90 + 9 padding + the 12pt line box's
            // 4.5pt ascent offset) and the progress row sits 7.5pt under the
            // title's line box, which lands the card at 148pt.
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          course.progress,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _yellow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.instructor,
                          style: GoogleFonts.figtree(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _gray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACCOUNT SETTINGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildAccountSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'ACCOUNT SETTINGS',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        for (int i = 0; i < _settings.length; i++)
          _buildSettingItem(_settings[i], isLast: i == _settings.length - 1),
      ],
    );
  }

  Widget _buildSettingItem(_SettingItem item, {required bool isLast}) {
    final labelColor = item.isDestructive ? const Color(0xFFEF4444) : _ink;
    // The reference tints Log Out's chevron with its label; every other row's
    // chevron is _gray (#4B5563) — sampled, not the lighter #9CA3AF this used
    // to be, which is reserved for the trailing value text.
    final chevronColor = item.isDestructive ? const Color(0xFFEF4444) : _gray;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.isDestructive ? _logout : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : const Color(0xFFF3F4F6),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
            if (item.trailingText != null) ...[
              Text(
                item.trailingText!,
                // 12, not 13: "Rs.12,450.00" measures 67.7pt of ink and
                // Figtree @12pt gives 67.5. @13pt would be 73.
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 18, color: chevronColor),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    // Tell the server first, then clear locally. The backend blacklists the
    // refresh token (handoff §11), so skipping this call would leave it usable
    // for the rest of its 7 days. `logOut` is best effort and never throws, so
    // the local clear happens either way.
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(authRepositoryProvider).logOut();
    if (!mounted) return;

    // Clear the profile store too. Dropping only the session left the previous
    // user's name, photo and documents behind, so the next person to sign in on
    // this device would see them — including on the profile screens, which read
    // straight from here. `clear()` existed for this and was never called.
    container.read(userProfileProvider.notifier).clear();
    context.go('/login-screen');
  }
}

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────
class _SavedShort {
  const _SavedShort({
    required this.image,
    required this.title,
    required this.duration,
    required this.savedAgo,
  });

  final String image;
  final String title;
  final String duration;
  final String savedAgo;
}

class _SavedCourse {
  const _SavedCourse({
    required this.image,
    required this.title,
    required this.progress,
    required this.instructor,
  });

  final String image;
  final String title;
  final String progress;
  final String instructor;
}

class _SettingItem {
  const _SettingItem({
    required this.label,
    this.trailingText,
    this.isDestructive = false,
  });

  final String label;
  final String? trailingText;
  final bool isDestructive;
}

class _CourseTab {
  const _CourseTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _MyCourse {
  const _MyCourse({
    required this.image,
    required this.title,
    required this.price,
  });

  final String image;
  final String title;
  final String price;
}

/// Draws the "Add New Course" outline.
///
/// Hand-rolled because Flutter has no dashed `Border`, and a solid one reads as
/// a filled card rather than an empty slot. Dash 4 / gap 3 at 1pt reproduces
/// the reference's 9pt repeat.
///
/// The path is inset half a stroke so the line is not clipped at the edges —
/// the painter's canvas is exactly the child's size, with no overflow room.
class _DashedRoundedBorder extends CustomPainter {
  const _DashedRoundedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 4.0;
  static const _gap = 3.0;
  static const _stroke = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    // A box narrower than one stroke would make the inset rect negative and
    // trip an assert inside `RRect.fromRectAndRadius`.
    if (size.width <= _stroke || size.height <= _stroke) return;

    const inset = _stroke / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - _stroke,
            size.height - _stroke,
          ),
          Radius.circular(radius),
        ),
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        // Clamped by hand rather than `clamp()`: `num.clamp` only narrows to
        // `double` under the analyzer's special-case rules, and this reads
        // unambiguously either way.
        var end = start + _dash;
        if (end > metric.length) end = metric.length;
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
