import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/location_prompt_dialog.dart';
import '../../../core/widgets/option_picker_sheet.dart';
import '../../../core/widgets/profile_photo_picker.dart';
import '../../../core/widgets/upload_card.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile_completion_request.dart';
import '../../auth/data/profile_update_request.dart';
import '../../auth/data/student_completion_request.dart';
import '../data/gender.dart';
import '../data/profile_role.dart';
import '../data/reference_data.dart';
import '../data/user_profile.dart';

const _pageBackground = Color(0xFFFAF9F6);
const _ink = Color(0xFF111827);
const _accent = Color(0xFFE6B800);
const _chevron = 'assets/figma/signup_chevron_down.svg';

/// What became of the user's answers when they tapped Save.
///
/// A `bool?` used to carry this and could not: `false` meant both "this role has
/// no server call to make" and "the call was made and the route is not built
/// yet", which are the same *result* and different *stories*. Only the second
/// one deserves a message that hedges, so the states are named instead of
/// inferred.
enum SaveOutcome {
  /// The server accepted the deferred fields.
  sentToServer,

  /// Nothing beyond the shared fields was sent because nothing needed sending —
  /// an ordinary save, where `PATCH /me/` took the common fields and the role's
  /// deferred half had nothing in it. Not a failure, and the message must not
  /// read like one.
  storedLocally,

  /// The deferred fields exist but the completion route answered 404, so they
  /// are on the device only for now.
  deferred,

  /// The request was made and failed. The error was shown; the local save stands.
  failed,
}

/// A [SaveOutcome] together with the failure that produced it, when there was
/// one.
///
/// Exists so `_sendCompletion` can report a failure **without presenting it**.
/// The screen has to show the error while it is still mounted and skip the
/// confirmation afterwards; a method that showed the error itself could not
/// express that, and the two snack bars ended up queued on top of each other.
@immutable
class SaveResult {
  const SaveResult(this.outcome, {this.error});

  final SaveOutcome outcome;

  /// The rejection to show, for [SaveOutcome.failed] and only that outcome.
  final ApiException? error;
}

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
    this.imagePicker = const PlatformImagePicker(),
    this.requireCompletion = false,
  });

  final ProfileRole role;

  /// Injectable so the location popup can be driven from tests.
  final LocationService locationService;

  /// Injectable for the same reason as [locationService] — and more importantly,
  /// because the photo is **state this screen has to hand back to the store**, a
  /// bug that is invisible until a test drives a pick through a save.
  final PhotoPicker imagePicker;

  /// When true this is the "complete your profile" step reached from the enrol
  /// gate: every field is mandatory, so the user cannot come back still
  /// incomplete. The profile tab leaves it false — a user fixing a typo should
  /// not be marched through eight required fields.
  final bool requireCompletion;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

/// The one method this screen needs from a photo picker.
///
/// Narrower than `ImagePicker` on purpose: a test only has to answer "what did
/// the user pick", and every other method of the real picker is irrelevant here.
abstract interface class PhotoPicker {
  Future<PickedPhoto?> pickImage();
}

/// A real image, as the picker hands it over.
///
/// **Bytes, not a path.** `Image.file` asserts `!kIsWeb` and crashes the moment a
/// photo is chosen on Flutter web, where a picked file's path is a blob URL
/// nothing else can read. The name travels with the bytes because dio infers an
/// upload's content type from the extension.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// The production picker, wrapped so the widget does not depend on
/// `image_picker` at all.
class PlatformImagePicker implements PhotoPicker {
  const PlatformImagePicker();

