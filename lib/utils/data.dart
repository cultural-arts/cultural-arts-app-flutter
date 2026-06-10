import 'dart:convert';
import 'dart:typed_data';
import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


class DataUtilities {

  static String formatMapToString(Map<String, String> data) {
    final List<String> keyValuePairs = [];

    data.forEach((key, value) {
      keyValuePairs.add('$key=$value');
    });

    return '{${keyValuePairs.join(',')}}';
  }

  static Future<Map<String, String>> photoToWebStorage(Uint8List imageBytes) async {

    Map<String, String> exifData = {};
    String base64Image = '';

    // obtain image width and height
    var image = await decodeImageFromList(imageBytes);
    exifData['ImageLength'] = image.height.toString();
    exifData['ImageWidth'] = image.width.toString();

    // encode image to send
    base64Image = base64Encode(imageBytes);

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

    final formattedExifData = formatMapToString(exifData);

    return {
      'base64Image': base64Image,
      'formattedExifData': formattedExifData
    };
  }

}