import 'dart:convert';

import 'package:http/http.dart' as http;

class AiCompanionApiException implements Exception {
  const AiCompanionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiCompanionAPI {
  AiCompanionAPI({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<String> describeImage(
    String encodedPhoto,
    String exif, {
    String mode = 'standard',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/ai-companion'),
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'encoded_photo': encodedPhoto,
        'exif': exif,
        'mode': mode,
      },
    );

    if (response.statusCode != 200) {
      throw AiCompanionApiException(_errorMessage(response));
    }

    final responseData = jsonDecode(response.body);
    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI Companion response.');
    }

    final description = responseData['description'];
    if (description is! String || description.trim().isEmpty) {
      throw const FormatException('AI Companion returned no description.');
    }

    return description.trim();
  }

  String _errorMessage(http.Response response) {
    switch (response.statusCode) {
      case 429:
        return 'Our AI companion has reached its shared global limit of 100 '
            'calls for today. Sorry for the pause! The AI service is provided '
            'on a fixed monthly term. If you’re interested or have any questions, '
            'contact info@cultural-arts.com.';
      case 452:
        return 'The image could not be processed. Please try another image.';
      case 502:
      case 503:
        return 'The image description service is unavailable. Please try again later.';
      default:
        return 'Image description request failed (HTTP ${response.statusCode}).';
    }
  }

  void close() {
    _client.close();
  }
}
