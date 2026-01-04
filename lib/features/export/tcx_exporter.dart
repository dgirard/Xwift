import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/ride_session.dart';
import '../../models/bike_telemetry.dart';

/// Exports ride sessions to TCX (Training Center XML) format
///
/// TCX is widely supported by Strava, Garmin Connect, and other platforms.
class TcxExporter {
  /// Export a ride session to a TCX file
  ///
  /// Returns the path to the exported file
  static Future<String> export(RideSession session) async {
    final tcxContent = _generateTcx(session);

    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final fileName = _generateFileName(session);
    final file = File('${exportDir.path}/$fileName.tcx');
    await file.writeAsString(tcxContent);

    return file.path;
  }

  /// Export to a specific file path
  static Future<void> exportToPath(RideSession session, String filePath) async {
    final tcxContent = _generateTcx(session);
    final file = File(filePath);
    await file.writeAsString(tcxContent);
  }

  /// Generate TCX content as a string
  static String generateContent(RideSession session) {
    return _generateTcx(session);
  }

  static String _generateFileName(RideSession session) {
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'ride_${formatter.format(session.startTime)}';
  }

  static String _generateTcx(RideSession session) {
    final buffer = StringBuffer();

    // XML header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 '
        'http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">');

    // Activities
    buffer.writeln('  <Activities>');
    buffer.writeln('    <Activity Sport="Biking">');

    // Activity ID (start time in ISO 8601)
    final startTimeIso = session.startTime.toUtc().toIso8601String();
    buffer.writeln('      <Id>$startTimeIso</Id>');

    // Single lap for the entire ride
    buffer.writeln('      <Lap StartTime="$startTimeIso">');

    // Lap statistics
    final totalSeconds = session.duration.inSeconds;
    buffer.writeln('        <TotalTimeSeconds>$totalSeconds</TotalTimeSeconds>');

    final distanceMeters = _calculateTotalDistance(session.samples);
    buffer.writeln('        <DistanceMeters>$distanceMeters</DistanceMeters>');

    final avgSpeed = distanceMeters / (totalSeconds > 0 ? totalSeconds : 1);
    buffer.writeln('        <MaximumSpeed>${_formatDouble(avgSpeed)}</MaximumSpeed>');

    final calories = _estimateCalories(session);
    buffer.writeln('        <Calories>$calories</Calories>');

    // Heart rate stats
    final avgHeartRate = _calculateAverageHeartRate(session.samples);
    if (avgHeartRate > 0) {
      buffer.writeln('        <AverageHeartRateBpm><Value>$avgHeartRate</Value></AverageHeartRateBpm>');
    }
    final maxHeartRate = _calculateMaxHeartRate(session.samples);
    if (maxHeartRate > 0) {
      buffer.writeln('        <MaximumHeartRateBpm><Value>$maxHeartRate</Value></MaximumHeartRateBpm>');
    }

    buffer.writeln('        <Intensity>Active</Intensity>');
    buffer.writeln('        <TriggerMethod>Manual</TriggerMethod>');

    // Track with trackpoints
    buffer.writeln('        <Track>');

    for (final sample in session.samples) {
      _writeTrackpoint(buffer, sample);
    }

    buffer.writeln('        </Track>');
    buffer.writeln('      </Lap>');

    // Creator info
    buffer.writeln('      <Creator xsi:type="Device_t">');
    buffer.writeln('        <Name>Xwift</Name>');
    buffer.writeln('        <UnitId>0</UnitId>');
    buffer.writeln('        <ProductID>0</ProductID>');
    buffer.writeln('        <Version>');
    buffer.writeln('          <VersionMajor>1</VersionMajor>');
    buffer.writeln('          <VersionMinor>0</VersionMinor>');
    buffer.writeln('        </Version>');
    buffer.writeln('      </Creator>');

    buffer.writeln('    </Activity>');
    buffer.writeln('  </Activities>');

