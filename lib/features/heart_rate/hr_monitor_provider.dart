import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'hr_constants.dart';

/// HR Monitor device model
class HrMonitorDevice {
  const HrMonitorDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;

  factory HrMonitorDevice.fromScanResult(ScanResult result) {
    return HrMonitorDevice(
      id: result.device.remoteId.str,
      name: result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown HR Monitor',
      rssi: result.rssi,
    );
  }
}

/// HR Scanner state
class HrScanState {
  const HrScanState({
    this.isScanning = false,
    this.devices = const [],
    this.error,
  });

  final bool isScanning;
  final List<HrMonitorDevice> devices;
  final String? error;

  HrScanState copyWith({
    bool? isScanning,
    List<HrMonitorDevice>? devices,
    String? error,
  }) {
    return HrScanState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      error: error,
    );
  }
}

/// HR Scanner provider
final hrScannerProvider =
    StateNotifierProvider<HrScannerNotifier, HrScanState>((ref) {
  return HrScannerNotifier();
});

/// HR Scanner notifier
class HrScannerNotifier extends StateNotifier<HrScanState> {
  HrScannerNotifier() : super(const HrScanState());

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  /// Request necessary Bluetooth permissions
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Start scanning for HR monitors
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (state.isScanning) return;

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      state = state.copyWith(
        error: 'Bluetooth permissions not granted',
        isScanning: false,
      );
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      state = state.copyWith(
        error: 'Bluetooth is not enabled',
        isScanning: false,
      );
      return;
    }

    state = state.copyWith(isScanning: true, devices: [], error: null);

    try {
      await FlutterBluePlus.startScan(
        withServices: [HrConstants.serviceUuid],
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final devices = results
            .where((r) => r.device.platformName.isNotEmpty)
            .map((r) => HrMonitorDevice.fromScanResult(r))
            .toList();

        devices.sort((a, b) => b.rssi.compareTo(a.rssi));

        state = state.copyWith(devices: devices);
      });

      await Future.delayed(timeout);
      await stopScan();
    } catch (e) {
      state = state.copyWith(
        error: 'Scan failed: $e',
        isScanning: false,
      );
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}

/// HR Connection state
class HrConnectionState {
  const HrConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.connectedDevice,
    this.currentHeartRate,
    this.error,
  });

  final bool isConnected;
  final bool isConnecting;
  final HrMonitorDevice? connectedDevice;
  final int? currentHeartRate;
  final String? error;

  HrConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    HrMonitorDevice? connectedDevice,
    int? currentHeartRate,
    String? error,
  }) {
    return HrConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      error: error,
    );
  }
}

/// HR Connection provider
final hrConnectionProvider =
    StateNotifierProvider<HrConnectionNotifier, HrConnectionState>((ref) {
  return HrConnectionNotifier();
});

/// Current heart rate provider
final currentHeartRateProvider = Provider<int?>((ref) {
  return ref.watch(hrConnectionProvider).currentHeartRate;
});

/// HR stream provider
final hrStreamProvider = StreamProvider<int>((ref) {
  final notifier = ref.watch(hrConnectionProvider.notifier);
  return notifier.heartRateStream;
});

/// HR Connection notifier
class HrConnectionNotifier extends StateNotifier<HrConnectionState> {
  HrConnectionNotifier() : super(const HrConnectionState());

  BluetoothDevice? _bleDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _hrSubscription;
  final _hrStreamController = StreamController<int>.broadcast();

  Stream<int> get heartRateStream => _hrStreamController.stream;

  /// Connect to an HR monitor
  Future<void> connect(HrMonitorDevice device) async {
    if (state.isConnected || state.isConnecting) {
      await disconnect();
    }

    state = state.copyWith(
      isConnecting: true,
      connectedDevice: device,
      error: null,
    );

    try {
      _bleDevice = BluetoothDevice.fromId(device.id);

      _connectionSubscription = _bleDevice!.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      await _bleDevice!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      final services = await _bleDevice!.discoverServices();

      final hrService = services.firstWhere(
        (s) => s.uuid == HrConstants.serviceUuid,
        orElse: () => throw Exception('HR service not found'),
      );

      final hrMeasurementChar = hrService.characteristics.firstWhere(
        (c) => c.uuid == HrConstants.measurementCharUuid,
        orElse: () => throw Exception('HR measurement characteristic not found'),
      );

      // Enable notifications
      await hrMeasurementChar.setNotifyValue(true);
      _hrSubscription = hrMeasurementChar.onValueReceived.listen(_handleHrData);

      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
      );
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        isConnecting: false,
        error: 'Connection failed: $e',
      );
    }
  }

  void _handleHrData(List<int> value) {
    if (value.isEmpty) return;

    // Parse HR measurement according to BLE HR Profile spec
    final flags = value[0];
    int heartRate;

    // Bit 0 of flags: 0 = HR is UINT8, 1 = HR is UINT16
    if ((flags & 0x01) == 0) {
      // HR is UINT8
      heartRate = value[1];
    } else {
      // HR is UINT16 (Little Endian)
      heartRate = value[1] | (value[2] << 8);
    }

    state = state.copyWith(currentHeartRate: heartRate);
    _hrStreamController.add(heartRate);
  }

  void _handleDisconnection() {
    if (state.isConnected) {
      state = state.copyWith(
        isConnected: false,
        error: 'Connection lost',
      );
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _hrSubscription?.cancel();
    _hrSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_bleDevice != null) {
      await _bleDevice!.disconnect();
      _bleDevice = null;
    }

    state = const HrConnectionState();
  }

  @override
  void dispose() {
    disconnect();
    _hrStreamController.close();
    super.dispose();
  }
}
