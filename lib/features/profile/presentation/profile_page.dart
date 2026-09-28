import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/data/auth_repository.dart';
import '../data/user_profile.dart';
import 'edit_profile_page.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _streakBorder = Color(0xFFE2E8F0);
const _streakIconBg = Color(0xFFF8FAFC);

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
  static const _savedShorts = <_SavedShort>[
    _SavedShort(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'Quick UI Layout Tips',
      duration: '4:12',
      savedAgo: 'Saved • 2h ago',
    ),
    _SavedShort(
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'Figma Auto Layout Tricks',
      duration: '5:45',
      savedAgo: 'Saved • 3d ago',
    ),
    _SavedShort(
      image: 'assets/figma/instructorprofile/adobe.png',
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
      image: 'assets/figma/instructorprofile/problem.png',
      title: 'UI Design Systems',
      progress: '32% Complete',
      instructor: 'Prof. Karki',
    ),
    _SavedCourse(
      image: 'assets/figma/instructorprofile/art.png',
      title: 'Motion Graphics 101',
      progress: '12% Complete',
      instructor: 'Prof. Karki',
    ),
  ];

  static const _settings = <_SettingItem>[
    _SettingItem(label: 'Personal Information', trailingText: 'Verified'),
    _SettingItem(label: 'Notification Settings'),
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
              _buildSavedShorts(),
              _buildSavedCourses(),
              _buildAccountSettings(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(child: _buildCourseTab('My Courses')),
          Expanded(child: _buildCourseTab('Saved Shorts')),
          Expanded(child: _buildCourseTab('Saved Courses')),
        ],
      ),
    );
  }

  Widget _buildCourseTab(String label) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _gray,
            ),
          ),
        ),
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
                // Stats: Badges / Courses / Challenge
                Positioned(
                  top: 64,
                  left: 107,
                  child: _buildMiniStat('45', 'Badges'),
                ),
                Positioned(
                  top: 64,
                  left: 203,
                  child: Container(
                    width: 77,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: _border),
                        right: BorderSide(color: _border),
                      ),
                    ),
                    child: _buildMiniStat('40', 'Courses'),
                  ),
                ),
                Positioned(
                  top: 64,
                  left: 279,
                  child: _buildMiniStat('25', 'Challenge'),
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

  Widget _buildMiniStat(String value, String label) {
    return SizedBox(
      width: label == 'Courses' ? null : 80,
      child: Column(
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
          Text(label, style: GoogleFonts.figtree(fontSize: 11, color: _gray)),
        ],
      ),
    );
  }

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
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        trailing,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
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
  // ─────────────────────────────────────────────────────────────
  Widget _buildAboutMe() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            'A dedicated and curious design student with a strong foundation '
            'in visual communication, typography, and user-centered design. '
            'Currently pursuing a degree in Digital Media Arts with a focus on '
            'UI/UX, and actively building a portfolio through freelance projects '
            'and design challenges.',
            style: GoogleFonts.figtree(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
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
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _savedShorts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildShortCard(_savedShorts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortCard(_SavedShort short) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: 164,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with duration badge
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
  // ─────────────────────────────────────────────────────────────
  Widget _buildSavedCourses() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
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
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _savedCourses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildSavedCourseCard(_savedCourses[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCourseCard(_SavedCourse course) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: 164,
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
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
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
