import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _chipBg = Color(0xFFF2F1F7);
const _border = Color(0xFFEAEAEA);
const _gold = Color(0xFFE6B800);
const _iconYellowBg = Color(0xFFFDF6DD);
const _iconBlueBg = Color(0xFFEEF2F6);

class EventDetailsPage extends StatefulWidget {
  const EventDetailsPage({super.key});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool _bookmarked = false;

  static const _avatars = <String>[
    'assets/figma/instructors/instructor.png',
    'assets/figma/instructors/instructor1.png',
    'assets/figma/instructors/instructor2.png',
    'assets/figma/instructors/instructor3.png',
    'assets/figma/instructors/instructor4.png',
    'assets/figma/instructors/instructor5.png',
    'assets/figma/instructors/instructor6.png',
    'assets/figma/instructors/instructor7.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildScreenHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBanner(),
                    const SizedBox(height: 20),
                    _buildTitleHost(),
                    const SizedBox(height: 20),
                    _buildInfoCards(),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: _border),
                    const SizedBox(height: 20),
                    _buildAboutSection(),
                    const SizedBox(height: 20),
                    _buildWhatYouLearn(),
                    const SizedBox(height: 20),
                    _buildAttendees(),
                    const SizedBox(height: 20),
                    _buildRegisterButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Event Details',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _bookmarked = !_bookmarked),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: const Color.fromARGB(255, 254, 210, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 203,
        width: double.infinity,
        child: Image.asset(
          'assets/figma/event/event-banner.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.event, size: 60, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleHost() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Algebra & Calculus Masterclass',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                _avatars[0],
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 36,
                  height: 36,
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. Sarah Pakhrin',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Text(
                  'Mathematics Dept Head',
                  style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildInfoCard(
          iconBg: _iconYellowBg,
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFFB98A00),
          title: 'Saturday, November 25',
          subtitle: '10:00 AM - 2:00 PM',
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          iconBg: _iconBlueBg,
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFF4A6B8A),
          title: 'Seminar Hall A, Tech Hub',
          subtitle: 'Kathmandu, Nepal (In-Person)',
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Event',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dive deep into higher-level analytical calculus and practical '
          'applications of college algebra with visual graph proofs and '
          'interactive query sessions.',
          style: GoogleFonts.figtree(fontSize: 13, height: 1.5, color: _gray),
        ),
      ],
    );
  }

  Widget _buildWhatYouLearn() {
    const items = [
      'Integration & derivatives made practical',
      'Graphing techniques for complex functions',
      'Mental shortcuts for competitive calculus exams',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What you'll learn",
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Color(0xFF22C55E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttendees() {
    const avatarCount = 4;
    const avatarSize = 28.0;
    const overlap = 8.0;
    final totalWidth = avatarSize + (avatarCount - 1) * (avatarSize - overlap);

    return Row(
      children: [
        SizedBox(
          width: totalWidth,
          height: avatarSize,
          child: Stack(
            children: [
              for (var i = 0; i < avatarCount; i++)
                Positioned(
                  left: i * (avatarSize - overlap),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _avatars[i % _avatars.length],
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: avatarSize,
                          height: avatarSize,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '120+ attending',
          style: GoogleFonts.figtree(fontSize: 12, color: _gray),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registered for event!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _ink,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Text(
            'Register Now',
            style: GoogleFonts.figtree(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
