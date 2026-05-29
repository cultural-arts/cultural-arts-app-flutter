

import 'package:cultural_arts/api/art_suggestion_api.dart';
import 'package:cultural_arts/api/communication_driver.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';

class UploadLocalPhotosScreen extends StatefulWidget {
  const UploadLocalPhotosScreen({super.key});

  @override
  State<UploadLocalPhotosScreen> createState() =>
      _UploadLocalPhotosScreenState();
}

class _UploadLocalPhotosScreenState extends State<UploadLocalPhotosScreen> {
  int _current = 0;        // index of image being processed
  bool _done = false;
  bool _cancelled = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _runUpload();
  }

  Future<void> _runUpload() async {
    List<StorageContainer> photos = WebPhotoStorage.getPhotos();
    for (int i = 0; i < photos.length; i++) {

      if (photos[i].isUploaded) continue;

      if (_cancelled) break;
      
      setState(() {
        _current = i;
        _statusMessage = 'Uploading ${i + 1} of ${photos.length}…';
      });

      try {
        var artSuggestionsAPI = ArtSuggestionsAPI(baseUrl: CommunicationDriver.baseURL);
        final response = await artSuggestionsAPI.searchPerfectMatch(
          photos[i].base64Image,
          photos[i].formattedExifData
        );

        if (response.statusCode != CommunicationDriver.http231CulturalArtsNoResultsFound) {
          throw Exception('upload failed with status code ${response.statusCode}');
        }

        photos[i].isUploaded = true;
        await WebPhotoStorage.savePhoto(photos[i]);
      } catch (e) {
        setState(() => _statusMessage = 'Error on image ${i + 1}: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!_cancelled && mounted) {
      setState(() {
        _done = true;
        _statusMessage = 'All done!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = WebPhotoStorage.getPhotos().length;
    final progress = total == 0 ? 0.0 : (_current + 1) / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploading photos'),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // no back while uploading
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            LinearProgressIndicator(
              value: _done ? 1.0 : progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Text(
              _done
                  ? '$total / $total'
                  : '${_current + 1} / $total',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            if (_done)
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _cancelled = true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}