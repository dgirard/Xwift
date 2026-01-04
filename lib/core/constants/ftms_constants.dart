import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// FTMS (Fitness Machine Service) Bluetooth constants
class FtmsConstants {
  FtmsConstants._();

  // Service UUID
  static final Guid serviceUuid = Guid('00001826-0000-1000-8000-00805f9b34fb');

  // Characteristic UUIDs
  static final Guid fitnessMachineFeature =
      Guid('00002acc-0000-1000-8000-00805f9b34fb');
  static final Guid indoorBikeData =
      Guid('00002ad2-0000-1000-8000-00805f9b34fb');
  static final Guid trainingStatus =
      Guid('00002ad3-0000-1000-8000-00805f9b34fb');
  static final Guid supportedResistanceRange =
      Guid('00002ad6-0000-1000-8000-00805f9b34fb');
  static final Guid supportedPowerRange =
      Guid('00002ad8-0000-1000-8000-00805f9b34fb');
  static final Guid controlPoint =
      Guid('00002ad9-0000-1000-8000-00805f9b34fb');
  static final Guid machineStatus =
      Guid('00002ada-0000-1000-8000-00805f9b34fb');

  // Control Point OpCodes
  static const int opCodeRequestControl = 0x00;
  static const int opCodeReset = 0x01;
  static const int opCodeSetTargetSpeed = 0x02;
  static const int opCodeSetTargetInclination = 0x03;
  static const int opCodeSetTargetResistance = 0x04;
  static const int opCodeSetTargetPower = 0x05;
  static const int opCodeSetTargetHeartRate = 0x06;
  static const int opCodeStartOrResume = 0x07;
  static const int opCodeStopOrPause = 0x08;
  static const int opCodeSetSimulationParams = 0x11;
  static const int opCodeSpinDownControl = 0x13;
  static const int opCodeSetTargetCadence = 0x14;
  static const int opCodeResponseCode = 0x80;

  // Response Result Codes
  static const int resultSuccess = 0x01;
  static const int resultNotSupported = 0x02;
  static const int resultInvalidParameter = 0x03;
  static const int resultOperationFailed = 0x04;
  static const int resultControlNotPermitted = 0x05;

  // Stop/Pause values
  static const int stopValue = 0x01;
  static const int pauseValue = 0x02;

  // Default simulation parameters
  static const double defaultWindSpeed = 0.0;
  static const double defaultGrade = 0.0;
  static const double defaultCrr = 0.004; // Rolling resistance
  static const double defaultCw = 0.51; // Wind resistance coefficient
}

/// Power training zones based on FTP percentage
enum PowerZone {
  recovery(0, 55, 'Recovery'),
  endurance(55, 75, 'Endurance'),
  tempo(75, 90, 'Tempo'),
  threshold(90, 105, 'Threshold'),
  vo2max(105, 120, 'VO2max'),
  anaerobic(120, 200, 'Anaerobic');

  const PowerZone(this.minPercent, this.maxPercent, this.name);

  final int minPercent;
  final int maxPercent;
  final String name;

  static PowerZone fromPowerAndFtp(int power, int ftp) {
    if (ftp <= 0) return PowerZone.recovery;
    final percent = (power / ftp * 100).round();

    for (final zone in PowerZone.values) {
      if (percent >= zone.minPercent && percent < zone.maxPercent) {
        return zone;
      }
    }
    return PowerZone.anaerobic;
  }
}

/// Virtual gear ratios for Zwift-style shifting
class VirtualGearing {
  VirtualGearing._();

  static const int defaultTotalGears = 22;
  static const int defaultStartGear = 11;

  /// Grade adjustment per gear (in percentage points)
  static const double gradePerGear = 0.5;

  /// Calculate grade from gear position
  /// Gear 1 = easiest (uphill), Gear 22 = hardest (downhill)
  static double gradeFromGear(int gear, {int totalGears = defaultTotalGears}) {
    final midGear = totalGears ~/ 2;
    return (midGear - gear) * gradePerGear;
  }
}
