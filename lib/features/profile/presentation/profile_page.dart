import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFE6B800);
const _streakBorder = Color(0xFFE2E8F0);
const _streakIconBg = Color(0xFFF8FAFC);

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
  Widget _buildProfileHeader() {
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
                  child: ClipOval(
                    child: Image.asset(
                      'assets/figma/instructorprofile/adobe-certified.png',
                      width: 107,
                      height: 107,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 107,
                        height: 107,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Camera badge
                Positioned(
                  top: 63,
                  left: 81,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                    },
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
                const Positioned(
                  top: 12,
                  left: 136,
                  child: SizedBox.shrink(),
                ),
                Positioned(
                  top: 12,
                  left: 136,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shuvanga Karki',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class 9',
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          color: _gray,
                        ),
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
            onTap: () {
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0x1F363636),
                  width: 1.5,
                ),
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
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 11,
              color: _gray,
            ),
          ),
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
              errorBuilder: (_, _, _) => Icon(
                fallbackIcon,
                size: 16,
                color: const Color(0xFF6366F1),
              ),
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
                onTap: () {
                },
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
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: _gray,
                    ),
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
                  onTap: () {
                  },
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
      onTap: () {
      },
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
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      color: _gray,
                    ),
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
                  onTap: () {
                  },
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
      onTap: () {
      },
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
                  child: const Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 32,
                  ),
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
    final labelColor =
        item.isDestructive ? const Color(0xFFEF4444) : _ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
      },
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
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
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
