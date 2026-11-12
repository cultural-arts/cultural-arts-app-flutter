import 'dart:convert';
import 'dart:io';

import 'package:cultural_arts/main.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:cultural_arts/widgets/ai_disclosure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> photosBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('cultural-arts-ui');
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

  testWidgets('AI disclosure explains the value and limitations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiDisclosureCard(),
        ),
      ),
    );

    expect(find.text(aiDisclosureTitle), findsOneWidget);
    expect(
      find.textContaining('We work to provide valuable results'),
      findsOneWidget,
    );
    expect(find.textContaining('AI can make mistakes'), findsOneWidget);
  });

  testWidgets('selecting a gallery photo opens its saved description', (
    WidgetTester tester,
  ) async {
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    final photoId = await WebPhotoStorage.savePhoto(image);
    await WebPhotoStorage.setDescription(
      photoId,
      'A carefully researched description.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'cultural-arts.com'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('A carefully researched description.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('The story behind your photo'), findsOneWidget);
    expect(find.text('A carefully researched description.'), findsOneWidget);
    expect(find.text('AI-generated'), findsOneWidget);
  });
}
