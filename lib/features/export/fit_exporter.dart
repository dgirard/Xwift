import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/bike_telemetry.dart';
import '../../models/ride_session.dart';

/// Exports ride sessions to FIT (Flexible and Interoperable Data Transfer) format
///
/// FIT is Garmin's binary format, widely used by cycling computers and Strava.
/// Field numbers and types follow the FIT SDK profile (Profile.xlsx).
class FitExporter {
  // FIT protocol constants
  static const int _fitProtocolVersion = 0x10; // Protocol 1.0
  static const int _fitProfileVersion = 2068; // Profile 20.68
  static const String _fitFileSignature = '.FIT';

  // FIT timestamp epoch: December 31, 1989 00:00:00 UTC
  static final DateTime _fitEpoch = DateTime.utc(1989, 12, 31, 0, 0, 0);

  // Global message numbers
  static const int _msgFileId = 0;
  static const int _msgSession = 18;
  static const int _msgLap = 19;
  static const int _msgRecord = 20;
  static const int _msgEvent = 21;
  static const int _msgActivity = 34;

  // Base types
  static const int _enum = 0x00;
  static const int _uint8 = 0x02;
  static const int _uint16 = 0x84;
  static const int _uint32 = 0x86;

  // "No value" for each base type: readers ignore these (0 would be a value).
  static const int _invalidUint8 = 0xFF;
  static const int _invalidUint16 = 0xFFFF;
  static const int _invalidUint32 = 0xFFFFFFFF;

  // Profile enums
  static const int _manufacturerDevelopment = 255;
  static const int _eventTimer = 0;
  static const int _eventSession = 8;
  static const int _eventLap = 9;
  static const int _eventActivity = 26;
  static const int _eventTypeStart = 0;
  static const int _eventTypeStop = 1;
  static const int _sportCycling = 2;
  static const int _subSportIndoorCycling = 6;

  // Local message types (each definition is written once)
  static const int _localFileId = 0;
  static const int _localEvent = 1;
  static const int _localRecord = 2;
  static const int _localLap = 3;
  static const int _localSession = 4;
  static const int _localActivity = 5;

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
    final data = BytesBuilder();
    final summary = _Summary(session);

    _writeFileId(data, session);

    _writeDefinition(data, _localEvent, _msgEvent, const [
      _FieldDef(253, 4, _uint32), // timestamp
      _FieldDef(0, 1, _enum), // event
      _FieldDef(1, 1, _enum), // event_type
    ]);
    _writeEvent(data, session.startTime, _eventTypeStart);

    _writeDefinition(data, _localRecord, _msgRecord, const [
      _FieldDef(253, 4, _uint32), // timestamp
      _FieldDef(3, 1, _uint8), // heart_rate (bpm)
      _FieldDef(4, 1, _uint8), // cadence (rpm)
      _FieldDef(5, 4, _uint32), // distance (1/100 m)
      _FieldDef(6, 2, _uint16), // speed (1/1000 m/s)
      _FieldDef(7, 2, _uint16), // power (W)
    ]);
    for (final sample in session.samples) {
      _writeRecord(data, sample);
    }

    // The timer stop event comes before lap, session and activity.
    _writeEvent(data, summary.endTime, _eventTypeStop);
    _writeLap(data, session, summary);
    _writeSession(data, session, summary);
    _writeActivity(data, summary);

    final dataBytes = data.toBytes();
    final dataCrc = _calculateCrc(dataBytes);

