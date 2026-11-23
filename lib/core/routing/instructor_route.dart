import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens an instructor route when a router is present, and the previous
/// `Navigator.push` otherwise. Tests that pump a page with no router keep
/// working.
Future<T?> openInstructorRoute<T>(
  BuildContext context,
  String location, {
  Object? extra,
  required WidgetBuilder fallback,
}) {
  if (GoRouter.maybeOf(context) != null) {
    return context.push<T>(location, extra: extra);
  }
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: fallback));
}
