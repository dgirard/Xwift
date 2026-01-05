import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/ride_session.dart';
import '../../models/bike_telemetry.dart';

/// Exports ride sessions to FIT (Flexible and Interoperable Data Transfer) format
///
/// FIT is Garmin's binary format, widely used by cycling computers and Strava.
class FitExporter {
  // FIT protocol constants
  static const int _fitProtocolVersion = 0x10; // Version 1.0
  static const int _fitProfileVersion = 0x0814; // Profile 8.20
  static const String _fitFileSignature = '.FIT';

  // FIT timestamp epoch: December 31, 1989 00:00:00 UTC
  static final DateTime _fitEpoch = DateTime.utc(1989, 12, 31, 0, 0, 0);

  // Message types (Global Message Numbers)
  static const int _msgFileId = 0;
  static const int _msgSession = 18;
  static const int _msgLap = 19;
  static const int _msgRecord = 20;
  static const int _msgEvent = 21;
  static const int _msgActivity = 34;

  /// Export a ride session to a FIT file
  ///
  /// Returns the path to the exported file
  static Future<String> export(RideSession session) async {
    final fitBytes = _generateFit(session);

    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final fileName = _generateFileName(session);
    final file = File('${exportDir.path}/$fileName.fit');
    await file.writeAsBytes(fitBytes);

    return file.path;
  }

  /// Export to a specific file path
  static Future<void> exportToPath(RideSession session, String filePath) async {
    final fitBytes = _generateFit(session);
    final file = File(filePath);
    await file.writeAsBytes(fitBytes);
  }

  /// Generate FIT content as bytes
  static Uint8List generateContent(RideSession session) {
    return _generateFit(session);
  }

  static String _generateFileName(RideSession session) {
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'ride_${formatter.format(session.startTime)}';
  }

  static Uint8List _generateFit(RideSession session) {
    final dataBuffer = BytesBuilder();

    // Write data messages
    _writeFileIdMessage(dataBuffer, session);
    _writeEventMessage(dataBuffer, session.startTime, isStart: true);

    // Write record messages (telemetry data)
    for (final sample in session.samples) {
      _writeRecordMessage(dataBuffer, sample, session.startTime);
    }

    // Write end event (must come before lap/session/activity)
    final endTime = session.endTime ?? session.startTime.add(session.duration);
    _writeEventMessage(dataBuffer, endTime, isStart: false);

    // Write lap message
    _writeLapMessage(dataBuffer, session);

    // Write session message
    _writeSessionMessage(dataBuffer, session);

    // Write activity message
    _writeActivityMessage(dataBuffer, session);

    final dataBytes = dataBuffer.toBytes();

    // Calculate CRC of data
    final dataCrc = _calculateCrc(dataBytes);

    // Build final file
    final fileBuffer = BytesBuilder();

    // Write file header
    _writeFileHeader(fileBuffer, dataBytes.length);

    // Write data
    fileBuffer.add(dataBytes);

    // Write data CRC
    fileBuffer.add([dataCrc & 0xFF, (dataCrc >> 8) & 0xFF]);

    return fileBuffer.toBytes();
  }

  static void _writeFileHeader(BytesBuilder buffer, int dataSize) {
    // Build header bytes first (without CRC) to calculate CRC
    final headerBytes = <int>[];

    // Header size (14 bytes for FIT 1.0)
    headerBytes.add(14);

    // Protocol version
    headerBytes.add(_fitProtocolVersion);

    // Profile version (little endian)
    headerBytes.add(_fitProfileVersion & 0xFF);
    headerBytes.add((_fitProfileVersion >> 8) & 0xFF);

    // Data size (little endian, 4 bytes)
    headerBytes.add(dataSize & 0xFF);
    headerBytes.add((dataSize >> 8) & 0xFF);
    headerBytes.add((dataSize >> 16) & 0xFF);
    headerBytes.add((dataSize >> 24) & 0xFF);

    // File signature ".FIT"
    headerBytes.addAll(_fitFileSignature.codeUnits);

    // Calculate header CRC (first 12 bytes only, excluding CRC itself)
    final headerCrc = _calculateCrc(headerBytes);

    // Write header with CRC
    buffer.add(headerBytes);
    buffer.addByte(headerCrc & 0xFF);
    buffer.addByte((headerCrc >> 8) & 0xFF);
  }