    final file = BytesBuilder();
    _writeFileHeader(file, dataBytes.length);
    file.add(dataBytes);
    file.add([dataCrc & 0xFF, (dataCrc >> 8) & 0xFF]);
    return file.toBytes();
  }

  static void _writeFileHeader(BytesBuilder buffer, int dataSize) {
    final header = <int>[
      14, // header size
      _fitProtocolVersion,
      _fitProfileVersion & 0xFF,
      (_fitProfileVersion >> 8) & 0xFF,
      dataSize & 0xFF,
      (dataSize >> 8) & 0xFF,
      (dataSize >> 16) & 0xFF,
      (dataSize >> 24) & 0xFF,
      ..._fitFileSignature.codeUnits,
    ];
    // Header CRC covers the first 12 bytes.
    final headerCrc = _calculateCrc(header);
    buffer.add(header);
    buffer.addByte(headerCrc & 0xFF);
    buffer.addByte((headerCrc >> 8) & 0xFF);
  }

  static void _writeFileId(BytesBuilder buffer, RideSession session) {
    _writeDefinition(buffer, _localFileId, _msgFileId, const [
      _FieldDef(0, 1, _enum), // type
      _FieldDef(1, 2, _uint16), // manufacturer
      _FieldDef(2, 2, _uint16), // product
      _FieldDef(3, 4, _uint32), // serial_number
      _FieldDef(4, 4, _uint32), // time_created
    ]);
    buffer.addByte(_localFileId);
    buffer.addByte(4); // type: activity
    _writeUint16(buffer, _manufacturerDevelopment);
    _writeUint16(buffer, 1); // product
    _writeUint32(buffer, 12345); // serial number
    _writeTimestamp(buffer, session.startTime);
  }

  static void _writeEvent(BytesBuilder buffer, DateTime time, int eventType) {
    buffer.addByte(_localEvent);
    _writeTimestamp(buffer, time);
    buffer.addByte(_eventTimer);
    buffer.addByte(eventType);
  }

  static void _writeRecord(BytesBuilder buffer, TelemetrySample sample) {
    buffer.addByte(_localRecord);
    _writeTimestamp(buffer, sample.timestamp);
    buffer.addByte(_uint8OrInvalid(sample.heartRate));
    buffer.addByte(_uint8OrInvalid(sample.cadence));
    final distance = sample.distance;
    _writeUint32(
      buffer,
      distance == null ? _invalidUint32 : math.max(0, distance) * 100,
    );
    final speed = sample.speed;
    _writeUint16(
      buffer,
      speed == null ? _invalidUint16 : _clampUint16((speed / 3.6 * 1000).round()),
    );
    final power = sample.power;
    _writeUint16(buffer, power == null ? _invalidUint16 : _clampUint16(power));
  }

  static void _writeLap(
    BytesBuilder buffer,
    RideSession session,
    _Summary summary,
  ) {
    _writeDefinition(buffer, _localLap, _msgLap, const [
      _FieldDef(253, 4, _uint32), // timestamp
      _FieldDef(0, 1, _enum), // event
      _FieldDef(1, 1, _enum), // event_type
      _FieldDef(2, 4, _uint32), // start_time
      _FieldDef(7, 4, _uint32), // total_elapsed_time (1/1000 s)
      _FieldDef(8, 4, _uint32), // total_timer_time (1/1000 s)
      _FieldDef(9, 4, _uint32), // total_distance (1/100 m)
      _FieldDef(11, 2, _uint16), // total_calories
      _FieldDef(13, 2, _uint16), // avg_speed (1/1000 m/s)
      _FieldDef(14, 2, _uint16), // max_speed (1/1000 m/s)
      _FieldDef(15, 1, _uint8), // avg_heart_rate
      _FieldDef(16, 1, _uint8), // max_heart_rate
      _FieldDef(17, 1, _uint8), // avg_cadence
      _FieldDef(18, 1, _uint8), // max_cadence
      _FieldDef(19, 2, _uint16), // avg_power
      _FieldDef(20, 2, _uint16), // max_power
      _FieldDef(25, 1, _enum), // sport
    ]);
    buffer.addByte(_localLap);
    _writeTimestamp(buffer, summary.endTime);
    buffer.addByte(_eventLap);
    buffer.addByte(_eventTypeStop);
    _writeTimestamp(buffer, session.startTime);
    _writeUint32(buffer, summary.totalTimeMs);
    _writeUint32(buffer, summary.totalTimeMs);
    _writeUint32(buffer, summary.distanceMeters * 100);
    _writeUint16(buffer, summary.calories);
    _writeUint16(buffer, summary.avgSpeedMms);
    _writeUint16(buffer, summary.maxSpeedMms);
    buffer.addByte(_uint8OrInvalid(summary.avgHeartRate));
    buffer.addByte(_uint8OrInvalid(summary.maxHeartRate));
    buffer.addByte(_uint8OrInvalid(summary.avgCadence));
    buffer.addByte(_uint8OrInvalid(summary.maxCadence));
    _writeUint16(buffer, _uint16OrInvalid(summary.avgPower));
    _writeUint16(buffer, _uint16OrInvalid(summary.maxPower));
    buffer.addByte(_sportCycling);
  }

  static void _writeSession(
    BytesBuilder buffer,
    RideSession session,
    _Summary summary,
  ) {
    _writeDefinition(buffer, _localSession, _msgSession, const [
      _FieldDef(253, 4, _uint32), // timestamp
      _FieldDef(0, 1, _enum), // event
      _FieldDef(1, 1, _enum), // event_type
      _FieldDef(2, 4, _uint32), // start_time
      _FieldDef(5, 1, _enum), // sport
      _FieldDef(6, 1, _enum), // sub_sport
      _FieldDef(7, 4, _uint32), // total_elapsed_time (1/1000 s)
      _FieldDef(8, 4, _uint32), // total_timer_time (1/1000 s)
      _FieldDef(9, 4, _uint32), // total_distance (1/100 m)
      _FieldDef(11, 2, _uint16), // total_calories
      _FieldDef(14, 2, _uint16), // avg_speed (1/1000 m/s)
      _FieldDef(15, 2, _uint16), // max_speed (1/1000 m/s)
      _FieldDef(16, 1, _uint8), // avg_heart_rate
      _FieldDef(17, 1, _uint8), // max_heart_rate
      _FieldDef(18, 1, _uint8), // avg_cadence
      _FieldDef(19, 1, _uint8), // max_cadence
      _FieldDef(20, 2, _uint16), // avg_power
      _FieldDef(21, 2, _uint16), // max_power
      _FieldDef(25, 2, _uint16), // first_lap_index
      _FieldDef(26, 2, _uint16), // num_laps
    ]);
    buffer.addByte(_localSession);
    _writeTimestamp(buffer, summary.endTime);
    buffer.addByte(_eventSession);
    buffer.addByte(_eventTypeStop);
    _writeTimestamp(buffer, session.startTime);
    buffer.addByte(_sportCycling);
    buffer.addByte(_subSportIndoorCycling);
    _writeUint32(buffer, summary.totalTimeMs);
    _writeUint32(buffer, summary.totalTimeMs);
    _writeUint32(buffer, summary.distanceMeters * 100);
    _writeUint16(buffer, summary.calories);
    _writeUint16(buffer, summary.avgSpeedMms);
    _writeUint16(buffer, summary.maxSpeedMms);
    buffer.addByte(_uint8OrInvalid(summary.avgHeartRate));
    buffer.addByte(_uint8OrInvalid(summary.maxHeartRate));
    buffer.addByte(_uint8OrInvalid(summary.avgCadence));
    buffer.addByte(_uint8OrInvalid(summary.maxCadence));
    _writeUint16(buffer, _uint16OrInvalid(summary.avgPower));
    _writeUint16(buffer, _uint16OrInvalid(summary.maxPower));
    _writeUint16(buffer, 0); // first_lap_index
    _writeUint16(buffer, 1); // num_laps
  }

  static void _writeActivity(BytesBuilder buffer, _Summary summary) {
    _writeDefinition(buffer, _localActivity, _msgActivity, const [
      _FieldDef(253, 4, _uint32), // timestamp
      _FieldDef(0, 4, _uint32), // total_timer_time (1/1000 s)
      _FieldDef(1, 2, _uint16), // num_sessions
      _FieldDef(2, 1, _enum), // type
      _FieldDef(3, 1, _enum), // event
      _FieldDef(4, 1, _enum), // event_type
    ]);
    buffer.addByte(_localActivity);
    _writeTimestamp(buffer, summary.endTime);
    _writeUint32(buffer, summary.totalTimeMs);
    _writeUint16(buffer, 1); // num_sessions
    buffer.addByte(0); // type: manual
    buffer.addByte(_eventActivity);
    buffer.addByte(_eventTypeStop);
  }

  static void _writeDefinition(
    BytesBuilder buffer,
    int localMsgType,
    int globalMsgNum,
    List<_FieldDef> fields,
  ) {
    buffer.addByte(0x40 | localMsgType); // definition record header
    buffer.addByte(0); // reserved
    buffer.addByte(0); // architecture: little endian
    _writeUint16(buffer, globalMsgNum);
    buffer.addByte(fields.length);
    for (final field in fields) {
      buffer.addByte(field.fieldDefNum);
      buffer.addByte(field.size);
      buffer.addByte(field.baseType);
    }
  }

  static int _uint8OrInvalid(int? value) =>
      value == null ? _invalidUint8 : value.clamp(0, _invalidUint8 - 1);

  static int _uint16OrInvalid(int? value) =>
      value == null ? _invalidUint16 : _clampUint16(value);

  static int _clampUint16(int value) => value.clamp(0, _invalidUint16 - 1);

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
}

