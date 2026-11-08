import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Utility to trigger Android media scanner for new files
class MediaScanner {
  static const _channel = MethodChannel('xwift.ridecontroller/media_scanner');

  /// Scan a file to make it visible in gallery and file managers
  static Future<void> scanFile(String filePath) async {
    try {
      await _channel.invokeMethod('scanFile', {'path': filePath});
      _log('[MEDIA_SCANNER] Scanned: $filePath');
    } catch (e) {
      _log('[MEDIA_SCANNER] Error scanning file: $e');
    }
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}
