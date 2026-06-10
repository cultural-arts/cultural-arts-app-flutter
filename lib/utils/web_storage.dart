import 'dart:typed_data';
import 'package:hive/hive.dart';

class WebPhotoStorage {
  static final _box = Hive.box('photos');

  static Map<String, dynamic> _photoToMap(StorageContainer container) {
    return {
      'imageBytes': container.imageBytes,
      'base64Image': container.base64Image,
      'formattedExifData': container.formattedExifData,
      'isUploaded': container.isUploaded,
    };
  }

  /// Save or update a StorageContainer
  static Future<void> savePhoto(StorageContainer container) async {
    final key = container.key ?? DateTime.now().millisecondsSinceEpoch.toString();
    final value = _photoToMap(container);
    await _box.put(key, value);
    container.key = key;  // why?
  }

  /// Check if a key exists
  static bool exists(String key) {
    return _box.containsKey(key);
  }

  /// Get all StorageContainers
  static List<StorageContainer> getPhotos() {
    return _box.toMap().entries.map((entry) {
      final key = entry.key as String;
      final map = Map<String, dynamic>.from(entry.value as Map);

      Uint8List imageBytes = Uint8List.fromList(
        List<int>.from(map['imageBytes'] as List),
      );

      String base64Image = map['base64Image'] as String? ?? '';

      String formattedExifData = map['formattedExifData'] as String? ?? '';

      bool isUploaded = map['isUploaded'] as bool? ?? false;

      return StorageContainer(
        key: key,
        imageBytes: imageBytes,
        base64Image: base64Image,
        formattedExifData: formattedExifData,
        isUploaded: isUploaded,
      );
    }).toList();
  }

  /// Clear all photos
  static Future<void> clear() async {
    await _box.clear();
  }

  /// Count photos that still need upload
  static int pendingUploadCount() {
    return getPhotos().where((photo) => !photo.isUploaded).length;
  }
}

class StorageContainer {
  String? key;
  Uint8List imageBytes = Uint8List(0);
  String base64Image = "";
  String formattedExifData = "";
  bool isUploaded = false;

  StorageContainer({
    this.key,
    required this.imageBytes,
    required this.base64Image,
    required this.formattedExifData,
    required this.isUploaded,
  });

}

class WebSettingsStorage {
  static final _box = Hive.box('settings');
  static const _offlineMode = 'offlineMode';

  // generic helpers
  static bool getBool(String key, {required bool defaultValue}) {
    return _box.get(key, defaultValue: defaultValue) as bool;
  }

  static Future<void> setBool(String key, bool value) async {
    await _box.put(key, value);
  }

  static bool getOfflineMode() {
    return _box.get(_offlineMode) ?? false;
  }

  static void setOfflineMode(bool value) {
    _box.put(_offlineMode, value);
  }

}