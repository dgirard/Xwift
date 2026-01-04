import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../models/workout_plan.dart';
import 'zwo_parser.dart';
import 'erg_parser.dart';
import 'mrc_parser.dart';

/// Base class for workout file parsers
abstract class WorkoutParser {
  /// Parse workout content and return a WorkoutPlan
  WorkoutPlan parse(String content, {int? ftp});

  /// Get the file extension this parser handles
  String get extension;
}

/// Factory for creating appropriate parser based on file extension
class WorkoutParserFactory {
  static final Map<String, WorkoutParser> _parsers = {
    '.zwo': ZwoParser(),
    '.erg': ErgParser(),
    '.mrc': MrcParser(),
  };

  /// Parse a workout file
  static WorkoutPlan parseFile(File file, {int? ftp}) {
    final ext = path.extension(file.path).toLowerCase();
    final parser = _parsers[ext];

    if (parser == null) {
      throw UnsupportedWorkoutFormatException(ext);
    }

    final content = file.readAsStringSync();
    return parser.parse(content, ftp: ftp);
  }

  /// Parse workout content with known format
  static WorkoutPlan parseContent(String content, String format, {int? ftp}) {
    final ext = format.startsWith('.') ? format.toLowerCase() : '.$format'.toLowerCase();
    final parser = _parsers[ext];

    if (parser == null) {
      throw UnsupportedWorkoutFormatException(ext);
    }

    return parser.parse(content, ftp: ftp);
  }

  /// Get list of supported extensions
  static List<String> get supportedExtensions => _parsers.keys.toList();

  /// Check if a format is supported
  static bool isSupported(String extension) {
    final ext = extension.startsWith('.') ? extension.toLowerCase() : '.$extension'.toLowerCase();
    return _parsers.containsKey(ext);
  }
}

/// Exception thrown when workout format is not supported
class UnsupportedWorkoutFormatException implements Exception {
  final String format;

  UnsupportedWorkoutFormatException(this.format);

  @override
  String toString() => 'Unsupported workout format: $format. '
      'Supported formats: ${WorkoutParserFactory.supportedExtensions.join(", ")}';
}

/// Exception thrown when workout file is malformed
class MalformedWorkoutException implements Exception {
  final String message;
  final String? details;

  MalformedWorkoutException(this.message, {this.details});

  @override
  String toString() => details != null ? '$message: $details' : message;
}
