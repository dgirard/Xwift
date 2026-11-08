import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
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
    // Generate FIT file once
    debugPrint('[Strava Upload] Generating FIT file...');
    final fitBytes = FitExporter.generateContent(session);
    final compressedBytes = GZipEncoder().encode(fitBytes);
    debugPrint('[Strava Upload] FIT file: ${fitBytes.length} bytes, compressed: ${compressedBytes.length} bytes');

    final externalId = 'xwift_${session.id}';
    final activityName = name ?? _generateActivityName(session);
    final activityDescription = description ?? _generateDescription(session);

    // Try upload, retry once on 401 after token refresh
    var response = await _sendUpload(
      compressedBytes, externalId, activityName, activityDescription,
    );

    if (response.statusCode == 401) {
      debugPrint('[Strava Upload] 401 received, attempting token refresh and retry...');
      try {
        await _authService.refreshToken();
        response = await _sendUpload(
          compressedBytes, externalId, activityName, activityDescription,
        );
      } catch (e) {
        debugPrint('[Strava Upload] Token refresh failed: $e');
        throw StravaUploadException('Authentication expired. Please reconnect to Strava.');
      }
    }

    debugPrint('[Strava Upload] Response status: ${response.statusCode}');

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final uploadStatus = StravaUploadStatus.fromJson(json);
      debugPrint('[Strava Upload] Upload accepted, polling for completion (id: ${uploadStatus.id})');
      return _pollForCompletion(uploadStatus.id);
    } else if (response.statusCode == 401) {
      throw StravaUploadException('Authentication expired. Please reconnect to Strava.');
    } else if (response.statusCode == 429) {
      debugPrint('[Strava Upload] Rate limited (429)');
      throw StravaUploadException('Rate limit exceeded. Please try again later.');
    } else {
      debugPrint('[Strava Upload] Upload failed with status ${response.statusCode}');
      throw StravaUploadException(
        'Upload failed: ${response.statusCode}',
      );
    }
  }

  /// Send the upload request with a fresh token
  Future<http.Response> _sendUpload(
    List<int> compressedBytes,
    String externalId,
    String activityName,
    String activityDescription,
  ) async {
    final accessToken = await _authService.getValidAccessToken();
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

    debugPrint('[Strava Upload] Sending upload request...');
    final streamedResponse = await _httpClient.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  /// Poll the upload status until processing is complete
  Future<StravaUploadResult> _pollForCompletion(int uploadId) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      debugPrint('[Strava Upload] Polling attempt ${attempt + 1}/$maxAttempts for upload $uploadId');
      final accessToken = await _authService.getValidAccessToken();
      final status = await _checkUploadStatus(uploadId, accessToken);

      if (status.hasError) {
        if (status.isDuplicate) {
          debugPrint('[Strava Upload] Duplicate activity detected');
          return StravaUploadResult(
            success: true,
            isDuplicate: true,
            message: 'Activity already exists on Strava',
          );
        }
        debugPrint('[Strava Upload] Upload error: ${status.error}');
        throw StravaUploadException('Upload error: ${status.error}');
      }

      if (status.isReady && status.activityId != null) {
        debugPrint('[Strava Upload] Upload complete! Activity ID: ${status.activityId}');
        return StravaUploadResult(
          success: true,
          activityId: status.activityId,
          message: 'Activity uploaded successfully',
        );
      }

      debugPrint('[Strava Upload] Still processing (status: ${status.status})...');
      // Still processing, continue polling
    }

    debugPrint('[Strava Upload] Polling timed out after $maxAttempts attempts');
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