    // Author info
    buffer.writeln('  <Author xsi:type="Application_t">');
    buffer.writeln('    <Name>Xwift</Name>');
    buffer.writeln('    <Build>');
    buffer.writeln('      <Version>');
    buffer.writeln('        <VersionMajor>1</VersionMajor>');
    buffer.writeln('        <VersionMinor>0</VersionMinor>');
    buffer.writeln('      </Version>');
    buffer.writeln('    </Build>');
    buffer.writeln('    <LangID>en</LangID>');
    buffer.writeln('    <PartNumber>000-00000-00</PartNumber>');
    buffer.writeln('  </Author>');

    buffer.writeln('</TrainingCenterDatabase>');

    return buffer.toString();
  }

  static void _writeTrackpoint(StringBuffer buffer, TelemetrySample sample) {
    buffer.writeln('          <Trackpoint>');

    // Time
    final timeIso = sample.timestamp.toUtc().toIso8601String();
    buffer.writeln('            <Time>$timeIso</Time>');

    // Distance in meters
    final distanceMeters = (sample.distance ?? 0).toDouble();
    buffer.writeln('            <DistanceMeters>${_formatDouble(distanceMeters)}</DistanceMeters>');

    // Heart rate
    if (sample.heartRate != null && sample.heartRate! > 0) {
      buffer.writeln('            <HeartRateBpm><Value>${sample.heartRate}</Value></HeartRateBpm>');
    }

    // Cadence
    final cadence = sample.cadence ?? 0;
    if (cadence > 0) {
      buffer.writeln('            <Cadence>$cadence</Cadence>');
    }

    // Extensions for power
    final power = sample.power ?? 0;
    if (power > 0) {
      buffer.writeln('            <Extensions>');
      buffer.writeln('              <ns3:TPX xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">');
      buffer.writeln('                <ns3:Watts>$power</ns3:Watts>');
      final speed = sample.speed ?? 0;
      if (speed > 0) {
        buffer.writeln('                <ns3:Speed>${_formatDouble(speed / 3.6)}</ns3:Speed>'); // km/h to m/s
      }
      buffer.writeln('              </ns3:TPX>');
      buffer.writeln('            </Extensions>');
    }

    buffer.writeln('          </Trackpoint>');
  }

  static double _calculateTotalDistance(List<TelemetrySample> samples) {
    if (samples.isEmpty) return 0;
    return (samples.last.distance ?? 0).toDouble();
  }

  static int _calculateAverageHeartRate(List<TelemetrySample> samples) {
    final heartRates = samples
        .where((s) => s.heartRate != null && s.heartRate! > 0)
        .map((s) => s.heartRate!)
        .toList();
    if (heartRates.isEmpty) return 0;
    return (heartRates.reduce((a, b) => a + b) / heartRates.length).round();
  }

  static int _calculateMaxHeartRate(List<TelemetrySample> samples) {
    final heartRates = samples
        .where((s) => s.heartRate != null && s.heartRate! > 0)
        .map((s) => s.heartRate!)
        .toList();
    if (heartRates.isEmpty) return 0;
    return heartRates.reduce((a, b) => a > b ? a : b);
  }

  static int _estimateCalories(RideSession session) {
    // Simple calorie estimation based on power and duration
    // ~3.6 kJ per calorie, power is in watts (J/s)
    final avgPower = session.averagePower;
    final durationSeconds = session.duration.inSeconds;
    if (avgPower == null || avgPower <= 0 || durationSeconds <= 0) {
      return 0;
    }
    // Energy in kJ = power (W) * time (s) / 1000
    // Calories = kJ / 4.184 (but cycling efficiency ~25% so multiply by 4)
    final energyKj = avgPower * durationSeconds / 1000;
    return (energyKj / 4.184 * 4).round();
  }

  static String _formatDouble(double value) {
    return value.toStringAsFixed(2);
  }
}
