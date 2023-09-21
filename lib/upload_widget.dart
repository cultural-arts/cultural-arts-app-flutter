import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cultural_arts/api/art_suggestion_api.dart';
import 'package:cultural_arts/api/classes/art_suggestions.dart';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'api/log_api.dart';
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
      appBar: AppBar(title: const Text('Upload Widget')),
    );
  }

  void uploadPhoto() async {
    uploadAttempts--;
    String? base64Image;

    // encode image as base64
    final imageBytes = await acquiredImage.readAsBytes();
    base64Image = base64Encode(imageBytes);

    // prepare the exif data container
    Map<String, String> exifData = {};

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

    var artSuggestionsAPI =
        ArtSuggestionsAPI(baseUrl: CommunicationDriver.baseURL);

    final response =
        await artSuggestionsAPI.searchPerfectMatch(base64Image, exifData);

    switch (response.statusCode) {
      case 200:
        break;
      case CommunicationDriver.http230CulturalArtsServerUnderMaintenance:
        myDialogBuilder(
            "Server Error", "Server is under maintenance", Icons.warning);
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
        myDialogBuilder("No results found", "Sorry for this", Icons.warning);
        break;
      case CommunicationDriver.http452CulturalArtsInvalidImg:
        break;
      case CommunicationDriver.http453CulturalArtsInvalidGpsCoordinates:
        break;
      case CommunicationDriver.http454CulturalArtsInappropriateContent:
        break;
    }

    /**

    var exifData;
    try {
      exifData = ExifInterface(filePath);
    } on PlatformException catch (e) {
      // TODO think what to do in this case
      ca_logs.sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "Error on ExifInterface read: $e");
    }
    final prepareExif = PrepareExifData(exifData);
    final preparedExif = prepareExif.preparedExifData;
    final latitude = photoParcelable!.photoLatitude;
    final longitude = photoParcelable!.photoLongitude;

    if (Utils.isGpsValidCoordinates(latitude, longitude)) {
      preparedExif["GPSLatitude"] = latitude;
      preparedExif["GPSLongitude"] = longitude;
    } else {
      preparedExif["OriginalGPSLatitude"] = latitude;
      preparedExif["OriginalGPSLongitude"] = longitude;
      preparedExif["GPSLatitude"] = Utils.DEFAULT_LATITUDE;
      preparedExif["GPSLongitude"] = Utils.DEFAULT_LONGITUDE;
    }

    final picture = File(filePath);
    if (picture.existsSync()) {
      final myBitmap = BitmapFactory.decodeFile(picture.absolutePath);
      if (myBitmap == null) {
        // TODO think what to do in this case
        ca_logs.sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "Null reference bitmap.");
      } else {
        final byteArrayOutputStream = ByteArrayOutputStream();
        myBitmap.compress(Bitmap.CompressFormat.JPEG, 100, byteArrayOutputStream);
        final imgBytes = byteArrayOutputStream.toByteArray();
        final encodedPhoto = base64Encode(imgBytes);

        
      }
    } else {
      // TODO think what to do in this case
      ca_logs.sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "The photo to load does not exist");
    }
     */
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

/**

class UploadPhotoState extends State<UploadPhoto> {
  TextEditingController messageController = TextEditingController();
  bool photoUploadToCloudDone = false;
  UtilsPhotoParcelable? photoParcelable;
  int uploadAttemptsCounter = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      try {
        photoParcelable = ModalRoute.of(context)!.settings.arguments as UtilsPhotoParcelable;
        uploadPhotos();
      } catch (e) {
        myDialogBuilder("Error", "No photos found", Icons.warning);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upload Photo"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: photoUploadToCloudDone ? 1.0 : null,
            ),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: "Message",
              ),
            ),
            if (photoUploadToCloudDone)
              Icon(
                Icons.done,
                size: 48.0,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  void storePhotoParcelableToInternalDB() {
    // add the photo(s) to the app's Room database in order to display it on the main page
    final photoTaken = PhotoTaken(photoParcelable!);
    photosTakenViewModel.insert(photoTaken);
  }

}*/