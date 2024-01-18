import 'dart:convert';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:camera/camera.dart';
import 'package:cultural_arts/api/art_defect_detection_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'utils/geo_utilities.dart';

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
  Uint8List? uploadedImageBytes; // Added variable to store uploaded image bytes

  @override
  void initState() {
    super.initState();
    // obtain the image path by using widget*
    acquiredImage = widget.acquiredImage;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      try {
        uploadPhoto();
      } on PlatformException catch (e) {
        myDialogBuilder("Error 01", "$e", Icons.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: photoUploadedToCloud
          ? Image.memory(
              uploadedImageBytes!,
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
            )
          : Center(
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
                  const SizedBox(
                      height: 32.0), // Space between spinner and icon
                  const Text(
                    "detecting bio-colonization defects...",
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

  void uploadPhoto() async {
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

    var artDefectDetectionAPI =
        ArtDefectDetectionAPI(baseUrl: CommunicationDriver.baseURL);

    final response = await artDefectDetectionAPI.getBioColonizationDefects(
        base64Image!, formattedExifData);

    switch (response.statusCode) {
      case 200:
        // Assuming response.body contains the image bytes
        Uint8List imageBytes = base64Decode(response.body);

        // Use the Image.memory widget to display the image
        Widget imageWidget = Image.memory(imageBytes);

        // Now, you can use this imageWidget wherever you need to display the image.
        // For example, you might replace the CircularProgressIndicator with the imageWidget.
        setState(() {
          photoUploadedToCloud = true;
          uploadedImageBytes = base64Decode(response.body);
        });
        break;
      case 500:
        myDialogBuilder(
            "Internal Server Error", "Try again later", Icons.error);
        break;
      case 429:
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429
        myDialogBuilder(
            "Daily Limit Reached",
            "You have reached the daily limit of calls. If you are interested"
                "in a unlimited service contact info@cultural-arts.com",
            Icons.warning);
        break;
    }
  }

  void myDialogBuilder(String title, String msg, IconData iconData) {
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
    );
  }
}
