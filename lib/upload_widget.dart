import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/log_api.dart';

class UploadPhoto extends StatefulWidget {
  const UploadPhoto({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<UploadPhoto> createState() => _MyUploadPhotoState();
}

class _MyUploadPhotoState extends State<UploadPhoto> {
  // variables to store widget data
  late String imagePath;

  // variables to store state data
  bool photoUploadedToCloud = false;
  int uploadAttempts = 3;

  @override
  void initState() {
    super.initState();
    // obtain the image path by using widget*
    imagePath = widget.imagePath;
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

  void uploadPhoto() {
    uploadAttempts--;

    var imageObject = Image.network(imagePath);

    var caLogs = CulturalArtsLogAPI(baseUrl: "baseUrl");

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

  void uploadPhotos() {
    uploadAttemptsCounter--;

    final filePath = photoParcelable!.photoAbsolutePath;
    var exifData;
    try {
      exifData = ExifInterface(filePath);
    } on PlatformException catch (e) {
      // TODO think what to do in this case
      sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "Error on ExifInterface read: $e");
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
        sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "Null reference bitmap.");
      } else {
        final byteArrayOutputStream = ByteArrayOutputStream();
        myBitmap.compress(Bitmap.CompressFormat.JPEG, 100, byteArrayOutputStream);
        final imgBytes = byteArrayOutputStream.toByteArray();
        final encodedPhoto = base64Encode(imgBytes);

        uploadPhoto(encodedPhoto, preparedExif);
      }
    } else {
      // TODO think what to do in this case
      sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "The photo to load does not exist");
    }
  }

  Future<void> uploadPhoto(String encodedPhoto, Map<String, dynamic> preparedExif) async {
    try {
      final photoAPI = RetrofitClientInstance.retrofitInstance?.create(ArtSuggestionsAPI);
      final response = await photoAPI?.searchPerfectMatch(encodedPhoto, preparedExif);

      if (response?.statusCode == 200) {
        overallProcessCompleted();

        switch (response.statusCode) {
          case CommunicationDriver.HTTP_230_CULTURAL_ARTS_SERVER_UNDER_MAINTENANCE:
            myDialogBuilder("Server Error", "Server is under maintenance", Icons.warning);
            break;
          case CommunicationDriver.HTTP_227_CULTURAL_ARTS_FOUND_PERFECT_MATCH:
            final perfectMatch = ArtSuggestions.fromJson(jsonDecode(response.body));
            // Navigate to the presentation activity with perfectMatch
            break;
          case CommunicationDriver.HTTP_228_CULTURAL_ARTS_FOUND_FIRST_STRIKE_SUGGESTIONS:
            // TODO fetch the response (if any) and extract the arts. Then navigate to SearchActivity
            break;
          case CommunicationDriver.HTTP_229_CULTURAL_ARTS_FOUND_SECOND_STRIKE_SUGGESTIONS:
            // TODO fetch the response (if any) and extract the arts. Then navigate to SearchActivity
            break;
          case CommunicationDriver.HTTP_231_CULTURAL_ARTS_NO_RESULTS_FOUND:
            // TODO in this case, it's probably better to terminate with the possibility to start another capture session
            break;
        }
      } else {
        switch (response.statusCode) {
          case CommunicationDriver.HTTP_452_CULTURAL_ARTS_INVALID_IMG:
            break;
          case CommunicationDriver.HTTP_453_CULTURAL_ARTS_INVALID_GPS_COORDINATES:
            break;
          case CommunicationDriver.HTTP_454_CULTURAL_ARTS_INAPPROPRIATE_CONTENT:
            break;
        }

        try {
          final errorMsg = "Error on photo upload ${response.statusCode} ${response.body}";
          sendLog(context, CulturalArtsLog.SEVERITY_ERROR, errorMsg);
        } catch (e) {
          sendLog(context, CulturalArtsLog.SEVERITY_ERROR, "Error on photo upload $e");
        }
      }
    } catch (e) {
      // check if we completed an upload run
      if (uploadAttemptsCounter == 0) {
        resetUIAndFinish();
      } else {
        uploadPhotos();
      }
    }
  }


  void storePhotoParcelableToInternalDB() {
    // add the photo(s) to the app's Room database in order to display it on the main page
    final photoTaken = PhotoTaken(photoParcelable!);
    photosTakenViewModel.insert(photoTaken);
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
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void resetUIAndFinish() {
    setState(() {
      messageController.text = "";
      photoUploadToCloudDone = false;
    });
    myDialogBuilder("Error", "Run finished with errors", Icons.warning);
  }

  void overallProcessCompleted() {
    setState(() {
      photoUploadToCloudDone = true;
      messageController.text = "Loaded correctly";
    });
  }
}


class Utils {
  static void sendLog(BuildContext context, String severity, String message) {
    // Implement your logging logic here
  }

  static bool isGpsValidCoordinates(double latitude, double longitude) {
    // Implement your GPS coordinate validation logic here
    return true; // Placeholder return value
  }

  // Define other utility functions as needed
}

class UtilsPhotoParcelable {
  // Define your PhotoParcelable properties here
}

class RetrofitClientInstance {
  // Define your RetrofitClientInstance logic here
}

class ArtSuggestionsAPI {
  // Define your API endpoints and methods here
}

class CulturalArtsLog {
  // Define your CulturalArtsLog logic here
}

class PhotoTaken {
  // Define your PhotoTaken logic here
}

class PhotosTakenModel {
  // Define your PhotosTakenModel logic here
}
 */