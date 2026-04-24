import 'dart:typed_data';
import 'package:hive/hive.dart';

class WebPhotoStorage {
  static final _box = Hive.box('photos');

  /// Save image (base64 or bytes)
  static Future<void> savePhoto(Uint8List bytes) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    _box.put(key, bytes);
  }

  /// Get all photos
  static List<Uint8List> getPhotos() {
    return _box.values.cast<Uint8List>().toList();
  }

  /// Clear all photos
  static Future<void> clear() async {
    await _box.clear();
  }

}