import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'illustration_config.dart';

/// The Gemini API key, kept in the encrypted storage like the Strava secrets.
///
/// Earlier versions stored it in plain SharedPreferences (readable in backups
/// and on rooted devices): it is moved here the first time it is read.
class GeminiKeyStorage {
  GeminiKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) return stored;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(IllustrationPrefsKeys.legacyGeminiApiKey);
    if (legacy == null || legacy.isEmpty) return null;
    await _storage.write(key: _key, value: legacy);
    await prefs.remove(IllustrationPrefsKeys.legacyGeminiApiKey);
    return legacy;
  }

  Future<void> write(String apiKey) => _storage.write(key: _key, value: apiKey);

  Future<void> delete() => _storage.delete(key: _key);
}
