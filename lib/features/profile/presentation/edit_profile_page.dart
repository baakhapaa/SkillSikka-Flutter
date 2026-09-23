import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/option_picker_sheet.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../../core/widgets/upload_card.dart';
import '../data/profile_role.dart';
import '../data/user_profile.dart';

const _pageBackground = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _accent = Color(0xFFE6B800);
const _chevron = 'assets/figma/signup_chevron_down.svg';

/// Values the form opens with, keyed by field id. Stands in for the API until
/// there is one; the seeds mirror what each profile screen displays.
const _studentSeed = <String, String>{
  'name': 'Shuvanga Karki',
  'email': 'shuvanga.karki@email.com',
  'phone': '9801234567',
  'grade': 'Class 9',
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
///
/// This is also where the fields that signup no longer asks for get completed:
/// phone, location, class, province, district, school and the student ID card
/// all live here, and the form opens with whatever [UserProfile] captured —
/// including the location the signup popup detected.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({
    super.key,
    this.role = ProfileRole.student,
    this.locationService = const LocationService(),
    this.requireCompletion = false,
  });

  final ProfileRole role;

  /// Injectable so the location popup can be driven from tests.
  final LocationService locationService;

  /// When true this is the "complete your profile" step reached from the enrol
  /// gate: every field is mandatory, so the user cannot come back still
  /// incomplete. The profile tab leaves it false — a user fixing a typo should
  /// not be marched through eight required fields.
  final bool requireCompletion;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _controllers = <String, TextEditingController>{};
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  /// Errors stay hidden until the first save attempt, then update live as the
  /// user types.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  Uint8List? _photoBytes;
  PlatformFile? _studentIdCard;
  PlatformFile? _cvFile;
  PlatformFile? _certificatesFile;

  bool get _isInstructor => widget.role == ProfileRole.instructor;

  /// Re-checks the form after a picker writes into a controller.
  ///
  /// A programmatic `controller.text` write does not fire `FormField.didChange`,
  /// so picker-driven fields would otherwise keep showing a stale error.
  void _revalidate() {
    if (_autovalidateMode == AutovalidateMode.disabled) return;
    _formKey.currentState?.validate();
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: _initialValue(key)),
  );

  /// The controller keys this screen owns, in form order. Drives both the
  /// initial values and what Save writes back, so a field cannot be added to
  /// the form and silently dropped on save.
  static const _commonKeys = <String>[
    'name',
    'email',
    'phone',
    'gender',
    'dob',
    'location',
  ];
  static const _studentKeys = <String>[
    'grade',
    'province',
    'district',
    'school',
  ];
  static const _instructorKeys = <String>[
    'qualification',
    'expertise',
    'experience',
  ];

  List<String> get _editableKeys => [
    ..._commonKeys,
    ...(_isInstructor ? _instructorKeys : _studentKeys),
  ];

  /// Wraps a validator so an optional field is only checked when it has a
  /// value. In [EditProfilePage.requireCompletion] mode the rule is mandatory.
  FormFieldValidator<String>? _requiredOrOptional(
    FormFieldValidator<String> validator,
  ) => widget.requireCompletion ? validator : validateWhenPresent(validator);

  /// A picker field has no format to check, but the completion flow still needs
  /// it to be present.
  FormFieldValidator<String>? _requiredChoice(String label) =>
      widget.requireCompletion ? (value) => validateChoice(value, label) : null;

  /// Whatever the profile already holds wins; the demo seed fills the gaps.
  ///
  /// This is also how the location the signup popup detected surfaces — signup
  /// has no field to show it in.
  String _initialValue(String key) {
    final saved = ref.read(userProfileProvider).valueFor(key);
    if (saved.isNotEmpty) return saved;
    return (_isInstructor ? _instructorSeed : _studentSeed)[key] ?? '';
  }

  @override
  void initState() {
    super.initState();
    // Carried over from signup so the user doesn't have to pick it twice.
    _photoBytes = ref.read(userProfileProvider).photoBytes;
  }

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
    _revalidate();
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
    _revalidate();
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
    _revalidate();
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
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      // Name and email are the only mandatory fields here; everything else is
      // checked for shape only when it has been filled in, so a partial profile
      // can still be saved.
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check the highlighted fields.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // No backend yet, so the profile store is the store — write back every key
    // this screen owns, or re-opening it would silently discard the edit.
    ref.read(userProfileProvider.notifier).save({
      for (final key in _editableKeys) key: _controller(key).text.trim(),
    });

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
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
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
            ),
          ],
        ),
      ),
    );
  }

  /// Fields shared by both roles, then the role's own block, then the bio.
  /// The order is the same for both roles so the form doesn't reshuffle itself
  /// — only the middle block changes.
  ///
  /// By default only name and email are mandatory. Everything else is optional
  /// — a user editing their profile should not be forced to fill eight fields
  /// to fix a typo — but any value that *is* present still has to be
  /// well-formed. In [EditProfilePage.requireCompletion] mode every field
  /// becomes mandatory instead.
  List<Widget> _buildFields() => [
    _field(
      key: 'name',
      label: 'Full Name',
      hint: 'e.g. Skill Sikka',
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      validator: validateFullName,
    ),
    _field(
      key: 'email',
      label: 'Email Address',
      hint: 'e.g. skill@email.com',
      leading: 'assets/figma/signup_mail.svg',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: validateEmail,
    ),
    _field(
      key: 'phone',
      label: 'Phone Number',
      hint: '+977 98XXXXXXXX',
      keyboardType: TextInputType.phone,
      validator: _requiredOrOptional(validatePhoneNumber),
    ),
    _twoUp(
      _field(
        key: 'gender',
        label: 'Gender',
        hint: 'Select gender',
        hintFontSize: 12,
        trailing: _chevron,
        validator: _requiredChoice('gender'),
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
        validator: _requiredOrOptional(validateDateOfBirth),
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
      validator: _requiredOrOptional(validateLocation),
    ),
    const LocationFieldHint(),
    ...(_isInstructor ? _instructorFields() : _studentFields()),
  ];

  List<Widget> _studentFields() => [
    _field(
      key: 'grade',
      label: 'Class / Grade',
      hint: 'Select your class',
      trailing: _chevron,
      validator: _requiredChoice('class'),
      onTap: () => _pickOption(
        key: 'grade',
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
        validator: _requiredChoice('province'),
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
        validator: _requiredChoice('district'),
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
      validator: _requiredChoice('school or college'),
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
      textInputAction: TextInputAction.next,
      validator: _requiredOrOptional(
        (value) => validateShortText(value, 'qualification'),
      ),
    ),
    _field(
      key: 'expertise',
      label: 'Subject Expertise',
      hint: 'e.g. Physics, Fullstack Web Dev',
      textInputAction: TextInputAction.next,
      validator: _requiredOrOptional(
        (value) => validateShortText(value, 'subject expertise'),
      ),
    ),
    _field(
      key: 'experience',
      label: 'Years of Experience',
      hint: 'e.g. 5 Years',
      keyboardType: TextInputType.number,
      validator: _requiredOrOptional(validateYearsOfExperience),
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
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
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
        // Matches the validators above, so the marker never lies: name and
        // email always, everything else only in completion mode.
        requiredField:
            widget.requireCompletion || key == 'name' || key == 'email',
        leading: leading,
        trailing: trailing,
        trailingWidget: trailingWidget,
        onTap: onTap,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
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
