import '../../../models/workout_plan.dart';
import 'workout_parser.dart';

/// Parser for MRC workout files (.mrc)
///
/// MRC files are text format similar to ERG but use percentage of FTP:
/// ```
/// [COURSE HEADER]
/// VERSION = 2
/// UNITS = ENGLISH
/// DESCRIPTION = Workout description
/// FILE NAME = workout.mrc
/// MINUTES PERCENT
/// [END COURSE HEADER]
/// [COURSE DATA]
/// 0.00	50
/// 5.00	75
/// 10.00	100
/// 15.00	75
/// 20.00	50
/// [END COURSE DATA]
/// ```
///
/// Times are in minutes, power in percentage of FTP
class MrcParser implements WorkoutParser {
  @override
  String get extension => '.mrc';

  @override
  WorkoutPlan parse(String content, {int? ftp}) {
    final effectiveFtp = ftp ?? 200; // Default FTP if not provided
    final lines = content.split('\n').map((l) => l.trim()).toList();

    String? name;
    String? description;
    final dataPoints = <_DataPoint>[];
    bool inCourseData = false;
    bool inHeader = false;

    for (final line in lines) {
      if (line.isEmpty) continue;

      // Track sections
      if (line.toUpperCase().contains('[COURSE HEADER]')) {
        inHeader = true;
        continue;
      }
      if (line.toUpperCase().contains('[END COURSE HEADER]')) {
        inHeader = false;
        continue;
      }
      if (line.toUpperCase().contains('[COURSE DATA]')) {
        inCourseData = true;
        continue;
      }
      if (line.toUpperCase().contains('[END COURSE DATA]')) {
        inCourseData = false;
        continue;
      }

      // Parse header
      if (inHeader) {
        if (line.toUpperCase().startsWith('FILE NAME')) {
          name = _parseHeaderValue(line);
          // Remove extension from name
          if (name != null && name.contains('.')) {
            name = name.substring(0, name.lastIndexOf('.'));
          }
        } else if (line.toUpperCase().startsWith('DESCRIPTION')) {
          description = _parseHeaderValue(line);
        }
      }

      // Parse data points
      if (inCourseData) {
        final point = _parseDataPoint(line, effectiveFtp);
        if (point != null) {
          dataPoints.add(point);
        }
      }
    }

    if (dataPoints.isEmpty) {
      throw MalformedWorkoutException('Invalid MRC file', details: 'No data points found');
    }

    // Convert data points to intervals
    final intervals = _convertToIntervals(dataPoints);

    return WorkoutPlan(
      name: name ?? 'Imported MRC Workout',
      description: description,
      intervals: intervals,
      ftp: effectiveFtp,
    );
  }

  String? _parseHeaderValue(String line) {
    final parts = line.split('=');
    if (parts.length < 2) return null;
    return parts.sublist(1).join('=').trim();
  }

  _DataPoint? _parseDataPoint(String line, int ftp) {
    // Handle both tab and space separators
    final parts = line.split(RegExp(r'[\t\s]+'));
    if (parts.length < 2) return null;

    final minutes = double.tryParse(parts[0]);
    final percent = double.tryParse(parts[1]);

    if (minutes == null || percent == null) return null;

    // Convert percentage to watts
    final watts = (percent / 100 * ftp).round();

    return _DataPoint(
      timeMinutes: minutes,
      watts: watts,
    );
  }

  List<WorkoutInterval> _convertToIntervals(List<_DataPoint> dataPoints) {
    final intervals = <WorkoutInterval>[];

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final current = dataPoints[i];
      final next = dataPoints[i + 1];

      final durationMinutes = next.timeMinutes - current.timeMinutes;
      if (durationMinutes <= 0) continue;

      final duration = Duration(seconds: (durationMinutes * 60).round());

      // Check if this is a ramp (power changes between points)
      if (current.watts != next.watts) {
        // Create stepped ramp
        const steps = 5;
        final stepDuration = Duration(seconds: duration.inSeconds ~/ steps);
        final powerStep = (next.watts - current.watts) / steps;

        for (int s = 0; s < steps; s++) {
          final power = (current.watts + (powerStep * s)).round();
          intervals.add(WorkoutInterval(
            duration: stepDuration,
            targetPower: power,
            name: 'Segment ${intervals.length + 1}',
          ));
        }
      } else {
        // Steady state
        intervals.add(WorkoutInterval(
          duration: duration,
          targetPower: current.watts,
          name: 'Segment ${intervals.length + 1}',
        ));
      }
    }

    // Merge consecutive intervals with same power
    return _mergeConsecutiveIntervals(intervals);
  }

  List<WorkoutInterval> _mergeConsecutiveIntervals(List<WorkoutInterval> intervals) {
    if (intervals.isEmpty) return intervals;

    final merged = <WorkoutInterval>[];
    var current = intervals.first;

    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];

      if (current.targetPower == next.targetPower) {
        // Merge intervals
        current = WorkoutInterval(
          duration: current.duration + next.duration,
          targetPower: current.targetPower,
          name: current.name,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    return merged;
  }
}

class _DataPoint {
  final double timeMinutes;
  final int watts;

  _DataPoint({required this.timeMinutes, required this.watts});
}
