import 'dart:convert';
import 'dart:js_interop';

import 'package:camera/camera.dart';
import 'package:cultural_arts/api/art_suggestion_api.dart';
import 'package:cultural_arts/api/classes/art_suggestions.dart';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'utils/geo_utilities.dart';
import 'vlm.dart';

class UploadPhoto extends StatefulWidget {
  const UploadPhoto({super.key, required this.acquiredImage});

  final XFile acquiredImage;

  @override
  State<UploadPhoto> createState() => _MyUploadPhotoState();
}

class _MyUploadPhotoState extends State<UploadPhoto> {
  // variables to store widget data
  late XFile acquiredImage;

  // variables to store state data
  bool photoUploadedToCloud = false;
  int uploadAttempts = 3;
  String? base64Image; // the base64 image version
  Map<String, String> exifData = {}; // the exif data container

  @override
  void initState() {
    super.initState();
    // obtain the image path by using widget*
    acquiredImage = widget.acquiredImage;
  }

  @override
  Widget build(BuildContext context) {

    // when this callback is called we are sure that the widget is completely build and drawn,
    // in fact the documentation says "callback after the last frame..."
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      try {
        uploadPhoto(context);
      } on PlatformException catch (e) {
        myDialogBuilder(context, "Error 01", "$e", Icons.error);
      }
    },);

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "cultural-arts.com",
              style: TextStyle(
                color: Colors.white, // Title text color
                fontSize: 24.0, // Title text font size
              ),
            ),
            const SizedBox(height: 32.0),
            Image.asset(
              'assets/images/custom_icons_il_santo.png', // Replace with the path to your custom PNG icon
            ),
            const SizedBox(height: 32.0), // Space between spinner and icon
            const Text(
              "searching for arts...",
              style: TextStyle(
                color: Colors.white, // Title text color
              ),
            ),
            const SizedBox(height: 16.0),
            const CircularProgressIndicator(
                color: Colors.white), // Loading spinner
          ],
        ),
      ),
    );
  }

  String formatMapToString(Map<String, String> data) {
    final List<String> keyValuePairs = [];

    data.forEach((key, value) {
      keyValuePairs.add('$key=$value');
    });

    return '{${keyValuePairs.join(',')}}';
  }

  void uploadPhoto(context) async {
    uploadAttempts--;

    // encode image as base64
    Uint8List imageBytes = await acquiredImage.readAsBytes();

    // obtain image width and height
    var image = await decodeImageFromList(imageBytes);
    exifData['ImageLength'] = image.height.toString();
    exifData['ImageWidth'] = image.width.toString();

    // encode image to send
    base64Image = base64Encode(imageBytes);

    // add gps location provider with geolocator
    Position currentPosition = await getPosition();
    String latitude = currentPosition.latitude.toString();
    String longitude = currentPosition.longitude.toString();

    if (isGPSValidCoordinates(latitude, longitude)) {
      exifData["GPSLatitude"] = latitude;
      exifData["GPSLongitude"] = longitude;
    } else {
      exifData["OriginalGPSLatitude"] = latitude;
      exifData["OriginalGPSLongitude"] = longitude;
      exifData["GPSLatitude"] = dafaultLatitude;
      exifData["GPSLongitude"] = defaultLongitude;
    }

    final formattedExifData = formatMapToString(exifData);

    var artSuggestionsAPI = ArtSuggestionsAPI(baseUrl: CommunicationDriver.baseURL);

    final response = await artSuggestionsAPI.searchPerfectMatch(base64Image!, formattedExifData);

    switch (response.statusCode) {
      case 200:
        break;
      case CommunicationDriver.http230CulturalArtsServerUnderMaintenance:
        myDialogBuilder(
          context, 
          "Server Error", 
          "The server is currently undergoing maintenance.", 
          Icons.warning
        );
        break;
      case CommunicationDriver.http227CulturalArtsFoundPerfectMatch:
        final perfectMatch = ArtSuggestions.fromJson(jsonDecode(response.body));
        // Navigate to the presentation activity with perfectMatch
        break;
      case CommunicationDriver.http228CulturalArtsFoundFirstStrikeSuggestions:
        break;
      case CommunicationDriver.http229CulturalArtsFoundSecondStrikeSuggestions:
        break;
      case CommunicationDriver.http231CulturalArtsNoResultsFound:
        // "https://cdn.britannica.com/61/93061-050-99147DCE/Statue-of-Liberty-Island-New-York-Bay.jpg"
        var generatedText = await whatsInTheImage(acquiredImage.path).toDart as String;
        myDialogBuilder(context, "AI Assistant", generatedText, Icons.assistant);
        break;
      case CommunicationDriver.http452CulturalArtsInvalidImg:
        break;
      case CommunicationDriver.http453CulturalArtsInvalidGpsCoordinates:
        break;
      case CommunicationDriver.http454CulturalArtsInappropriateContent:
        break;
    }
  }

  void myDialogBuilder(BuildContext context, String title, String msg, IconData iconData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    ).then((val) {
      Navigator.of(context).pop();
    });
  }
}
