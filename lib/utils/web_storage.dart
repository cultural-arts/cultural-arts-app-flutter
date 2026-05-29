import 'dart:typed_data';
import 'package:hive/hive.dart';

class WebPhotoStorage {
  static final _box = Hive.box('photos');

  /// Save a StorageContainer
  static Future<void> savePhoto(StorageContainer container) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    final value = {
      'imageBytes': container.imageBytes,
      'base64Image': container.base64Image,
      'exifData': container.exifData,
    };
    await _box.put(key, value);
  }

  /// Get all StorageContainers
  static List<StorageContainer> getPhotos() {
    return _box.values.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);

      Uint8List imageBytes = Uint8List.fromList(
        List<int>.from(map['imageBytes'] as List),
      );

      String base64Image = map['base64Image'] as String? ?? '';

      Map<String, String> exifData = Map<String, String>.from(
        map['exifData'] as Map? ?? {},
      );

      final container = StorageContainer(imageBytes: imageBytes, base64Image: base64Image, exifData: exifData);
      
      return container;
    }).toList();
  }

  /// Clear all photos
  static Future<void> clear() async {
    await _box.clear();
  }
}

class StorageContainer {
  Uint8List imageBytes = Uint8List(0);
  String base64Image = "";
  Map<String, String> exifData = {};

  StorageContainer({
    required this.imageBytes,
    required this.base64Image,
    required this.exifData,
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