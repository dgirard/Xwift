import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/export/fit_exporter.dart';
import 'package:ridecontroller/features/export/tcx_exporter.dart';
import 'package:ridecontroller/models/bike_telemetry.dart';
import 'package:ridecontroller/models/ride_session.dart';

/// Minimal FIT reader: enough to check what the exporter writes
/// (normal headers, little-endian definitions).
class _Fit {
  _Fit(this.bytes) {
    final headerSize = bytes[0];
    final dataSize = bytes[4] | bytes[5] << 8 | bytes[6] << 16 | bytes[7] << 24;
    final end = headerSize + dataSize;
    final definitions = <int, (int, List<(int, int)>)>{};
    var offset = headerSize;
    while (offset < end) {
      final header = bytes[offset++];
      final local = header & 0x0F;
      if (header & 0x40 != 0) {
        offset += 2; // reserved, architecture
        final global = bytes[offset] | bytes[offset + 1] << 8;
        offset += 2;
        final count = bytes[offset++];
        final fields = <(int, int)>[];
        for (var i = 0; i < count; i++) {
          fields.add((bytes[offset], bytes[offset + 1]));
          offset += 3;
        }
        definitions[local] = (global, fields);
        definitionCount[global] = (definitionCount[global] ?? 0) + 1;
      } else {
        final (global, fields) = definitions[local]!;
        final values = <int, int>{};
        for (final (number, size) in fields) {
          var value = 0;
          for (var i = 0; i < size; i++) {
            value |= bytes[offset + i] << (8 * i);
          }
          values[number] = value;
          offset += size;
        }
        messages.putIfAbsent(global, () => []).add(values);
      }
    }
  }

  final Uint8List bytes;
  final messages = <int, List<Map<int, int>>>{};
  final definitionCount = <int, int>{};

  Map<int, int> single(int global) => messages[global]!.single;
}

int _crc(List<int> data) {
  const table = [
    0x0000,
    0xCC01,
    0xD801,
    0x1400,
    0xF001,
    0x3C00,
    0x2800,
    0xE401,
    0xA001,
    0x6C00,
    0x7800,
    0xB401,
    0x5000,
    0x9C01,
    0x8801,
    0x4400,
  ];
  var crc = 0;
  for (final byte in data) {
    var tmp = table[crc & 0xF];
    crc = (crc >> 4) & 0x0FFF;
    crc = crc ^ tmp ^ table[byte & 0xF];
    tmp = table[crc & 0xF];
    crc = (crc >> 4) & 0x0FFF;
    crc = crc ^ tmp ^ table[(byte >> 4) & 0xF];
  }
  return crc;
}

const _fileId = 0, _session = 18, _lap = 19, _record = 20;

void main() {
  final start = DateTime.utc(2026, 1, 10, 18);
  // 10 minutes at 1 Hz; heart rate missing during the first minute.
  final session = RideSession(
    id: 'test',
    startTime: start,
    endTime: start.add(const Duration(minutes: 10)),
    mode: RideMode.sim,
    state: RideState.completed,
    samples: [
      for (var i = 0; i < 600; i++)
        TelemetrySample(
          timestamp: start.add(Duration(seconds: i)),
          power: 180 + i % 41, // 180..220
          cadence: 85 + i % 11, // 85..95
          speed: 30.0 + i % 5, // 30..34 km/h
          heartRate: i < 60 ? null : 140 + i % 21, // 140..160
          distance: (i * 8.5).round(),
        ),
    ],
  );
  final fit = _Fit(FitExporter.generateContent(session));

  test('header and file checksums are valid', () {
    expect(_crc(fit.bytes.sublist(0, 12)), fit.bytes[12] | fit.bytes[13] << 8);
    expect(_crc(fit.bytes), 0, reason: 'CRC over data + CRC must be 0');
  });

  test('declares a development device, not a Garmin product', () {
    expect(fit.single(_fileId)[1], 255);
  });

  test('records are defined once and carry no fake zero heart rate', () {
    expect(fit.definitionCount[_record], 1);
    final records = fit.messages[_record]!;
    expect(records, hasLength(600));
    expect(records.first[3], 0xFF, reason: 'absent heart rate = invalid');
    expect(records.last[3], 140 + 599 % 21);
    expect(records.first[7], 180);
  });

  test('lap summary uses the FIT lap field numbers', () {
    final lap = fit.single(_lap);
    expect(lap[15], 150, reason: 'avg_heart_rate');
    expect(lap[16], 160, reason: 'max_heart_rate');
    expect(lap[17], 90, reason: 'avg_cadence');
    expect(lap[18], 95, reason: 'max_cadence');
    expect(lap[19], 200, reason: 'avg_power');
    expect(lap[20], 220, reason: 'max_power');
    for (final wrong in [21, 22, 23, 24]) {
      expect(lap.containsKey(wrong), isFalse,
          reason:
              'field $wrong is total_ascent/total_descent/intensity/lap_trigger');
    }
    expect(lap[14], (34 / 3.6 * 1000).round(), reason: 'max_speed');
  });

  test('session summary includes heart rate, cadence and max power', () {
    final s = fit.single(_session);
    expect(s[16], 150);
    expect(s[17], 160);
    expect(s[18], 90);
    expect(s[19], 95);
    expect(s[20], 200);
    expect(s[21], 220);
    expect(s[9], 5092 * 100, reason: 'total_distance');
  });

  test('TCX maximum speed is the real maximum, not the average', () {
    final tcx = TcxExporter.generateContent(session);
    expect(tcx, contains('<MaximumSpeed>9.44</MaximumSpeed>'));
  });
}
