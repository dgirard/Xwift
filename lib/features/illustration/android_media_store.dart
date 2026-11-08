import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android shared storage, through MainActivity (MediaStore).
class AndroidMediaStore {
  static const _channel = MethodChannel('xwift.ridecontroller/media_store');

  /// Android API level, or null when unavailable.
  static Future<int?> sdkInt() async {
    try {
      return await _channel.invokeMethod<int>('sdkInt');
    } catch (e) {
      _log('[MEDIA_STORE] sdkInt failed: $e');
      return null;
    }
  }

  /// Saves [bytes] in the public Download folder, visible in the gallery and
  /// file managers. Returns where the file is, or null on failure.
  static Future<String?> saveToDownloads(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } catch (e) {
      _log('[MEDIA_STORE] saveToDownloads failed: $e');
      return null;
    }
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}
