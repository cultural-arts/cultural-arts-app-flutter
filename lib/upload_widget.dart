import 'dart:convert';

import 'package:cultural_arts/api/ai_companion_api.dart';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'utils/geo_utilities.dart';
import 'utils/web_storage.dart';
import 'widgets/ai_disclosure.dart';

class UploadPhoto extends StatefulWidget {
  const UploadPhoto({
    super.key,
    required this.photoId,
    required this.imageBytes,
  });

  final String photoId;
  final Uint8List imageBytes;

  @override
  State<UploadPhoto> createState() => _UploadPhotoState();
}

class _UploadPhotoState extends State<UploadPhoto> {
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your discovery'),
        actions: [
          if (description != null)
            IconButton(
              tooltip: 'Copy AI-generated description',
              icon: const Icon(Icons.copy),
              onPressed: () => _copyDescription(description!),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Image.memory(
            widget.imageBytes,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Photo being described by AI',
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading) ...[
                  const AiGeneratedBadge(),
                  const SizedBox(height: 12),
                  Text(
                    'Generating an AI description...',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ] else if (errorMessage != null) ...[
                  Text(
                    'We couldn’t create your description this time.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _uploadPhoto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ] else ...[
                  const AiGeneratedBadge(),
                  const SizedBox(height: 8),
                  Text(
                    'The story behind your photo',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    description!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 20),
                const AiDisclosureCard(),
              ],
            ),
          ),
        ],
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
      await WebPhotoStorage.setGenerationPending(widget.photoId);
      final image = await decodeImageFromList(widget.imageBytes);
      final exifData = <String, String>{
        'ImageLength': image.height.toString(),
        'ImageWidth': image.width.toString(),
      };
      image.dispose();

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
        base64Encode(widget.imageBytes),
        _formatMapToString(exifData),
      );
      await WebPhotoStorage.setDescription(widget.photoId, result);

      if (!mounted) return;
      setState(() {
        description = result;
        isLoading = false;
      });
    } on AiCompanionApiException catch (error) {
      await _showError(error.message);
    } on http.ClientException {
      await _showError('Unable to connect to the image description service.');
    } on FormatException catch (error) {
      await _showError(error.message);
    } on PlatformException catch (error) {
      await _showError(error.message ?? 'Unable to prepare the image.');
    }
  }

  Future<void> _showError(String message) async {
    await WebPhotoStorage.setGenerationFailed(widget.photoId, message);
    if (!mounted) return;
    setState(() {
      errorMessage = message;
      isLoading = false;
    });
  }

  Future<void> _copyDescription(String text) async {
    await Clipboard.setData(
      ClipboardData(
          text: 'AI-generated description (may contain errors):\n\n$text'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI-generated description copied.')),
    );
  }
}
