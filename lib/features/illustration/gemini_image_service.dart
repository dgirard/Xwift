import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service pour generer des images avec l'API Gemini
class GeminiImageService {
  GeminiImageService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  static const _apiBase = 'https://generativelanguage.googleapis.com/v1beta';

  /// Stable image model (successor of gemini-3-pro-image-preview).
  static const defaultModel = 'gemini-3-pro-image';

  /// Order of preference when a model is retired (HTTP 404): the first one
  /// the API still lists is used, then any other image model it offers.
  static const preferredModels = [
    'gemini-3-pro-image',
    'gemini-3.1-flash-image',
    'gemini-2.5-flash-image',
  ];

  /// Model that last answered, reused for the rest of the session.
  static String? _workingModel;

  @visibleForTesting
  static void resetModelForTests() => _workingModel = null;

  final String apiKey;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      };

  /// Genere une image a partir d'un prompt.
  /// Retourne les octets de l'image (PNG ou JPEG selon le modele), ou null
  /// si la reponse ne contient pas d'image.
  Future<Uint8List?> generateImage(String prompt) async {
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
      final tried = <String>{};
      var model = _workingModel ?? defaultModel;
      while (true) {
        tried.add(model);
        final response = await _client
            .post(
              Uri.parse('$_apiBase/models/$model:generateContent'),
              headers: _headers,
              body: body,
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 404) {
          // Model retired or renamed: switch to one the API still offers.
          _log('[GEMINI_IMAGE] Model $model not found');
          final next = await _nextAvailableModel(tried);
          if (next == null) {
            throw GeminiImageException(
              'Aucun modele d\'image Gemini disponible pour cette cle API',
              response.body,
            );
          }
          model = next;
          continue;
        }
        if (response.statusCode != 200) {
          _log('[GEMINI_IMAGE] Error: ${response.statusCode}');
          throw GeminiImageException(
            'Erreur API Gemini: ${response.statusCode}',
            response.body,
          );
        }

        _workingModel = model;
        return _extractImage(response.body);
      }
    } catch (e) {
      if (e is GeminiImageException) rethrow;
      _log('[GEMINI_IMAGE] Error: $e');
      throw GeminiImageException('Erreur de generation: $e', null);
    }
  }

  Uint8List? _extractImage(String responseBody) {
    final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = jsonResponse['candidates'] as List<dynamic>?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      for (final part in parts ?? const []) {
        final inlineData = part['inlineData'] as Map<String, dynamic>?;
        if (inlineData != null && inlineData['data'] != null) {
          return base64Decode(inlineData['data'] as String);
        }
      }
    }
    _log('[GEMINI_IMAGE] No image in response');
    return null;
  }

  /// An image model the API offers and that was not tried yet.
  Future<String?> _nextAvailableModel(Set<String> tried) async {
    final response = await _client
        .get(Uri.parse('$_apiBase/models?pageSize=1000'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return null;

    final models = (jsonDecode(response.body)['models'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((m) =>
            (m['supportedGenerationMethods'] as List<dynamic>? ?? const [])
                .contains('generateContent'))
        .map((m) => (m['name'] as String).replaceFirst('models/', ''))
        .where((name) => name.contains('image') && !tried.contains(name))
        .toList();

    for (final preferred in preferredModels) {
      if (models.contains(preferred)) return preferred;
    }
    // Unknown newer models: stable before preview.
    models.sort((a, b) =>
        (a.contains('preview') ? 1 : 0).compareTo(b.contains('preview') ? 1 : 0));
    return models.isEmpty ? null : models.first;
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

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}
