import 'package:xml/xml.dart';

import '../../../models/workout_plan.dart';
import 'workout_parser.dart';

/// Parser for Zwift workout files (.zwo)
///
/// ZWO files are XML format with structure:
/// ```xml
/// <workout_file>
///   <name>Workout Name</name>
///   <description>Description</description>
///   <author>Author</author>
///   <workout>
///     <Warmup Duration="300" PowerLow="0.25" PowerHigh="0.75"/>
///     <SteadyState Duration="600" Power="0.88"/>
///     <IntervalsT Repeat="5" OnDuration="60" OffDuration="60" OnPower="1.2" OffPower="0.5"/>
///     <Cooldown Duration="300" PowerLow="0.75" PowerHigh="0.25"/>
///     <FreeRide Duration="600"/>
///   </workout>
/// </workout_file>
/// ```
class ZwoParser implements WorkoutParser {
  @override
  String get extension => '.zwo';

  @override
  WorkoutPlan parse(String content, {int? ftp}) {
    final effectiveFtp = ftp ?? 200; // Default FTP if not provided

    try {
      final document = XmlDocument.parse(content);
      final workoutFile = document.findElements('workout_file').firstOrNull;

      if (workoutFile == null) {
        throw MalformedWorkoutException('Invalid ZWO file', details: 'Missing workout_file element');
      }

      // Extract metadata
      final name = _getTextContent(workoutFile, 'name') ?? 'Imported Workout';
      final description = _getTextContent(workoutFile, 'description');
      final author = _getTextContent(workoutFile, 'author');

      // Parse workout segments
      final workoutElement = workoutFile.findElements('workout').firstOrNull;
      if (workoutElement == null) {
        throw MalformedWorkoutException('Invalid ZWO file', details: 'Missing workout element');
      }

      final intervals = <WorkoutInterval>[];

      for (final element in workoutElement.children.whereType<XmlElement>()) {
        intervals.addAll(_parseSegment(element, effectiveFtp));
      }

      if (intervals.isEmpty) {
        throw MalformedWorkoutException('Invalid ZWO file', details: 'No workout segments found');
      }

      return WorkoutPlan(
        name: name,
        description: description,
        author: author,
        intervals: intervals,
        ftp: effectiveFtp,
      );
    } on XmlException catch (e) {
      throw MalformedWorkoutException('Failed to parse ZWO file', details: e.message);
    }
  }

  String? _getTextContent(XmlElement parent, String elementName) {
    final element = parent.findElements(elementName).firstOrNull;
    return element?.innerText.trim();
  }

  List<WorkoutInterval> _parseSegment(XmlElement element, int ftp) {
    final tagName = element.name.local.toLowerCase();

    return switch (tagName) {
      'warmup' => _parseWarmupCooldown(element, ftp, 'Warmup'),
      'cooldown' => _parseWarmupCooldown(element, ftp, 'Cooldown'),
      'steadystate' => [_parseSteadyState(element, ftp)],
      'intervalst' => _parseIntervals(element, ftp),
      'freeride' => [_parseFreeRide(element)],
      'ramp' => _parseRamp(element, ftp),
      _ => [], // Skip unknown elements
    };
  }

  List<WorkoutInterval> _parseWarmupCooldown(XmlElement element, int ftp, String name) {
    final duration = _parseDuration(element);
    final powerLow = _parsePower(element, 'PowerLow', ftp) ?? (ftp * 0.25).round();
    final powerHigh = _parsePower(element, 'PowerHigh', ftp) ?? (ftp * 0.75).round();

    // Create stepped intervals for gradual power change
    const steps = 5;
    final stepDuration = Duration(seconds: duration.inSeconds ~/ steps);
    final powerStep = (powerHigh - powerLow) / (steps - 1);

    return List.generate(steps, (i) {
      final power = (powerLow + (powerStep * i)).round();
      return WorkoutInterval(
        duration: stepDuration,
        targetPower: power,
        name: '$name ${i + 1}/$steps',
      );
    });
  }

  WorkoutInterval _parseSteadyState(XmlElement element, int ftp) {
    final duration = _parseDuration(element);
    final power = _parsePower(element, 'Power', ftp) ?? ftp;
    final cadence = _parseInt(element, 'Cadence');

    return WorkoutInterval(
      duration: duration,
      targetPower: power,
      name: _getAttribute(element, 'Name'),
      cadenceTarget: cadence,
    );
  }

  List<WorkoutInterval> _parseIntervals(XmlElement element, int ftp) {
    final repeat = _parseInt(element, 'Repeat') ?? 1;
    final onDuration = Duration(seconds: _parseInt(element, 'OnDuration') ?? 60);
    final offDuration = Duration(seconds: _parseInt(element, 'OffDuration') ?? 60);
    final onPower = _parsePower(element, 'OnPower', ftp) ?? (ftp * 1.2).round();
    final offPower = _parsePower(element, 'OffPower', ftp) ?? (ftp * 0.5).round();
    final onCadence = _parseInt(element, 'Cadence');
    final offCadence = _parseInt(element, 'CadenceResting');

    final intervals = <WorkoutInterval>[];

    for (int i = 0; i < repeat; i++) {
      intervals.add(WorkoutInterval(
        duration: onDuration,
        targetPower: onPower,
        name: 'Interval ${i + 1}',
        cadenceTarget: onCadence,
      ));
      intervals.add(WorkoutInterval(
        duration: offDuration,
        targetPower: offPower,
        name: 'Recovery ${i + 1}',
        cadenceTarget: offCadence,
      ));
    }

    return intervals;
  }

  WorkoutInterval _parseFreeRide(XmlElement element) {
    final duration = _parseDuration(element);

    return WorkoutInterval(
      duration: duration,
      targetPower: 0, // Free ride - no target
      name: 'Free Ride',
    );
  }

  List<WorkoutInterval> _parseRamp(XmlElement element, int ftp) {
    final duration = _parseDuration(element);
    final powerLow = _parsePower(element, 'PowerLow', ftp) ?? (ftp * 0.5).round();
    final powerHigh = _parsePower(element, 'PowerHigh', ftp) ?? ftp;

    // Create stepped intervals for ramp
    const steps = 10;
    final stepDuration = Duration(seconds: duration.inSeconds ~/ steps);
    final powerStep = (powerHigh - powerLow) / (steps - 1);

    return List.generate(steps, (i) {
      final power = (powerLow + (powerStep * i)).round();
      return WorkoutInterval(
        duration: stepDuration,
        targetPower: power,
        name: 'Ramp ${i + 1}/$steps',
      );
    });
  }

  Duration _parseDuration(XmlElement element) {
    final seconds = _parseInt(element, 'Duration') ?? 60;
    return Duration(seconds: seconds);
  }

  int? _parsePower(XmlElement element, String attribute, int ftp) {
    final value = _getAttribute(element, attribute);
    if (value == null) return null;

    final parsed = double.tryParse(value);
    if (parsed == null) return null;

    // ZWO uses percentage of FTP (0.0 - 2.0+)
    if (parsed <= 3.0) {
      return (parsed * ftp).round();
    }
    // Some files use absolute watts
    return parsed.round();
  }

  int? _parseInt(XmlElement element, String attribute) {
    final value = _getAttribute(element, attribute);
    if (value == null) return null;
    return int.tryParse(value);
  }

  String? _getAttribute(XmlElement element, String name) {
    return element.getAttribute(name);
  }
}
