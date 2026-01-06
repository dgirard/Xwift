import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'media_scanner.dart';

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

  /// Retourne le dossier Download du telephone
  static Future<Directory?> _getDownloadFolder() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Navigate to Download folder: /storage/emulated/0/Download
        final downloadDir = Directory('${directory.parent.parent.parent.parent.path}/Download');
        if (await downloadDir.exists()) {
          return downloadDir;
        }
      }
    }
    // Fallback pour autres plateformes
    return await getDownloadsDirectory();
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

  /// Sauvegarde l'illustration dans le dossier Download du telephone
  /// Retourne le chemin du fichier sauvegarde ou null en cas d'erreur
  static Future<String?> saveToDownloads(String rideId, Uint8List imageBytes, String sessionName) async {
    try {
      final downloadDir = await _getDownloadFolder();
      print('[ILLUSTRATION_STORAGE] Download dir: ${downloadDir?.path}');
      if (downloadDir == null) {
        print('[ILLUSTRATION_STORAGE] Download dir is null!');
        return null;
      }

      // Generer un nom de fichier lisible
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = sessionName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = 'Xwift_${safeName}_$timestamp.png';
      final filePath = '${downloadDir.path}/$fileName';

      print('[ILLUSTRATION_STORAGE] Saving to: $filePath');
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      print('[ILLUSTRATION_STORAGE] Saved ${imageBytes.length} bytes');

      // Declencher un scan media pour rendre le fichier visible dans la galerie
      await MediaScanner.scanFile(filePath);

      return filePath;
    } catch (e) {
      print('[ILLUSTRATION_STORAGE] Error saving to downloads: $e');
      return null;
    }
  }
}
