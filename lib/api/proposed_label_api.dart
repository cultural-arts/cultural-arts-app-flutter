import 'dart:convert';
import 'package:http/http.dart' as http;
import 'classes/proposed_label.dart';

class ProposedLabelAPI {
  final String baseUrl;

  ProposedLabelAPI({required this.baseUrl});

  Future<void> sendLabel(ProposedLabel? proposedLabel) async {
    final response = await http.post(
      Uri.parse('$baseUrl/labels/?format=json'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(proposedLabel?.toJson()),
    );

    if (response.statusCode == 200) {
      // The label was successfully sent
    } else {
      throw Exception('Failed to send label');
    }
  }
}
