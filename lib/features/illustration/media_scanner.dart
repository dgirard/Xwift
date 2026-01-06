import 'package:flutter/services.dart';

/// Utility to trigger Android media scanner for new files
class MediaScanner {
  static const _channel = MethodChannel('xwift.ridecontroller/media_scanner');

  /// Scan a file to make it visible in gallery and file managers
  static Future<void> scanFile(String filePath) async {
    try {
      await _channel.invokeMethod('scanFile', {'path': filePath});
      print('[MEDIA_SCANNER] Scanned: $filePath');
    } catch (e) {
      print('[MEDIA_SCANNER] Error scanning file: $e');
    }
  }
}
