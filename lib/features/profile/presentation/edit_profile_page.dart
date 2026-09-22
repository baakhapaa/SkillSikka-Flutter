import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/option_picker_sheet.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../../core/widgets/upload_card.dart';

const _pageBackground = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _accent = Color(0xFFE6B800);
const _chevron = 'assets/figma/signup_chevron_down.svg';

/// Which set of fields the edit screen shows.
///
/// The app has no persisted role yet, so the caller states it — the profile tab
/// shows a student's profile, while the instructor profile screen would pass
/// [instructor].
enum ProfileRole {
  student('Student'),
  instructor('Instructor');

  const ProfileRole(this.label);

  /// Shown in the header chip.
  final String label;
}

/// Values the form opens with, keyed by field id. Stands in for the API until
/// there is one; the seeds mirror what each profile screen displays.
const _studentSeed = <String, String>{
  'name': 'Shuvanga Karki',
  'email': 'shuvanga.karki@email.com',
  'phone': '9801234567',
  'class': 'Class 9',
};

const _instructorSeed = <String, String>{
  'name': 'Prof. Shuvanga Karki',
  'email': 'prof.karki@email.com',
  'phone': '9801234567',
  'qualification': 'Adobe Certified Instructor',
  'expertise': 'Illustration, Digital Arts',
  'experience': '8 Years',
};

