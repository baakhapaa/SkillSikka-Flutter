/// Which kind of account the user has, and therefore which set of fields the
/// profile screens show.
///
/// This lives in the data layer rather than next to the edit screen because
/// three places need it and they are not all UI: the signup role step writes it,
/// the profile and enrol-gate screens read it, and `POST /auth/register` has to
/// send it.
///
/// [wireValue] is deliberately separate from [name] and from [label]. The label
/// is copy and will change; the wire value is a contract and must not.
enum ProfileRole {
  student('Student', 'student'),
  instructor('Instructor', 'instructor');

  const ProfileRole(this.label, this.wireValue);

  /// Shown in the header chip and on the role picker cards.
  final String label;

  /// What goes on the wire in `POST /auth/register`.
  final String wireValue;

  /// Parses a wire value, or returns null when it does not match.
  ///
  /// Null rather than a fallback on purpose: a response carrying an unrecognised
  /// role should be visible as a gap, not silently coerced into `student` and
  /// then shown to the user as if it were their real role.
  static ProfileRole? tryParse(String? value) {
    final needle = value?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return null;
    for (final role in ProfileRole.values) {
      if (role.wireValue == needle) return role;
    }
    return null;
  }
}