  static void _writeFileIdMessage(BytesBuilder buffer, RideSession session) {
    // Definition message for file_id
    _writeDefinitionMessage(buffer, 0, _msgFileId, [
      _FieldDef(0, 1, 0), // type: enum (activity)
      _FieldDef(1, 2, 132), // manufacturer: uint16
      _FieldDef(2, 2, 132), // product: uint16
      _FieldDef(3, 4, 134), // serial_number: uint32
      _FieldDef(4, 4, 134), // time_created: uint32
    ]);

    // Data message
    _writeDataHeader(buffer, 0);
    buffer.addByte(4); // type: activity
    _writeUint16(buffer, 1); // manufacturer: development
    _writeUint16(buffer, 1); // product
    _writeUint32(buffer, 12345); // serial number
    _writeTimestamp(buffer, session.startTime); // time_created
  }

  static void _writeEventMessage(BytesBuilder buffer, DateTime time, {required bool isStart}) {
    // Definition message for event
    _writeDefinitionMessage(buffer, 1, _msgEvent, [
      _FieldDef(253, 4, 134), // timestamp: uint32
      _FieldDef(0, 1, 0), // event: enum
      _FieldDef(1, 1, 0), // event_type: enum
    ]);

    // Data message
    _writeDataHeader(buffer, 1);
    _writeTimestamp(buffer, time);
    buffer.addByte(0); // event: timer
    buffer.addByte(isStart ? 0 : 1); // event_type: start/stop
  }

  static void _writeRecordMessage(BytesBuilder buffer, TelemetrySample sample, DateTime sessionStart) {
    // Definition message for record
    _writeDefinitionMessage(buffer, 2, _msgRecord, [
      _FieldDef(253, 4, 134), // timestamp: uint32
      _FieldDef(3, 1, 2), // heart_rate: uint8
      _FieldDef(4, 1, 2), // cadence: uint8
      _FieldDef(5, 4, 134), // distance: uint32 (scaled, 100 = 1m)
      _FieldDef(6, 2, 132), // speed: uint16 (scaled, 1000 = 1 m/s)
      _FieldDef(7, 2, 132), // power: uint16
    ]);

    // Data message
    _writeDataHeader(buffer, 2);
    _writeTimestamp(buffer, sample.timestamp);

    // Heart rate (uint8, clamped to 255)
    final hr = (sample.heartRate ?? 0).clamp(0, 255);
    buffer.addByte(hr);

    // Cadence (uint8, clamped to 255)
    final cadence = (sample.cadence ?? 0).clamp(0, 255);
    buffer.addByte(cadence);

    // Distance in meters * 100
    final distanceCm = ((sample.distance ?? 0) * 100).round();
    _writeUint32(buffer, distanceCm);

    // Speed in m/s * 1000
    final speedMs = (sample.speed ?? 0) / 3.6; // km/h to m/s
    _writeUint16(buffer, (speedMs * 1000).round());

    // Power
    _writeUint16(buffer, sample.power ?? 0);
  }

