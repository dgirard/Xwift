import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_media_store.dart';
import 'image_format.dart';
import 'package:flutter/foundation.dart';

/// Service pour sauvegarder et charger les illustrations par ride ID
class IllustrationStorage {
  static const String _folderName = 'illustrations';

  /// Retourne le dossier des illustrations (app documents)
  static Future<Directory> _getFolder() async {
    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory('${appDir.path}/$_folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Retourne le chemin du fichier pour un ride ID
  static Future<String> _getFilePath(String rideId) async {
    final folder = await _getFolder();
    return '${folder.path}/ride_$rideId.png';
  }

  /// Sauvegarde une illustration pour un ride
  static Future<void> save(String rideId, Uint8List imageBytes) async {
    final path = await _getFilePath(rideId);
    final file = File(path);
    await file.writeAsBytes(imageBytes);
  }

  /// Charge une illustration pour un ride (null si n'existe pas)
  static Future<Uint8List?> load(String rideId) async {
    final path = await _getFilePath(rideId);
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Verifie si une illustration existe pour un ride
  static Future<bool> exists(String rideId) async {
    final path = await _getFilePath(rideId);
    return File(path).exists();
  }

  /// Supprime une illustration
  static Future<void> delete(String rideId) async {
    final path = await _getFilePath(rideId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Retourne le chemin du fichier si existe
  static Future<String?> getPath(String rideId) async {
    final path = await _getFilePath(rideId);
    if (await File(path).exists()) {
      return path;
    }
    return null;
  }

  /// Sauvegarde l'illustration dans le dossier Download du telephone.
  /// Retourne l'emplacement du fichier, ou null en cas d'echec.
  static Future<String?> saveToDownloads(
    String rideId,
    Uint8List imageBytes,
    String sessionName,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName =
        sessionName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName =
        'Xwift_${safeName}_$timestamp.${imageFileExtension(imageBytes)}';

    if (!Platform.isAndroid) {
      try {
        final directory = await getDownloadsDirectory();
        if (directory == null) return null;
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(imageBytes);
        return file.path;
      } catch (e) {
        _log('[ILLUSTRATION_STORAGE] Error saving to downloads: $e');
        return null;
      }
    }

    // Android 9 and below: writing to Download needs the storage permission
    // (Android 10+ goes through MediaStore, without permission).
    final sdk = await AndroidMediaStore.sdkInt();
    if (sdk != null && sdk < 29) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _log('[ILLUSTRATION_STORAGE] Storage permission denied');
        return null;
      }
    }
    return AndroidMediaStore.saveToDownloads(
      imageBytes,
      fileName: fileName,
      mimeType: imageMimeType(imageBytes),
    );
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}
