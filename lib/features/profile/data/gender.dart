/// The gender options a user can pick, and what each one puts on the wire.
///
/// Same shape as [ProfileRole], and for the same reason: [label] is copy and
/// will change, [wireValue] is a contract and must not.
///
/// The wire values are **confirmed lowercase** by the backend handoff §2 —
/// `male`, `female`, `other` — which states explicitly that `Male` is wrong. So
/// the label the picker shows and the value the API receives are now different
/// strings, and the forms map between them with [wireValueOf].
///
/// The mapping has to happen at the request boundary rather than in the picker,
/// because `showOptionPickerSheet` returns the string it was given and that is
/// also what the profile store holds — the store keeps what the user sees, the
/// request sends what the server wants.
enum Gender {
  female('Female', 'female'),
  male('Male', 'male'),
  other('Other', 'other');

  const Gender(this.label, this.wireValue);

  /// Shown in the picker.
  final String label;

  /// What goes on the wire as `gender`. Lowercase, per the backend contract.
  final String wireValue;

  /// The picker's options, in the order they are shown.
  static List<String> get labels =>
      Gender.values.map((gender) => gender.label).toList(growable: false);

  /// Matches a label or a wire value, case-insensitively, or returns null.
  ///
  /// Tolerant on both sides because the profile store holds a [label] while a
  /// response from the server would carry a [wireValue]; reading has to survive
  /// both without a migration.
  static Gender? tryParse(String? value) {
    final needle = value?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return null;
    for (final gender in Gender.values) {
      if (gender.label.toLowerCase() == needle ||
          gender.wireValue.toLowerCase() == needle) {
        return gender;
      }
    }
    return null;
  }

  /// The wire value for a value the picker stored, or the trimmed input
  /// unchanged when it is not one we recognise.
  ///
  /// Passing an unrecognised value through rather than blanking it is
  /// deliberate. A blank would be caught by the form's own "please select"
  /// validation and reported as an empty field, which hides the real problem;
  /// an unrecognised value should fail at the server, where the vocabulary is
  /// actually defined.
  static String wireValueOf(String? stored) {
    final trimmed = (stored ?? '').trim();
    return tryParse(trimmed)?.wireValue ?? trimmed;
  }
}