/// Edit the signed-in user's profile.
///
/// Laid out like the signup forms — same labelled fields, same gold CTA — but
/// with the signup-only parts removed (passwords, document uploads and the
/// verification notice) and the role's own fields shown instead.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    this.role = ProfileRole.student,
    this.locationService = const LocationService(),
  });

  final ProfileRole role;

  /// Injectable so the location popup can be driven from tests.
  final LocationService locationService;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _controllers = <String, TextEditingController>{};
  final _imagePicker = ImagePicker();
  Uint8List? _photoBytes;
  PlatformFile? _studentIdCard;
  PlatformFile? _cvFile;
  PlatformFile? _certificatesFile;

  bool get _isInstructor => widget.role == ProfileRole.instructor;

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(
      text: (_isInstructor ? _instructorSeed : _studentSeed)[key] ?? '',
    ),
  );

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    // Bytes, not a path: `Image.file` is not supported on Flutter web.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  /// Opens the location popup and, if the user confirms a fix, writes it into
  /// the Location field. The field stays editable either way.
  Future<void> _promptForLocation({bool? skipIntro}) async {
    final alreadyGranted = skipIntro == null
        ? await widget.locationService.hasPermission()
        : false;
    if (!mounted) return;

    final location = await showLocationPromptDialog(
      context,
      service: widget.locationService,
      skipIntro: skipIntro ?? alreadyGranted,
    );
    if (location == null || !mounted) return;
    setState(() => _controller('location').text = location.label);
  }

  Future<void> _pickOption({
    required String key,
    required String title,
    required List<String> options,
    List<String> clearKeys = const [],
  }) async {
    final value = await showOptionPickerSheet(
      context,
      title: title,
      options: options,
    );
    if (value == null || !mounted) return;
    setState(() {
      _controller(key).text = value;
      for (final clearKey in clearKeys) {
        _controller(clearKey).clear();
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    setState(() => _controller('dob').text = '$day / $month / ${date.year}');
  }

  Future<void> _pickStudentIdCard() async {
    final file = await _pickFile(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null || !mounted) return;
    if (file.size > 5 * 1024 * 1024) {
      _showUploadError('Student ID card must be 5 MB or smaller.');
      return;
    }
    setState(() => _studentIdCard = file);
  }

  /// CV: PDF + DOC/DOCX, 5MB. Certificates: PDF + JPG/PNG, 10MB.
  Future<void> _pickDocument({required bool isCv}) async {
    final file = await _pickFile(
      allowedExtensions: isCv
          ? const ['pdf', 'doc', 'docx']
          : const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;

    final maxBytes = isCv ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
    if (file.size > maxBytes) {
      _showUploadError(
        'File too large. Maximum allowed is ${isCv ? '5MB' : '10MB'}.',
      );
      return;
    }
    setState(() {
      if (isCv) {
        _cvFile = file;
      } else {
        _certificatesFile = file;
      }
    });
  }

  Future<PlatformFile?> _pickFile({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  void _showUploadError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final missing = _controller('name').text.trim().isEmpty
        ? 'name'
        : (_controller('email').text.trim().isEmpty ? 'email address' : null);
    if (missing != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Please enter your $missing.')),
      );
      return;
    }
    // No backend yet — closing the screen is the whole save.
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: 'Edit Profile',
              roleLabel: widget.role.label,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                  child: Column(
                    children: [
                      ProfilePhotoPicker(
                        photoBytes: _photoBytes,
                        onTap: _pickProfilePhoto,
                      ),
                      const SizedBox(height: 24),
                      ..._buildFields(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _ink,
                            elevation: 4,
                            shadowColor: const Color(0x40E6B800),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Save Changes',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fields shared by both roles, then the role's own block, then the bio.
  /// The order is the same for both roles so the form doesn't reshuffle itself
  /// — only the middle block changes.
  List<Widget> _buildFields() => [
    _field(key: 'name', label: 'Full Name', hint: 'e.g. Skill Sikka'),
    _field(
      key: 'email',
      label: 'Email Address',
      hint: 'e.g. skill@email.com',
      leading: 'assets/figma/signup_mail.svg',
    ),
    _field(key: 'phone', label: 'Phone Number', hint: '+977 98XXXXXXXX'),
    _twoUp(
      _field(
        key: 'gender',
        label: 'Gender',
        hint: 'Select gender',
        hintFontSize: 12,
        trailing: _chevron,
        onTap: () => _pickOption(
          key: 'gender',
          title: 'Select gender',
          options: const ['Female', 'Male', 'Other'],
        ),
      ),
      _field(
        key: 'dob',
        label: 'Date of Birth',
        hint: 'DD / MM / YYYY',
        onTap: _pickDateOfBirth,
      ),
    ),
    _field(
      key: 'location',
      label: 'Location',
      hint: 'Enter your current location',
      leading: 'assets/figma/signup_location.svg',
      trailingWidget: CurrentLocationButton(
        onPressed: () => _promptForLocation(skipIntro: true),
      ),
    ),
    const LocationFieldHint(),
    ...(_isInstructor ? _instructorFields() : _studentFields()),
  ];

  List<Widget> _studentFields() => [
    _field(
      key: 'class',
      label: 'Class / Grade',
      hint: 'Select your class',
      trailing: _chevron,
      onTap: () => _pickOption(
        key: 'class',
        title: 'Select class',
        options: const [
          'Class 8',
          'Class 9',
          'Class 10',
          'Class 11',
          'Class 12',
        ],
      ),
    ),
    _twoUp(
      _field(
        key: 'province',
        label: 'Province',
        hint: 'Select province',
        hintFontSize: 12,
        trailing: _chevron,
        onTap: () => _pickOption(
          key: 'province',
          title: 'Select province',
          options: const ['Bagmati', 'Gandaki', 'Koshi', 'Lumbini'],
          clearKeys: const ['district', 'school'],
        ),
      ),
      _field(
        key: 'district',
        label: 'District',
        hint: 'Select province first',
        hintFontSize: 11,
        trailing: _chevron,
        enabled: _controller('province').text.isNotEmpty,
        onTap: () => _pickOption(
          key: 'district',
          title: 'Select district',
          options: const ['Kathmandu', 'Lalitpur', 'Bhaktapur', 'Chitwan'],
          clearKeys: const ['school'],
        ),
      ),
    ),
    _field(
      key: 'school',
      label: 'School / College',
      hint: 'Select school or college',
      trailing: _chevron,
      enabled: _controller('district').text.isNotEmpty,
      onTap: () => _pickOption(
        key: 'school',
        title: 'Select school or college',
        options: const [
          'Skill Sikka Academy',
          'Kathmandu Model College',
          'National College',
        ],
      ),
    ),
    UploadCard(
      title: 'Student ID Card',
      formats: 'Supported formats: PDF, JPG, PNG (Max 5MB)',
      asset: 'assets/figma/signup_student_file.svg',
      pickedFile: _studentIdCard,
      onTap: _pickStudentIdCard,
      onClear: () => setState(() => _studentIdCard = null),
      removeTooltip: 'Remove student ID card',
    ),
  ];

  List<Widget> _instructorFields() => [
    _field(
      key: 'qualification',
      label: 'Highest Qualification / Degree',
      hint: 'e.g. Master of Computer Applications',
    ),
    _field(
      key: 'expertise',
      label: 'Subject Expertise',
      hint: 'e.g. Physics, Fullstack Web Dev',
    ),
    _field(
      key: 'experience',
      label: 'Years of Experience',
      hint: 'e.g. 5 Years',
    ),
    UploadCard(
      title: 'CV / Resume',
      formats: 'Supported formats: PDF, DOCX (Max 5MB)',
      asset: 'assets/figma/signup_file_text.svg',
      pickedFile: _cvFile,
      onTap: () => _pickDocument(isCv: true),
      onClear: () => setState(() => _cvFile = null),
      removeTooltip: 'Remove CV',
    ),
    UploadCard(
      title: 'Certificates & Recommendation Letters',
      formats: 'Supported formats: PDF, JPG, PNG (Max 10MB)',
      asset: 'assets/figma/signup_file.svg',
      pickedFile: _certificatesFile,
      onTap: () => _pickDocument(isCv: false),
      onClear: () => setState(() => _certificatesFile = null),
      removeTooltip: 'Remove certificates',
    ),
  ];

  Widget _field({
    required String key,
    required String label,
    required String hint,
    String? leading,
    String? trailing,
    Widget? trailingWidget,
    VoidCallback? onTap,
    bool enabled = true,
    double hintFontSize = 14,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LabeledTextField(
        label: label,
        hint: hint,
        controller: _controller(key),
        requiredField: key != 'about',
        leading: leading,
        trailing: trailing,
        trailingWidget: trailingWidget,
        onTap: onTap,
        enabled: enabled,
        hintFontSize: hintFontSize,
        maxLines: maxLines,
      ),
    );
  }

  /// Two fields side by side, as the signup forms do for gender/date pairs.
  Widget _twoUp(Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.roleLabel,
    required this.onBack,
  });

  final String title;
  final String roleLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            tooltip: 'Back',
            icon: SvgPicture.asset(
              'assets/figma/signup_arrow_left.svg',
              width: 50,
              height: 50,
            ),
            style: IconButton.styleFrom(shape: const CircleBorder()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4CC),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            roleLabel,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2F2600),
            ),
          ),
        ),
      ],
    ),
  );
}
