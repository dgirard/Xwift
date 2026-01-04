import '../../../models/workout_plan.dart';
import 'workout_parser.dart';

/// Parser for ERG workout files (.erg)
///
/// ERG files are text format with structure:
/// ```
/// [COURSE HEADER]
/// VERSION = 2
/// UNITS = ENGLISH
/// DESCRIPTION = Workout description
/// FILE NAME = workout.erg
/// MINUTES WATTS
/// [END COURSE HEADER]
/// [COURSE DATA]
/// 0.00	100
/// 5.00	150
/// 10.00	200
/// 15.00	150
/// 20.00	100
/// [END COURSE DATA]
/// ```
///
/// Times are in minutes, power in watts (absolute)
class ErgParser implements WorkoutParser {
  @override
  String get extension => '.erg';

  @override
  WorkoutPlan parse(String content, {int? ftp}) {
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
        final point = _parseDataPoint(line);
        if (point != null) {
          dataPoints.add(point);
        }
      }
    }

    if (dataPoints.isEmpty) {
      throw MalformedWorkoutException('Invalid ERG file', details: 'No data points found');
    }

    // Convert data points to intervals
    final intervals = _convertToIntervals(dataPoints);

    return WorkoutPlan(
      name: name ?? 'Imported ERG Workout',
      description: description,
      intervals: intervals,
      ftp: ftp,
    );
  }

  String? _parseHeaderValue(String line) {
    final parts = line.split('=');
    if (parts.length < 2) return null;
    return parts.sublist(1).join('=').trim();
  }

  _DataPoint? _parseDataPoint(String line) {
    // Handle both tab and space separators
    final parts = line.split(RegExp(r'[\t\s]+'));
    if (parts.length < 2) return null;

    final minutes = double.tryParse(parts[0]);
    final watts = double.tryParse(parts[1]);

    if (minutes == null || watts == null) return null;

    return _DataPoint(
      timeMinutes: minutes,
      watts: watts.round(),
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
