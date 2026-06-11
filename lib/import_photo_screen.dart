import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cultural_arts/utils/data.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ImportLocalPhotosScreen extends StatefulWidget {
  const ImportLocalPhotosScreen({super.key, required this.images});

  final List<XFile> images;

  @override
  State<ImportLocalPhotosScreen> createState() => _ImportLocalPhotosScreenState();
}

class _ImportLocalPhotosScreenState extends State<ImportLocalPhotosScreen> {
  int _current = 0;
  bool _done = false;
  bool _cancelled = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runImport();
    });
  }

  Future<void> _runImport() async {
    final images = widget.images;

    for (int i = 0; i < images.length; i++) {
      if (_cancelled) break;

      setState(() {
        _current = i;
        _statusMessage = 'Be patient! Importing ${i + 1} of ${images.length}…';
      });

      try {
        // read bytes
        final Uint8List imageBytes = await images[i].readAsBytes();

        // compress
        final Uint8List compressed = DataUtilities.compressImage(imageBytes);

        // extract exif + gps (no current location for gallery imports)
        final Map<String, String> data = await DataUtilities.photoToWebStorage(
          compressed,
          useCurrentLocation: true,
        );

        // skip if already saved
        final String key = images[i].name;
        if (WebPhotoStorage.exists(key)) continue;

        // save to local storage
        await WebPhotoStorage.savePhoto(StorageContainer(
          key: key,
          imageBytes: compressed,
          base64Image: data['base64Image']!,
          formattedExifData: data['formattedExifData']!,
          isUploaded: false,
        ));
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
    final total = widget.images.length;
    final progress = total == 0 ? 0.0 : (_current + 1) / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importing photos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
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
              _done ? '$total / $total' : '${_current + 1} / $total',
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