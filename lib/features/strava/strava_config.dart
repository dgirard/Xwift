/// Strava API Configuration
///
/// To use Strava integration, create an app at https://www.strava.com/settings/api
/// and configure the client ID and secret.
class StravaConfig {
  /// Strava OAuth authorization URL
  static const String authorizationUrl = 'https://www.strava.com/oauth/mobile/authorize';

  /// Strava OAuth token URL
  static const String tokenUrl = 'https://www.strava.com/oauth/token';

  /// Strava API base URL
  static const String apiBaseUrl = 'https://www.strava.com/api/v3';

  /// OAuth callback URL scheme
  static const String callbackScheme = 'xwift';

  /// OAuth callback host
  static const String callbackHost = 'strava-callback';

  /// Full callback URL
  static const String callbackUrl = '$callbackScheme://$callbackHost';

  /// Required OAuth scopes for Xwift
  /// - activity:write: Upload activities
  /// - activity:read_all: Read activities to detect duplicates
  /// - profile:read_all: Read user profile info
  static const String scopes = 'activity:write,activity:read_all,profile:read_all';

  /// Secure storage keys
  static const String accessTokenKey = 'strava_access_token';
  static const String refreshTokenKey = 'strava_refresh_token';
  static const String expiresAtKey = 'strava_expires_at';
  static const String athleteIdKey = 'strava_athlete_id';
  static const String athleteNameKey = 'strava_athlete_name';
  static const String athleteAvatarKey = 'strava_athlete_avatar';
  static const String clientIdKey = 'strava_client_id';
  static const String clientSecretKey = 'strava_client_secret';
}

/// Strava athlete information
class StravaAthlete {
  final int id;
  final String firstName;
  final String lastName;
  final String? profileMedium;

  StravaAthlete({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profileMedium,
  });

  String get fullName => '$firstName $lastName';

  factory StravaAthlete.fromJson(Map<String, dynamic> json) {
    return StravaAthlete(
      id: json['id'] as int,
      firstName: json['firstname'] as String? ?? '',
      lastName: json['lastname'] as String? ?? '',
      profileMedium: json['profile_medium'] as String?,
    );
  }
}

/// Strava OAuth token response
class StravaTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final StravaAthlete? athlete;

  StravaTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.athlete,
  });

  bool get isExpired {
    final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    // Consider expired if less than 10 minutes remaining
    return DateTime.now().isAfter(expiresAtDate.subtract(const Duration(minutes: 10)));
  }

  factory StravaTokens.fromJson(Map<String, dynamic> json) {
    return StravaTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: json['expires_at'] as int,
      athlete: json['athlete'] != null
          ? StravaAthlete.fromJson(json['athlete'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Strava upload status
class StravaUploadStatus {
  final int id;
  final String? externalId;
  final String? status;
  final String? error;
  final int? activityId;

  StravaUploadStatus({
    required this.id,
    this.externalId,
    this.status,
    this.error,
    this.activityId,
  });

  bool get isProcessing => status?.contains('processing') ?? false;
  bool get isReady => status?.contains('ready') ?? false;
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isDuplicate => error?.toLowerCase().contains('duplicate') ?? false;

  factory StravaUploadStatus.fromJson(Map<String, dynamic> json) {
    return StravaUploadStatus(
      id: json['id'] as int,
      externalId: json['external_id'] as String?,
      status: json['status'] as String?,
      error: json['error'] as String?,
      activityId: json['activity_id'] as int?,
    );
  }
}

/// Strava connection state
enum StravaConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Strava upload state
enum StravaUploadState {
  idle,
  uploading,
  processing,
  success,
  error,
}
