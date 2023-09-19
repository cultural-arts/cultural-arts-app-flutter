import 'dart:convert';
import 'package:http/http.dart' as http;
import 'classes/log.dart';

class CulturalArtsLogAPI {
  final String baseUrl;

  CulturalArtsLogAPI({required this.baseUrl});

  Future<void> sendLog(CulturalArtsLog? culturalArtsLog) async {
    final response = await http.post(
      Uri.parse('$baseUrl/log/?format=json'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(culturalArtsLog?.toJson()),
    );

    if (response.statusCode == 200) {
      // The log was successfully sent
    } else {
      throw Exception('Failed to send log');
    }
  }
}
