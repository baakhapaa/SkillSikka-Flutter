import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/events/presentation/event_details.dart';
import 'package:skillsikka/features/instructors/presentation/instructor_page.dart';
import 'package:skillsikka/features/books/presentation/book_details.dart';
import 'package:skillsikka/features/courses/presentation/courses.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_course_details_page.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_courses_page.dart';
import 'package:skillsikka/features/recommendedcourse/presentation/recommended_course.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_courses.dart';

const _cream = Color(0xFFFAF9F6);
const _ink = Color(0xFF282828);
const _gray = Color(0xFF4B5563);
const _yellow = Color(0xFFFFD233);
const _titleInk = Color(0xFF111827);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final PageController _promoController;
  late final AnimationController _heroController;
  Timer? _promoTimer;
  int _activePromoIndex = 0;
  int _heroFrontIndex = 4;
  double _heroDragDistance = 0;
  int _heroDirection = 1;
  bool _heroAnimating = false;
  int _selectedClassIndex = 0;
  int _selectedBootcampDays = 4;
  int _hoveredClassIndex = -1;
  bool _hoveredBootcampSelector = false;

  static const _promoSlides = <_PromoSlide>[
    _PromoSlide(
      eyebrow: 'WELCOME',
      headline: 'BACK TO',
      subhead: 'SCHOOL',
      badge: 'SUPER SALE',
      offer: 'DISC UP TO 50% OFF',
      colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF1565C0)],
      image: 'assets/figma/homescreen/ads1.png',
    ),
    _PromoSlide(
      eyebrow: 'MUST-HAVES',
      headline: 'STATIONERY',
      subhead: 'ESSENTIALS',
      badge: 'FEATURED DEALS',
      offer: 'BUY 2 GET 1 FREE',
      colors: [Color(0xFF1B5E20), Color(0xFF4CAF50), Color(0xFF2E7D32)],
      image: 'assets/figma/homescreen/ads2.png',
    ),
    _PromoSlide(
      eyebrow: 'GET READY',
      headline: 'NEW SEMESTER',
      subhead: 'DEALS',
      badge: 'STARTER PACK',
      offer: 'STARTING FROM Rs.9.99',
      colors: [Color(0xFFE65100), Color(0xFFFF9800), Color(0xFFF57C00)],
      image: 'assets/figma/homescreen/ads3.png',
    ),
    _PromoSlide(
      eyebrow: 'NEW STYLE',
      headline: 'BAGS',
      subhead: 'COLLECTION',
      badge: 'PREMIUM QUALITY',
      offer: 'SAVE UP TO 40% OFF',
      colors: [Color(0xFF4A148C), Color(0xFF9C27B0), Color(0xFF7B1FA2)],
      image: 'assets/figma/homescreen/ads4.png',
    ),
    _PromoSlide(
      eyebrow: 'GET CREATIVE',
      headline: 'ART & CRAFT',
      subhead: 'SUPPLIES',
      badge: 'CREATIVE SALE',
      offer: 'FLAT 30% DISCOUNT',
      colors: [Color(0xFF004D40), Color(0xFF009688), Color(0xFF00796B)],
      image: 'assets/figma/homescreen/ads1.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _promoController = PageController();
    _heroController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _heroAnimating) {
            setState(() {
              _heroFrontIndex = (_heroFrontIndex + _heroDirection + 5) % 5;
              _heroDragDistance = 0;
              _heroAnimating = false;
            });
            _heroController.reset();
          }
          if (status == AnimationStatus.dismissed && _heroAnimating) {
            setState(() {
              _heroDragDistance = 0;
              _heroAnimating = false;
            });
          }
        });
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_promoController.hasClients) return;
      final nextPage = (_activePromoIndex + 1) % _promoSlides.length;
      _promoController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  void _finishHeroDrag() {
    if (_heroAnimating) return;
    _heroAnimating = true;
    if (_heroDragDistance.abs() < 70) {
      _heroController.reverse(
        from: (_heroDragDistance.abs() / 220).clamp(0.0, 1.0).toDouble(),
      );
    } else {
      _heroController.forward(
        from: (_heroDragDistance.abs() / 220).clamp(0.0, 1.0).toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  _buildHeroCarousel(),
                  const SizedBox(height: 24),
                  _buildSkillCourses(),
                  const SizedBox(height: 24),
                  _buildIctBootcamp(),
                  const SizedBox(height: 24),
                  _buildCoursesSection(),
                  const SizedBox(height: 24),
                  _buildPromoBanner(),
                  const SizedBox(height: 24),
                  _buildTopInstructors(),
                  const SizedBox(height: 24),
                  _buildPremiumCourses(),
                  const SizedBox(height: 24),
                  _buildRecommendedBooks(),
                  const SizedBox(height: 24),
                  _buildEventsNearYou(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildTopHeader(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      color: _cream,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEDEDEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Colors.black87,
              size: 22,
            ),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/text.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _buildIconButton(
            Icons.notifications_none,
            hasBadge: true,
            semanticLabel: 'Notifications',
          ),
          const SizedBox(width: 6),
          _buildIconButton(Icons.search, semanticLabel: 'Search'),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon, {
    bool hasBadge = false,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? _describeIcon(icon),
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _gray, size: 22),
          ),
          if (hasBadge)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5F1F),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _describeIcon(IconData icon) {
    if (icon == Icons.notifications_none || icon == Icons.notifications) {
      return 'Notifications';
    }
    if (icon == Icons.search) return 'Search';
    return 'Icon button';
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '| ',
            style: GoogleFonts.manrope(
              fontSize: 21,
              fontWeight: FontWeight.w300,
              color: const Color(0x1F282828),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: _ink,
              ),
            ),
          ),
          trailing ??
              Text(
                'See All',
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel() {
    // Pixel layout from Figma HTML/CSS: 439.4 x 317.1 track, 5 overlapping cards.
    const trackW = 439.4;
    const trackH = 317.1;
    const cards = <_HeroCardLayout>[
      _HeroCardLayout(
        left: 0,
        top: 47,
        width: 174.4,
        height: 223.1,
        imageHeight: 149.2,
        image: 'assets/figma/homescreen/Rectangle 3353.png',
        titleSize: 11,
        descSize: 6,
        avatarSize: 15,
        nameSize: 10,
        avatar: 'assets/figma/face/face1.png',
        showPlay: true,
        playSize: 39.1,
      ),
      _HeroCardLayout(
        left: 48,
        top: 23,
        width: 211.9,
        height: 271.1,
        imageHeight: 181.2,
        image: 'assets/figma/homescreen/Rectangle 3352.png',
        titleSize: 12,
        descSize: 9,
        avatarSize: 20,
        nameSize: 12,
        avatar: 'assets/figma/face/face2.png',
        showPlay: true,
        playSize: 47.5,
      ),
      _HeroCardLayout(
        left: 265,
        top: 47,
        width: 174.4,
        height: 223.1,
        imageHeight: 149.2,
        image: 'assets/figma/homescreen/Rectangle 3351.png',
        titleSize: 11,
        descSize: 6,
        avatarSize: 15,
        nameSize: 10,
        avatar: 'assets/figma/face/face3.png',
      ),
      _HeroCardLayout(
        left: 180,
        top: 23,
        width: 211.9,
        height: 271.1,
        imageHeight: 181.2,
        image: 'assets/figma/homescreen/Rectangle 3354.png',
        titleSize: 12,
        descSize: 9,
        avatarSize: 20,
        nameSize: 12,
        avatar: 'assets/figma/face/face5.png',
      ),
      _HeroCardLayout(
        left: 95.69,
        top: 0,
        width: 247.8,
        height: 317.1,
        imageHeight: 212,
        image: 'assets/figma/homescreen/Rectangle 3350.png',
        titleSize: 14,
        descSize: 10,
        avatarSize: 28,
        nameSize: 13,
        avatar: 'assets/figma/face/faace4.png',
      ),
    ];

    Widget heroStack() {
      final currentSlots = List.generate(cards.length, (slotIndex) {
        final contentIndex = switch (slotIndex) {
          0 => (_heroFrontIndex - 2 + cards.length) % cards.length,
          1 => (_heroFrontIndex - 1 + cards.length) % cards.length,
          2 => (_heroFrontIndex + 2) % cards.length,
          3 => (_heroFrontIndex + 1) % cards.length,
          _ => _heroFrontIndex,
        };
        final slot = cards[slotIndex];
        return cards[contentIndex].copyWith(
          left: slot.left,
          top: slot.top,
          width: slot.width,
          height: slot.height,
          imageHeight: slot.imageHeight,
          titleSize: slot.titleSize,
          descSize: slot.descSize,
          avatarSize: slot.avatarSize,
          nameSize: slot.nameSize,
          showPlay: slot.showPlay,
          playSize: slot.playSize,
        );
      });
      final targetFront =
          (_heroFrontIndex + _heroDirection + cards.length) % cards.length;
      final targetSlot = _heroDirection > 0 ? 3 : 1;
      final rawProgress = _heroAnimating
          ? _heroController.value
          : (_heroDragDistance.abs() / 220).clamp(0.0, 1.0).toDouble();
      final progress = Curves.easeInOutCubic.transform(rawProgress);
      final targetFrom = currentSlots[targetSlot];
      final targetTo = cards[targetFront].copyWith(
        left: cards[4].left,
        top: cards[4].top,
        width: cards[4].width,
        height: cards[4].height,
        imageHeight: cards[4].imageHeight,
        titleSize: cards[4].titleSize,
        descSize: cards[4].descSize,
        avatarSize: cards[4].avatarSize,
        nameSize: cards[4].nameSize,
        showPlay: cards[4].showPlay,
        playSize: cards[4].playSize,
      );
      double mix(double from, double to) => from + (to - from) * progress;
      final movingTarget = targetFrom.copyWith(
        left: mix(targetFrom.left, targetTo.left),
        top: mix(targetFrom.top, targetTo.top),
        width: mix(targetFrom.width, targetTo.width),
        height: mix(targetFrom.height, targetTo.height),
        imageHeight: mix(targetFrom.imageHeight, targetTo.imageHeight),
        titleSize: mix(targetFrom.titleSize, targetTo.titleSize),
        descSize: mix(targetFrom.descSize, targetTo.descSize),
        avatarSize: mix(targetFrom.avatarSize, targetTo.avatarSize),
        nameSize: mix(targetFrom.nameSize, targetTo.nameSize),
        playSize: mix(targetFrom.playSize, targetTo.playSize),
      );
      final front = currentSlots[4];
      final frontOffset = _heroAnimating
          ? -_heroDirection * 220 * progress
          : _heroDragDistance;
      final frontScale = 1 - (0.035 * progress);
      final targetScale = 0.965 + (0.035 * progress);

      return ClipRect(
        child: OverflowBox(
          maxWidth: trackW,
          minWidth: trackW,
          maxHeight: 350,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: SizedBox(
              width: trackW,
              height: trackH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var slot = 0; slot < currentSlots.length; slot++)
                    if (slot != 4 && slot != targetSlot)
                      Positioned(
                        left: currentSlots[slot].left,
                        top: currentSlots[slot].top,
                        child: _HeroBookCard(layout: currentSlots[slot]),
                      ),
                  Positioned(
                    left: movingTarget.left,
                    top: movingTarget.top,
                    child: Transform.scale(
                      scale: targetScale,
                      child: _HeroBookCard(layout: movingTarget),
                    ),
                  ),
                  Positioned(
                    left: front.left + frontOffset,
                    top: front.top,
                    child: Transform.rotate(
                      angle: -_heroDirection * 0.018 * progress,
                      child: Transform.scale(
                        scale: frontScale,
                        child: _HeroBookCard(layout: front),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 350,
        width: double.infinity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _heroAnimating
              ? null
              : (details) => setState(() {
                  _heroDragDistance += details.delta.dx;
                  if (_heroDragDistance.abs() > 2) {
                    _heroDirection = _heroDragDistance < 0 ? 1 : -1;
                  }
                }),
          onHorizontalDragEnd: _heroAnimating ? null : (_) => _finishHeroDrag(),
          child: AnimatedBuilder(
            animation: _heroController,
            builder: (context, child) => heroStack(),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillCourses() {
    const courses = [
      (Icons.code, 'Coding', '32 Courses'),
      (Icons.brush, 'Drawing', '24 Courses'),
      (Icons.mic, 'Public Speaking', '18 Courses'),
      (Icons.music_note, 'Music', '40 Lessons'),
    ];

    return Column(
      children: [
        _buildSectionHeader(
          'Skill Courses',
          trailing: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SkillCoursesPage()),
              );
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
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = courses[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        c.$1,
                        color: const Color(0xFFE6BD1E),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.$2,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _titleInk,
                          ),
                        ),
                        Text(
                          c.$3,
                          style: GoogleFonts.figtree(fontSize: 9, color: _gray),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIctBootcamp() {
    const camps = [
      ('assets/figma/homescreen/ict1.png', 'Sundarbazar'),
      ('assets/figma/homescreen/ict2.png', 'PALUNGTAR'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '| ',
                style: GoogleFonts.manrope(
                  fontSize: 21,
                  fontWeight: FontWeight.w300,
                  color: const Color(0x1F282828),
                ),
              ),
              Expanded(
                child: Text(
                  'ICT & AI Bootcamp',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: _ink,
                  ),
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _hoveredBootcampSelector = true),
                onExit: (_) => setState(() => _hoveredBootcampSelector = false),
                child: _glossyGlassButton(
                  pressed: false,
                  hovered: _hoveredBootcampSelector,
                  fill: Colors.white,
                  radius: BorderRadius.circular(14),
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 4,
                    top: 2,
                    bottom: 2,
                  ),
                  child: SizedBox(
                    height: 22,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedBootcampDays,
                        isDense: true,
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.black,
                        ),
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF141414),
                        ),
                        items: [4, 7]
                            .map(
                              (days) => DropdownMenuItem<int>(
                                value: days,
                                child: Text('$days Days'),
                              ),
                            )
                            .toList(),
                        onChanged: (days) {
                          if (days != null) {
                            setState(() => _selectedBootcampDays = days);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 223,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: camps.length,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final camp = camps[index];
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 311,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          camp.$1,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF4B5563), Color(0xFF111827)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x0D494949),
                              Color(0x36181C1E),
                            ],
                            stops: [0, 0.41, 0.95],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 8,
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildPill('SKILL SIKKA'),
                                _buildPill(camp.$2.toUpperCase()),
                                _buildPill('2.5K VIEWS'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _classFilterChip({
    required String label,
    required bool selected,
    required bool hovered,
  }) {
    return _glossyGlassButton(
      pressed: selected,
      hovered: hovered,
      fill: Colors.white,
      radius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        label,
        style: GoogleFonts.figtree(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _titleInk,
        ),
      ),
    );
  }

  /// Glossy / skeuomorphic glass: soft white fill, bevel highlight, and raised shadow.
  Widget _glossyGlassButton({
    required Widget child,
    required bool pressed,
    bool hovered = false,
    required Color fill,
    required BorderRadius radius,
    required EdgeInsetsGeometry padding,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: hovered ? const Color(0x2E000000) : const Color(0x22000000),
            blurRadius: hovered ? 10 : 7,
            offset: Offset(0, pressed ? 1 : 3),
          ),
          const BoxShadow(
            color: Color(0xCCFFFFFF),
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: fill.withValues(alpha: 0.72)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: hovered ? 0.96 : 0.82),
                        const Color(0xFFF3F4F6).withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: pressed
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      end: pressed
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                      colors: [
                        pressed
                            ? const Color(0x22000000)
                            : const Color(0x26000000),
                        Color(0x00000000),
                      ],
                      stops: pressed ? [0, 0.55] : [0, 0.4],
                    ),
                  ),
                ),
              ),
            ),
            if (!pressed || hovered)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: hovered ? 0.9 : 0.58),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesSection() {
    const filters = [
      'All',
      'Class 6',
      'Class 7',
      'Class 8',
      'Class 9',
      'Class 10',
    ];
    const courses = [
      (
        'assets/figma/homescreen/course-thumbnail.png',
        'Physics',
        'Physical Chemistry Foundations',
        '4.7',
      ),
      (
        'assets/figma/homescreen/course-thumbnail2.png',
        'History',
        'World History: Middle Ages to Modern',
        '4.9',
      ),
      (
        'assets/figma/homescreen/course-thumbnail3.png',
        'Geometry',
        'Basic Geometry: Proofs & Shapes',
        '4.6',
      ),
      (
        'assets/figma/homescreen/course-thumbnail4.png',
        'Biology',
        'Introduction to Biology & Life',
        '4.8',
      ),
    ];

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            _buildSectionHeader(
              'Courses',
              trailing: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllCoursesPage()),
                  );
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
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 16, right: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (c, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _selectedClassIndex;
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredClassIndex = index),
                    onExit: (_) => setState(() => _hoveredClassIndex = -1),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedClassIndex = index),
                      child: _classFilterChip(
                        label: filters[index],
                        selected: selected,
                        hovered: _hoveredClassIndex == index,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courses.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final c = courses[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.asset(
                            c.$1,
                            height: 98,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              height: 98,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.$2,
                                      style: GoogleFonts.figtree(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: _gray,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFFBBF24),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    c.$4,
                                    style: GoogleFonts.figtree(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _titleInk,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c.$3,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: _titleInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Column(
      children: [
        SizedBox(
          height: 195,
          child: PageView.builder(
            controller: _promoController,
            itemCount: _promoSlides.length,
            onPageChanged: (index) => setState(() => _activePromoIndex = index),
            itemBuilder: (context, index) {
              final slide = _promoSlides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: slide.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Image.asset(
                            slide.image,
                            width: 180,
                            height: 180,
                            errorBuilder: (c, e, s) => const SizedBox(),
                          ),
                        ),
                        Positioned(
                          right: -30,
                          bottom: -40,
                          child: Container(
                            width: 138,
                            height: 138,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.13),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slide.eyebrow,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                slide.headline,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFFF176),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      offset: Offset(1, 2),
                                      color: Color(0x66000000),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                slide.subhead,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      offset: Offset(1, 2),
                                      color: Color(0x66000000),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD54F),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  slide.badge,
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slide.offer,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promoSlides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _activePromoIndex ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _activePromoIndex
                    ? _yellow
                    : const Color(0xFFD6D3D1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInstructors() {
    return ColoredBox(
      color: const Color(0xFFEEEEEE),
      child: Column(
        children: [
          SizedBox(
            height: 39,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '|',
                    style: GoogleFonts.manrope(
                      fontSize: 21,
                      fontWeight: FontWeight.w300,
                      color: const Color(0x1F282828),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Explore our Top instructors',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: _ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TopInstructorsPage(),
                        ),
                      );
                    },
                    child: Text(
                      'See All',
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF646161),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 213,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
              scrollDirection: Axis.horizontal,
              children: [
                _buildFeaturedInstructor(),
                const SizedBox(width: 16),
                SizedBox(
                  width: 205.72,
                  height: 165,
                  child: Stack(
                    children: const [
                      Positioned(
                        left: 0,
                        child: _InstructorPeekSlice(
                          image: 'assets/figma/homescreen/instructor2.png',
                          imageOffsetX: 0,
                        ),
                      ),
                      Positioned(
                        left: 53.43,
                        child: _InstructorPeekSlice(
                          image: 'assets/figma/homescreen/instructor3.png',
                          imageOffsetX: -11.52,
                        ),
                      ),
                      Positioned(
                        left: 106.86,
                        child: _InstructorPeekSlice(
                          image: 'assets/figma/homescreen/instructor4.png',
                          imageOffsetX: -23.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedInstructor() {
    return Container(
      width: 178,
      height: 165,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x40ADC0FF), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/figma/homescreen/instructor.png',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey.shade400),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00666666), Color(0x80000000)],
                  stops: [0, 0.96],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shuvanga Karki',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFFFF8E2),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Adobe Certified Instructure',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFF8E2),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: '915,213 students\n',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFF8E2),
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '40 courses',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFF8E2),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _buildPremiumCourses() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          _buildSectionHeader(
            'Get Premium Courses',
            trailing: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumCoursesPage()),
                );
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
          ),
          const SizedBox(height: 12),
          _buildPremiumCard(
            image: 'assets/figma/homescreen/premium-course1.png',
            avatar: 'assets/figma/face/face5.png',
          ),
          const SizedBox(height: 21),
          _buildPremiumCard(
            image: 'assets/figma/homescreen/premium-course2.png',
            avatar: 'assets/figma/face/face2.png',
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({required String image, required String avatar}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPremiumCourseDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7E7E7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1917).withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Image.asset(
                    image,
                    height: 235,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 235,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'ART & CRAFT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        color: const Color(0xFF191918),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Learn: the art of problem solving',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF201C15),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    avatar,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prof. Shuvanga Karki',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF201C15),
                      ),
                    ),
                    Text(
                      'Art Educator & Illustrator',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF8D887F),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFB01F),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '4.9',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8D887F),
                          ),
                        ),
                        Text(
                          '(128)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8D887F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.bar_chart,
                          size: 12,
                          color: Color(0xFF8D887F),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Beginner Friendly',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8D887F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Master the art of problem solving. Bring brilliant ideas to life with easy, follow-along video steps perfect for young artists.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF8D887F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F1F7),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ENROLLMENT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                height: 1.0,
                                color: const Color(0xFF8D887F),
                              ),
                            ),
                            Text(
                              'Rs.24.99',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                height: 1.0,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF524C00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 69),
                  Container(
                    height: 38,
                    width: 137,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
                      ),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Color(0x80FFFFFF),
                          blurRadius: 2,
                          offset: Offset(0, -1),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _openPremiumCourseDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF1B1B1B),
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Learning',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
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

  void _openPremiumCourseDetails() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CourseDetailsPage()));
  }

  Widget _buildRecommendedBooks() {
    const books = [
      (
        'assets/figma/homescreen/Rectangle 3352.png',
        'The Art of Problem Solving (Intro)',
        'Math',
        'Beginner',
        'Practice-heavy',
        'Strengthen problem-solving with guided practice.',
        'R. L. Smith',
        '4.7',
        'assets/figma/face/faace4.png',
      ),
      (
        'assets/figma/homescreen/Rectangle 3351.png',
        'Clean Code for Learners',
        'Programming',
        'Best Practices',
        'Projects',
        'Write readable programs with real examples.',
        'M. Johnson',
        '4.7',
        'assets/figma/face/face2.png',
      ),
      (
        'assets/figma/homescreen/Rectangle 3350.png',
        'Physics: Concepts & Questions',
        'Science',
        'Visual learning',
        'Exam prep',
        'Concept-first approach with step-by-step solutions.',
        'K. Patel',
        '4.7',
        'assets/figma/face/face3.png',
      ),
    ];

    return Container(
      color: const Color(0xFFF2F1F7),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          _buildSectionHeader(
            'Recommended Books',
            trailing: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BrowseCategoriesPage(),
                  ),
                );
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
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < books.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookDetailsPage(
                        image: books[i].$1,
                        title: books[i].$2,
                        category: books[i].$3,
                        tags: [books[i].$4, books[i].$5],
                        description: books[i].$6,
                        author: books[i].$7,
                        rating: books[i].$8,
                      ),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        books[i].$1,
                        width: 80,
                        height: 114,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 80,
                          height: 114,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.menu_book,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            books[i].$2,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            books[i].$3,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildTag(books[i].$4),
                              const SizedBox(width: 6),
                              _buildTag(books[i].$5),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            books[i].$6,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  books[i].$9,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                books[i].$7,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFBBF24),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                books[i].$8,
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
            ),
            if (i != books.length - 1)
              const Divider(height: 1, color: Color(0x1A000000)),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.black),
      ),
    );
  }

  Widget _buildEventsNearYou() {
    const events = [
      (
        'assets/figma/homescreen/event-near1.png',
        'Advanced Algebra & Calculus Masterclass',
        'By Dr. Sarah Pakhrin',
        '4.9',
      ),
      (
        'assets/figma/homescreen/event-near2.png',
        'Intro to Python: Build 10 Games in 30 Days',
        'By Alex Thapa',
        '4.8',
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          _buildSectionHeader(
            'Event near you',
            trailing: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EventDetailsPage()),
                );
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
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (c, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final e = events[index];
                return Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F1F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Image.asset(
                          e.$1,
                          height: 92,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 92,
                            color: const Color.fromARGB(255, 255, 255, 255),
                            child: const Icon(Icons.image, color: Colors.white),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: _titleInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.$3,
                              style: GoogleFonts.figtree(
                                fontSize: 11,
                                color: _gray,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ...List.generate(5, (i) {
                                  return Icon(
                                    Icons.star,
                                    size: 12,
                                    color: i < 4
                                        ? const Color(0xFFFBBF24)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            252,
                                            255,
                                          ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  e.$4,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _gray,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EventDetailsPage(),
                                      ),
                                    );
                                  },
                                  child: _glassSurface(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'View',
                                          style: GoogleFonts.figtree(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward,
                                          size: 12,
                                        ),
                                      ],
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassSurface({required Widget child, EdgeInsetsGeometry? padding}) {
    return _glossyGlassButton(
      pressed: false,
      fill: Colors.white,
      radius: BorderRadius.circular(18),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: child,
    );
  }
}

class _PromoSlide {
  const _PromoSlide({
    required this.eyebrow,
    required this.headline,
    required this.subhead,
    required this.badge,
    required this.offer,
    required this.colors,
    required this.image,
  });

  final String eyebrow;
  final String headline;
  final String subhead;
  final String badge;
  final String offer;
  final List<Color> colors;
  final String image;
}

class _HeroCardLayout {
  const _HeroCardLayout({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.image,
    required this.titleSize,
    required this.descSize,
    required this.avatarSize,
    required this.nameSize,
    this.avatar = 'assets/figma/face/face1.png',
    this.showPlay = false,
    this.playSize = 0,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double imageHeight;
  final String image;
  final double titleSize;
  final double descSize;
  final double avatarSize;
  final double nameSize;
  final String avatar;
  final bool showPlay;
  final double playSize;

  _HeroCardLayout copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    double? imageHeight,
    double? titleSize,
    double? descSize,
    double? avatarSize,
    double? nameSize,
    bool? showPlay,
    double? playSize,
  }) {
    return _HeroCardLayout(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      imageHeight: imageHeight ?? this.imageHeight,
      image: image,
      titleSize: titleSize ?? this.titleSize,
      descSize: descSize ?? this.descSize,
      avatarSize: avatarSize ?? this.avatarSize,
      nameSize: nameSize ?? this.nameSize,
      avatar: avatar,
      showPlay: showPlay ?? this.showPlay,
      playSize: playSize ?? this.playSize,
    );
  }
}

class _HeroBookCard extends StatelessWidget {
  const _HeroBookCard({required this.layout});

  final _HeroCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Card body ─────────────────────────────────────────────
          Container(
            width: layout.width,
            height: layout.height,
            decoration: BoxDecoration(
              // Pure white base with a very subtle gray fade at bottom
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Color(0xFFF7F7F7)],
                stops: [0.0, 0.75, 1.0],
              ),
              borderRadius: BorderRadius.circular(14),
              // Outer drop shadow only (no inset here)
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    width: layout.width,
                    height: layout.imageHeight,
                    child: Image.asset(
                      layout.image,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => ColoredBox(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      children: [
                        Text(
                          'The art of problem solving',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: layout.titleSize,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            letterSpacing: -0.2,
                            color: const Color(0xFF1C1917),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lorem ipsum dolor sit amet consectetur. Mauris ornare sapien eu leca.',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: layout.descSize,
                            height: 1.5,
                            color: const Color(0xFF44403C),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              width: layout.avatarSize,
                              height: layout.avatarSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  layout.avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        color: Colors.black54,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sarah Jenkins',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: layout.nameSize,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1917),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '4.9',
                              style: GoogleFonts.figtree(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _titleInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1F000000), // subtle dark at top edge
                      Color(0x00000000),
                      Color(0x0A000000), // very subtle at bottom
                    ],
                    stops: [0.0, 0.15, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Play button ───────────────────────────────────────────
          if (layout.showPlay)
            Positioned(
              top: 0,
              right: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: layout.playSize,
                  height: layout.playSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: layout.playSize * 0.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InstructorPeekSlice extends StatelessWidget {
  const _InstructorPeekSlice({required this.image, required this.imageOffsetX});

  final String image;
  final double imageOffsetX;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 45.43,
        height: 165,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: imageOffsetX,
              child: Image.asset(
                image,
                width: 150,
                height: 165,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 150,
                  height: 165,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
