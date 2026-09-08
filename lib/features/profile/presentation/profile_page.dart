import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int? _selectedCourseTab;

  void _selectCourseTab(int index) {
    if (index == _selectedCourseTab) return;
    setState(() => _selectedCourseTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('destination-Profile'),
      color: const Color(0xFFFAF9F6),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 46),
              _ProfileHeader(),
              const SizedBox(height: 10),
              _ProgressCards(),
              const SizedBox(height: 10),
              _AboutSection(),
              const SizedBox(height: 10),
              _CourseTabs(
                selectedIndex: _selectedCourseTab,
                onSelected: _selectCourseTab,
              ),
              const SizedBox(height: 10),
              _CourseContent(selectedIndex: _selectedCourseTab),
              const SizedBox(height: 10),
              const _AccountSettings(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 107,
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/figma/profile/avatar_new.png',
                        width: 107,
                        height: 107,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 15,
                      child: Container(
                        width: 26,
                        height: 27,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6B800),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x21000000),
                              blurRadius: 2,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/figma/profile/camera_new.svg',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prof. Shuvanga Karki',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF111827),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Adobe Certified Instructor & Illustrator',
                          style: GoogleFonts.figtree(
                            color: const Color(0xFF4B5563),
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        const Row(
                          children: [
                            _Stat(value: '915.2K', label: 'Students'),
                            _Stat(
                              value: '40',
                              label: 'Courses',
                              bordered: true,
                            ),
                            _Stat(value: '4.9', label: 'Rating'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: SvgPicture.asset(
              'assets/figma/profile/edit_new.svg',
              width: 16,
              height: 16,
            ),
            label: const Text('Edit Profile Settings'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: const Color(0xFF363636),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0x1F363636), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.bordered = false,
  });

  final String value;
  final String label;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: bordered
              ? const Border.symmetric(
                  vertical: BorderSide(color: Color(0xFFEAEAEA)),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                color: const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.figtree(
                color: const Color(0xFF4B5563),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCards extends StatelessWidget {
  const _ProgressCards();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: const [
          Expanded(
            child: _ProgressCard(
              title: 'Daily Streak',
              value: '12 Days',
              asset: 'assets/figma/profile/flame_new.svg',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _ProgressCard(
              title: 'Current Rank',
              value: '#5',
              suffix: 'Active',
              asset: 'assets/figma/profile/award_new.svg',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.value,
    required this.asset,
    this.suffix,
  });

  final String title;
  final String value;
  final String asset;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(asset),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (suffix != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        suffix!,
                        style: GoogleFonts.figtree(
                          color: const Color(0xFF6366F1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('About Me', style: _headingStyle),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/figma/profile/edit_bio_new.svg',
                  width: 14,
                  height: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Prof. Karki is an expert illustrator and digital arts certified educator with over 12 years of teaching design theory, UI concepts, and logical visual structures to over 900k pupils world-wide.',
            style: GoogleFonts.figtree(
              color: const Color(0xFF4B5563),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyCoursesSection extends StatelessWidget {
  const _MyCoursesSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'My Courses', action: 'See All (40)'),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _AddCourseCard()),
              SizedBox(width: 32),
              Expanded(
                child: _CourseCard(
                  title: 'Adobe Certified Foundations',
                  price: 'Rs.19.99',
                  image: 'assets/figma/profile/course_new_a.png',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _CourseCard(
                  title: 'The Art of Problem Solving',
                  price: 'Rs.24.99',
                  image: 'assets/figma/profile/course_new_b.png',
                ),
              ),
              SizedBox(width: 32),
              Expanded(
                child: _CourseCard(
                  title: 'Adobe Certified Foundations',
                  price: 'Rs.19.99',
                  image: 'assets/figma/profile/course_new_a.png',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _CourseCard(
                  title: 'The Art of Problem Solving',
                  price: 'Rs.24.99',
                  image: 'assets/figma/profile/course_new_b.png',
                ),
              ),
              SizedBox(width: 32),
              Expanded(
                child: _CourseCard(
                  title: 'Adobe Certified Foundations',
                  price: 'Rs.19.99',
                  image: 'assets/figma/profile/course_new_a.png',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseContent extends StatelessWidget {
  const _CourseContent({required this.selectedIndex});

  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      1 => const _SavedShortsSection(),
      2 => const _SavedCoursesSection(),
      _ => const _MyCoursesSection(),
    };
  }
}

class _CourseTabs extends StatelessWidget {
  const _CourseTabs({required this.selectedIndex, required this.onSelected});

  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CourseTab(
            asset: 'assets/figma/profile/book_open.svg',
            label: 'My Courses',
            active: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _CourseTab(
            asset: 'assets/figma/profile/play_circle.svg',
            label: 'Saved Shorts',
            active: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _CourseTab(
            asset: 'assets/figma/profile/bookmark_new.svg',
            label: 'Saved Courses',
            active: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _CourseTab extends StatelessWidget {
  const _CourseTab({
    required this.asset,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 112,
          height: 32,
          child: Column(
            children: [
              SvgPicture.asset(asset, width: 20, height: 20),
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE6B800) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCourseCard extends StatelessWidget {
  const _AddCourseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFE6B800)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE6B800),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset('assets/figma/profile/plus_new.svg'),
          ),
          const SizedBox(height: 8),
          Text('Add New Course', style: _yellowTextStyle),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.price,
    required this.image,
  });

  final String title;
  final String price;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            width: double.infinity,
            child: Image.asset(image, fit: BoxFit.cover),
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
                  style: _cardTitleStyle,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(price, style: _priceStyle),
                    const _Badge(label: 'Edit'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedShortsSection extends StatelessWidget {
  const _SavedShortsSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Saved Shorts', action: 'See All'),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _ShortCard(
                  title: 'Quick UI Layout Tips',
                  image: 'assets/figma/profile/course_new_a.png',
                  duration: '4:12',
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _ShortCard(
                  title: 'Color Theory Basics',
                  image: 'assets/figma/profile/course_new_b.png',
                  duration: '3:08',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({
    required this.title,
    required this.image,
    required this.duration,
  });

  final String title;
  final String image;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(image, fit: BoxFit.cover),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cardTitleStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCoursesSection extends StatelessWidget {
  const _SavedCoursesSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Saved Courses', action: 'See All'),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _SavedCourseCard(
                  title: 'Advanced Illustrator',
                  progress: '65% Complete',
                  image: 'assets/figma/profile/course_new_a.png',
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _SavedCourseCard(
                  title: 'UI Design Systems',
                  progress: '32% Complete',
                  image: 'assets/figma/profile/course_new_b.png',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedCourseCard extends StatelessWidget {
  const _SavedCourseCard({
    required this.title,
    required this.progress,
    required this.image,
  });

  final String title;
  final String progress;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 153,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            width: double.infinity,
            child: Image.asset(image, fit: BoxFit.cover),
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
                  style: _cardTitleStyle,
                ),
                const SizedBox(height: 6),
                Text(progress, style: _priceStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings();

  static const _settings = [
    ('Personal Information', 'Verified', false),
    ('Notification Settings', '', false),
    ('Payment & Earnings', 'Rs.12,450.00', false),
    ('Privacy Settings', '', false),
    ('Help & Support', '', false),
    ('Log Out', '', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('ACCOUNT SETTINGS', style: _eyebrowStyle),
        ),
        for (final setting in _settings)
          InkWell(
            onTap: setting.$3 ? () => context.go('/login-screen') : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    setting.$1,
                    style: GoogleFonts.figtree(
                      color: setting.$3
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      if (setting.$2.isNotEmpty)
                        Text(setting.$2, style: _mutedSmallStyle),
                      const SizedBox(width: 8),
                      SvgPicture.asset(
                        setting.$3
                            ? 'assets/figma/profile/chevron_logout_new.svg'
                            : 'assets/figma/profile/chevron_new.svg',
                        width: 14,
                        height: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF9F6),
      padding: const EdgeInsets.fromLTRB(16, 1, 16, 16),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: _headingStyle),
        Text(action, style: _actionStyle),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: _badgeStyle),
    );
  }
}

final _headingStyle = GoogleFonts.manrope(
  color: const Color(0xFF111827),
  fontSize: 16,
  fontWeight: FontWeight.w700,
);
final _actionStyle = GoogleFonts.figtree(
  color: const Color(0xFF4B5563),
  fontSize: 13,
  fontWeight: FontWeight.w600,
);
final _cardTitleStyle = GoogleFonts.manrope(
  color: const Color(0xFF111827),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);
final _priceStyle = GoogleFonts.figtree(
  color: const Color(0xFFE6B800),
  fontSize: 11,
  fontWeight: FontWeight.w700,
);
final _mutedSmallStyle = GoogleFonts.figtree(
  color: const Color(0xFF4B5563),
  fontSize: 11,
);
final _badgeStyle = GoogleFonts.figtree(
  color: const Color(0xFF4B5563),
  fontSize: 9,
  fontWeight: FontWeight.w600,
);
final _yellowTextStyle = GoogleFonts.manrope(
  color: const Color(0xFFE6B800),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);
final _eyebrowStyle = GoogleFonts.manrope(
  color: const Color(0xFF9CA3AF),
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.2,
);
