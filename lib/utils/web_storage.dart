import 'dart:typed_data';
import 'package:hive/hive.dart';

import '../models/photo_record.dart';

class WebPhotoStorage {
  static final _box = Hive.box('photos');

  static Future<void> migrateLegacyPhotos() async {
    for (final entry in _box.toMap().entries) {
      if (entry.value is Uint8List) {
        final record = PhotoRecord.fromStoredValue(
          entry.key.toString(),
          entry.value,
        );
        await _box.put(entry.key, record.toMap());
      }
    }
  }

  static Future<void> markInterruptedGenerations() async {
    for (final record in getPhotoRecords()) {
      if (record.status == PhotoGenerationStatus.pending) {
        await setGenerationFailed(
          record.id,
          'Description generation did not finish. Please try again.',
        );
      }
    }
  }

  static Future<String> savePhoto(Uint8List bytes) async {
    var timestamp = DateTime.now().microsecondsSinceEpoch;
    while (_box.containsKey(timestamp.toString())) {
      timestamp++;
    }
    final id = timestamp.toString();
    final record = PhotoRecord(
      id: id,
      imageBytes: bytes,
      capturedAt: DateTime.fromMicrosecondsSinceEpoch(timestamp),
      status: PhotoGenerationStatus.pending,
    );
    await _box.put(id, record.toMap());
    return id;
  }

  static List<PhotoRecord> getPhotoRecords() {
    final records = _box
        .toMap()
        .entries
        .map(
          (entry) => PhotoRecord.fromStoredValue(
            entry.key.toString(),
            entry.value,
          ),
        )
        .toList();
    records.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return records;
  }

  static PhotoRecord? getPhotoRecord(String id) {
    final value = _box.get(id);
    return value == null ? null : PhotoRecord.fromStoredValue(id, value);
  }

  static Future<void> setGenerationPending(String id) async {
    await _updateRecord(
      id,
      (record) => record.copyWith(status: PhotoGenerationStatus.pending),
    );
  }

  static Future<void> setDescription(String id, String description) async {
    await _updateRecord(
      id,
      (record) => record.copyWith(
        status: PhotoGenerationStatus.ready,
        description: description,
      ),
    );
  }

  static Future<void> setGenerationFailed(String id, String message) async {
    await _updateRecord(
      id,
      (record) => record.copyWith(
        status: PhotoGenerationStatus.failed,
        errorMessage: message,
      ),
    );
  }

  static Future<void> deletePhoto(String id) async {
    await _box.delete(id);
  }

  static Future<void> clear() async {
    await _box.clear();
  }

  static Future<void> _updateRecord(
    String id,
    PhotoRecord Function(PhotoRecord) update,
  ) async {
    final value = _box.get(id);
    if (value == null) {
      throw StateError('Photo "$id" does not exist.');
    }
    final record = PhotoRecord.fromStoredValue(id, value);
    await _box.put(id, update(record).toMap());
  }
}
