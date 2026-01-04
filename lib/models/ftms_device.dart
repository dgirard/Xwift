import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Represents a discovered FTMS-compatible Bluetooth device
class FtmsDevice extends Equatable {
  const FtmsDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.features,
    this.resistanceRange,
    this.powerRange,
  });

  final String id;
  final String name;
  final int rssi;
  final FtmsFeatures? features;
  final ResistanceRange? resistanceRange;
  final PowerRange? powerRange;

  factory FtmsDevice.fromScanResult(ScanResult result) {
    return FtmsDevice(
      id: result.device.remoteId.str,
      name: result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown Device',
      rssi: result.rssi,
    );
  }

  /// Signal quality based on RSSI
  SignalQuality get signalQuality {
    if (rssi >= -60) return SignalQuality.excellent;
    if (rssi >= -70) return SignalQuality.good;
    return SignalQuality.fair;
  }

  FtmsDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    FtmsFeatures? features,
    ResistanceRange? resistanceRange,
    PowerRange? powerRange,
  }) {
    return FtmsDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      features: features ?? this.features,
      resistanceRange: resistanceRange ?? this.resistanceRange,
      powerRange: powerRange ?? this.powerRange,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, rssi, features, resistanceRange, powerRange];
}

enum SignalQuality {
  excellent('Excellent'),
  good('Bon signal'),
  fair('Faible');

  const SignalQuality(this.label);
  final String label;
}

/// Device capabilities read from Fitness Machine Feature characteristic
class FtmsFeatures extends Equatable {
  const FtmsFeatures({
    this.supportsAverageSpeed = false,
    this.supportsCadence = false,
    this.supportsDistance = false,
    this.supportsInclination = false,
    this.supportsElevation = false,
    this.supportsPace = false,
    this.supportsStepCount = false,
    this.supportsResistance = false,
    this.supportsStrideCount = false,
    this.supportsExpendedEnergy = false,
    this.supportsHeartRate = false,
    this.supportsMetabolicEquivalent = false,
    this.supportsElapsedTime = false,
    this.supportsRemainingTime = false,
    this.supportsPower = false,
    this.supportsForceOnBelt = false,
    this.supportsPowerOutput = false,
    this.supportsTargetResistance = false,
    this.supportsTargetPower = false,
    this.supportsTargetSpeed = false,
    this.supportsTargetInclination = false,
    this.supportsTargetHeartRate = false,
    this.supportsTargetCadence = false,
    this.supportsSimulation = false,
  });

  final bool supportsAverageSpeed;
  final bool supportsCadence;
  final bool supportsDistance;
  final bool supportsInclination;
  final bool supportsElevation;
  final bool supportsPace;
  final bool supportsStepCount;
  final bool supportsResistance;
  final bool supportsStrideCount;
  final bool supportsExpendedEnergy;
  final bool supportsHeartRate;
  final bool supportsMetabolicEquivalent;
  final bool supportsElapsedTime;
  final bool supportsRemainingTime;
  final bool supportsPower;
  final bool supportsForceOnBelt;
  final bool supportsPowerOutput;
  final bool supportsTargetResistance;
  final bool supportsTargetPower;
  final bool supportsTargetSpeed;
  final bool supportsTargetInclination;
  final bool supportsTargetHeartRate;
  final bool supportsTargetCadence;
  final bool supportsSimulation;

  /// Can use ERG mode (target power control)
  bool get canErg => supportsTargetPower;

  /// Can use SIM mode (simulation parameters)
  bool get canSim => supportsSimulation || supportsTargetResistance;

  @override
  List<Object?> get props => [
        supportsAverageSpeed,
        supportsCadence,
        supportsDistance,
        supportsInclination,
        supportsElevation,
        supportsPace,
        supportsStepCount,
        supportsResistance,
        supportsStrideCount,
        supportsExpendedEnergy,
        supportsHeartRate,
        supportsMetabolicEquivalent,
        supportsElapsedTime,
        supportsRemainingTime,
        supportsPower,
        supportsForceOnBelt,
        supportsPowerOutput,
        supportsTargetResistance,
        supportsTargetPower,
        supportsTargetSpeed,
        supportsTargetInclination,
        supportsTargetHeartRate,
        supportsTargetCadence,
        supportsSimulation,
      ];
}

/// Supported resistance level range
class ResistanceRange extends Equatable {
  const ResistanceRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  final double minimum;
  final double maximum;
  final double increment;

  @override
  List<Object?> get props => [minimum, maximum, increment];
}

/// Supported power range for ERG mode
class PowerRange extends Equatable {
  const PowerRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  final int minimum;
  final int maximum;
  final int increment;

  @override
  List<Object?> get props => [minimum, maximum, increment];
}
