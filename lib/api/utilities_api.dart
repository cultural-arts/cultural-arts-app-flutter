
class UtilitiesAPI {
  final String baseUrl;

  UtilitiesAPI({required this.baseUrl});

  /**

  Future<> getEndpointsAPI(
      String gpsLatitude, String gpsLongitude) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/get-endpoints-api?gps_latitude=$gpsLatitude&gps_longitude=$gpsLongitude'),
    );

    if (response.statusCode == 200) {
      return ResponseBody.fromString(response.body, ResponseBodyType.String);
    } else {
      throw Exception('Failed to fetch endpoints API');
    }
  }

  Future<GEPHOSResponse> getGEPHOS(
      String gpsLatitude, String gpsLongitude) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/get-gephos-settings?gps_latitude=$gpsLatitude&gps_longitude=$gpsLongitude'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return GEPHOSResponse.fromJson(responseData);
    } else {
      throw Exception('Failed to fetch GEPHOS settings');
    }
  }
   */
}
