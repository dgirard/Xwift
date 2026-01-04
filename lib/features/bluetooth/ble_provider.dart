import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/ftms_constants.dart';
import '../../models/ftms_device.dart';

/// Bluetooth adapter state provider
final bluetoothAdapterStateProvider = StreamProvider<BluetoothAdapterState>((ref) {
  return FlutterBluePlus.adapterState;
});

/// Whether Bluetooth is available and on
final isBluetoothAvailableProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(bluetoothAdapterStateProvider).whenData(
        (state) => state == BluetoothAdapterState.on,
      );
});

/// BLE Scanner provider
final bleScannerProvider =
    StateNotifierProvider<BleScannerNotifier, BleScanState>((ref) {
  return BleScannerNotifier();
});

/// BLE Connection manager provider
final bleConnectionProvider =
    StateNotifierProvider<BleConnectionNotifier, BleConnectionState>((ref) {
  return BleConnectionNotifier();
});

/// Connected device stream provider
final connectedDeviceProvider = Provider<FtmsDevice?>((ref) {
  final connectionState = ref.watch(bleConnectionProvider);
  return connectionState.connectedDevice;
});

/// BLE Scan state
class BleScanState {
  const BleScanState({
    this.isScanning = false,
    this.devices = const [],
    this.error,
  });

  final bool isScanning;
  final List<FtmsDevice> devices;
  final String? error;

  BleScanState copyWith({
    bool? isScanning,
    List<FtmsDevice>? devices,
    String? error,
  }) {
    return BleScanState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      error: error,
    );
  }
}

/// BLE Scanner state notifier
class BleScannerNotifier extends StateNotifier<BleScanState> {
  BleScannerNotifier() : super(const BleScanState());

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  /// Request necessary Bluetooth permissions
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Start scanning for FTMS devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (state.isScanning) return;

    // Request permissions first
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      state = state.copyWith(
        error: 'Bluetooth permissions not granted',
        isScanning: false,
      );
      return;
    }

    // Check if Bluetooth is on
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
      // Start scanning for FTMS devices
      await FlutterBluePlus.startScan(
        withServices: [FtmsConstants.serviceUuid],
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final devices = results
            .where((r) => r.device.platformName.isNotEmpty)
            .map((r) => FtmsDevice.fromScanResult(r))
            .toList();

        // Sort by signal strength
        devices.sort((a, b) => b.rssi.compareTo(a.rssi));

        state = state.copyWith(devices: devices);
      });

      // Auto-stop after timeout
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

/// Connection state
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  requestingControl,
  ready,
  reconnecting,
  error,
}

/// BLE Connection state
class BleConnectionState {
  const BleConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.connectedDevice,
    this.bleDevice,
    this.error,
  });

  final ConnectionStatus status;
  final FtmsDevice? connectedDevice;
  final BluetoothDevice? bleDevice;
  final String? error;

  bool get isConnected =>
      status == ConnectionStatus.connected ||
      status == ConnectionStatus.requestingControl ||
      status == ConnectionStatus.ready;

  BleConnectionState copyWith({
    ConnectionStatus? status,
    FtmsDevice? connectedDevice,
    BluetoothDevice? bleDevice,
    String? error,
  }) {
    return BleConnectionState(
      status: status ?? this.status,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      bleDevice: bleDevice ?? this.bleDevice,
      error: error,
    );
  }
}

/// BLE Connection state notifier
class BleConnectionNotifier extends StateNotifier<BleConnectionState> {
  BleConnectionNotifier() : super(const BleConnectionState());

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  List<BluetoothService>? _services;

  /// Get discovered services
  List<BluetoothService>? get services => _services;

  /// Get FTMS service
  BluetoothService? get ftmsService {
    return _services?.firstWhere(
      (s) => s.uuid == FtmsConstants.serviceUuid,
      orElse: () => throw Exception('FTMS service not found'),
    );
  }

  /// Connect to a device
  Future<void> connect(FtmsDevice device) async {
    if (state.isConnected) {
      await disconnect();
    }

    state = state.copyWith(
      status: ConnectionStatus.connecting,
      connectedDevice: device,
      error: null,
    );

    try {
      final bleDevice = BluetoothDevice.fromId(device.id);

      // Listen for connection state changes
      _connectionSubscription = bleDevice.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Connect with timeout
      await bleDevice.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      state = state.copyWith(
        status: ConnectionStatus.connected,
        bleDevice: bleDevice,
      );

      // Discover services
      _services = await bleDevice.discoverServices();

      // Verify FTMS service exists
      final hasFtms = _services!.any((s) => s.uuid == FtmsConstants.serviceUuid);
      if (!hasFtms) {
        throw Exception('Device does not support FTMS');
      }

      state = state.copyWith(status: ConnectionStatus.ready);
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        error: 'Connection failed: $e',
      );
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (state.bleDevice != null) {
      await state.bleDevice!.disconnect();
    }

    _services = null;
    state = const BleConnectionState();
  }

  void _handleDisconnection() {
    if (state.status == ConnectionStatus.ready ||
        state.status == ConnectionStatus.connected) {
      // Unexpected disconnection - could implement reconnection here
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        error: 'Connection lost',
      );
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
