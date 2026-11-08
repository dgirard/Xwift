import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'strava_config.dart';
import 'strava_token_storage.dart';

/// Service for Strava OAuth authentication
class StravaAuthService {
  final StravaTokenStorage _storage;
  final http.Client _httpClient;

  StravaAuthService({
    StravaTokenStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? StravaTokenStorage(),
        _httpClient = httpClient ?? http.Client();

  /// Check if user is connected to Strava
  Future<bool> isConnected() async {
    final tokens = await _storage.getTokens();
    if (tokens == null) {
      debugPrint('[Strava Auth] isConnected: no tokens found');
      return false;
    }
    // If token is expired, try to refresh
    if (tokens.isExpired) {
      try {
        debugPrint('[Strava Auth] isConnected: token expired, attempting refresh');
        await refreshToken();
        debugPrint('[Strava Auth] isConnected: token refresh successful');
        return true;
      } catch (e) {
        debugPrint('[Strava Auth] isConnected: token refresh failed: $e');
        return false;
      }
    }
    debugPrint('[Strava Auth] isConnected: valid token found');
    return true;
  }

  /// Get stored athlete info
  Future<StravaAthlete?> getAthlete() async {
    final tokens = await _storage.getTokens();
    return tokens?.athlete;
  }

  /// Build the authorization URL
  Future<Uri> buildAuthorizationUrl() async {
    final creds = await _storage.getCredentials();
    if (creds.clientId == null || creds.clientId!.isEmpty) {
      throw StravaAuthException('Client ID not configured');
    }

    return Uri.parse(StravaConfig.authorizationUrl).replace(
      queryParameters: {
        'client_id': creds.clientId,
        'redirect_uri': StravaConfig.callbackUrl,
        'response_type': 'code',
        'scope': StravaConfig.scopes,
        'approval_prompt': 'auto',
      },
    );
  }

  /// Initiate OAuth flow by opening browser/Strava app
  Future<void> initiateAuth() async {
    final authUrl = await buildAuthorizationUrl();
    debugPrint('[Strava Auth] initiateAuth: opening authorization URL');

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      debugPrint('[Strava Auth] initiateAuth: URL launched successfully');
    } else {
      debugPrint('[Strava Auth] initiateAuth: could not launch URL');
      throw StravaAuthException('Could not launch authorization URL');
    }
  }

  /// Handle OAuth callback URI
  /// Returns true if authentication was successful
  Future<bool> handleCallback(Uri uri) async {
    debugPrint('[Strava Auth] handleCallback: received callback (has code: ${uri.queryParameters.containsKey("code")})');

    // Check if this is our callback
    if (uri.scheme != StravaConfig.callbackScheme ||
        uri.host != StravaConfig.callbackHost ||
        !uri.path.startsWith('/callback')) {
      debugPrint('[Strava Auth] handleCallback: URI does not match callback pattern');
      return false;
    }

    // Check for errors
    final error = uri.queryParameters['error'];
    if (error != null) {
      debugPrint('[Strava Auth] handleCallback: authorization error: $error');
      throw StravaAuthException('Authorization denied: $error');
    }

    // Get the authorization code
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      debugPrint('[Strava Auth] handleCallback: no authorization code in URI');
      throw StravaAuthException('No authorization code received');
    }

    debugPrint('[Strava Auth] handleCallback: exchanging code for token');
    // Exchange code for tokens
    await exchangeCodeForToken(code);
    return true;
  }

  /// Exchange authorization code for access token
  Future<StravaTokens> exchangeCodeForToken(String code) async {
    final creds = await _storage.getCredentials();
    if (creds.clientId == null || creds.clientSecret == null) {
      throw StravaAuthException('Client credentials not configured');
    }

    final response = await _httpClient.post(
      Uri.parse(StravaConfig.tokenUrl),
      body: {
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
      },
    );

    debugPrint('[Strava Auth] exchangeCodeForToken: response status ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[Strava Auth] exchangeCodeForToken: failed with status ${response.statusCode}');
      throw StravaAuthException(
        'Token exchange failed: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tokens = StravaTokens.fromJson(json);
    await _storage.saveTokens(tokens);
    debugPrint('[Strava Auth] exchangeCodeForToken: tokens saved successfully');
    return tokens;
  }

  /// Refresh the access token using refresh token
  Future<StravaTokens> refreshToken() async {
    final creds = await _storage.getCredentials();
    final refreshToken = await _storage.getRefreshToken();

    if (creds.clientId == null || creds.clientSecret == null) {
      throw StravaAuthException('Client credentials not configured');
    }
    if (refreshToken == null) {
      throw StravaAuthException('No refresh token available');
    }

    debugPrint('[Strava Auth] refreshToken: attempting refresh');
    final response = await _httpClient.post(
      Uri.parse(StravaConfig.tokenUrl),
      body: {
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    debugPrint('[Strava Auth] refreshToken: response status ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[Strava Auth] refreshToken: failed with status ${response.statusCode}');
      throw StravaAuthException(
        'Token refresh failed: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tokens = StravaTokens.fromJson(json);
    await _storage.saveTokens(tokens);
    debugPrint('[Strava Auth] refreshToken: tokens refreshed successfully');
    return tokens;
  }

  /// Get a valid access token (refreshing if needed)
  Future<String> getValidAccessToken() async {
    final tokens = await _storage.getTokens();
    if (tokens == null) {
      throw StravaAuthException('Not authenticated');
    }

    if (tokens.isExpired) {
      final newTokens = await refreshToken();
      return newTokens.accessToken;
    }

    return tokens.accessToken;
  }

  /// Logout (clear all tokens)
  Future<void> logout() async {
    await _storage.clearTokens();
  }

  /// Save credentials
  Future<void> saveCredentials(String clientId, String clientSecret) async {
    await _storage.saveCredentials(clientId, clientSecret);
  }

  /// Check if credentials are configured
  Future<bool> hasCredentials() async {
    return _storage.hasCredentials();
  }
}

/// Exception for Strava authentication errors
class StravaAuthException implements Exception {
  final String message;
  StravaAuthException(this.message);

  @override
  String toString() => 'StravaAuthException: $message';
}
