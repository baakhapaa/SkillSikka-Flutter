import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF9CA3AF);
const _border = Color(0xFFEAEAEA);
const _yellow = Color(0xFFFFD233);

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  int _selectedCategory = 0;
  final _searchController = TextEditingController();

  static const _categories = <_ChallengeCategory>[
    _ChallengeCategory(
      label: 'Coding',
      icon: Icons.code,
    ),
    _ChallengeCategory(
      label: 'Design',
      icon: Icons.brush_outlined,
    ),
    _ChallengeCategory(
      label: 'Math',
      icon: Icons.calculate_outlined,
    ),
    _ChallengeCategory(
      label: 'Science',
      icon: Icons.science_outlined,
    ),
  ];

  static const _challenges = <_Challenge>[
    _Challenge(
      difficulty: 'Medium',
      timeLeft: '4h left',
      title: 'Algorithmic Speedrun: Sort & Match',
      players: '1,240 players',
      difficultyColor: Color(0xFFF59E0B),
    ),
    _Challenge(
      difficulty: 'Hard',
      timeLeft: '1d left',
      title: 'Vector Masterclass: Flat Landscape',
      players: '843 players',
      difficultyColor: Color(0xFFEF4444),
    ),
    _Challenge(
      difficulty: 'Expert',
      timeLeft: '2d left',
      title: 'Rocket Orbit Trajectory Math',
      players: '412 players',
      difficultyColor: Color(0xFF8B5CF6),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _joinChallenge(_Challenge challenge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined ${challenge.title}'),
        backgroundColor: _ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildCategoriesTrack(),
              const SizedBox(height: 20),
              _buildFeaturedChallenge(),
              const SizedBox(height: 20),
              _buildActiveCompetitionsLabel(),
              const SizedBox(height: 12),
              _buildChallengeList(),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildHeaderRow() {
  return Row(
    children: [
      Text(
        'Challenges',
        style: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E8),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/figma/challenges/Vector.png',
              width: 14,
              height: 14,
              color: const Color.fromARGB(255, 255, 171, 35),
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 4),
            Text(
              '450 XP',
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: _softGray),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.figtree(
                fontSize: 14,
                color: _ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search active competitions...',
                hintStyle: GoogleFonts.figtree(
                  fontSize: 14,
                  color: _softGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCategoriesTrack() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategory;
          final cat = _categories[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                color: selected ? _yellow : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 14, color: _ink),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedChallenge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/figma/challenges/featured-challenge.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FEATURED EVENT',
                    style: GoogleFonts.figtree(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'UI Championship #12: Glassmorphism Dashboard',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '🏆 Rs.500 Prize Pool',
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _yellow,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '•  3,410 entered',
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
  
  Widget _buildActiveCompetitionsLabel() {
    return Text(
      'Active Competitions',
      style: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    );
  }

  Widget _buildChallengeList() {
    return Column(
      children: [
        for (int i = 0; i < _challenges.length; i++) ...[
          _buildChallengeCard(_challenges[i]),
          if (i < _challenges.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildChallengeCard(_Challenge challenge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  challenge.difficulty,
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: challenge.difficultyColor,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.access_time, size: 14, color: _gray),
              const SizedBox(width: 4),
              Text(
                challenge.timeLeft,
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: _gray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            challenge.title,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: _gray),
              const SizedBox(width: 6),
              Text(
                challenge.players,
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: _gray,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _joinChallenge(challenge),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Join',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Challenge {
  const _Challenge({
    required this.difficulty,
    required this.timeLeft,
    required this.title,
    required this.players,
    required this.difficultyColor,
  });

  final String difficulty;
  final String timeLeft;
  final String title;
  final String players;
  final Color difficultyColor;
}

class _ChallengeCategory {
  const _ChallengeCategory({required this.label, required this.icon});

  final String label;
  final IconData icon;
}