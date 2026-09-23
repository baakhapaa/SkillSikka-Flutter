import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';

Future<String?> _pickInstructorOption(
  BuildContext context,
  String title,
  List<String> options,
) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          ...options.map(
            (option) => ListTile(
              title: Text(option),
              onTap: () => Navigator.pop(context, option),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SignupInstructorFormPage extends ConsumerStatefulWidget {
  const SignupInstructorFormPage({
    super.key,
    this.locationService = const LocationService(),
  });

  /// Injectable so the popup flow can be driven from tests.
  final LocationService locationService;

  @override
  ConsumerState<SignupInstructorFormPage> createState() =>
      _SignupInstructorFormPageState();
}

class _SignupInstructorFormPageState
    extends ConsumerState<SignupInstructorFormPage> {
  final _controllers = <String, TextEditingController>{};
  bool _obscurePassword = true;

  Uint8List? _profilePhotoBytes;

  PlatformFile? _cvFile;
  PlatformFile? _certificatesFile;

  final _imagePicker = ImagePicker();

  LocationService get _locationService => widget.locationService;

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  void initState() {
    super.initState();
    // Ask for the current location as soon as the form is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptForLocation();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Opens the location popup and, if the user confirms a fix, writes it into
  /// the Location field.
  ///
  /// [skipIntro] `true` jumps straight to detection (the user explicitly asked
  /// for it), `false` always shows the explainer, and `null` decides based on
  /// whether permission was already granted — so returning visitors aren't
  /// nagged every time the form opens.
  Future<void> _promptForLocation({bool? skipIntro}) async {
    final alreadyGranted = skipIntro == null
        ? await _locationService.hasPermission()
        : false;
    if (!mounted) return;

    final location = await showLocationPromptDialog(
      context,
      service: _locationService,
      skipIntro: skipIntro ?? alreadyGranted,
    );
    if (location == null || !mounted) return;

    // The field stays editable, so this only pre-fills it.
    setState(() => _controller('location').text = location.label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                      child: Column(
                        children: [
                          ProfilePhotoPicker(
                            photoBytes: _profilePhotoBytes,
                            onTap: _pickProfilePhoto,
                          ),
                          const SizedBox(height: 24),

                          _FormField(
                            label: 'Full Name',
                            requiredField: true,
                            hint: 'e.g. Skill Sikka',
                            controller: _controller('name'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _FormField(
                                  label: 'Gender',
                                  requiredField: true,
                                  hint: 'Select gender',
                                  trailingAsset:
                                      'assets/figma/signup_chevron_down.svg',
                                  controller: _controller('gender'),
                                  onTap: () => _selectGender(),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _FormField(
                                  label: 'Date of Birth',
                                  requiredField: true,
                                  hint: 'DD / MM / YYYY',
                                  controller: _controller('dob'),
                                  onTap: () => _selectDateOfBirth(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Email Address',
                            hint: 'e.g. skill@email.com',
                            requiredField: true,
                            leadingAsset: 'assets/figma/signup_mail.svg',
                            controller: _controller('email'),
                          ),
                          const SizedBox(height: 16),
                          _PasswordField(
                            label: 'Password',
                            controller: _controller('password'),
                            requiredField: true,
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PasswordField(
                            label: 'Confirm Password',
                            controller: _controller('confirmPassword'),
                            requiredField: true,
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Phone Number',
                            hint: '98XXXXXXXX',
                            requiredField: true,
                            controller: _controller('phone'),
                            leadingText: '🇳🇵 +977',
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Location',
                            requiredField: true,
                            hint: 'Enter your current location',
                            leadingAsset: 'assets/figma/signup_location.svg',
                            controller: _controller('location'),
                            trailingWidget: CurrentLocationButton(
                              onPressed: () =>
                                  _promptForLocation(skipIntro: true),
                            ),
                          ),
                          const LocationFieldHint(),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Highest Qualification / Degree',
                            requiredField: true,
                            hint: 'e.g. Master of Computer Applications',
                            controller: _controller('degree'),
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Subject Expertise',
                            requiredField: true,
                            hint: 'e.g. Physics, Fullstack Web Dev',
                            controller: _controller('subject'),
                          ),
                          const SizedBox(height: 16),
                          _FormField(
                            label: 'Years of Experience',
                            requiredField: true,
                            hint: 'e.g. 5 Years',
                            controller: _controller('experience'),
                          ),
                          const SizedBox(height: 20),

                          _UploadCard(
                            title: 'CV / Resume',
                            formats: 'Supported formats: PDF, DOCX (Max 5MB)',
                            asset: 'assets/figma/signup_file_text.svg',
                            pickedFile: _cvFile,
                            onTap: () => _pickDocument(isCv: true),
                            onClear: () => _clearDocument(
                              ProfileDocumentSlot.cvResume,
                              () => setState(() => _cvFile = null),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _UploadCard(
                            title: 'Certificates & Recommendation Letters',
                            formats:
                                'Supported formats: PDF, JPG, PNG (Max 10MB)',
                            asset: 'assets/figma/signup_file.svg',
                            pickedFile: _certificatesFile,
                            onTap: () => _pickDocument(isCv: false),
                            onClear: () => _clearDocument(
                              ProfileDocumentSlot.certificates,
                              () => setState(() => _certificatesFile = null),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SvgPicture.asset(
                                  'assets/figma/signup_info.svg',
                                  width: 18,
                                  height: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Our admin team reviews all verification requests within 24-48 business hours. You'll receive an email notification once approved.",
                                    style: GoogleFonts.manrope(
                                      color: const Color(0xFF2F2600),
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE6B800),
                                foregroundColor: const Color(0xFF111827),
                                elevation: 4,
                                shadowColor: const Color(0x40E6B800),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Submit Verification',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    setState(() => _profilePhotoBytes = bytes);
  }

  Future<void> _pickDocument({required bool isCv}) async {
    // CV: PDF + DOC/DOCX, max 5MB
    // Certificates: PDF + JPG + PNG, max 10MB
    final allowedExtensions = isCv
        ? <String>['pdf', 'doc', 'docx']
        : <String>['pdf', 'jpg', 'jpeg', 'png'];

    // withData: true so the bytes come back in memory. The app targets Flutter
    // web, where a picked file has no readable path, and the multipart upload
    // needs bytes rather than a location anyway.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    // Size guard
    final maxBytes = isCv ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
    if (file.size > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File too large. Maximum allowed is '
            '${isCv ? '5MB' : '10MB'}.',
          ),
        ),
      );
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That file could not be read. Please pick another.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      if (isCv) {
        _cvFile = file;
      } else {
        _certificatesFile = file;
      }
    });

    // Stored here rather than at submit: these bytes are the only copy, and the
    // register call needs them after two more screen transitions.
    ref
        .read(userProfileProvider.notifier)
        .setDocument(
          isCv
              ? ProfileDocumentSlot.cvResume
              : ProfileDocumentSlot.certificates,
          PickedDocument(bytes: bytes, fileName: file.name),
        );
  }

  /// Removes a file from the screen *and* the store. The store took a copy of
  /// the bytes when the file was picked, so clearing only the local state would
  /// leave the deleted file queued for the register call.
  void _clearDocument(String slot, VoidCallback clearLocal) {
    clearLocal();
    ref.read(userProfileProvider.notifier).clearDocument(slot);
  }

  void _submit() {
    final missing = <String>[];
    if (_profilePhotoBytes == null) missing.add('Profile Photo');
    if (_controller('name').text.trim().isEmpty) missing.add('Full Name');
    if (_controller('email').text.trim().isEmpty) missing.add('Email');
    if (_cvFile == null) missing.add('CV / Resume');
    if (_certificatesFile == null) missing.add('Certificates');

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide: ${missing.join(", ")}')),
      );
      return;
    }

    // Recorded before navigating: these values used to live only in the
    // controllers and were lost the moment this screen was popped, so the
    // register call had nothing to send.
    final profile = ref.read(userProfileProvider.notifier);
    profile.setRole(ProfileRole.instructor);
    profile.setPhoto(_profilePhotoBytes!);

    // `degree` and `subject` are this form's controller keys; the profile store
    // and Edit Profile call the same two fields `qualification` and `expertise`.
    // Renaming at the boundary keeps one set of keys in the store instead of
    // two spellings of the same field. The passwords are deliberately absent —
    // they are only ever read inside this method.
    profile.save({
      'name': _controller('name').text.trim(),
      'email': _controller('email').text.trim(),
      'gender': _controller('gender').text,
      'dob': _controller('dob').text,
      'phone': _controller('phone').text.trim(),
      'location': _controller('location').text.trim(),
      'qualification': _controller('degree').text.trim(),
      'expertise': _controller('subject').text.trim(),
      'experience': _controller('experience').text.trim(),
    });

    context.push('/signup/verify');
  }

  Future<void> _selectGender() async {
    final value = await _pickInstructorOption(context, 'Select gender', const [
      'Female',
      'Male',
      'Other',
    ]);
    if (value != null) setState(() => _controller('gender').text = value);
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      setState(() => _controller('dob').text = '$day / $month / ${date.year}');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: SvgPicture.asset(
                'assets/figma/signup_arrow_left.svg',
                width: 50,
                height: 50,
              ),
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Step: 2 of 4',
              style: GoogleFonts.manrope(
                color: const Color.fromARGB(255, 44, 43, 45),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.leadingAsset,
    this.trailingAsset,
    this.trailingWidget,
    this.onTap,
    this.obscureText = false,
    this.leadingText,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool requiredField;
  final String? leadingAsset;
  final String? trailingAsset;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final String? leadingText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label: label, requiredField: requiredField),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: onTap != null,
          onTap: onTap,
          obscureText: obscureText,
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixText: leadingText,
            prefixIcon: leadingAsset == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: SvgPicture.asset(
                      leadingAsset!,
                      width: 16,
                      height: 16,
                    ),
                  ),
            suffixIcon:
                trailingWidget ??
                (trailingAsset == null
                    ? null
                    : IconButton(
                        onPressed: onTap,
                        icon: SvgPicture.asset(
                          trailingAsset!,
                          width: 16,
                          height: 16,
                        ),
                      )),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6B800)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.requiredField,
    required this.obscure,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final bool requiredField;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _FormField(
      label: label,
      requiredField: requiredField,
      hint: '••••••••••••',
      controller: controller,
      leadingAsset: 'assets/figma/signup_lock.svg',
      trailingWidget: IconButton(
        onPressed: onToggle,
        tooltip: obscure ? 'Show password' : 'Hide password',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: obscure
              ? const Icon(
                  Icons.visibility_off_outlined,
                  key: ValueKey('password-hidden'),
                  color: Color(0xFF4B5462),
                  size: 20,
                )
              : const Icon(
                  Icons.visibility_outlined,
                  key: ValueKey('password-visible'),
                  color: Color(0xFF4B5462),
                  size: 20,
                ),
        ),
      ),
      obscureText: obscure,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.requiredField});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.formats,
    required this.asset,
    required this.pickedFile,
    required this.onTap,
    required this.onClear,
  });

  final String title;
  final String formats;
  final String asset;
  final PlatformFile? pickedFile;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = pickedFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label: title, requiredField: false),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              border: Border.all(
                color: const Color(0xFFE6B800),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasFile ? _buildPickedState(context) : _buildEmptyState(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFE6B800),
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(asset),
        ),
        const SizedBox(height: 12),
        Text(
          'Upload Document',
          style: GoogleFonts.manrope(
            color: const Color(0xFF2F2600),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          formats,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: const Color(0xFF4B5563),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildPickedState(BuildContext context) {
    final name = pickedFile!.name;
    final sizeLabel = _formatBytes(pickedFile!.size);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFE6B800),
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(asset),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2F2600),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sizeLabel,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF4B5563),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClear,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close, size: 18, color: Color(0xFF4B5563)),
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
