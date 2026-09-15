import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF9CA3AF);
const _chipBg = Color(0xFFF2F1F7);
const _border = Color(0xFFEAEAEA);
const _gold = Color(0xFFE6B800);

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({
    super.key,
    this.image = 'assets/figma/book-cover.png',
    this.title = 'The Art of Problem Solving (Intro)',
    this.category = 'Math',
    this.tags = const ['Math', 'Beginner', 'Practice-heavy'],
    this.description =
        'Strengthen logic, visualization, and critical thinking with '
        'step-by-step math problem solving guides and real world '
        'mental-model exercises.',
    this.author = 'R. L. Smith',
    this.rating = '4.7',
  });

  final String image;
  final String title;
  final String category;
  final List<String> tags;
  final String description;
  final String author;
  final String rating;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  bool _isFavorite = false;

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
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_buildBookCoverArea(), _buildDetailsCard()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Back button (glassy circle)
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
              'Book Details',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          // Favorite (heart) button
          GestureDetector(
            onTap: () => setState(() => _isFavorite = !_isFavorite),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _isFavorite ? const Color(0xFFE53935) : _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOOK COVER AREA
  // ─────────────────────────────────────────────────────────────
  Widget _buildBookCoverArea() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x21000000), // rgba(0,0,0,0.13)
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              widget.image,
              width: 140,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DETAILS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title + author + rating ────────────────────────────
          Text(
            widget.title,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'By ${widget.author}',
                style: GoogleFonts.figtree(fontSize: 14, color: _gray),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: GoogleFonts.figtree(fontSize: 14, color: _softGray),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 14),
              const SizedBox(width: 4),
              Text(
                widget.rating,
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tag row ────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTag(widget.category),
              for (final tag in widget.tags)
                if (tag != widget.category) _buildTag(tag),
            ],
          ),
          const SizedBox(height: 16),

          // ── Divider ────────────────────────────────────────────
          const Divider(height: 1, color: _border),
          const SizedBox(height: 16),

          // ── Description ────────────────────────────────────────
          Text(
            'Description',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.description,
            style: GoogleFonts.figtree(fontSize: 13, height: 1.5, color: _gray),
          ),
          const SizedBox(height: 16),

          // ── Key Highlights ─────────────────────────────────────
          Text(
            'Key Highlights',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          _buildHighlight('Over 200 interactive mental exercises'),
          const SizedBox(height: 8),
          _buildHighlight('Step-by-step visual proofs and diagrams'),
          const SizedBox(height: 8),
          _buildHighlight('Access to supplementary digital practice tools'),
          const SizedBox(height: 20),

          // ── Bottom buy bar ─────────────────────────────────────
          _buildBottomBuyBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAG PILL
  // ─────────────────────────────────────────────────────────────
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _gray,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // KEY HIGHLIGHT ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildHighlight(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.figtree(fontSize: 13, color: _gray, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM BUY BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomBuyBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _chipBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PRICE',
                style: GoogleFonts.figtree(
                  fontSize: 10,
                  color: _softGray,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '\$14.99',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Add to cart button
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.title} added to cart'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _ink,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Add To Cart',
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
