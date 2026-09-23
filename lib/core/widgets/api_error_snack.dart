import 'package:flutter/material.dart';

import '../network/api_error.dart';

/// Shows an [ApiException] to the user.
///
/// The one place that decides how a failed request looks, so three signup
/// screens cannot drift into three different presentations.
///
/// [fieldErrorsAreShown] says whether the caller has already put the server's
/// per-field messages onto its inputs.
///
/// * When it has, the summary comes from [ApiException.displayMessage] — the
///   server's own wording, or an actionable default per kind.
/// * When it has not (a screen with no inline validation, such as the OTP boxes
///   or the instructor form), the field messages are the useful part, so they
///   are listed instead. `displayMessage` is deliberately skipped in that case:
///   its validation wording is "please check the highlighted fields", which
///   would point the user at nothing at all.
void showApiErrorSnack(
  BuildContext context,
  ApiException error, {
  bool fieldErrorsAreShown = false,
}) {
  final lines = <String>[];

  if (!fieldErrorsAreShown && error.hasFieldErrors) {
    final own = error.message?.trim();
    if (own != null && own.isNotEmpty) lines.add(own);
    lines.addAll(error.fieldErrors.values);
  }

  if (lines.isEmpty) lines.add(error.displayMessage);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(lines.join('\n')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
