import 'dart:async';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

/// Why a location lookup failed, expressed in terms the UI can act on.
enum LocationFailureReason {
  /// GPS / location services are switched off at the OS level.
  serviceDisabled,

  /// The user said no this time (can be asked again).
  permissionDenied,

  /// The user said no permanently (only fixable from app settings).
  permissionDeniedForever,

  /// Services and permission are fine, but the fix never arrived.
  lookupFailed,
}

class LocationFailure implements Exception {
  const LocationFailure(this.reason, this.message);

  final LocationFailureReason reason;
  final String message;

  @override
  String toString() => 'LocationFailure(${reason.name}): $message';
}

class DetectedLocation {
  const DetectedLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  /// Human readable place name, e.g. `Baneshwor, Kathmandu`.
  final String label;
  final double latitude;
  final double longitude;
}

/// Thin wrapper around `geolocator` + `geocoding` so the signup screens stay
/// free of plugin details and platform quirks.
class LocationService {
  const LocationService();

  /// True when the device location can be read without prompting again.
  Future<bool> hasPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      // Plugin missing (e.g. unit tests) or platform refusal — treat as "ask".
      return false;
    }
  }

  /// Resolves the device's current position and turns it into a place name.
  ///
  /// Throws [LocationFailure] for every failure path so callers can show a
  /// specific message instead of a generic error.
  Future<DetectedLocation> detectCurrentLocation({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    var serviceEnabled = true;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      // Can't tell — let the position call below produce the real error.
    }

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureReason.serviceDisabled,
        'Location services are turned off on this device.',
      );
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      throw const LocationFailure(
        LocationFailureReason.lookupFailed,
        "We couldn't reach your device's location service.",
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
        'Location access is blocked for Skill Sikka.',
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureReason.permissionDenied,
        'Location access was not granted.',
      );
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      throw const LocationFailure(
        LocationFailureReason.lookupFailed,
        "We couldn't pin down your location in time.",
      );
    } catch (_) {
      throw const LocationFailure(
        LocationFailureReason.lookupFailed,
        "We couldn't read your location.",
      );
    }

    return DetectedLocation(
      label: await _describe(position),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Sends the user to the OS settings page so they can grant access.
  Future<void> openSettings({required bool forLocationServices}) async {
    try {
      if (forLocationServices) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // Nothing sensible to do if settings can't be opened.
    }
  }

  /// Best-effort reverse geocode. Falls back to coordinates when the platform
  /// geocoder is unavailable (it is on some Android builds without a backend).
  Future<String> _describe(Position position) async {
    final coordinates =
        '${position.latitude.toStringAsFixed(4)}, '
        '${position.longitude.toStringAsFixed(4)}';

    try {
      final placemarks = await geocoding.Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return coordinates;

      final placemark = placemarks.first;
      final parts = <String?>[
        placemark.subLocality,
        placemark.locality ?? placemark.subAdministrativeArea,
        placemark.administrativeArea,
      ];

      final unique = <String>[];
      for (final part in parts) {
        final value = part?.trim();
        if (value == null || value.isEmpty || unique.contains(value)) continue;
        unique.add(value);
      }

      if (unique.isEmpty) return coordinates;
      return unique.take(2).join(', ');
    } catch (_) {
      return coordinates;
    }
  }
}
