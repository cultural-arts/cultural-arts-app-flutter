import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cultural_arts/api/ai_companion_api.dart';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'utils/geo_utilities.dart';

class UploadPhoto extends StatefulWidget {
  const UploadPhoto({super.key, required this.acquiredImage});

  final XFile acquiredImage;

  @override
  State<UploadPhoto> createState() => _MyUploadPhotoState();
}

class _MyUploadPhotoState extends State<UploadPhoto> {
  late final AiCompanionAPI aiCompanionAPI;
  bool isLoading = true;
  String? description;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    aiCompanionAPI = AiCompanionAPI(baseUrl: CommunicationDriver.baseURL);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _uploadPhoto();
    });
  }

  @override
  void dispose() {
    aiCompanionAPI.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'cultural-arts.com',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 32),
            Image.asset('assets/images/custom_icons_il_santo.png'),
            const SizedBox(height: 32),
            if (isLoading) ...[
              const Text(
                'Generating image description...',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 32),
            ] else if (errorMessage == null) ...[
              const Text(
                'Art Assistant',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (description != null)
                        Text(
                          description!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      if (errorMessage != null) ...[
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _uploadPhoto,
                          child: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMapToString(Map<String, String> data) {
    final keyValuePairs =
        data.entries.map((entry) => '${entry.key}=${entry.value}').toList();
    return '{${keyValuePairs.join(',')}}';
  }

  Future<void> _uploadPhoto() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      description = null;
      errorMessage = null;
    });

    try {
      final imageBytes = await widget.acquiredImage.readAsBytes();
      final image = await decodeImageFromList(imageBytes);
      final exifData = <String, String>{
        'ImageLength': image.height.toString(),
        'ImageWidth': image.width.toString(),
      };

      final Position currentPosition = await LocationService.getPosition();
      final latitude = currentPosition.latitude.toString();
      final longitude = currentPosition.longitude.toString();

      if (LocationService.isGPSValidCoordinates(latitude, longitude)) {
        exifData['GPSLatitude'] = latitude;
        exifData['GPSLongitude'] = longitude;
      } else {
        exifData['OriginalGPSLatitude'] = latitude;
        exifData['OriginalGPSLongitude'] = longitude;
        exifData['GPSLatitude'] = LocationConfig.defaultLatitude.toString();
        exifData['GPSLongitude'] = LocationConfig.defaultLongitude.toString();
      }

      final result = await aiCompanionAPI.describeImage(
        base64Encode(imageBytes),
        _formatMapToString(exifData),
      );

      if (!mounted) return;
      setState(() {
        description = result;
        isLoading = false;
      });
    } on AiCompanionApiException catch (error) {
      _showError(error.message);
    } on http.ClientException {
      _showError('Unable to connect to the image description service.');
    } on FormatException catch (error) {
      _showError(error.message);
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Unable to prepare the image.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      errorMessage = message;
      isLoading = false;
    });
  }
}
