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
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/option_picker_sheet.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/registration_request.dart';
import '../../profile/data/gender.dart';
import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';

const _chevron = 'assets/figma/signup_chevron_down.svg';

/// Server field names that are not this form's keys.
///
/// Only the password confirmation differs now — the phone, the location and the
/// three geographic pickers that used to need aliases have moved to Edit
/// Profile, and they can no longer fail here because they are no longer sent.
/// `confirm` is the controller key and `confirm_password` the wire name; without
/// this an error the server raised on the pair would land on no input at all.
const _serverFieldAliases = <String, String>{'confirm_password': 'confirm'};

/// Step 2 of signup, instructor branch.
///
/// **Identity and credentials only — the same six fields as the student form.**
/// This is the payoff of the request we made on 2026-10-01: `InstructorRegistration`
/// used to require fifteen fields, so this screen had to ask for nine more than a
/// student's, for no product reason. The backend made those nine optional, and
/// they are now collected on Edit Profile behind the same completion gate.
///
/// The history is in `RegistrationRequest.instructor` — this screen has been
/// trimmed, restored to fifteen, and trimmed again, so a future reader finding
/// an old note claiming the instructor endpoint requires geography should trust
/// the schema over the note.
///
/// The avatar is still collected here even though it is optional on the wire: it
/// is the one field a user is asked for at signup in both roles, and the form is
/// built around it.
///
/// **The location popup runs here too, exactly as it does on the student form.**
/// It opens as soon as the form is on screen and, when the user confirms a fix,
/// writes the label into the [UserProfile] — there is no Location input on this
/// screen either, so Edit Profile is where it becomes visible.
///
/// It was dropped in `a605a12` while trimming the fifteen-field form down to
/// six, on a note claiming an instructor "has never been asked for a location at
/// signup". That note was wrong: the pre-trim form had a Location input with the
/// same crosshair the Edit Profile field has. And location is not a student-only
/// concern — it is one of `instructorCourseCreationFields`, so an instructor is
/// asked for it too, just later. Capturing the fix here is one GPS read instead
/// of a typed address on a screen the user may never reach.
class SignupInstructorFormPage extends ConsumerStatefulWidget {
  const SignupInstructorFormPage({
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
  ConsumerState<SignupInstructorFormPage> createState() =>
      _SignupInstructorFormPageState();
}

class _SignupInstructorFormPageState
    extends ConsumerState<SignupInstructorFormPage> {
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

  /// Field messages the server sent, keyed the way this form's controllers are.
  ///
  /// Kept so a validator can show them: the alternative is a snack bar that says
  /// "that email is taken" without pointing at the email box.
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
    // Ask for the current location as soon as the form is on screen — the same
    // moment the student form asks, so neither role is treated differently.
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
  /// There is no Location field on this screen, so the value is kept for the
  /// profile and the user gets a snack bar as the receipt.
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
    // Bytes, not a path: `Image.file` asserts `!kIsWeb`, so a File-based avatar
    // blanks the screen on Flutter web.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final rejection = profilePhotoRejection(
      fileName: picked.name,
      byteCount: bytes.length,
    );
    if (rejection != null) {
      _showSnack(rejection);
      return;
    }
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

    // Recorded before navigating: these values live only in the controllers and
    // are lost the moment this screen is popped, so the register call would have
    // nothing to send. Only the six this screen owns are written — a stale value
    // for a deferred field would look filled to the completeness gate and the
    // user would never be asked for it.
    final profileStore = ref.read(userProfileProvider.notifier);
    // The role step already recorded this, so for the normal flow the call is
    // redundant. It stays because a deep link straight to `/signup/instructor`
    // never passes through that step, and the role is what decides which field
    // set the profile screens show once the account exists.
    profileStore.setRole(ProfileRole.instructor);
    profileStore.save({
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
            RegistrationRequest.instructor(
              name: _controller('name').text.trim(),
              email: _controller('email').text.trim(),
              // Read here rather than from the store: a password is only ever
              // read by the method that sends it.
              password: _controller('password').text,
              // The backend requires this on the wire and validates the pair
              // itself; the client-side check above is not a substitute.
              confirmPassword: _controller('confirm').text,
              // The picker stores the label the user saw; the API wants the
              // lowercase wire value. Mapped here, at the boundary.
              gender: Gender.wireValueOf(_controller('gender').text),
              // The form holds DD / MM / YYYY because that is what the user
              // picks and reads; the API wants ISO, and the backend explicitly
              // allows the UI to keep displaying the other format.
              dob: isoDateOf(_controller('dob').text) ?? '',
              photo: PickedDocument(bytes: photo, fileName: photoName),
            ),
          );
      if (!mounted) return;
      // Cleared before navigating, not after: this screen stays on the stack
      // behind the next step, so coming back would otherwise find the button
      // still disabled.
      setState(() => _isSubmitting = false);
      context.push('/signup/verify');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _applyServerFieldErrors(error);
      showSignupErrorSnack(
        context,
        error,
        // True only when something actually landed on an input. The server may
        // name fields this screen does not have, and those must still be said.
        fieldErrorsAreShown: _serverErrors.isNotEmpty,
        // Offered only when the server says this email already has an account —
        // then signing in is the one thing worth doing next.
        onLogIn: () => context.go('/login-screen'),
      );
    }
  }

