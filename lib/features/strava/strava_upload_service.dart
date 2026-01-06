import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../models/ride_session.dart';
import '../export/fit_exporter.dart';
import 'strava_auth_service.dart';
import 'strava_config.dart';

/// Service for uploading activities to Strava
class StravaUploadService {
  final StravaAuthService _authService;
  final http.Client _httpClient;

  StravaUploadService({
    required StravaAuthService authService,
    http.Client? httpClient,
  })  : _authService = authService,
        _httpClient = httpClient ?? http.Client();

  /// Upload a ride session to Strava
  /// Returns the activity ID on success
  Future<StravaUploadResult> uploadActivity(
    RideSession session, {
    String? name,
    String? description,
  }) async {
    // Get valid access token
    final accessToken = await _authService.getValidAccessToken();

    // Generate FIT file
    final fitBytes = FitExporter.generateContent(session);

    // Compress with GZIP
    final gzipEncoder = GZipEncoder();
    final compressedBytes = gzipEncoder.encode(fitBytes);

    // Generate unique external ID for deduplication
    final externalId = 'xwift_${session.id}';

    // Build activity name
    final activityName = name ?? _generateActivityName(session);

    // Build description
    final activityDescription = description ?? _generateDescription(session);

    // Create multipart request
    final uri = Uri.parse('${StravaConfig.apiBaseUrl}/uploads');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['data_type'] = 'fit.gz';
    request.fields['activity_type'] = 'VirtualRide';
    request.fields['name'] = activityName;
    request.fields['description'] = activityDescription;
    request.fields['external_id'] = externalId;

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      compressedBytes,
      filename: '${externalId}.fit.gz',
    ));

    // Send request
    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final uploadStatus = StravaUploadStatus.fromJson(json);

      // Poll for completion
      return _pollForCompletion(uploadStatus.id, accessToken);
    } else if (response.statusCode == 401) {
      throw StravaUploadException('Authentication expired. Please reconnect to Strava.');
    } else if (response.statusCode == 429) {
      throw StravaUploadException('Rate limit exceeded. Please try again later.');
    } else {
      throw StravaUploadException(
        'Upload failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Poll the upload status until processing is complete
  Future<StravaUploadResult> _pollForCompletion(
    int uploadId,
    String accessToken,
  ) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      final status = await _checkUploadStatus(uploadId, accessToken);

      if (status.hasError) {
        if (status.isDuplicate) {
          return StravaUploadResult(
            success: true,
            isDuplicate: true,
            message: 'Activity already exists on Strava',
          );
        }
        throw StravaUploadException('Upload error: ${status.error}');
      }

      if (status.isReady && status.activityId != null) {
        return StravaUploadResult(
          success: true,
          activityId: status.activityId,
          message: 'Activity uploaded successfully',
        );
      }

      // Still processing, continue polling
    }

    throw StravaUploadException('Upload timed out. Please check Strava later.');
  }

  /// Check the status of an upload
  Future<StravaUploadStatus> _checkUploadStatus(
    int uploadId,
    String accessToken,
  ) async {
    final uri = Uri.parse('${StravaConfig.apiBaseUrl}/uploads/$uploadId');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return StravaUploadStatus.fromJson(json);
    } else {
      throw StravaUploadException(
        'Status check failed: ${response.statusCode}',
      );
    }
  }

  /// Generate activity name
  String _generateActivityName(RideSession session) {
    final dateStr = DateFormat('dd/MM/yyyy').format(session.startTime);
    final modeStr = session.mode == RideMode.erg ? 'ERG' : 'SIM';
    return 'Xwift $modeStr - $dateStr';
  }

  /// Generate activity description
  String _generateDescription(RideSession session) {
    final buffer = StringBuffer();
    buffer.writeln('Session Xwift');
    buffer.writeln();

    if (session.averagePower != null) {
      buffer.writeln('Puissance moyenne: ${session.averagePower}W');
    }
    if (session.maxPower != null) {
      buffer.writeln('Puissance max: ${session.maxPower}W');
    }
    if (session.averageCadence != null) {
      buffer.writeln('Cadence moyenne: ${session.averageCadence} rpm');
    }
    if (session.averageHeartRate != null) {
      buffer.writeln('FC moyenne: ${session.averageHeartRate} bpm');
    }

    return buffer.toString();
  }
}

/// Result of a Strava upload
class StravaUploadResult {
  final bool success;
  final int? activityId;
  final bool isDuplicate;
  final String? message;

  StravaUploadResult({
    required this.success,
    this.activityId,
    this.isDuplicate = false,
    this.message,
  });

  /// Get the Strava activity URL
  String? get activityUrl => activityId != null
      ? 'https://www.strava.com/activities/$activityId'
      : null;
}

/// Exception for Strava upload errors
class StravaUploadException implements Exception {
  final String message;
  StravaUploadException(this.message);

  @override
  String toString() => 'StravaUploadException: $message';
}
