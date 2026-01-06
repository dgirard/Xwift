import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ride_session.dart';
import 'strava_auth_service.dart';
import 'strava_config.dart';
import 'strava_token_storage.dart';
import 'strava_upload_service.dart';

/// Provider for Strava token storage
final stravaTokenStorageProvider = Provider<StravaTokenStorage>((ref) {
  return StravaTokenStorage();
});

/// Provider for Strava auth service
final stravaAuthServiceProvider = Provider<StravaAuthService>((ref) {
  final storage = ref.watch(stravaTokenStorageProvider);
  return StravaAuthService(storage: storage);
});

/// Provider for Strava upload service
final stravaUploadServiceProvider = Provider<StravaUploadService>((ref) {
  final authService = ref.watch(stravaAuthServiceProvider);
  return StravaUploadService(authService: authService);
});

/// Provider for app links (deep link handling)
final appLinksProvider = Provider<AppLinks>((ref) {
  return AppLinks();
});

/// State for Strava connection
class StravaConnectionState {
  final StravaConnectionStatus status;
  final StravaAthlete? athlete;
  final String? error;

  const StravaConnectionState({
    this.status = StravaConnectionStatus.unknown,
    this.athlete,
    this.error,
  });

  StravaConnectionState copyWith({
    StravaConnectionStatus? status,
    StravaAthlete? athlete,
    String? error,
  }) {
    return StravaConnectionState(
      status: status ?? this.status,
      athlete: athlete ?? this.athlete,
      error: error,
    );
  }
}

enum StravaConnectionStatus {
  unknown,
  notConfigured,
  disconnected,
  connecting,
  connected,
  error,
}

/// Notifier for Strava connection state
class StravaConnectionNotifier extends StateNotifier<StravaConnectionState> {
  final StravaAuthService _authService;
  final StravaTokenStorage _storage;
  final AppLinks _appLinks;

  StravaConnectionNotifier(this._authService, this._storage, this._appLinks)
      : super(const StravaConnectionState()) {
    _initialize();
    _listenForDeepLinks();
  }

  Future<void> _initialize() async {
    // Check if credentials are configured
    final hasCredentials = await _storage.hasCredentials();
    if (!hasCredentials) {
      state = state.copyWith(status: StravaConnectionStatus.notConfigured);
      return;
    }

    // Check if connected
    final isConnected = await _authService.isConnected();
    if (isConnected) {
      final athlete = await _authService.getAthlete();
      state = state.copyWith(
        status: StravaConnectionStatus.connected,
        athlete: athlete,
      );
    } else {
      state = state.copyWith(status: StravaConnectionStatus.disconnected);
    }
  }

  void _listenForDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == StravaConfig.callbackScheme &&
          uri.host == StravaConfig.callbackHost) {
        await handleCallback(uri);
      }
    });
  }

  /// Save Strava API credentials
  Future<void> saveCredentials(String clientId, String clientSecret) async {
    await _authService.saveCredentials(clientId, clientSecret);
    state = state.copyWith(status: StravaConnectionStatus.disconnected);
  }

  /// Initiate OAuth connection
  Future<void> connect() async {
    try {
      state = state.copyWith(status: StravaConnectionStatus.connecting);
      await _authService.initiateAuth();
    } catch (e) {
      state = state.copyWith(
        status: StravaConnectionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Handle OAuth callback
  Future<void> handleCallback(Uri uri) async {
    try {
      state = state.copyWith(status: StravaConnectionStatus.connecting);
      final success = await _authService.handleCallback(uri);
      if (success) {
        final athlete = await _authService.getAthlete();
        state = state.copyWith(
          status: StravaConnectionStatus.connected,
          athlete: athlete,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: StravaConnectionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Disconnect from Strava
  Future<void> disconnect() async {
    await _authService.logout();
    state = state.copyWith(
      status: StravaConnectionStatus.disconnected,
      athlete: null,
    );
  }

  /// Refresh connection state
  Future<void> refresh() async {
    await _initialize();
  }
}

/// Provider for Strava connection state
final stravaConnectionProvider =
    StateNotifierProvider<StravaConnectionNotifier, StravaConnectionState>((ref) {
  final authService = ref.watch(stravaAuthServiceProvider);
  final storage = ref.watch(stravaTokenStorageProvider);
  final appLinks = ref.watch(appLinksProvider);
  return StravaConnectionNotifier(authService, storage, appLinks);
});

/// State for Strava upload
class StravaUploadState {
  final StravaUploadStatus status;
  final String? message;
  final int? activityId;
  final String? error;

  const StravaUploadState({
    this.status = StravaUploadStatus.idle,
    this.message,
    this.activityId,
    this.error,
  });

  StravaUploadState copyWith({
    StravaUploadStatus? status,
    String? message,
    int? activityId,
    String? error,
  }) {
    return StravaUploadState(
      status: status ?? this.status,
      message: message,
      activityId: activityId,
      error: error,
    );
  }
}

enum StravaUploadStatus {
  idle,
  uploading,
  success,
  duplicate,
  error,
}

/// Notifier for Strava upload state
class StravaUploadNotifier extends StateNotifier<StravaUploadState> {
  final StravaUploadService _uploadService;

  StravaUploadNotifier(this._uploadService) : super(const StravaUploadState());

  /// Upload a ride session to Strava
  Future<void> uploadActivity(
    RideSession session, {
    String? name,
    String? description,
  }) async {
    try {
      state = state.copyWith(
        status: StravaUploadStatus.uploading,
        message: 'Envoi vers Strava...',
        error: null,
      );

      final result = await _uploadService.uploadActivity(
        session,
        name: name,
        description: description,
      );

      if (result.isDuplicate) {
        state = state.copyWith(
          status: StravaUploadStatus.duplicate,
          message: 'Activite deja presente sur Strava',
        );
      } else {
        state = state.copyWith(
          status: StravaUploadStatus.success,
          message: 'Activite envoyee avec succes!',
          activityId: result.activityId,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: StravaUploadStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Reset state
  void reset() {
    state = const StravaUploadState();
  }
}

/// Provider for Strava upload state
final stravaUploadProvider =
    StateNotifierProvider<StravaUploadNotifier, StravaUploadState>((ref) {
  final uploadService = ref.watch(stravaUploadServiceProvider);
  return StravaUploadNotifier(uploadService);
});
