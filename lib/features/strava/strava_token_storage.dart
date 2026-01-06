import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'strava_config.dart';

/// Secure storage for Strava OAuth tokens
class StravaTokenStorage {
  final FlutterSecureStorage _storage;

  StravaTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  /// Save Strava tokens securely
  Future<void> saveTokens(StravaTokens tokens) async {
    await _storage.write(key: StravaConfig.accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: StravaConfig.refreshTokenKey, value: tokens.refreshToken);
    await _storage.write(key: StravaConfig.expiresAtKey, value: tokens.expiresAt.toString());

    if (tokens.athlete != null) {
      await _storage.write(key: StravaConfig.athleteIdKey, value: tokens.athlete!.id.toString());
      await _storage.write(key: StravaConfig.athleteNameKey, value: tokens.athlete!.fullName);
      if (tokens.athlete!.profileMedium != null) {
        await _storage.write(key: StravaConfig.athleteAvatarKey, value: tokens.athlete!.profileMedium);
      }
    }
  }

  /// Get stored tokens, or null if not available
  Future<StravaTokens?> getTokens() async {
    final accessToken = await _storage.read(key: StravaConfig.accessTokenKey);
    final refreshToken = await _storage.read(key: StravaConfig.refreshTokenKey);
    final expiresAtStr = await _storage.read(key: StravaConfig.expiresAtKey);

    if (accessToken == null || refreshToken == null || expiresAtStr == null) {
      return null;
    }

    final athleteIdStr = await _storage.read(key: StravaConfig.athleteIdKey);
    final athleteName = await _storage.read(key: StravaConfig.athleteNameKey);
    final athleteAvatar = await _storage.read(key: StravaConfig.athleteAvatarKey);

    StravaAthlete? athlete;
    if (athleteIdStr != null && athleteName != null) {
      final nameParts = athleteName.split(' ');
      athlete = StravaAthlete(
        id: int.parse(athleteIdStr),
        firstName: nameParts.isNotEmpty ? nameParts.first : '',
        lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        profileMedium: athleteAvatar,
      );
    }

    return StravaTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: int.parse(expiresAtStr),
      athlete: athlete,
    );
  }

  /// Get just the access token (for quick checks)
  Future<String?> getAccessToken() async {
    return _storage.read(key: StravaConfig.accessTokenKey);
  }

  /// Get just the refresh token
  Future<String?> getRefreshToken() async {
    return _storage.read(key: StravaConfig.refreshTokenKey);
  }

  /// Check if tokens are stored
  Future<bool> hasTokens() async {
    final accessToken = await _storage.read(key: StravaConfig.accessTokenKey);
    return accessToken != null;
  }

  /// Clear all stored tokens (logout)
  Future<void> clearTokens() async {
    await _storage.delete(key: StravaConfig.accessTokenKey);
    await _storage.delete(key: StravaConfig.refreshTokenKey);
    await _storage.delete(key: StravaConfig.expiresAtKey);
    await _storage.delete(key: StravaConfig.athleteIdKey);
    await _storage.delete(key: StravaConfig.athleteNameKey);
    await _storage.delete(key: StravaConfig.athleteAvatarKey);
  }

  /// Save Strava API credentials (client ID and secret)
  Future<void> saveCredentials(String clientId, String clientSecret) async {
    await _storage.write(key: StravaConfig.clientIdKey, value: clientId);
    await _storage.write(key: StravaConfig.clientSecretKey, value: clientSecret);
  }

  /// Get stored credentials
  Future<({String? clientId, String? clientSecret})> getCredentials() async {
    final clientId = await _storage.read(key: StravaConfig.clientIdKey);
    final clientSecret = await _storage.read(key: StravaConfig.clientSecretKey);
    return (clientId: clientId, clientSecret: clientSecret);
  }

  /// Check if credentials are configured
  Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds.clientId != null &&
        creds.clientId!.isNotEmpty &&
        creds.clientSecret != null &&
        creds.clientSecret!.isNotEmpty;
  }

  /// Clear credentials
  Future<void> clearCredentials() async {
    await _storage.delete(key: StravaConfig.clientIdKey);
    await _storage.delete(key: StravaConfig.clientSecretKey);
  }
}