  static void _writeLapMessage(BytesBuilder buffer, RideSession session) {
    // Definition message for lap
    _writeDefinitionMessage(buffer, 3, _msgLap, [
      _FieldDef(253, 4, 134), // timestamp: uint32
      _FieldDef(2, 4, 134), // start_time: uint32
      _FieldDef(7, 4, 134), // total_elapsed_time: uint32 (scaled, 1000 = 1s)
      _FieldDef(8, 4, 134), // total_timer_time: uint32 (scaled, 1000 = 1s)
      _FieldDef(9, 4, 134), // total_distance: uint32 (scaled, 100 = 1m)
      _FieldDef(11, 2, 132), // total_calories: uint16
      _FieldDef(13, 2, 132), // avg_speed: uint16 (scaled)
      _FieldDef(14, 2, 132), // max_speed: uint16 (scaled)
      _FieldDef(19, 2, 132), // avg_power: uint16
      _FieldDef(20, 2, 132), // max_power: uint16
      _FieldDef(21, 1, 2), // avg_heart_rate: uint8
      _FieldDef(22, 1, 2), // max_heart_rate: uint8
      _FieldDef(23, 1, 2), // avg_cadence: uint8
      _FieldDef(24, 1, 2), // max_cadence: uint8
    ]);

    // Data message
    final endTime = session.endTime ?? session.startTime.add(session.duration);
    final totalTimeMs = session.duration.inMilliseconds;
    final distance = session.samples.isNotEmpty ? (session.samples.last.distance ?? 0).toDouble() : 0.0;
    final avgPower = session.averagePower ?? 0;
    final maxPower = session.maxPower ?? 0;
    final avgHr = _calculateAverageHeartRate(session.samples);
    final maxHr = _calculateMaxHeartRate(session.samples);
    final avgCadence = _calculateAverageCadence(session.samples);
    final maxCadence = _calculateMaxCadence(session.samples);
    final avgSpeed = distance / (session.duration.inSeconds > 0 ? session.duration.inSeconds : 1);
    final maxSpeed = _calculateMaxSpeed(session.samples);

    _writeDataHeader(buffer, 3);
    _writeTimestamp(buffer, endTime);
    _writeTimestamp(buffer, session.startTime);
    _writeUint32(buffer, totalTimeMs); // total_elapsed_time
    _writeUint32(buffer, totalTimeMs); // total_timer_time
    _writeUint32(buffer, (distance * 100).round()); // total_distance
    _writeUint16(buffer, _estimateCalories(session)); // total_calories
    _writeUint16(buffer, (avgSpeed * 1000).round()); // avg_speed
    _writeUint16(buffer, (maxSpeed * 1000).round()); // max_speed
    _writeUint16(buffer, avgPower); // avg_power
    _writeUint16(buffer, maxPower); // max_power
    buffer.addByte(avgHr); // avg_heart_rate
    buffer.addByte(maxHr); // max_heart_rate
    buffer.addByte(avgCadence); // avg_cadence
    buffer.addByte(maxCadence); // max_cadence
  }

  static void _writeSessionMessage(BytesBuilder buffer, RideSession session) {
    // Definition message for session
    _writeDefinitionMessage(buffer, 4, _msgSession, [
      _FieldDef(253, 4, 134), // timestamp: uint32
      _FieldDef(2, 4, 134), // start_time: uint32
      _FieldDef(5, 1, 0), // sport: enum
      _FieldDef(6, 1, 0), // sub_sport: enum
      _FieldDef(7, 4, 134), // total_elapsed_time: uint32
      _FieldDef(8, 4, 134), // total_timer_time: uint32
      _FieldDef(9, 4, 134), // total_distance: uint32
      _FieldDef(11, 2, 132), // total_calories: uint16
      _FieldDef(14, 2, 132), // avg_speed: uint16
      _FieldDef(20, 2, 132), // avg_power: uint16
      _FieldDef(25, 1, 0), // first_lap_index: uint16
      _FieldDef(26, 2, 132), // num_laps: uint16
    ]);

    // Data message
    final endTime = session.endTime ?? session.startTime.add(session.duration);
    final totalTimeMs = session.duration.inMilliseconds;
    final distance = session.samples.isNotEmpty ? (session.samples.last.distance ?? 0).toDouble() : 0.0;
    final avgPower = session.averagePower ?? 0;
    final avgSpeed = distance / (session.duration.inSeconds > 0 ? session.duration.inSeconds : 1);

    _writeDataHeader(buffer, 4);
    _writeTimestamp(buffer, endTime);
    _writeTimestamp(buffer, session.startTime);
    buffer.addByte(2); // sport: cycling
    buffer.addByte(6); // sub_sport: indoor_cycling
    _writeUint32(buffer, totalTimeMs);
    _writeUint32(buffer, totalTimeMs);
    _writeUint32(buffer, (distance * 100).round());
    _writeUint16(buffer, _estimateCalories(session));
    _writeUint16(buffer, (avgSpeed * 1000).round());
    _writeUint16(buffer, avgPower);
    buffer.addByte(0); // first_lap_index
    _writeUint16(buffer, 1); // num_laps
  }

  static void _writeActivityMessage(BytesBuilder buffer, RideSession session) {
    // Definition message for activity
    _writeDefinitionMessage(buffer, 5, _msgActivity, [
      _FieldDef(253, 4, 134), // timestamp: uint32
      _FieldDef(0, 4, 134), // total_timer_time: uint32
      _FieldDef(1, 2, 132), // num_sessions: uint16
      _FieldDef(2, 1, 0), // type: enum
      _FieldDef(3, 1, 0), // event: enum
      _FieldDef(4, 1, 0), // event_type: enum
    ]);

    // Data message
    final endTime = session.endTime ?? session.startTime.add(session.duration);
    final totalTimeMs = session.duration.inMilliseconds;

    _writeDataHeader(buffer, 5);
    _writeTimestamp(buffer, endTime);
    _writeUint32(buffer, totalTimeMs);
    _writeUint16(buffer, 1); // num_sessions
    buffer.addByte(0); // type: manual
    buffer.addByte(26); // event: activity
    buffer.addByte(1); // event_type: stop
  }

