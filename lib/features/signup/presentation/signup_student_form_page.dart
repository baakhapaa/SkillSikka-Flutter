import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../profile/data/user_profile.dart';

Future<String?> _pickOption(
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

/// Step 2 of signup: identity and credentials only.
///
/// The academic and geographic fields (phone, class, province, district,
/// school, student ID card) were moved off this screen — they are collected on
/// Edit Profile when the user first tries to enrol. The location popup still
/// runs here, but it writes into the [UserProfile] instead of a visible field,
/// because the Location field now lives on Edit Profile too.
class SignupStudentFormPage extends ConsumerStatefulWidget {
  const SignupStudentFormPage({
    super.key,
    this.locationService = const LocationService(),
    this.imagePicker,
  });

  /// Injectable so the popup flow can be driven from tests.
  final LocationService locationService;

  /// Injectable so the photo step can be driven from tests. Defaults to a real
  /// [ImagePicker].
  final ImagePicker? imagePicker;

  @override
  ConsumerState<SignupStudentFormPage> createState() =>
      _SignupStudentFormPageState();
}

class _SignupStudentFormPageState extends ConsumerState<SignupStudentFormPage> {
  final _controllers = <String, TextEditingController>{};
  final _formKey = GlobalKey<FormState>();

  /// Errors stay hidden until the first submit attempt, then update live as the
  /// user types. Validating on interaction from the start would flag a field as
  /// invalid after its very first keystroke.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool _obscurePassword = true;

  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  LocationService get _locationService => widget.locationService;

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  /// Re-checks the form after a picker writes into a controller.
  ///
  /// A programmatic `controller.text` write does not fire `FormField.didChange`,
  /// so the picker-driven fields (gender, date of birth) would otherwise keep
  /// showing their old error until something else triggered a rebuild.
  void _revalidate() {
    if (_autovalidateMode == AutovalidateMode.disabled) return;
    _formKey.currentState?.validate();
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

  /// Opens the location popup and stores the confirmed fix on the draft.
  ///
  /// There is no Location field on this screen any more, so the value is kept
  /// for the profile and the user gets a snack bar as the receipt.
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

    ref.read(userProfileProvider.notifier).setLocation(location.label);
    _showSnack('Location saved: ${location.label}');
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    // Bytes, not a path: `Image.file` asserts `!kIsWeb`, so a File-based
    // avatar blanks the screen on Flutter web.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    ref.read(userProfileProvider.notifier).setPhoto(bytes);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      // Every failing field is marked inline now. Switch on live re-validation
      // and say so once: the summary is what tells the user to look at the form
      // rather than wonder whether the tap registered.
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      _showSnack('Please check the highlighted fields.');
      return;
    }

    ref.read(userProfileProvider.notifier).save({
      'name': _controller('name').text.trim(),
      'email': _controller('email').text.trim(),
      'gender': _controller('gender').text,
      'dob': _controller('dob').text,
    });

    context.push('/signup/verify');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
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
                          photoBytes: profile.photoBytes,
                          onTap: _pickProfilePhoto,
                        ),
                        const SizedBox(height: 24),
                        _Field(
                          label: 'Full Name',
                          hint: 'e.g. Skill Sikka',
                          requiredField: true,
                          controller: _controller('name'),
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          validator: validateFullName,
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          label: 'Email Address',
                          hint: 'e.g. skill@email.com',
                          requiredField: true,
                          leading: 'assets/figma/signup_mail.svg',
                          controller: _controller('email'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          label: 'Password',
                          controller: _controller('password'),
                          requiredField: true,
                          obscure: _obscurePassword,
                          onToggle: _togglePassword,
                          validator: validatePassword,
                          // The confirmation rule depends on this value, so
                          // editing it has to re-check the pair.
                          onChanged: (_) => _revalidate(),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          label: 'Confirm Password',
                          controller: _controller('confirm'),
                          requiredField: true,
                          obscure: _obscurePassword,
                          onToggle: _togglePassword,
                          validator: (value) => validateConfirmPassword(
                            value,
                            _controller('password').text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Gender',
                                hint: 'Select gender',
                                requiredField: true,
                                trailing:
                                    'assets/figma/signup_chevron_down.svg',
                                controller: _controller('gender'),
                                onTap: () => _selectGender(),
                                validator: (value) =>
                                    validateChoice(value, 'gender'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Field(
                                label: 'Date of Birth',
                                hint: 'DD / MM / YYYY',
                                requiredField: true,
                                controller: _controller('dob'),
                                onTap: () => _selectDateOfBirth(),
                                validator: validateDateOfBirth,
                              ),
                            ),
                          ],
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
                              'Create Account',
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

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _selectGender() async {
    final value = await _pickOption(context, 'Select gender', const [
      'Female',
      'Male',
      'Other',
    ]);
    if (value == null) return;
    setState(() => _controller('gender').text = value);
    _revalidate();
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    setState(() => _controller('dob').text = '$day / $month / ${date.year}');
    _revalidate();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.leading,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool requiredField;
  final String? leading;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
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
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: onTap != null,
        onTap: onTap,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
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
          errorStyle: GoogleFonts.manrope(
            color: const Color(0xFFEF4444),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          // Two lines keeps a long message readable in the two-up rows.
          errorMaxLines: 2,
          prefixIcon: leading == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(14),
                  child: SvgPicture.asset(leading!, width: 16, height: 16),
                ),
          suffixIcon:
              trailingWidget ??
              (trailing == null
                  ? null
                  : IconButton(
                      onPressed: onTap,
                      icon: SvgPicture.asset(trailing!, width: 16, height: 16),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.requiredField,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final bool requiredField;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => _Field(
    label: label,
    requiredField: requiredField,
    hint: '••••••••••••',
    controller: controller,
    validator: validator,
    onChanged: onChanged,
    leading: 'assets/figma/signup_lock.svg',
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
            : SvgPicture.asset(
                'assets/figma/signup_eye.svg',
                key: const ValueKey('password-visible'),
                width: 16,
                height: 16,
              ),
      ),
    ),
    obscureText: obscure,
  );
}
