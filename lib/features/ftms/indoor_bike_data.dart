import 'dart:typed_data';

import '../../models/bike_telemetry.dart';

/// One notification of the FTMS Indoor Bike Data characteristic (0x2AD2).
///
/// Fields absent from the notification are null. Field order and sizes follow
/// the FTMS 1.0 specification (§4.9).
class IndoorBikeDataPacket {
  const IndoorBikeDataPacket({
    required this.flags,
    this.instantSpeed,
    this.averageSpeed,
    this.instantCadence,
    this.averageCadence,
    this.totalDistance,
    this.resistanceLevel,
    this.instantPower,
    this.averagePower,
    this.totalEnergy,
    this.heartRate,
  });

  final int flags;
  final double? instantSpeed; // km/h
  final double? averageSpeed; // km/h
  final double? instantCadence; // rpm
  final double? averageCadence; // rpm
  final int? totalDistance; // m
  final int? resistanceLevel;
  final int? instantPower; // W
  final int? averagePower; // W
  final int? totalEnergy; // kcal
  final int? heartRate; // bpm

  /// "More Data" flag: the record continues in another notification and the
  /// instantaneous speed is not present in this one.
  bool get moreData => flags & 0x0001 != 0;

  /// Decodes a notification, or returns null when it is too short to hold the
  /// flags. Fields announced by the flags but truncated are left null.
  static IndoorBikeDataPacket? parse(List<int> bytes) {
    if (bytes.length < 2) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final flags = data.getUint16(0, Endian.little);
    var offset = 2;

    bool has(int size) => offset + size <= bytes.length;
    int u16() {
      final v = data.getUint16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int s16() {
      final v = data.getInt16(offset, Endian.little);
      offset += 2;
      return v;
    }

    double? instantSpeed, averageSpeed, instantCadence, averageCadence;
    int? totalDistance, resistanceLevel, instantPower, averagePower;
    int? totalEnergy, heartRate;

    // Bit 0 is inverted: 0 means the instantaneous speed IS present.
    if (flags & 0x0001 == 0 && has(2)) instantSpeed = u16() * 0.01;
    if (flags & 0x0002 != 0 && has(2)) averageSpeed = u16() * 0.01;
    if (flags & 0x0004 != 0 && has(2)) instantCadence = u16() * 0.5;
    if (flags & 0x0008 != 0 && has(2)) averageCadence = u16() * 0.5;
    if (flags & 0x0010 != 0 && has(3)) {
      totalDistance =
          bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
      offset += 3;
    }
    if (flags & 0x0020 != 0 && has(2)) resistanceLevel = s16();
    if (flags & 0x0040 != 0 && has(2)) instantPower = s16();
    if (flags & 0x0080 != 0 && has(2)) averagePower = s16();
    if (flags & 0x0100 != 0 && has(5)) {
      totalEnergy = u16();
      offset += 3; // energy per hour (uint16) + energy per minute (uint8)
    }
    if (flags & 0x0200 != 0 && has(1)) {
      final hr = bytes[offset];
      offset += 1;
      heartRate = hr == 0 ? null : hr; // 0 = no heart rate sensor
    }

    return IndoorBikeDataPacket(
      flags: flags,
      instantSpeed: instantSpeed,
      averageSpeed: averageSpeed,
      instantCadence: instantCadence,
      averageCadence: averageCadence,
      totalDistance: totalDistance,
      resistanceLevel: resistanceLevel,
      instantPower: instantPower,
      averagePower: averagePower,
      totalEnergy: totalEnergy,
      heartRate: heartRate,
    );
  }
}

/// Builds a current view of the trainer data from successive notifications.
///
/// Trainers may split one record over several notifications ("More Data"
/// flag) or send some fields less often. Replacing the whole view with each
/// notification makes values flicker to "no data". Here a field keeps its last
/// received value for [fieldLifetime], then expires, so the view never shows
/// values that stopped arriving (trainer silent or disconnected).
class TelemetryMerger {
  TelemetryMerger({this.fieldLifetime = const Duration(seconds: 3)});

  final Duration fieldLifetime;
  final Map<_Field, _Stamped> _fields = {};
  DateTime? _lastPacketAt;

  DateTime? get lastPacketAt => _lastPacketAt;

  BikeTelemetry add(IndoorBikeDataPacket packet, DateTime now) {
    void put(_Field field, num? value) {
      if (value != null) _fields[field] = _Stamped(value, now);
    }

    put(_Field.instantSpeed, packet.instantSpeed);
    put(_Field.averageSpeed, packet.averageSpeed);
    put(_Field.instantCadence, packet.instantCadence);
    put(_Field.averageCadence, packet.averageCadence);
    put(_Field.totalDistance, packet.totalDistance);
    put(_Field.resistanceLevel, packet.resistanceLevel);
    put(_Field.instantPower, packet.instantPower);
    put(_Field.averagePower, packet.averagePower);
    put(_Field.totalEnergy, packet.totalEnergy);
    put(_Field.heartRate, packet.heartRate);
    _lastPacketAt = now;
    return current(now);
  }

  /// The current view at [now]: fields older than [fieldLifetime] are null.
  BikeTelemetry current(DateTime now) {
    _fields.removeWhere((_, v) => now.difference(v.at) > fieldLifetime);
    num? get(_Field f) => _fields[f]?.value;
    return BikeTelemetry(
      instantSpeed: get(_Field.instantSpeed)?.toDouble(),
      averageSpeed: get(_Field.averageSpeed)?.toDouble(),
      instantCadence: get(_Field.instantCadence)?.toDouble(),
      averageCadence: get(_Field.averageCadence)?.toDouble(),
      totalDistance: get(_Field.totalDistance)?.toInt(),
      resistanceLevel: get(_Field.resistanceLevel)?.toInt(),
      instantPower: get(_Field.instantPower)?.toInt(),
      averagePower: get(_Field.averagePower)?.toInt(),
      totalEnergy: get(_Field.totalEnergy)?.toInt(),
      heartRate: get(_Field.heartRate)?.toInt(),
      timestamp: _lastPacketAt ?? now,
    );
  }
}

enum _Field {
  instantSpeed,
  averageSpeed,
  instantCadence,
  averageCadence,
  totalDistance,
  resistanceLevel,
  instantPower,
  averagePower,
  totalEnergy,
  heartRate,
}

class _Stamped {
  const _Stamped(this.value, this.at);
  final num value;
  final DateTime at;
}
