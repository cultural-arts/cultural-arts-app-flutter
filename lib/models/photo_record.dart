import 'dart:typed_data';

enum PhotoGenerationStatus {
  pending,
  ready,
  failed,
  notGenerated,
}

class PhotoRecord {
  const PhotoRecord({
    required this.id,
    required this.imageBytes,
    required this.capturedAt,
    required this.status,
    this.description,
    this.errorMessage,
  });

  final String id;
  final Uint8List imageBytes;
  final DateTime capturedAt;
  final PhotoGenerationStatus status;
  final String? description;
  final String? errorMessage;

  Map<String, Object?> toMap() {
    return {
      'imageBytes': imageBytes,
      'capturedAt': capturedAt.millisecondsSinceEpoch,
      'status': status.name,
      'description': description,
      'errorMessage': errorMessage,
    };
  }

  PhotoRecord copyWith({
    required PhotoGenerationStatus status,
    String? description,
    String? errorMessage,
  }) {
    return PhotoRecord(
      id: id,
      imageBytes: imageBytes,
      capturedAt: capturedAt,
      status: status,
      description: description,
      errorMessage: errorMessage,
    );
  }

  factory PhotoRecord.fromStoredValue(String id, Object? value) {
    if (value is Uint8List) {
      final timestamp = int.tryParse(id);
      return PhotoRecord(
        id: id,
        imageBytes: value,
        capturedAt: timestamp == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(timestamp),
        status: PhotoGenerationStatus.notGenerated,
      );
    }

    if (value is! Map) {
      throw FormatException('Stored photo "$id" has an invalid format.');
    }

    final data = Map<String, Object?>.from(value);
    final rawBytes = data['imageBytes'];
    if (rawBytes is! List<int>) {
      throw FormatException('Stored photo "$id" has invalid image data.');
    }

    final rawCapturedAt = data['capturedAt'];
    if (rawCapturedAt is! int) {
      throw FormatException('Stored photo "$id" has an invalid capture time.');
    }

    final rawStatus = data['status'];
    final status = PhotoGenerationStatus.values.where(
      (candidate) => candidate.name == rawStatus,
    );
    if (status.isEmpty) {
      throw FormatException('Stored photo "$id" has an invalid status.');
    }

    final description = data['description'];
    final errorMessage = data['errorMessage'];
    if (description != null && description is! String) {
      throw FormatException('Stored photo "$id" has an invalid description.');
    }
    if (errorMessage != null && errorMessage is! String) {
      throw FormatException('Stored photo "$id" has an invalid error.');
    }
    if (status.first == PhotoGenerationStatus.ready &&
        (description is! String || description.trim().isEmpty)) {
      throw FormatException('Stored photo "$id" is missing its description.');
    }

    return PhotoRecord(
      id: id,
      imageBytes: Uint8List.fromList(rawBytes),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(rawCapturedAt),
      status: status.first,
      description: description as String?,
      errorMessage: errorMessage as String?,
    );
  }
}
