import 'dart:convert';
import 'dart:typed_data';
import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

class DataUtilities {

  static String formatMapToString(Map<String, String> data) {
    final List<String> keyValuePairs = [];

    data.forEach((key, value) {
      keyValuePairs.add('$key=$value');
    });

    return '{${keyValuePairs.join(',')}}';
  }

  static Future<Map<String, String>> photoToWebStorage(Uint8List imageBytes, {
    bool useCurrentLocation = true,
  }) async {

    Map<String, String> exifData = {};
    String base64Image = '';

    // obtain image width and height
    var image = await decodeImageFromList(imageBytes);
    exifData['ImageLength'] = image.height.toString();
    exifData['ImageWidth'] = image.width.toString();

    // encode image to send
    base64Image = base64Encode(imageBytes);

    if (useCurrentLocation) {
      // add gps location provider with geolocator
      Position currentPosition = await LocationService.getPosition();
      String latitude = currentPosition.latitude.toString();
      String longitude = currentPosition.longitude.toString();

      if (LocationService.isGPSValidCoordinates(latitude, longitude)) {
        exifData["GPSLatitude"] = latitude;
        exifData["GPSLongitude"] = longitude;
      } else {
        exifData["OriginalGPSLatitude"] = latitude;
        exifData["OriginalGPSLongitude"] = longitude;
        exifData["GPSLatitude"] = LocationConfig.defaultLatitude.toString();
        exifData["GPSLongitude"] = LocationConfig.defaultLongitude.toString();
      }
    } else {
      final gps = await LocationService.extractGpsFromBytes(imageBytes);
      if (gps.isNotEmpty) {
        exifData.addAll(gps);
      } else {
        exifData["GPSLatitude"] = LocationConfig.defaultLatitude.toString();
        exifData["GPSLongitude"] = LocationConfig.defaultLongitude.toString();
      }
    }

    final formattedExifData = formatMapToString(exifData);

    return {
      'base64Image': base64Image,
      'formattedExifData': formattedExifData
    };
  }

  static Uint8List compressImage(Uint8List imageBytes, {int quality = 92}) {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return imageBytes;
    
    final isPortrait = decodedImage.height > decodedImage.width;

    final resized = img.copyResize(
      decodedImage,
      width: isPortrait ? 1080 : 1920,
      height: isPortrait ? 1920 : 1080,
      maintainAspect: true,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

}
