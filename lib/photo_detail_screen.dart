import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/photo_record.dart';
import 'upload_widget.dart';
import 'utils/web_storage.dart';
import 'widgets/ai_disclosure.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({super.key, required this.photoId});

  final String photoId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  PhotoRecord? record;

  @override
  void initState() {
    super.initState();
    _refreshRecord();
  }

  void _refreshRecord() {
    record = WebPhotoStorage.getPhotoRecord(widget.photoId);
  }

  @override
  Widget build(BuildContext context) {
    final photo = record;
    if (photo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photo')),
        body: const Center(child: Text('This photo is no longer available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your discovery'),
        actions: [
          if (photo.status == PhotoGenerationStatus.ready)
            IconButton(
              tooltip: 'Copy AI-generated description',
              icon: const Icon(Icons.copy),
              onPressed: () => _copyDescription(photo.description!),
            ),
          IconButton(
            tooltip: 'Delete photo',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deletePhoto,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.memory(
              photo.imageBytes,
              width: double.infinity,
              height: 320,
              fit: BoxFit.contain,
              semanticLabel: 'Captured cultural heritage photo',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formattedDate(photo.capturedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _buildGenerationContent(photo),
                const SizedBox(height: 20),
                const AiDisclosureCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationContent(PhotoRecord photo) {
    switch (photo.status) {
      case PhotoGenerationStatus.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiGeneratedBadge(),
            const SizedBox(height: 8),
            Text(
              'The story behind your photo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            SelectableText(
              photo.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
      case PhotoGenerationStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Your AI description is waiting to be generated.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _retryButton(photo, 'Generate description'),
          ],
        );
      case PhotoGenerationStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              photo.errorMessage ?? 'We couldn’t generate a description.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _retryButton(photo, 'Try again'),
          ],
        );
      case PhotoGenerationStatus.notGenerated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This photo doesn’t have an AI description yet.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _retryButton(photo, 'Generate description'),
          ],
        );
    }
  }

  Widget _retryButton(PhotoRecord photo, String label) {
    return FilledButton.icon(
      onPressed: () => _generateDescription(photo),
      icon: const Icon(Icons.auto_awesome),
      label: Text(label),
    );
  }

  Future<void> _generateDescription(PhotoRecord photo) async {
    await WebPhotoStorage.setGenerationPending(photo.id);
    if (!mounted) return;
    setState(_refreshRecord);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadPhoto(
          photoId: photo.id,
          imageBytes: photo.imageBytes,
        ),
      ),
    );
    if (!mounted) return;
    setState(_refreshRecord);
  }

  Future<void> _copyDescription(String description) async {
    await Clipboard.setData(
      ClipboardData(
        text: 'AI-generated description (may contain errors):\n\n$description',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI-generated description copied.')),
    );
  }

  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('This will also delete its saved description.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    await WebPhotoStorage.deletePhoto(widget.photoId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _formattedDate(DateTime date) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$month/$day/${localDate.year}';
  }
}
