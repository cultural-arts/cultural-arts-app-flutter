import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// ---------------------------
/// CONFIG DEFAULT LOCATION
/// ---------------------------

class LocationConfig {
  static const double defaultLatitude = 45.5455;
  static const double defaultLongitude = 11.5354;
}

/// DEV MODE: bypass GPS (blocchi admin inclusi)
const bool useFakeLocation = kDebugMode;

/// ---------------------------
/// LOCATION SERVICE
/// ---------------------------

class LocationService {
  /// Main entry point (safe for UI)
  static Future<Position> getPosition() async {
    if (useFakeLocation) {
      return _fakePosition();
    }

    try {
      final permission = await _handlePermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return _fakePosition(); // fallback automatico
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return _fakePosition(); // fallback sicurezza
    }
  }

  /// ---------------------------
  /// PERMISSION HANDLING
  /// ---------------------------

  static Future<LocationPermission> checkPermission() async {
    if (useFakeLocation) {
      return LocationPermission.whileInUse;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.unableToDetermine;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }


  /// ---------------------------
  /// PERMISSION HANDLING
  /// ---------------------------

  static Future<LocationPermission> _handlePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return LocationPermission.unableToDetermine;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// ---------------------------
  /// FAKE POSITION (DEV + FALLBACK)
  /// ---------------------------

  static Position _fakePosition() {
    return Position(
      latitude: LocationConfig.defaultLatitude,
      longitude: LocationConfig.defaultLongitude,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0
    );
  }

  /// ---------------------------
  /// VALIDATION UTILITY
  /// ---------------------------

  static bool isGPSValidCoordinates(String? lat, String? lon) {
    if (lat == null || lon == null) return false;

    final regex = RegExp(r"^-?\d+(\.\d+)?$");

    return regex.hasMatch(lat) && regex.hasMatch(lon);
  }
}