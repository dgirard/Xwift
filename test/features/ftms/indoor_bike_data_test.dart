import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/ftms/indoor_bike_data.dart';

/// Little-endian helpers to write FTMS frames as the trainer sends them.
List<int> u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> u24(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF];

void main() {
  group('IndoorBikeDataPacket.parse', () {
    test('decodes speed, cadence, distance, power and heart rate', () {
      // Flags: cadence (bit 2), distance (bit 4), power (bit 6), HR (bit 9).
      // Bit 0 = 0, so the instantaneous speed is present.
      final frame = [
        ...u16(0x0254),
        ...u16(3150), // 31.50 km/h
        ...u16(176), // 88 rpm (resolution 0.5)
        ...u24(12345), // m
        ...u16(212), // W
        145, // bpm
      ];
      final p = IndoorBikeDataPacket.parse(frame)!;
      expect(p.moreData, isFalse);
      expect(p.instantSpeed, closeTo(31.5, 1e-9));
      expect(p.instantCadence, 88);
      expect(p.totalDistance, 12345);
      expect(p.instantPower, 212);
      expect(p.heartRate, 145);
      expect(p.averageSpeed, isNull);
    });

    test('decodes every field in specification order', () {
      // Bits 1-9 set, bit 0 clear: all fields up to heart rate.
      final frame = [
        ...u16(0x03FE),
        ...u16(3000), // inst speed 30.00
        ...u16(2800), // avg speed 28.00
        ...u16(180), // inst cadence 90
        ...u16(170), // avg cadence 85
        ...u24(5000), // distance
        ...u16(7), // resistance level
        ...u16(250), // inst power
        ...u16(230), // avg power
        ...u16(120), 0x00, 0x00, 0x00, // energy: total, per hour, per minute
        150, // HR
      ];
      final p = IndoorBikeDataPacket.parse(frame)!;
      expect(p.instantSpeed, closeTo(30, 1e-9));
      expect(p.averageSpeed, closeTo(28, 1e-9));
      expect(p.instantCadence, 90);
      expect(p.averageCadence, 85);
      expect(p.totalDistance, 5000);
      expect(p.resistanceLevel, 7);
      expect(p.instantPower, 250);
      expect(p.averagePower, 230);
      expect(p.totalEnergy, 120);
      expect(p.heartRate, 150);
    });

    test('"More Data" frames carry no instantaneous speed', () {
      final p = IndoorBikeDataPacket.parse([...u16(0x0011), ...u24(800)])!;
      expect(p.moreData, isTrue);
      expect(p.instantSpeed, isNull);
      expect(p.totalDistance, 800);
    });

    test('power is signed', () {
      final p = IndoorBikeDataPacket.parse(
          [...u16(0x0040), ...u16(0), ...u16(0xFFF6)])!;
      expect(p.instantPower, -10);
    });

    test('heart rate 0 means no sensor', () {
      final p = IndoorBikeDataPacket.parse([...u16(0x0200), ...u16(0), 0])!;
      expect(p.heartRate, isNull);
    });

    test('truncated frames do not crash and leave missing fields empty', () {
      // Announces cadence and power but stops after the speed.
      final p = IndoorBikeDataPacket.parse([...u16(0x0044), ...u16(2500)])!;
      expect(p.instantSpeed, closeTo(25, 1e-9));
      expect(p.instantCadence, isNull);
      expect(p.instantPower, isNull);
      expect(IndoorBikeDataPacket.parse([0x44]), isNull);
    });
  });

  group('TelemetryMerger', () {
    final t0 = DateTime(2026, 1, 10, 18);

    test('keeps power and cadence across split frames', () {
      final merger = TelemetryMerger();
      // Frame A: speed, cadence, power. Frame B ("More Data"): distance only.
      final a = IndoorBikeDataPacket.parse(
          [...u16(0x0044), ...u16(3000), ...u16(180), ...u16(200)])!;
      final b = IndoorBikeDataPacket.parse([...u16(0x0011), ...u24(1500)])!;

      merger.add(a, t0);
      final view = merger.add(b, t0.add(const Duration(milliseconds: 250)));

      expect(view.instantPower, 200, reason: 'must not flicker to empty');
      expect(view.instantCadence, 90);
      expect(view.instantSpeed, closeTo(30, 1e-9));
      expect(view.totalDistance, 1500);
      expect(view.hasData, isTrue);
    });

    test('values expire when the trainer stops sending them', () {
      final merger = TelemetryMerger();
      merger.add(
        IndoorBikeDataPacket.parse(
            [...u16(0x0040), ...u16(3000), ...u16(180)])!,
        t0,
      );
      expect(
          merger.current(t0.add(const Duration(seconds: 2))).instantPower, 180);
      final later = merger.current(t0.add(const Duration(milliseconds: 3500)));
      expect(later.instantPower, isNull);
      expect(later.hasData, isFalse);
    });

    test('a new value replaces the previous one', () {
      final merger = TelemetryMerger();
      merger.add(
          IndoorBikeDataPacket.parse([...u16(0x0040), ...u16(0), ...u16(150)])!,
          t0);
      final view = merger.add(
        IndoorBikeDataPacket.parse([...u16(0x0040), ...u16(0), ...u16(0)])!,
        t0.add(const Duration(seconds: 1)),
      );
      expect(view.instantPower, 0,
          reason: '0 W is a real value, not "no data"');
    });
  });
}
