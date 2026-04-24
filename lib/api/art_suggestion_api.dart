import 'dart:convert';
import 'package:http/http.dart' as http;

class ArtSuggestionsAPI {
  final String baseUrl;

  ArtSuggestionsAPI({required this.baseUrl});

  Future<http.Response> searchPerfectMatch(
      String encodedPhoto, String exif) async {
    final response = await http.post(
      Uri.parse('$baseUrl/search-perfect-match'),
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

  Future<http.Response> searchArtSuggestions(
      String imgId, List<String>? discardedArtList, int type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/search-art-suggestions'),
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'img_id': imgId,
        'discarded_art_list': jsonEncode(discardedArtList),
        'type': type.toString(),
      },
    );

    return response;

    /**
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return ArtSuggestions.fromJson(responseData);
    } else {
      throw Exception('Failed to load data');
    }
     */
  }
}
