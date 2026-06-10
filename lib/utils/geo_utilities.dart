import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:exif_reader/exif_reader.dart';


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

  /// ---------------------------
  /// EXTRACT GPS FROM IMAGE FILE
  /// ---------------------------

  static Future<Map<String, String>> extractGpsFromBytes(Uint8List imageBytes) async {
    try {
      final exif = await readExifFromBytes(imageBytes);

      if (exif.tags.isEmpty) return {};

      final latTag = exif.tags['GPS GPSLatitude'];
      final lonTag = exif.tags['GPS GPSLongitude'];
      final latRef = exif.tags['GPS GPSLatitudeRef']?.printable;
      final lonRef = exif.tags['GPS GPSLongitudeRef']?.printable;

      if (latTag == null || lonTag == null) return {};

      double parseDMS(IfdTag tag) {
        final values = tag.values.toList();
        final d = (values[0] as Ratio).toDouble();
        final m = (values[1] as Ratio).toDouble();
        final s = (values[2] as Ratio).toDouble();
        return d + m / 60 + s / 3600;
      }

      double lat = parseDMS(latTag);
      double lon = parseDMS(lonTag);
      if (latRef == 'S') lat = -lat;
      if (lonRef == 'W') lon = -lon;

      return {
        'GPSLatitude': lat.toString(),
        'GPSLongitude': lon.toString(),
      };
    } catch (_) {
      return {};
    }
  }
}