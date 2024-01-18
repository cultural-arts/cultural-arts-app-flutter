import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ArtDefectDetectionAPI {
  final String baseUrl;

  ArtDefectDetectionAPI({required this.baseUrl});

  Future<http.Response> getBioColonizationDefects(
      String encodedPhoto, String exif) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bio-colonization-v0'),
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'encoded_photo': encodedPhoto,
        'exif': exif,
      },
    );

    return response;
  }
}