  /// Puts the server's per-field messages onto the matching inputs.
  ///
  /// Only fields this screen owns are mapped, and the wire names are translated
  /// first (see [_serverFieldAliases]) because the password confirmation is two
  /// names for one input here. Anything else the server names — `qualification`,
  /// `subject_expertise`, `province_id` — has no input to attach to and no
  /// business being rejected at signup any more, so it still reaches the user
  /// through the summary message the snack bar shows.
  void _applyServerFieldErrors(ApiException error) {
    if (!error.hasFieldErrors) return;

    for (final entry in error.fieldErrors.entries) {
      final key = _serverFieldAliases[entry.key] ?? entry.key;
      if (_controllers.containsKey(key)) {
        _serverErrors[key] = entry.value;
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
                        LabeledTextField(
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
                        LabeledTextField(
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
                        _passwordField(label: 'Password', key: 'password'),
                        const SizedBox(height: 16),
                        _passwordField(
                          label: 'Confirm Password',
                          key: 'confirm',
                          // Wrapped so the `confirm_password` alias above is
                          // actually reachable — without it a server error on
                          // the confirmation would be stored under `confirm` and
                          // never shown.
                          validator: _serverAware(
                            'confirm',
                            (value) => validateConfirmPassword(
                              value,
                              _controller('password').text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LabeledTextField(
                                label: 'Gender',
                                hint: 'Select gender',
                                hintFontSize: 12,
                                requiredField: true,
                                trailing: _chevron,
                                controller: _controller('gender'),
                                onTap: _selectGender,
                                validator: _serverAware(
                                  'gender',
                                  (value) => validateChoice(value, 'gender'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LabeledTextField(
                                label: 'Date of Birth',
                                hint: 'DD / MM / YYYY',
                                requiredField: true,
                                controller: _controller('dob'),
                                onTap: _selectDateOfBirth,
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

  /// A password box with the show/hide toggle.
  ///
  /// [validator] defaults to the password policy; the confirmation passes its
  /// own, because its rule depends on the other field.
  Widget _passwordField({
    required String label,
    required String key,
    FormFieldValidator<String>? validator,
  }) {
    return LabeledTextField(
      label: label,
      requiredField: true,
      hint: '••••••••••••',
      controller: _controller(key),
      leading: 'assets/figma/signup_lock.svg',
      validator: validator ?? _serverAware('password', validatePassword),
      // The confirmation rule depends on the password value, so editing either
      // has to re-check the pair.
      onChanged: (_) => _revalidate(),
      obscureText: _obscurePassword,
      trailingWidget: IconButton(
        onPressed: _togglePassword,
        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: _obscurePassword
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
    );
  }

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _selectGender() async {
    final value = await showOptionPickerSheet(
      context,
      title: 'Select gender',
      options: Gender.labels,
    );
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
