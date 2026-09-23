import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/registration_request.dart';
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

  /// True while the registration request is in flight.
  ///
  /// Guards the button as well as showing progress: without it a slow request
  /// leaves the screen looking frozen and the button live, so an impatient
  /// second tap registers twice.
  bool _isSubmitting = false;

  /// Field messages the server sent, keyed the way the wire names them.
  ///
  /// Kept so a validator can show them: the alternative is a snack bar that
  /// says "that email is taken" without pointing at the email box.
  final _serverErrors = <String, String>{};

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
    // Any edit invalidates what the server said about a field: the value it
    // rejected is no longer the value in the box. Cleared wholesale rather than
    // per field because a resubmit is needed either way, and a stale server
    // message outliving the edit that fixed it is worse than clearing it.
    _serverErrors.clear();
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
    // The name travels with the bytes: the multipart part's content type is
    // inferred from the extension.
    ref.read(userProfileProvider.notifier).setPhoto(bytes, picked.name);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    // A second tap while the first request is in flight would create two
    // accounts. The button is disabled too; this is the belt to that braces.
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      // Every failing field is marked inline now. Switch on live re-validation
      // and say so once: the summary is what tells the user to look at the form
      // rather than wonder whether the tap registered.
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      _showSnack('Please check the highlighted fields.');
      return;
    }

    final profile = ref.read(userProfileProvider);
    final photo = profile.photoBytes;
    final photoName = profile.photoFileName;
    if (photo == null || photoName == null) {
      // Not a server failure, so it does not go through showApiErrorSnack —
      // this is something the user has to do to this screen.
      _showSnack('Add a profile photo to continue.');
      return;
    }

    ref.read(userProfileProvider.notifier).save({
      'name': _controller('name').text.trim(),
      'email': _controller('email').text.trim(),
      'gender': _controller('gender').text,
      'dob': _controller('dob').text,
    });

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            RegistrationRequest.student(
              name: _controller('name').text.trim(),
              email: _controller('email').text.trim(),
              // Read here rather than from the store: a password is only ever
              // read by the method that sends it.
              password: _controller('password').text,
              gender: _controller('gender').text,
              dob: _controller('dob').text,
              photo: PickedDocument(bytes: photo, fileName: photoName),
            ),
          );
      if (!mounted) return;
      // Cleared before navigating, not after: this screen stays on the stack
      // behind the OTP step, so coming back would otherwise find the button
      // still disabled.
      setState(() => _isSubmitting = false);
      context.push('/signup/verify');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _applyServerFieldErrors(error);
      showApiErrorSnack(
        context,
        error,
        // True only when something actually landed on an input. The server may
        // name fields this screen does not have, and those must still be said.
        fieldErrorsAreShown: _serverErrors.isNotEmpty,
      );
    }
  }

  /// Puts the server's per-field messages onto the matching inputs.
  ///
  /// Only fields this screen owns are mapped. The server may name something that
  /// lives on Edit Profile (`phone`, `school`, `grade`), and there is no input
  /// here to attach it to — those still reach the user through the summary
  /// message the snack bar shows.
  void _applyServerFieldErrors(ApiException error) {
    if (!error.hasFieldErrors) return;

    // The server's keys are the wire names, which for this form are also the
    // controller keys — so no translation table is needed, only a filter for the
    // keys that have no input here.
    for (final entry in error.fieldErrors.entries) {
      if (_controllers.containsKey(entry.key)) {
        _serverErrors[entry.key] = entry.value;
      }
    }
    if (_serverErrors.isEmpty) return;

    // Switch on live validation so the messages appear now, and survive until
    // the user edits something.
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    _formKey.currentState?.validate();
  }

  /// Wraps a client-side [validator] so a message from the server for the same
  /// field is shown instead, until the field is edited.
  FormFieldValidator<String> _serverAware(
    String key,
    FormFieldValidator<String> validator,
  ) {
    return (value) => _serverErrors[key] ?? validator(value);
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
                          // Re-checks on edit so a message the server sent about
                          // this field does not outlive the correction.
                          onChanged: (_) => _revalidate(),
                          validator: _serverAware('name', validateFullName),
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
                          // The likeliest server error of all: "already
                          // registered". It has to clear when the user changes
                          // the address.
                          onChanged: (_) => _revalidate(),
                          validator: _serverAware('email', validateEmail),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          label: 'Password',
                          controller: _controller('password'),
                          requiredField: true,
                          obscure: _obscurePassword,
                          onToggle: _togglePassword,
                          validator: _serverAware('password', validatePassword),
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
                                validator: _serverAware(
                                  'gender',
                                  (value) => validateChoice(value, 'gender'),
                                ),
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
                                validator: _serverAware(
                                  'dob',
                                  validateDateOfBirth,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            // Null while in flight: a second tap would register
                            // a second account.
                            onPressed: _isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE6B800),
                              foregroundColor: const Color(0xFF111827),
                              elevation: 4,
                              shadowColor: const Color(0x40E6B800),
                              shape: const StadiumBorder(),
                              // Kept gold rather than greyed: the spinner is the
                              // cue that it is working, and a grey button on a
                              // slow connection reads as broken.
                              disabledBackgroundColor: const Color(0xFFE6B800),
                              disabledForegroundColor: const Color(0xFF111827),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF111827),
                                    ),
                                  )
                                : Text(
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
