import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service pour generer des images avec l'API Gemini
class GeminiImageService {
  static const String _modelName = 'gemini-3-pro-image-preview';
  final String apiKey;

  GeminiImageService({required this.apiKey});

  /// Genere une image a partir d'un prompt
  /// Retourne les bytes de l'image PNG ou null en cas d'erreur
  Future<Uint8List?> generateImage(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
      }
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        print('[GEMINI_IMAGE] Error: ${response.statusCode} - ${response.body}');
        throw GeminiImageException(
          'Erreur API Gemini: ${response.statusCode}',
          response.body,
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      // Extraire l'image de la reponse
      final candidates = jsonResponse['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final part in parts) {
            final inlineData = part['inlineData'] as Map<String, dynamic>?;
            if (inlineData != null && inlineData['data'] != null) {
              final base64Data = inlineData['data'] as String;
              return base64Decode(base64Data);
            }
          }
        }
      }

      // Pas d'image dans la reponse
      print('[GEMINI_IMAGE] No image in response');
      return null;
    } catch (e) {
      if (e is GeminiImageException) rethrow;
      print('[GEMINI_IMAGE] Error: $e');
      throw GeminiImageException('Erreur de generation: $e', null);
    }
  }
}

/// Exception pour les erreurs de generation d'image
class GeminiImageException implements Exception {
  final String message;
  final String? details;

  GeminiImageException(this.message, this.details);

  @override
  String toString() => message;
}