/// Totals and averages shared by the lap and session messages.
class _Summary {
  _Summary(RideSession session)
      : endTime = session.endTime ?? session.startTime.add(session.duration),
        totalTimeMs = session.duration.inMilliseconds {
    final samples = session.samples;
    final heartRates = [
      for (final s in samples)
        if (s.heartRate != null && s.heartRate! > 0) s.heartRate!,
    ];
    final cadences = [
      for (final s in samples)
        if (s.cadence != null && s.cadence! > 0) s.cadence!,
    ];
    final powers = [
      for (final s in samples)
        if (s.power != null) math.max(0, s.power!),
    ];
    final speeds = [
      for (final s in samples)
        if (s.speed != null && s.speed! > 0) s.speed!,
    ];
    final distances = [
      for (final s in samples)
        if (s.distance != null) s.distance!,
    ];

    avgHeartRate = _average(heartRates);
    maxHeartRate = heartRates.isEmpty ? null : heartRates.reduce(math.max);
    avgCadence = _average(cadences);
    maxCadence = cadences.isEmpty ? null : cadences.reduce(math.max);
    avgPower = _average(powers);
    maxPower = powers.isEmpty ? null : powers.reduce(math.max);
    maxSpeedMms = speeds.isEmpty
        ? 0
        : (speeds.reduce(math.max) / 3.6 * 1000).round().clamp(0, 0xFFFE);
    distanceMeters =
        distances.isEmpty ? 0 : math.max(0, distances.reduce(math.max));
    final seconds = session.duration.inSeconds;
    avgSpeedMms = seconds > 0
        ? (distanceMeters / seconds * 1000).round().clamp(0, 0xFFFE)
        : 0;
    // Mechanical work (kJ) ≈ energy burned (kcal) at ~24 % efficiency.
    calories = avgPower == null || seconds <= 0
        ? 0
        : (avgPower! * seconds / 1000 / 4.184 * 4).round().clamp(0, 0xFFFE);
  }

  final DateTime endTime;
  final int totalTimeMs;
  late final int? avgHeartRate;
  late final int? maxHeartRate;
  late final int? avgCadence;
  late final int? maxCadence;
  late final int? avgPower;
  late final int? maxPower;
  late final int maxSpeedMms;
  late final int avgSpeedMms;
  late final int distanceMeters;
  late final int calories;

  static int? _average(List<int> values) => values.isEmpty
      ? null
      : (values.reduce((a, b) => a + b) / values.length).round();
}

class _FieldDef {
  const _FieldDef(this.fieldDefNum, this.size, this.baseType);

  final int fieldDefNum;
  final int size;
  final int baseType;
}
