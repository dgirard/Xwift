import 'dart:convert';
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
    if (tokens == null) return false;
    // If token is expired, try to refresh
    if (tokens.isExpired) {
      try {
        await refreshToken();
        return true;
      } catch (e) {
        return false;
      }
    }
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

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw StravaAuthException('Could not launch authorization URL');
    }
  }

  /// Handle OAuth callback URI
  /// Returns true if authentication was successful
  Future<bool> handleCallback(Uri uri) async {
    // Check if this is our callback
    if (uri.scheme != StravaConfig.callbackScheme ||
        uri.host != StravaConfig.callbackHost ||
        !uri.path.startsWith('/callback')) {
      return false;
    }

    // Check for errors
    final error = uri.queryParameters['error'];
    if (error != null) {
      throw StravaAuthException('Authorization denied: $error');
    }

    // Get the authorization code
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StravaAuthException('No authorization code received');
    }

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

    if (response.statusCode != 200) {
      throw StravaAuthException(
        'Token exchange failed: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tokens = StravaTokens.fromJson(json);
    await _storage.saveTokens(tokens);
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

    final response = await _httpClient.post(
      Uri.parse(StravaConfig.tokenUrl),
      body: {
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      throw StravaAuthException(
        'Token refresh failed: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tokens = StravaTokens.fromJson(json);
    await _storage.saveTokens(tokens);
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
