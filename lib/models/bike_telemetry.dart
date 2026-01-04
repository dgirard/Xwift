import 'package:equatable/equatable.dart';

import '../core/constants/ftms_constants.dart';

/// Real-time telemetry data from Indoor Bike Data characteristic (0x2AD2)
class BikeTelemetry extends Equatable {
  const BikeTelemetry({
    this.instantPower,
    this.averagePower,
    this.instantCadence,
    this.averageCadence,
    this.instantSpeed,
    this.averageSpeed,
    this.heartRate,
    this.totalDistance,
    this.totalEnergy,
    this.resistanceLevel,
    required this.timestamp,
  });

  final int? instantPower; // Watts
  final int? averagePower; // Watts
  final double? instantCadence; // RPM (resolution 0.5)
  final double? averageCadence; // RPM
  final double? instantSpeed; // km/h (resolution 0.01)
  final double? averageSpeed; // km/h
  final int? heartRate; // BPM
  final int? totalDistance; // meters
  final int? totalEnergy; // kcal
  final int? resistanceLevel; // Current resistance level
  final DateTime timestamp;

  /// Get power zone based on FTP
  PowerZone getPowerZone(int ftp) {
    if (instantPower == null) return PowerZone.recovery;
    return PowerZone.fromPowerAndFtp(instantPower!, ftp);
  }

  /// Create empty telemetry
  factory BikeTelemetry.empty() {
    return BikeTelemetry(timestamp: DateTime.now());
  }

  BikeTelemetry copyWith({
    int? instantPower,
    int? averagePower,
    double? instantCadence,
    double? averageCadence,
    double? instantSpeed,
    double? averageSpeed,
    int? heartRate,
    int? totalDistance,
    int? totalEnergy,
    int? resistanceLevel,
    DateTime? timestamp,
  }) {
    return BikeTelemetry(
      instantPower: instantPower ?? this.instantPower,
      averagePower: averagePower ?? this.averagePower,
      instantCadence: instantCadence ?? this.instantCadence,
      averageCadence: averageCadence ?? this.averageCadence,
      instantSpeed: instantSpeed ?? this.instantSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      heartRate: heartRate ?? this.heartRate,
      totalDistance: totalDistance ?? this.totalDistance,
      totalEnergy: totalEnergy ?? this.totalEnergy,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        instantPower,
        averagePower,
        instantCadence,
        averageCadence,
        instantSpeed,
        averageSpeed,
        heartRate,
        totalDistance,
        totalEnergy,
        resistanceLevel,
        timestamp,
      ];
}

/// A single telemetry sample for recording rides
class TelemetrySample extends Equatable {
  const TelemetrySample({
    required this.timestamp,
    this.power,
    this.cadence,
    this.speed,
    this.heartRate,
    this.distance,
    this.calories,
  });

  final DateTime timestamp;
  final int? power;
  final int? cadence;
  final double? speed;
  final int? heartRate;
  final int? distance;
  final int? calories;

  factory TelemetrySample.fromTelemetry(BikeTelemetry telemetry) {
    return TelemetrySample(
      timestamp: telemetry.timestamp,
      power: telemetry.instantPower,
      cadence: telemetry.instantCadence?.round(),
      speed: telemetry.instantSpeed,
      heartRate: telemetry.heartRate,
      distance: telemetry.totalDistance,
      calories: telemetry.totalEnergy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'power': power,
      'cadence': cadence,
      'speed': speed,
      'heartRate': heartRate,
      'distance': distance,
      'calories': calories,
    };
  }

  factory TelemetrySample.fromJson(Map<String, dynamic> json) {
    return TelemetrySample(
      timestamp: DateTime.parse(json['timestamp'] as String),
      power: json['power'] as int?,
      cadence: json['cadence'] as int?,
      speed: (json['speed'] as num?)?.toDouble(),
      heartRate: json['heartRate'] as int?,
      distance: json['distance'] as int?,
      calories: json['calories'] as int?,
    );
  }

  @override
  List<Object?> get props =>
      [timestamp, power, cadence, speed, heartRate, distance, calories];
}
