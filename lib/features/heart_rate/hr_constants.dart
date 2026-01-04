import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE Heart Rate Service constants
class HrConstants {
  HrConstants._();

  /// Heart Rate Service UUID (0x180D)
  static final serviceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');

  /// Heart Rate Measurement Characteristic UUID (0x2A37)
  static final measurementCharUuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');

  /// Body Sensor Location Characteristic UUID (0x2A38)
  static final bodySensorLocationCharUuid = Guid('00002a38-0000-1000-8000-00805f9b34fb');

  /// Heart Rate Control Point Characteristic UUID (0x2A39)
  static final controlPointCharUuid = Guid('00002a39-0000-1000-8000-00805f9b34fb');
}