  @override
  Future<PickedPhoto?> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return PickedPhoto(bytes: await picked.readAsBytes(), name: picked.name);
  }
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _controllers = <String, TextEditingController>{};
  final _formKey = GlobalKey<FormState>();

  /// Errors stay hidden until the first save attempt, then update live as the
  /// user types.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// True while Save is awaiting the completion request. See the button.
  bool _isSaving = false;

  Uint8List? _photoBytes;

  /// The picked photo's own name, carried alongside the bytes.
  ///
  /// **Load-bearing, not cosmetic.** dio infers a part's content type from the
  /// filename extension, so a JPEG sent as `avatar.png` goes up labelled
  /// `image/png`. It is recorded at the same moment as the bytes because a photo
  /// whose name is the *previous* one is worse than no upload at all.
  String? _photoFileName;

  /// True once the user picks a **new** photo on this screen.
  ///
  /// [_photoBytes] cannot answer that on its own: it is seeded from the store in
  /// [initState] so the signup photo shows without being picked twice, which
  /// makes "there is a photo" and "the user just changed the photo" the same
  /// value. Without this flag every save would re-upload the photo already sent
  /// at signup — and, for a 5 MB image, on every single save.
  bool _photoDirty = false;

  PlatformFile? _studentIdCard;
  PlatformFile? _cvFile;
  PlatformFile? _certificatesFile;

  /// The backend ids behind the geographic fields, keyed by controller key.
  ///
  /// The store holds what the user *read* (`Bagmati`, `Kathmandu`), while the
  /// completion endpoint validates the hierarchy by **id** — and the picker's
  /// captured id is the only place that exists, so it is dropped the moment the
  /// sheet closes unless it is kept here. Cleared alongside the field by
  /// [_pickRemoteOption], exactly as signup does it.
  ///
  /// **Unverified against a live endpoint**: no schema fetch has confirmed the
  /// completion route's spelling for these. They are sent; if the backend wants
  /// different names the values will simply be ignored rather than misfiled,
  /// because they are only ever written when the user actually picked one.
  final _selectedIds = <String, String>{};

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
    'province',
    'district',
    'municipality',
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

  /// Whatever the profile holds, or blank.
  ///
  /// **No fallback to demo values.** This used to fall back to a hardcoded
  /// `_studentSeed` / `_instructorSeed` holding "Shuvanga Karki" and a fake
  /// email, from when the profile store was a stand-in for an API. Now that
  /// `GET /me/` fills the store on sign-in (see `SessionBootstrap`), a seed
  /// would be worse than blank: it would show a real user someone else's name
  /// and email, and Save would then write those into their profile.
  ///
  /// A blank field is the honest state — the completeness gate treats it as
  /// missing and asks the user to fill it.
  ///
  /// The location detected at signup surfaces here for the same reason it always
  /// did: signup has no field to show it in.
  String _initialValue(String key) =>
      ref.read(userProfileProvider).valueFor(key);

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
    final picked = await widget.imagePicker.pickImage();
    if (picked == null) return;
    final bytes = picked.bytes;
    if (!mounted) return;
    final rejection = profilePhotoRejection(
      fileName: picked.name,
      byteCount: bytes.length,
    );
    if (rejection != null) {
      _showUploadError(rejection);
      return;
    }
    setState(() {
      _photoBytes = bytes;
      _photoFileName = picked.name;
      _photoDirty = true;
    });
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

  /// Opens the option sheet and writes the choice into [key].
  ///
  /// [title] is the **bare noun** — `class`, `province`, `school or college` —
  /// not the sheet's heading. The sheet is given `Select $title`, while
  /// [_showEmptyOptions] needs the noun on its own: "No class options are
  /// available yet." is a sentence, "No Select class options…" is not.
  /// `signup_instructor_form_page.dart` splits the two the same way.
  ///
  /// This is why the pickers used to read just "class" and "province" while
  /// Gender read "Select gender" — that one call site was passing the finished
  /// heading, and the sheet rendered whatever it was handed.
  Future<void> _pickOption({
    required String key,
    required String title,
    required List<String> options,
    List<String> clearKeys = const [],
    List<String>? optionIds,
  }) async {
    final value = await showOptionPickerSheet(
      context,
      title: 'Select $title',
      options: options,
    );
    if (value == null || !mounted) return;
    // By name, not by index: this sheet answers with the label the user tapped,
    // and `optionIds` is aligned with `options`, so the matching id is the one at
    // the same position. The reference lists genuinely contain duplicate names
    // (two municipalities really are both called "Aaurahi"), which is why the
    // *id* is recorded rather than looked up again later.
    final index = options.indexOf(value);
    setState(() {
      _controller(key).text = value;
      if (optionIds != null && index >= 0 && index < optionIds.length) {
        _selectedIds[key] = optionIds[index];
      }
      // A child list is only valid under the parent just chosen — and the id it
      // carried is now wrong, so it goes with the name.
      for (final clearKey in clearKeys) {
        _controller(clearKey).clear();
        _selectedIds.remove(clearKey);
      }
    });
    _revalidate();
  }

  /// The same, but the options come from the backend and have to be awaited
  /// before the sheet can open.
  ///
  /// Province, district, school and grade were hardcoded `const` lists — four
  /// provinces against the backend's seven, and school names the database has
  /// never held. Fetching them is what makes the saved value real: a const list
  /// invites the user to save something the backend will not recognise, and it
  /// goes stale silently the moment the reference data changes.
  ///
  /// An empty result opens no sheet at all. That is deliberate: the school list
  /// is genuinely empty on the backend today, and a sheet with nothing in it
  /// looks broken, whereas doing nothing plus the empty-state message below
  /// reads as "nothing to choose yet".
  ///
  /// [title] is the bare noun, as in [_pickOption].
  Future<void> _pickRemoteOption({
    required String key,
    required String title,
    required Future<List<ReferenceItem>> Function() load,
    List<String> clearKeys = const [],
  }) async {
    final items = await load();
    if (!mounted) return;
    if (items.isEmpty) {
      _showEmptyOptions(title);
      return;
    }
    await _pickOption(
      key: key,
      title: title,
      options: items.map((item) => item.name).toList(growable: false),
      clearKeys: clearKeys,
      // Two lists in step: the names the user reads, and the ids the completion
      // endpoint validates against. Dropping the ids here is what made the
      // deferred geographic fields unsendable.
      optionIds: items.map((item) => item.id).toList(growable: false),
    );
  }

  /// Tells the user there is nothing to pick, rather than opening a blank sheet.
  ///
  /// Takes the bare [noun], not the sheet's `Select …` heading.
  void _showEmptyOptions(String noun) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text('No $noun options are available yet.')),
    );
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
    // The backend allows 10 MB for the student ID card (handoff §6). This guard
    // used to be 5 MB, which refused files the backend would have accepted.
    if (file.size > 10 * 1024 * 1024) {
      _showUploadError('Student ID card must be 10 MB or smaller.');
      return;
    }
    final bytes = _bytesOf(file);
    if (bytes == null) return;

    setState(() => _studentIdCard = file);
    ref
        .read(userProfileProvider.notifier)
        .setDocument(
          ProfileDocumentSlot.studentIdCard,
          PickedDocument(bytes: bytes, fileName: file.name),
        );
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
    final bytes = _bytesOf(file);
    if (bytes == null) return;

    setState(() {
      if (isCv) {
        _cvFile = file;
      } else {
        _certificatesFile = file;
      }
    });
    ref
        .read(userProfileProvider.notifier)
        .setDocument(
          isCv
              ? ProfileDocumentSlot.cvResume
              : ProfileDocumentSlot.certificates,
          PickedDocument(bytes: bytes, fileName: file.name),
        );
  }

  Future<PlatformFile?> _pickFile({
    required List<String> allowedExtensions,
  }) async {
    // withData: true so the bytes come back in memory. The app targets Flutter
    // web, where a picked file's path is a blob URL nothing else can read, so
    // without this the file is picked, displayed, and then uploaded as nothing.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  /// The picked file's bytes, or null after telling the user it could not be
  /// read. A file with no bytes is unusable rather than merely inconvenient.
  Uint8List? _bytesOf(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    _showUploadError('That file could not be read. Please pick another.');
    return null;
  }

  /// Removes a file from the screen *and* the store. The store took a copy of
  /// the bytes when the file was picked, so clearing only the local state would
  /// leave the deleted file queued for upload.
  void _clearDocument(String slot, VoidCallback clearLocal) {
    clearLocal();
    ref.read(userProfileProvider.notifier).clearDocument(slot);
  }

  void _showUploadError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
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
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    // Written **before** the network call, not after: an edit the user made is
    // theirs whether or not the server accepted it, and a rejected save must not
    // also lose their typing.
    //
    // The server's own answer then overwrites these values where it has one —
    // see [_sendSharedFields] — so the store ends up agreeing with what was
    // actually stored rather than with what was typed.
    ref.read(userProfileProvider.notifier).save({
      for (final key in _editableKeys) key: _controller(key).text.trim(),
    });

    // **The photo too, and for the same reason — it was missing, and it was the
    // one change with no visible effect at all.** The bytes live in widget state
    // (see [_photoDirty]); nothing wrote them to the store here, so the profile
    // tab behind this screen kept rendering the *old* avatar until a relogin
    // re-downloaded it from `/me/`. A user who changed their picture and saw it
    // snap back had no way to tell the upload had worked.
    //
    // Written at the same moment as the text, before the network call, so a
    // rejected save still shows them what they chose. The server's copy wins on
    // the next login, which is the correct order of authority.
    if (_photoDirty) {
      final bytes = _photoBytes;
      final fileName = _photoFileName;
      if (bytes != null && fileName != null) {
        ref.read(userProfileProvider.notifier).setPhoto(bytes, fileName);
      }
    }

    // Everything the role's endpoints can accept: the seven shared fields for
    // both roles, then the deferred half for the role that has one.
    final result = await _sendCompletion();

    if (!mounted) return;
    setState(() => _isSaving = false);

    // **One message, never two.** A failure has an error to report, and showing
    // that *and* a confirmation queues two snack bars on the same messenger —
    // the confirmation then arrives four seconds later, over a screen the user
    // has already left, with nothing to attach it to. So the error replaces the
    // confirmation, and goes through the shared helper so this screen's failures
    // look like every other screen's.
    //
    // Both branches use the app-level messenger, which outlives this route
    // either way — so the order relative to `pop()` is not what keeps the
    // message alive. The error goes before the pop purely so its `context` is
    // still this screen's; the helper resolves the messenger from it.
    final error = result.error;

    if (error != null) {
      showApiErrorSnack(context, error);
      navigator.pop();
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_savedMessage(result.outcome))),
    );
  }

  /// Hands the profile to whichever endpoints the signed-in role has.
  ///
  /// **Two calls, in order.** The seven shared fields go to `PATCH /me/` for
  /// both roles; the instructor's nine deferred fields go to the completion
  /// route. The shared call runs first and a failure there ends the save — see
  /// [_sendSharedFields].
  ///
  /// Returns the [SaveResult] — what happened, and the error when something did
  /// — **without showing anything**. The caller decides how to present it,
  /// because only the caller knows the route is about to be popped and that the
  /// error has to replace the confirmation rather than queue behind it. Showing
  /// a snack bar from here is what queued two of them.
  ///
  /// A student's **completion** half goes to `POST /me/complete-profile/`, which
  /// takes `grade_id`, `province_id`, `district_id`, `municipality_id` and
  /// `school_id` — a hierarchy of ids where this screen holds names, so the ids
  /// are resolved from the reference data at save time. See [_studentRequest].
  Future<SaveResult> _sendCompletion() async {
    // The shared half first, for **both** roles. `PATCH /me/` took the seven
    // common fields on 2026-10-02; before it existed this method returned
    // immediately for a student and sent only the instructor's nine, so an edit
    // to the name, gender or date of birth had nowhere to go and was gone by
    // the next login.
    final shared = await _sendSharedFields();
    if (shared != null) return shared;

    final body = await (_isInstructor ? _instructorBody() : _studentBody());
    if (body == null) return const SaveResult(SaveOutcome.storedLocally);

    try {
      final accepted = await ref
          .read(authRepositoryProvider)
          .completeProfile(role: widget.role, fields: body);
      // `false` here means the route answered 404 — the one case where the user
      // typed something that genuinely did not reach a server. Everything else
      // that did not go is `storedLocally`, which needs no apology.
      return SaveResult(
        accepted ? SaveOutcome.sentToServer : SaveOutcome.deferred,
      );
    } on ApiException catch (error) {
      return SaveResult(SaveOutcome.failed, error: error);
    }
  }

  /// The instructor's nine deferred fields as a wire body, or null when there is
  /// nothing to send.
  ///
  /// **Awaited, for the same reason the student's is.** The geographic ids are
  /// read from the pickers when they are there and resolved from the stored
  /// names when they are not — see [_resolveIds]. A picker id is authoritative
  /// when present: it is what the user just tapped, so it cannot have gone stale
  /// against reference data.
  ///
  /// **This resolution used to be missing here**, and the doc comment above
  /// claimed otherwise. `_selectedIds` is populated only while a picker sheet is
  /// open, so an instructor who opened Edit Profile and saved without reopening
  /// all three pickers sent a body with **all three geographic ids missing** —
  /// which are required fields on this route. That is now fixed, and the test
  /// *'sends the geographic ids resolved from the names alone'* pins it.
  Future<Map<String, String>?> _instructorBody() async {
    final values = {
      for (final key in _editableKeys) key: _controller(key).text.trim(),
    };
    final ids = await _resolveIds(values);

    final request = InstructorCompletionRequest.forInstructor(
      values,
      provinceId: _selectedIds['province'] ?? ids.locations.provinceId,
      districtId: _selectedIds['district'] ?? ids.locations.districtId,
      municipalityId:
          _selectedIds['municipality'] ?? ids.locations.municipalityId,
    );
    if (request.isEmpty) return null;
    return request.toWireBody(widget.role);
  }

  /// The student's seven deferred fields as a wire body, or null when there is
  /// nothing worth sending.
  ///
  /// **Awaited, like [_instructorBody].** Resolving the geographic ids means
  /// fetching the reference lists, which is why these cannot be a synchronous
  /// build.
  ///
  /// Null when the seven required fields cannot all be assembled. This route has
  /// no partial mode — it names every missing field in one 400 — so a student who
  /// has filled in a class but not a school is better served by leaving their
  /// profile alone than by an error they cannot resolve. See
  /// [StudentCompletionRequest.isComplete].
  Future<Map<String, String>?> _studentBody() async {
    final values = {
      for (final key in _editableKeys) key: _controller(key).text.trim(),
    };
    final ids = await _resolveIds(values);

    final request = StudentCompletionRequest.fromValues(
      values,
      gradeId: ids.gradeId,
      provinceId: _selectedIds['province'] ?? ids.locations.provinceId,
      districtId: _selectedIds['district'] ?? ids.locations.districtId,
      // No municipality picker on the student's form, so this can only ever come
      // from the school. See [ReferenceItem.municipalityId].
      municipalityId: ids.locations.municipalityId,
      schoolId: _selectedIds['school'] ?? ids.locations.schoolId,
    );

    // Incomplete means the route would reject the whole body, so nothing is sent
    // and nothing is claimed. `isComplete` covers `municipality_id` too — the
    // route 500s without it rather than answering a 400.
    if (!request.isComplete) return null;
    return request.toWireBody(widget.role);
  }

  /// Looks the geographic and grade ids up from the names the store holds.
  ///
  /// **The fallback for a profile that arrived from the server.** The pickers
  /// record ids in [_selectedIds] only while a sheet is open, so they are gone
  /// for any profile that was prefilled rather than re-picked. That is not
  /// acceptable for a user who signs in, finds their class and school already
  /// filled in, and taps Save expecting them to stick — so the names are
  /// resolved back to ids here.
  ///
  /// **Both roles need this, which they did not before.** It was written for the
  /// student path and the instructor path never called it, so an instructor
  /// saving a prefilled profile sent no geographic ids at all.
  ///
  /// The municipality list is fetched **only when the form has a municipality
  /// field** — that is, only for an instructor. A student's form has no
  /// municipality picker (their id comes from the school), so the request would
  /// be a fifth round trip on every save for a value they cannot supply.
  ///
  /// Returns nulls rather than throwing when the reference data cannot be
  /// fetched: a save that cannot resolve its ids should leave those fields local
  /// and report the rest, not fail outright over a lookup.
  Future<({String? gradeId, LocationIds locations})> _resolveIds(
    Map<String, String> values,
  ) async {
    final needsMunicipality = values.containsKey('municipality');
    try {
      final api = ref.read(referenceDataApiProvider);
      final resolved = resolveLocationIds(
        grades: await api.grades(),
        provinces: await api.provinces(),
        districts: await api.districts(),
        schools: await api.schools(),
        municipalities: needsMunicipality
            ? await api.municipalities()
            : const [],
        gradeName: values['grade'] ?? '',
        provinceName: values['province'] ?? '',
        districtName: values['district'] ?? '',
        schoolName: values['school'] ?? '',
        municipalityName: values['municipality'] ?? '',
      );
      return resolved;
    } on Object {
      // Reference data unavailable. The shared fields have already been sent by
      // this point, so the save is partly real; dropping the deferred half is
      // better than failing the whole thing over a lookup.
      return (gradeId: null, locations: const LocationIds());
    }
  }

  /// The documents picked **on this screen**, shaped the way `PATCH /me/` wants
  /// them.
  ///
  /// **Only newly-picked files travel, and that is deliberate.** The profile
  /// store holds every document the user has ever picked this session, so
  /// sending "what the store has" would re-upload the same megabytes on every
  /// save. For `certificates_and_recommendations` it would be worse than
  /// wasteful: that slot is **additive** server-side, so a second save would add
  /// a duplicate copy every time. The widget fields are the honest "changed
  /// since this screen opened" signal, and they start empty.
  ///
  /// **Filtered by role**, because the route answers **400 naming the field**
  /// when a role sends a slot it may not — not a silent ignore. `profile_photo`
  /// is the only slot both roles may send; `student_id_card` belongs to a
  /// student and `cv_resume` / `certificates_and_recommendations` to an
  /// instructor. Verified against the live schema 2026-10-05.
  ///
  /// **Certificates go in [MultipartFile] lists, not the single-file map.** A
  /// `Map` holds one value per key, so a second certificate sent that way would
  /// replace the first instead of adding to it.
  ///
  /// A photo with no remembered filename is **skipped rather than given a
  /// guessed one**, because the extension is what picks the content type and a
  /// wrong guess uploads a real PNG labelled `image/jpeg`. `_photoDirty` is only
  /// set by the picker, which always supplies a name, so this is belt-and-braces.
  ({
    Map<String, MultipartFile> files,
    Map<String, List<MultipartFile>> fileLists,
  })
  _pendingUploads() {
    final files = <String, MultipartFile>{};
    final fileLists = <String, List<MultipartFile>>{};

    final bytes = _photoBytes;
    final photoName = _photoFileName;
    if (_photoDirty && bytes != null && photoName != null) {
      files[AuthApi.photoField] = filePart(bytes: bytes, fileName: photoName);
    }

    // `bytes` is nullable on `PlatformFile`, and a file the picker could not read
    // has none. The pickers already refuse those before storing them, so this is
    // belt-and-braces — but a null slipping through would be a runtime crash on
    // the save path rather than a missing upload, so it is skipped instead.
    Uint8List? bytesOf(PlatformFile? file) => file?.bytes;

    // The student's one slot.
    final idCard = _studentIdCard;
    if (!_isInstructor) {
      final bytes = bytesOf(idCard);
      if (idCard != null && bytes != null) {
        files[ProfileDocumentSlot.studentIdCard] = filePart(
          bytes: bytes,
          fileName: idCard.name,
        );
      }
    }

    if (_isInstructor) {
      final cv = _cvFile;
      final cvBytes = bytesOf(cv);
      if (cv != null && cvBytes != null) {
        files[ProfileDocumentSlot.cvResume] = filePart(
          bytes: cvBytes,
          fileName: cv.name,
        );
      }
      final certificates = _certificatesFile;
      final certificateBytes = bytesOf(certificates);
      if (certificates != null && certificateBytes != null) {
        fileLists[ProfileDocumentSlot.certificates] = [
          filePart(bytes: certificateBytes, fileName: certificates.name),
        ];
      }
    }

    return (files: files, fileLists: fileLists);
  }

  /// Sends the seven fields `PATCH /me/` accepts — for either role — plus any
  /// document picked on this screen.
  ///
  /// Returns null when there was nothing to send or the call succeeded, so the
  /// caller carries on to the role's deferred half; a [SaveResult] means the
  /// save is finished, one way or the other.
  ///
  /// **A failure here stops the save.** That is a change in behaviour, and the
  /// right one: before this route existed a 400 was impossible because no request
  /// was made. Now that the user's edits genuinely go to a server, a rejected
  /// body is a real rejection, and continuing to the completion route would
  /// report success for a save that half-failed.
  ///
  /// The response is applied back into the store when there is one. The server
  /// is the authority on what it stored — it may normalise a date or drop a
  /// field it does not recognise — so the screen should end up agreeing with it
  /// rather than with what was typed.
  Future<SaveResult?> _sendSharedFields() async {
    final request = ProfileUpdateRequest.fromValues({
      for (final key in _editableKeys) key: _controller(key).text.trim(),
    });
    final uploads = _pendingUploads();
    final hasUploads = uploads.files.isNotEmpty || uploads.fileLists.isNotEmpty;

    // **Both halves count as something to do.** Someone who changed only their
    // photo has no text at all, and returning early on empty fields alone would
    // tell them "Profile updated." while their picture quietly went nowhere —
    // which is the bug this route was added to fix.
    if (request.isEmpty && !hasUploads) return null;

    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            request.fields,
            files: uploads.files,
            fileLists: uploads.fileLists,
          );
      if (updated != null) {
        final values = updated.profileValues;
        if (values.isNotEmpty) {
          ref.read(userProfileProvider.notifier).save(values);
        }
      }
      return null;
    } on ApiException catch (error) {
      return SaveResult(SaveOutcome.failed, error: error);
    }
  }

  /// What to say after a save, which depends on what actually happened to the
  /// user's answers.
  ///
  /// Four outcomes hide behind one button, and "Profile updated." for all of them
  /// was the old behaviour. It was only a lie in *some* of them: a user whose
  /// details genuinely reached the server should hear it, and so should a user
  /// whose role simply has no server call to make. Telling a student their edit
  /// was "stored on this device" invents a limitation that does not exist for
  /// them and reads as a warning.
  ///
  /// So the message follows [SaveOutcome], not "did it send".
  String _savedMessage(SaveOutcome outcome) {
    switch (outcome) {
      case SaveOutcome.sentToServer:
      // Nothing on the completion route needed sending — the shared fields were
      // already accepted by `PATCH /me/`. This is the normal, successful path.
      case SaveOutcome.storedLocally:
        return 'Profile updated.';
      case SaveOutcome.deferred:
        // The instructor filled something in and the route is not live yet. We
        // cannot honestly claim it reached the server.
        return 'Profile saved on this device.';
      case SaveOutcome.failed:
        // **Unreachable, and deliberately not thrown away.** `_save` returns
        // early for this outcome, showing the error instead — a failure gets the
        // error message, never a confirmation on top of it. Kept so the switch
        // stays exhaustive: if the early return is ever removed, this is the
        // sentence that comes back, and it is written to be true.
        return 'Saved on this device — the server rejected the update.';
    }
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
                            // Disabled while the completion request is in
                            // flight: a second tap would send the same profile
                            // twice, and the button is the only thing on screen
                            // that says anything is happening.
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _ink,
                              elevation: 4,
                              shadowColor: const Color(0x40E6B800),
                              shape: const StadiumBorder(),
                              disabledBackgroundColor: _accent,
                              disabledForegroundColor: _ink,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: _ink,
                                    ),
                                  )
                                : Text(
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
          // Bare noun — the sheet adds "Select" itself. Passing the finished
          // "Select gender" here is what made the other pickers look different.
          title: 'gender',
          options: Gender.labels,
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
      onTap: () => _pickRemoteOption(
        key: 'grade',
        title: 'class',
        // `Grade 1` … `Grade 12` from `/grades/`. The hardcoded list here said
        // `Class 8`–`Class 12` — different words **and** a different range, so a
        // saved value would not have matched anything the backend holds.
        load: () => ref.read(gradesProvider.future),
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
        onTap: () => _pickRemoteOption(
          key: 'province',
          title: 'province',
          // The real seven provinces, not the four that were hardcoded here.
          load: () => ref.read(provincesProvider.future),
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
        onTap: () => _pickRemoteOption(
          key: 'district',
          title: 'district',
          // Filtered to the chosen province, which is what `province_id` on each
          // district is for. Without the filter every district in the country
          // would be offered under any province.
          load: () => ref.read(
            districtsForProvinceProvider(_controller('province').text).future,
          ),
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
      onTap: () => _pickRemoteOption(
        key: 'school',
        title: 'school or college',
        load: () => ref.read(
          schoolsForDistrictProvider(_controller('district').text).future,
        ),
      ),
    ),
    UploadCard(
      title: 'Student ID Card',
      formats: 'Supported formats: PDF, JPG, PNG (Max 10MB)',
      asset: 'assets/figma/signup_student_file.svg',
      pickedFile: _studentIdCard,
      onTap: _pickStudentIdCard,
      onClear: () => _clearDocument(
        ProfileDocumentSlot.studentIdCard,
        () => setState(() => _studentIdCard = null),
      ),
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
    // The three geographic fields, which a student picks on the way to a school
    // and an instructor needs for the same reason: the completion endpoint
    // validates them as a hierarchy. Municipality comes third here where a
    // student's third field is School — same provinces, same districts, a
    // different leaf.
    _twoUp(
      _field(
        key: 'province',
        label: 'Province',
        hint: 'Select province',
        hintFontSize: 12,
        trailing: _chevron,
        validator: _requiredChoice('province'),
        onTap: () => _pickRemoteOption(
          key: 'province',
          title: 'province',
          load: () => ref.read(provincesProvider.future),
          clearKeys: const ['district', 'municipality'],
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
        onTap: () => _pickRemoteOption(
          key: 'district',
          title: 'district',
          load: () => ref.read(
            districtsForProvinceProvider(_controller('province').text).future,
          ),
          clearKeys: const ['municipality'],
        ),
      ),
    ),
    _field(
      key: 'municipality',
      label: 'Municipality',
      hint: 'Select district first',
      hintFontSize: 12,
      trailing: _chevron,
      enabled: _controller('district').text.isNotEmpty,
      validator: _requiredChoice('municipality'),
      onTap: () => _pickRemoteOption(
        key: 'municipality',
        title: 'municipality',
        load: () => ref.read(
          municipalitiesForDistrictProvider(
            _controller('district').text,
          ).future,
        ),
      ),
    ),
    UploadCard(
      title: 'CV / Resume',
      formats: 'Supported formats: PDF, DOCX (Max 5MB)',
      asset: 'assets/figma/signup_file_text.svg',
      pickedFile: _cvFile,
      onTap: () => _pickDocument(isCv: true),
      onClear: () => _clearDocument(
        ProfileDocumentSlot.cvResume,
        () => setState(() => _cvFile = null),
      ),
      removeTooltip: 'Remove CV',
    ),
    UploadCard(
      title: 'Certificates & Recommendation Letters',
      formats: 'Supported formats: PDF, JPG, PNG (Max 10MB)',
      asset: 'assets/figma/signup_file.svg',
      pickedFile: _certificatesFile,
      onTap: () => _pickDocument(isCv: false),
      onClear: () => _clearDocument(
        ProfileDocumentSlot.certificates,
        () => setState(() => _certificatesFile = null),
      ),
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
