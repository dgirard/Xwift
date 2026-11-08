import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridecontroller/features/illustration/gemini_image_service.dart';
import 'package:ridecontroller/features/illustration/image_format.dart';

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00];
const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D];

String _imageResponse(List<int> bytes) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'Voici le dessin'},
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Encode(bytes)
                }
              },
            ]
          }
        }
      ]
    });

void main() {
  late List<String> calls;

  setUp(() {
    GeminiImageService.resetModelForTests();
    calls = [];
  });

  test('uses the stable image model by default', () async {
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['x-goog-api-key'], 'key');
      return http.Response(_imageResponse(_jpeg), 200);
    });
    final image = await GeminiImageService(apiKey: 'key', client: client)
        .generateImage('un hérisson');
    expect(image, _jpeg);
    expect(calls, ['POST /v1beta/models/gemini-3-pro-image:generateContent']);
  });

  test('switches to an available image model when one is retired', () async {
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/models')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-4-argon',
                'supportedGenerationMethods': ['generateContent']
              },
              {
                'name': 'models/gemini-9-image-preview',
                'supportedGenerationMethods': ['generateContent']
              },
              {
                'name': 'models/gemini-9-image',
                'supportedGenerationMethods': ['generateContent']
              },
            ]
          }),
          200,
        );
      }
      if (request.url.path.contains('gemini-3-pro-image')) {
        return http.Response('{"error": {"code": 404}}', 404);
      }
      return http.Response(_imageResponse(_png), 200);
    });
    final service = GeminiImageService(apiKey: 'key', client: client);

    expect(await service.generateImage('un coq'), _png);
    expect(calls, [
      'POST /v1beta/models/gemini-3-pro-image:generateContent',
      'GET /v1beta/models',
      'POST /v1beta/models/gemini-9-image:generateContent', // stable first
    ]);

    // The model that worked is reused: no new lookup.
    calls.clear();
    await service.generateImage('un renard');
    expect(calls, ['POST /v1beta/models/gemini-9-image:generateContent']);
  });

  test('reports clearly when no image model is available', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/models')) {
        return http.Response(jsonEncode({'models': []}), 200);
      }
      return http.Response('{}', 404);
    });
    await expectLater(
      GeminiImageService(apiKey: 'key', client: client).generateImage('x'),
      throwsA(isA<GeminiImageException>()),
    );
  });

  test('files get the extension and type of the real image format', () {
    expect(imageFileExtension(_jpeg), 'jpg');
    expect(imageMimeType(_jpeg), 'image/jpeg');
    expect(imageFileExtension(_png), 'png');
    expect(imageMimeType(_png), 'image/png');
  });
}
