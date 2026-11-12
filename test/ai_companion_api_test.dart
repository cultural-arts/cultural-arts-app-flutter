import 'package:cultural_arts/api/ai_companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts the image and EXIF and returns the description', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/ai-companion');
      expect(request.bodyFields, {
        'encoded_photo': 'encoded-image',
        'exif': '{GPSLatitude=45.5,GPSLongitude=11.8}',
      });
      return http.Response('{"description":"  A historic statue.  "}', 200);
    });
    final api = AiCompanionAPI(
      baseUrl: 'https://example.com',
      client: client,
    );

    expect(
      await api.describeImage(
        'encoded-image',
        '{GPSLatitude=45.5,GPSLongitude=11.8}',
      ),
      'A historic statue.',
    );
    api.close();
  });

  test('reports the daily rate limit', () async {
    final api = AiCompanionAPI(
      baseUrl: 'https://example.com',
      client: MockClient(
        (_) async => http.Response('{"message":"Daily limit reached"}', 429),
      ),
    );

    await expectLater(
      api.describeImage('encoded-image', '{}'),
      throwsA(
        isA<AiCompanionApiException>().having(
          (error) => error.message,
          'message',
          'Daily request limit reached. Please try again tomorrow.',
        ),
      ),
    );
    api.close();
  });

  test('rejects a successful response without a description', () async {
    final api = AiCompanionAPI(
      baseUrl: 'https://example.com',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      api.describeImage('encoded-image', '{}'),
      throwsFormatException,
    );
    api.close();
  });
}
