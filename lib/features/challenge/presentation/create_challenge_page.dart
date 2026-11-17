import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _soft = Color(0xFF9CA3AF);
const _line = Color(0xFFE5E7EB);
const _gold = Color(0xFFE6B800);
const _cream = Color(0xFFFFFBEB);
const _goldInk = Color(0xFF2F2600);
const _required = Color(0xFFEF4444);

/// Instructor form for a new challenge.
///
/// Not opened from anywhere yet. Wire it in when the entry point is decided.
class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({super.key});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final _title = TextEditingController(text: 'Build a Personal Portfolio');
  final _description = TextEditingController(
    text: 'Create a responsive portfolio using HTML and CSS',
  );
  final _requirements = TextEditingController(
    text:
        'Share your live website link and GitHub repository. Add a short note explaining your design choices.',
  );
  final _resources = <TextEditingController>[
    TextEditingController(text: 'https://developer.mozilla.org'),
  ];

  static const _categories = <String>[
    'Web Development',
    'Design',
    'Programming',
    'Math',
    'Science',
  ];

  String _category = 'Web Development';
  String _difficulty = 'Beginner';
  DateTime _deadline = DateTime(2026, 11, 15);
  TimeOfDay _time = const TimeOfDay(hour: 23, minute: 59);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _requirements.dispose();
    for (final resource in _resources) {
      resource.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  String get _dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${_deadline.day} ${months[_deadline.month - 1]} ${_deadline.year}';
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  Text(
                    'Create a Challenge',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn learning into doing. Share a challenge that helps your students put their skills to work.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      color: _gray,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _section('Challenge details'),
                  const SizedBox(height: 16),
                  _label('Challenge title'),
                  const SizedBox(height: 6),
                  _field(controller: _title),
                  const SizedBox(height: 16),
                  _label('Subject / Category'),
                  const SizedBox(height: 6),
                  _menuField(
                    value: _category,
                    icon: Icons.keyboard_arrow_down,
                    onTap: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final category in _categories)
                                ListTile(
                                  title: Text(
                                    category,
                                    style: GoogleFonts.manrope(
                                      fontWeight: category == _category
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(context, category),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (picked != null) setState(() => _category = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  _label('Difficulty level'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final level in const [
                        'Beginner',
                        'Intermediate',
                        'Advanced',
                      ]) ...[
                        Expanded(child: _difficultyChip(level)),
                        if (level != 'Advanced') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Description / Instructions'),
                  const SizedBox(height: 6),
                  _field(controller: _description, lines: 4),
                  const SizedBox(height: 6),
                  Text(
                    'Include an about section, three project cards and a contact form. Make it look great on mobile and desktop.\nBe clear about the goal and what students need to build.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 16),
                  _section('Submission & deadline'),
                  const SizedBox(height: 16),
                  _label('Submission requirements'),
                  const SizedBox(height: 6),
                  _field(controller: _requirements, lines: 3),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Deadline'),
                            const SizedBox(height: 6),
                            _menuField(
                              value: _dateLabel,
                              icon: Icons.calendar_today_outlined,
                              onTap: _pickDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 132,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Time'),
                            const SizedBox(height: 6),
                            _menuField(
                              value: _time.format(context),
                              icon: Icons.access_time,
                              onTap: _pickTime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nepal Time (UTC +5:45). Submissions close at the deadline.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 16),
                  _section('Materials & resources'),
                  const SizedBox(height: 16),
                  _label('Challenge materials'),
                  const SizedBox(height: 8),
                  _uploadCard(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _resources.length; i++) ...[
                    _resourceLabel(i),
                    const SizedBox(height: 6),
                    _field(controller: _resources[i], icon: Icons.link),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _resources.add(TextEditingController());
                      });
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 16, color: _goldInk),
                        const SizedBox(width: 6),
                        Text(
                          'Add another resource',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _goldInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: _goldInk,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Publishing makes this challenge visible to students. Not ready yet? Save a draft and come back anytime.',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              height: 1.4,
                              color: _goldInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _publishButton(),
                  const SizedBox(height: 12),
                  _draftButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: _ink),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _gold),
          ),
          child: Text(
            'New challenge',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _goldInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String text) {
    return Text(
      text,
      style: GoogleFonts.lexendDeca(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    );
  }

  Widget _label(String text, {bool markRequired = true}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        if (markRequired) ...[
          const SizedBox(width: 4),
          Text('*', style: GoogleFonts.manrope(fontSize: 13, color: _required)),
        ],
      ],
    );
  }

  Widget _resourceLabel(int index) {
    return Row(
      children: [
        Text(
          index == 0 ? 'Supporting resources' : 'Resource ${index + 1}',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(optional)',
          style: GoogleFonts.manrope(fontSize: 11, color: _soft),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    int lines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      style: GoogleFonts.manrope(fontSize: 14, color: _ink, height: 1.5),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: icon == null ? null : Icon(icon, size: 16, color: _gray),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold),
        ),
      ),
    );
  }

  Widget _menuField({
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.manrope(fontSize: 14, color: _ink),
              ),
            ),
            Icon(icon, size: 16, color: _gray),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChip(String level) {
    final selected = level == _difficulty;
    return GestureDetector(
      onTap: () => setState(() => _difficulty = level),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _cream : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _gold : _line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          level,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: _ink,
          ),
        ),
      ),
    );
  }

  Widget _uploadCard() {
    return GestureDetector(
      onTap: () => _note('Material upload is not connected yet.'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to upload materials',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _goldInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Brief, starter files or reference images\nPDF, DOCX, ZIP, JPG, PNG • Max 20MB each',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                height: 1.5,
                color: _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publishButton() {
    return GestureDetector(
      onTap: () => _note('Publish is not connected yet.'),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40E6B800),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Publish Challenge',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18, color: _ink),
          ],
        ),
      ),
    );
  }

  Widget _draftButton() {
    return GestureDetector(
      onTap: () => _note('Draft saving is not connected yet.'),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _line),
        ),
        child: Text(
          'Save as Draft',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
    );
  }
}
