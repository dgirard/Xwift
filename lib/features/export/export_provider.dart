import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/ride_session.dart';
import 'fit_exporter.dart';
import 'tcx_exporter.dart';

/// Export format options
enum ExportFormat {
  fit('FIT', 'fit', 'Garmin FIT format - best for Strava'),
  tcx('TCX', 'tcx', 'Training Center XML - widely compatible');

  final String displayName;
  final String extension;
  final String description;

  const ExportFormat(this.displayName, this.extension, this.description);
}

/// State for export operations
class ExportState {
  final bool isExporting;
  final String? lastExportPath;
  final String? error;

  const ExportState({
    this.isExporting = false,
    this.lastExportPath,
    this.error,
  });

  ExportState copyWith({
    bool? isExporting,
    String? lastExportPath,
    String? error,
  }) {
    return ExportState(
      isExporting: isExporting ?? this.isExporting,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      error: error,
    );
  }
}

/// Provider for ride export functionality
class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier() : super(const ExportState());

  /// Export a ride session to the specified format
  Future<String?> exportRide(RideSession session, ExportFormat format) async {
    state = state.copyWith(isExporting: true, error: null);

    try {
      String path;

      switch (format) {
        case ExportFormat.fit:
          path = await FitExporter.export(session);
          break;
        case ExportFormat.tcx:
          path = await TcxExporter.export(session);
          break;
      }

      state = state.copyWith(isExporting: false, lastExportPath: path);
      return path;
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
      return null;
    }
  }

  /// Export and immediately share the file
  Future<bool> exportAndShare(RideSession session, ExportFormat format) async {
    final path = await exportRide(session, format);
    if (path == null) return false;

    try {
      final rideName = session.workout?.name ?? 'Ride ${session.startTime.toLocal().toString().substring(0, 16)}';
      final result = await Share.shareXFiles(
        [XFile(path)],
        subject: 'Ride Export - $rideName',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to share: $e');
      return false;
    }
  }

  /// Get list of exported files
  Future<List<ExportedFile>> getExportedFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');

    if (!await exportDir.exists()) {
      return [];
    }

    final files = <ExportedFile>[];
    await for (final entity in exportDir.list()) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        final stat = await entity.stat();

        ExportFormat? format;
        if (name.endsWith('.fit')) {
          format = ExportFormat.fit;
        } else if (name.endsWith('.tcx')) {
          format = ExportFormat.tcx;
        }

        if (format != null) {
          files.add(ExportedFile(
            path: entity.path,
            name: name,
            format: format,
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }
    }

    // Sort by date, newest first
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  /// Share an already exported file
  Future<bool> shareFile(String path) async {
    try {
      final result = await Share.shareXFiles([XFile(path)]);
      return result.status == ShareResultStatus.success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to share: $e');
      return false;
    }
  }

  /// Delete an exported file
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Represents an exported file
class ExportedFile {
  final String path;
  final String name;
  final ExportFormat format;
  final DateTime createdAt;
  final int sizeBytes;

  ExportedFile({
    required this.path,
    required this.name,
    required this.format,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Provider for export functionality
final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  return ExportNotifier();
});

/// Provider for listing exported files
final exportedFilesProvider = FutureProvider<List<ExportedFile>>((ref) async {
  final notifier = ref.watch(exportProvider.notifier);
  return notifier.getExportedFiles();
});
