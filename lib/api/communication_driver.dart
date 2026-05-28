class CommunicationDriver {
  static const String requestKey = "REQUEST_CODE";
  static const String responseKey = "RESPONSE_CODE";

  static const String baseURL = "https://pedrocchi.cultural-arts.com";

  // Output messages
  static const int requestMatch = 100;
  static const int requestHitPerfectMatch = 101;
  static const int requestInvalidPerfectMatch = 102;
  static const int requestHitFirstStrike = 103;
  static const int requestInvalidFirstStrike = 104;
  static const int requestHitSecondStrike = 105;
  static const int requestInvalidSecondStrike = 106;
  static const int requestFromSuggestion = 107;

  static const int http227CulturalArtsFoundPerfectMatch = 227;
  static const int http228CulturalArtsFoundFirstStrikeSuggestions = 228;
  static const int http229CulturalArtsFoundSecondStrikeSuggestions = 229;
  static const int http230CulturalArtsServerUnderMaintenance = 230;
  static const int http231CulturalArtsNoResultsFound = 231;

  static const int http452CulturalArtsInvalidImg = 452;
  static const int http453CulturalArtsInvalidGpsCoordinates = 453;
  static const int http454CulturalArtsInappropriateContent = 454;

  static List<String>? getInputDataStructure(int key) {
    switch (key) {
      case http227CulturalArtsFoundPerfectMatch:
      case http228CulturalArtsFoundFirstStrikeSuggestions:
      case http229CulturalArtsFoundSecondStrikeSuggestions:
        return [
          "IMG_ID",
          "ART_IMG",
          "ART_ID",
          "ART_TITLE",
          "ART_INTRO",
          "ART_DESCRIPTION"
        ];
      default:
        return null;
    }
  }
}
