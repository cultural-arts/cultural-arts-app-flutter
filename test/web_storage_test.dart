import 'dart:io';
import 'dart:typed_data';

import 'package:cultural_arts/models/photo_record.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> photosBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('cultural-arts-hive');
    Hive.init(hiveDirectory.path);
    photosBox = await Hive.openBox<dynamic>('photos');
  });

  setUp(() async {
    await photosBox.clear();
  });

  tearDownAll(() async {
    await photosBox.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('migrates existing image-only entries and keeps them viewable',
      () async {
    final image = Uint8List.fromList([1, 2, 3]);
    await photosBox.put('1700000000000', image);

    await WebPhotoStorage.migrateLegacyPhotos();

    final record = WebPhotoStorage.getPhotoRecord('1700000000000');
    expect(record?.imageBytes, image);
    expect(record?.status, PhotoGenerationStatus.notGenerated);
    expect(
        record?.capturedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('persists generated descriptions and retry failures on one record',
      () async {
    final image = Uint8List.fromList([4, 5, 6]);
    final id = await WebPhotoStorage.savePhoto(image);

    expect(
      WebPhotoStorage.getPhotoRecord(id)?.status,
      PhotoGenerationStatus.pending,
    );

    await WebPhotoStorage.setGenerationFailed(id, 'Service unavailable.');
    expect(
      WebPhotoStorage.getPhotoRecord(id)?.errorMessage,
      'Service unavailable.',
    );

    await WebPhotoStorage.setGenerationPending(id);
    await WebPhotoStorage.setDescription(id, 'A historic monument.');
    final record = WebPhotoStorage.getPhotoRecord(id);
    expect(record?.imageBytes, image);
    expect(record?.description, 'A historic monument.');
    expect(record?.status, PhotoGenerationStatus.ready);
    expect(record?.errorMessage, isNull);
    expect(WebPhotoStorage.getPhotoRecords(), hasLength(1));
  });

  test('marks interrupted generation as retryable after restart', () async {
    final id = await WebPhotoStorage.savePhoto(Uint8List.fromList([7]));

    await WebPhotoStorage.markInterruptedGenerations();

    final record = WebPhotoStorage.getPhotoRecord(id);
    expect(record?.status, PhotoGenerationStatus.failed);
    expect(record?.errorMessage, contains('did not finish'));
  });
}
