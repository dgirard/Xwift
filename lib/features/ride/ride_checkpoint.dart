import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/ride_session.dart';

/// Snapshot of the ride in progress, saved regularly so that a ride survives
/// the app being killed (battery, crash, system cleanup).
class RideCheckpoint {
  const RideCheckpoint({
    required this.session,
    required this.elapsed,
    required this.distance,
  });

  /// Samples, start time, program used… `endTime` is the checkpoint time.
  final RideSession session;

  /// Riding time, pauses excluded.
  final Duration elapsed;

  /// Distance since the ride start, in meters.
  final int distance;

  String encode() => jsonEncode({
        'version': 1,
        'session': session.toJson(),
        'elapsedMs': elapsed.inMilliseconds,
        'distance': distance,
      });

  /// Null when the data is unreadable (partial write, older format).
  static RideCheckpoint? decode(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['version'] != 1) return null;
      return RideCheckpoint(
        session: RideSession.fromJson(json['session'] as Map<String, dynamic>),
        elapsed: Duration(milliseconds: json['elapsedMs'] as int),
        distance: json['distance'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where the ride in progress is kept between checkpoints.
abstract class RideCheckpointStore {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> delete();
}

/// One file in the app documents; written to a temporary file then renamed,
/// so that a crash during the write never leaves a truncated checkpoint.
class FileRideCheckpointStore implements RideCheckpointStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'ride_in_progress.json'));
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String data) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

/// In-memory store (tests).
class MemoryRideCheckpointStore implements RideCheckpointStore {
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String value) async => data = value;

  @override
  Future<void> delete() async => data = null;
}

final rideCheckpointStoreProvider =
    Provider<RideCheckpointStore>((ref) => FileRideCheckpointStore());
