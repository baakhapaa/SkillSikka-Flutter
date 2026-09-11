import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _HomePageState extends State<HomePage> {
  late final PageController _promoController;
  Timer? _promoTimer;
  int _activePromoIndex = 0;
  int _selectedClassIndex = 0;

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
    super.dispose();
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
                  const SizedBox(height: 24),
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
            child: const Icon(Icons.emoji_events_outlined, color: Colors.black87, size: 22),
          ),
          const Spacer(),
          Image.asset(
            'assets/image/text.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _buildIconButton(Icons.notifications_none, hasBadge: true),
          const SizedBox(width: 6),
          _buildIconButton(Icons.search),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {bool hasBadge = false}) {
    return Stack(
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
    );
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
      ),
    ];

    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 350,
        width: double.infinity,
        child: ClipRect(
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
                    for (final card in cards)
                      Positioned(
                        left: card.left,
                        top: card.top,
                        child: _HeroBookCard(layout: card),
                      ),
                  ],
                ),
              ),
            ),
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
        _buildSectionHeader('Skill Courses'),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                      child: Icon(c.$1, color: const Color(0xFFE6BD1E), size: 18),
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
                          style: GoogleFonts.figtree(
                            fontSize: 9,
                            color: _gray,
                          ),
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
      (
        'assets/figma/homescreen/ict1.png',
        'Sundarbazar',
      ),
      (
        'assets/figma/homescreen/ict2.png',
        'PALUNGTAR',
      ),
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
              Container(
                height: 26,
                padding: const EdgeInsets.only(left: 13, right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      '4 Days',
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF141414),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.black),
                  ],
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  width: 311,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
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
                        bottom: 16,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildPill('SKILL SIKKA'),
                                const SizedBox(width: 6),
                                _buildPill(camp.$2.toUpperCase()),
                                const SizedBox(width: 6),
                                _buildPill('2.5K VIEWS'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Text(
                                'Enter now',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
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

  Widget _buildCoursesSection() {
    const filters = ['All', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'];
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

    return Column(
      children: [
        _buildSectionHeader('Courses'),
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
              return GestureDetector(
                onTap: () => setState(() => _selectedClassIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _yellow : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: Text(
                    filters[index],
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _titleInk,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.asset(
                        c.$1,
                        height: 98,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 98,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.white),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 10),
                              const SizedBox(width: 2),
                              Text(
                                c.$4,
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                color: index == _activePromoIndex ? _yellow : const Color(0xFFD6D3D1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInstructors() {
    const peekImages = [
      'assets/figma/homescreen/instructor2.png',
      'assets/figma/homescreen/instructor3.png',
      'assets/figma/homescreen/instructor4.png',
    ];

    return Column(
      children: [
        _buildSectionHeader('Explore our Top instructors'),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _buildFeaturedInstructor(),
              const SizedBox(width: 16),
              SizedBox(
                width: 152,
                height: 165,
                child: Stack(
                  children: [
                    for (var i = 0; i < peekImages.length; i++)
                      Positioned(
                        left: i * 53.4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            peekImages[i],
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
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedInstructor() {
    return Container(
      width: 178,
      height: 165,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40ADC0FF),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/figma/homescreen/instructor1.png',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey.shade400),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x80000000)],
                  stops: [0, 0.96],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shuvanga Karki',
                    style: GoogleFonts.inter(
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
                    ),
                  ),
                  Text(
                    '915,213 students\n40 courses',
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
    );
  }

  Widget _buildPremiumCourses() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          _buildSectionHeader('Get Premium Courses'),
          const SizedBox(height: 12),
          _buildPremiumCard(
            image: 'assets/figma/homescreen/premium-course1.png',
          ),
          const SizedBox(height: 21),
          _buildPremiumCard(
            image: 'assets/figma/homescreen/premium-course2.png',
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({required String image}) {
    return Container(
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.asset(
                  image,
                  height: 235,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 235,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.white, size: 50),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 18),
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
                      const Icon(Icons.star, color: Color(0xFFFFB01F), size: 16),
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
                      const Icon(Icons.bar_chart, size: 12, color: Color(0xFF8D887F)),
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
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENROLLMENT',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8D887F)),
                  ),
                  Text(
                    'Rs.24.99',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF524C00),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B1B1B),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFE7E7E7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Start Learning',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      ),
    ];

    return Container(
      color: const Color(0xFFF2F1F7),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          _buildSectionHeader('Recommended Books'),
          const SizedBox(height: 16),
          for (var i = 0; i < books.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                        child: const Icon(Icons.menu_book, color: Colors.white),
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
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
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
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, size: 12),
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
                            const Icon(Icons.star, color: Color(0xFFFBBF24), size: 12),
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 0.5),
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _buildSectionHeader('Event near you'),
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.asset(
                          e.$1,
                          height: 92,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 92,
                            color: Colors.grey.shade300,
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
                              style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ...List.generate(5, (i) {
                                  return Icon(
                                    Icons.star,
                                    size: 12,
                                    color: i < 4 ? const Color(0xFFFBBF24) : const Color(0xFF9CA3AF),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _yellow,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'View',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward, size: 12),
                                    ],
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
  final bool showPlay;
  final double playSize;
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
          Container(
            width: layout.width,
            height: layout.height,
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 1,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: SizedBox(
                    width: layout.width,
                    height: layout.imageHeight,
                    child: Image.asset(
                      layout.image,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => ColoredBox(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.menu_book, color: Colors.white, size: 40),
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
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Icon(
                                Icons.person,
                                size: layout.avatarSize * 0.55,
                                color: Colors.black54,
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
                            const Icon(Icons.star, color: Color(0xFFFBBF24), size: 10),
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