  static void _writeDefinitionMessage(BytesBuilder buffer, int localMsgType, int globalMsgNum, List<_FieldDef> fields) {
    // Record header: definition message
    buffer.addByte(0x40 | localMsgType);

    // Reserved byte
    buffer.addByte(0);

    // Architecture: little endian
    buffer.addByte(0);

    // Global message number (little endian)
    _writeUint16(buffer, globalMsgNum);

    // Number of fields
    buffer.addByte(fields.length);

    // Field definitions
    for (final field in fields) {
      buffer.addByte(field.fieldDefNum);
      buffer.addByte(field.size);
      buffer.addByte(field.baseType);
    }
  }

  static void _writeDataHeader(BytesBuilder buffer, int localMsgType) {
    // Record header: data message
    buffer.addByte(localMsgType);
  }

  static void _writeUint16(BytesBuilder buffer, int value) {
    buffer.addByte(value & 0xFF);
    buffer.addByte((value >> 8) & 0xFF);
  }

  static void _writeUint32(BytesBuilder buffer, int value) {
    buffer.addByte(value & 0xFF);
    buffer.addByte((value >> 8) & 0xFF);
    buffer.addByte((value >> 16) & 0xFF);
    buffer.addByte((value >> 24) & 0xFF);
  }

  static void _writeTimestamp(BytesBuilder buffer, DateTime time) {
    final fitTimestamp = time.toUtc().difference(_fitEpoch).inSeconds;
    _writeUint32(buffer, fitTimestamp);
  }

  static int _calculateCrc(List<int> data) {
    const crcTable = [
      0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
      0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ];

    int crc = 0;
    for (final byte in data) {
      // Compute CRC using nibbles
      var tmp = crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ crcTable[byte & 0xF];

      tmp = crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ crcTable[(byte >> 4) & 0xF];
    }

    return crc;
  }

  static int _calculateAverageHeartRate(List<TelemetrySample> samples) {
    final hrs = samples.where((s) => s.heartRate != null && s.heartRate! > 0).map((s) => s.heartRate!).toList();
    if (hrs.isEmpty) return 0;
    return (hrs.reduce((a, b) => a + b) / hrs.length).round();
  }

  static int _calculateMaxHeartRate(List<TelemetrySample> samples) {
    final hrs = samples.where((s) => s.heartRate != null && s.heartRate! > 0).map((s) => s.heartRate!).toList();
    if (hrs.isEmpty) return 0;
    return hrs.reduce((a, b) => a > b ? a : b);
  }

  static int _calculateAverageCadence(List<TelemetrySample> samples) {
    final cadences = samples.where((s) => s.cadence != null && s.cadence! > 0).map((s) => s.cadence!).toList();
    if (cadences.isEmpty) return 0;
    return (cadences.reduce((a, b) => a + b) / cadences.length).round();
  }

  static int _calculateMaxCadence(List<TelemetrySample> samples) {
    final cadences = samples.where((s) => s.cadence != null && s.cadence! > 0).map((s) => s.cadence!).toList();
    if (cadences.isEmpty) return 0;
    return cadences.reduce((a, b) => a > b ? a : b);
  }

  static double _calculateMaxSpeed(List<TelemetrySample> samples) {
    final speeds = samples.where((s) => s.speed != null && s.speed! > 0).map((s) => s.speed! / 3.6).toList(); // to m/s
    if (speeds.isEmpty) return 0;
    return speeds.reduce((a, b) => a > b ? a : b);
  }

  static int _estimateCalories(RideSession session) {
    final avgPower = session.averagePower;
    final durationSeconds = session.duration.inSeconds;
    if (avgPower == null || avgPower <= 0 || durationSeconds <= 0) return 0;
    final energyKj = avgPower * durationSeconds / 1000;
    return (energyKj / 4.184 * 4).round();
  }
}

class _FieldDef {
  final int fieldDefNum;
  final int size;
  final int baseType;

  _FieldDef(this.fieldDefNum, this.size, this.baseType);
}
