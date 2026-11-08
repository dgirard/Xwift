import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/ftms_constants.dart';
import '../../models/ftms_device.dart';
import '../../models/user_settings.dart';
import '../settings/user_settings_provider.dart';

void _log(String message) {
  if (kDebugMode) debugPrint('[BLE] $message');
}

/// Bluetooth adapter state provider
final bluetoothAdapterStateProvider =
    StreamProvider<BluetoothAdapterState>((ref) {
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
  return BleConnectionNotifier(ref);
});

/// Connected device
final connectedDeviceProvider = Provider<FtmsDevice?>((ref) {
  return ref.watch(bleConnectionProvider).connectedDevice;
});

/// Waits until the adapter state is known and tells whether Bluetooth is on.
Future<bool> isBluetoothOn() async {
  try {
    final adapterState = await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown)
        .timeout(const Duration(seconds: 3));
    return adapterState == BluetoothAdapterState.on;
  } catch (_) {
    return true; // Unknown: let the Bluetooth stack report the real error.
  }
}

/// Why a scan could not run.
enum ScanIssue {
  none,
  bluetoothOff,
  permissionDenied,
  permissionBlocked,
  failed
}

/// BLE Scan state
class BleScanState {
  const BleScanState({
    this.isScanning = false,
    this.hasScanned = false,
    this.devices = const [],
    this.issue = ScanIssue.none,
    this.error,
  });

  final bool isScanning;

  /// At least one scan has finished (distinguishes "searching" from "none found").
  final bool hasScanned;
  final List<FtmsDevice> devices;
  final ScanIssue issue;
  final String? error;

  BleScanState copyWith({
    bool? isScanning,
    bool? hasScanned,
    List<FtmsDevice>? devices,
    ScanIssue? issue,
    String? error,
  }) {
    return BleScanState(
      isScanning: isScanning ?? this.isScanning,
      hasScanned: hasScanned ?? this.hasScanned,
      devices: devices ?? this.devices,
      issue: issue ?? this.issue,
      error: error,
    );
  }
}

/// Scans for FTMS trainers.
class BleScannerNotifier extends StateNotifier<BleScanState> {
  BleScannerNotifier() : super(const BleScanState());

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  int _generation = 0;

  /// Requests the Bluetooth permissions. Returns the resulting issue.
  Future<ScanIssue> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses.values.every((s) => s.isGranted)) return ScanIssue.none;
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return ScanIssue.permissionBlocked;
    }
    return ScanIssue.permissionDenied;
  }

  /// Start scanning for FTMS devices
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (state.isScanning) return;
    final generation = ++_generation;

    final permissionIssue = await requestPermissions();
    if (!mounted || generation != _generation) return;
    if (permissionIssue != ScanIssue.none) {
      state = state.copyWith(issue: permissionIssue, isScanning: false);
      return;
    }
    if (!await isBluetoothOn()) {
      if (mounted) {
        state =
            state.copyWith(issue: ScanIssue.bluetoothOff, isScanning: false);
      }
      return;
    }
    if (!mounted || generation != _generation) return;

    state =
        state.copyWith(isScanning: true, devices: [], issue: ScanIssue.none);
    await _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (!mounted || generation != _generation) return;
      final devices = results.map(FtmsDevice.fromScanResult).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      state = state.copyWith(devices: devices);
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [FtmsConstants.serviceUuid],
        timeout: timeout,
      );
      // startScan returns once started; wait for the end of the scan.
      await FlutterBluePlus.isScanning
          .firstWhere((scanning) => !scanning)
          .timeout(timeout + const Duration(seconds: 5));
    } catch (e) {
      _log('scan failed: $e');
      if (mounted && generation == _generation) {
        state = state.copyWith(issue: ScanIssue.failed, error: '$e');
      }
    }
    if (mounted && generation == _generation) {
      state = state.copyWith(isScanning: false, hasScanned: true);
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    _generation++;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    _generation++;
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    super.dispose();
  }
}

/// Connection state
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
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
    this.reconnectAttempt = 0,
    this.error,
  });

  final ConnectionStatus status;

  /// Device connected, being connected, or last connected (after a failure).
  final FtmsDevice? connectedDevice;
  final BluetoothDevice? bleDevice;
  final int reconnectAttempt;
  final String? error;

  bool get isConnected =>
      status == ConnectionStatus.connected || status == ConnectionStatus.ready;

  bool get isReady => status == ConnectionStatus.ready;

  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.connected ||
      status == ConnectionStatus.reconnecting;

  BleConnectionState copyWith({
    ConnectionStatus? status,
    FtmsDevice? connectedDevice,
    BluetoothDevice? bleDevice,
    int? reconnectAttempt,
    String? error,
  }) {
    return BleConnectionState(
      status: status ?? this.status,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      bleDevice: bleDevice ?? this.bleDevice,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      error: error,
    );
  }
}

/// Manages the link with the trainer: connection, remembered device and
/// automatic reconnection when the link drops.
class BleConnectionNotifier extends StateNotifier<BleConnectionState> {
  BleConnectionNotifier([this._ref]) : super(const BleConnectionState());

  /// Delays between automatic reconnection attempts.
  static const reconnectDelays = [1, 2, 4, 8, 15, 30];

  final Ref? _ref;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  List<BluetoothService>? _services;
  Timer? _reconnectTimer;
  int _generation = 0;
  bool _autoConnectTried = false;

  /// Get discovered services
  List<BluetoothService>? get services => _services;

  /// Connects to [device], replacing any current connection.
  Future<bool> connect(FtmsDevice device) async {
    _cancelReconnect();
    final generation = ++_generation;
    await _teardown();
    if (!mounted || generation != _generation) return false;
    return _connect(device, generation, ConnectionStatus.connecting,
        reportErrors: true);
  }

  /// Reconnects to the last trainer used, if any.
  Future<bool> connectToLast() async {
    final last = await lastDevice();
    if (last == null || !mounted) return false;
    return connect(last);
  }

  /// Reconnects automatically to the last trainer, once per app session.
  Future<void> autoConnect() async {
    if (_autoConnectTried || state.isConnected || state.isBusy) return;
    _autoConnectTried = true;
    final last = await lastDevice();
    if (last == null || !mounted) return;
    if (!await isBluetoothOn()) {
      if (mounted) {
        state = BleConnectionState(
          status: ConnectionStatus.disconnected,
          connectedDevice: last,
          error: 'Le Bluetooth est désactivé.',
        );
      }
      return;
    }
    await connect(last);
  }

  /// The last trainer used, from the settings.
  Future<FtmsDevice?> lastDevice() async {
    final settings = _ref?.read(userSettingsProvider).valueOrNull ??
        await UserSettings.load();
    final id = settings.lastDeviceId;
    if (id == null || id.isEmpty) return null;
    return FtmsDevice(
      id: id,
      name: settings.lastDeviceName ?? 'Home trainer',
      rssi: 0,
    );
  }

  Future<bool> _connect(
    FtmsDevice device,
    int generation,
    ConnectionStatus status, {
    required bool reportErrors,
    int reconnectAttempt = 0,
  }) async {
    state = BleConnectionState(
      status: status,
      connectedDevice: device,
      reconnectAttempt: reconnectAttempt,
    );
    final bleDevice = BluetoothDevice.fromId(device.id);
    try {
      if (!await isBluetoothOn()) {
        throw const _ConnectionError('Le Bluetooth est désactivé.');
      }
      await bleDevice.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
      if (!mounted || generation != _generation) return false;
      state = state.copyWith(
          status: ConnectionStatus.connected, bleDevice: bleDevice);

      final services = await bleDevice.discoverServices();
      if (!mounted || generation != _generation) return false;
      if (!services.any((s) => s.uuid == FtmsConstants.serviceUuid)) {
        throw const _ConnectionError(
            "Cet appareil n'est pas un home trainer compatible (FTMS).");
      }
      _services = services;
      _connectionSubscription = bleDevice.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _handleDisconnection(generation);
        }
      });
      state =
          state.copyWith(status: ConnectionStatus.ready, reconnectAttempt: 0);
      _ref?.read(userSettingsProvider.notifier).updateLastDevice(
            device.id,
            device.name,
          );
      _log('ready: ${device.name}');
      return true;
    } catch (e) {
      _log('connection to ${device.name} failed: $e');
      // Never leave a half-open link behind.
      try {
        await bleDevice.disconnect();
      } catch (_) {}
      if (!mounted || generation != _generation) return false;
      _services = null;
      if (reportErrors) {
        state = BleConnectionState(
          status: ConnectionStatus.error,
          connectedDevice: device,
          error: _describe(e),
        );
      }
      return false;
    }
  }

  void _handleDisconnection(int generation) {
    if (!mounted || generation != _generation) return;
    final device = state.connectedDevice;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _services = null;
    _log('link lost with ${device?.name}');
    if (device == null) {
      state = const BleConnectionState();
      return;
    }
    _scheduleReconnect(device, generation, 1);
  }

  void _scheduleReconnect(FtmsDevice device, int generation, int attempt) {
    if (!mounted || generation != _generation) return;
    if (attempt > reconnectDelays.length) {
      state = BleConnectionState(
        status: ConnectionStatus.disconnected,
        connectedDevice: device,
        error: 'Connexion perdue avec ${device.name}.',
      );
      return;
    }
    state = BleConnectionState(
      status: ConnectionStatus.reconnecting,
      connectedDevice: device,
      reconnectAttempt: attempt,
    );
    _reconnectTimer =
        Timer(Duration(seconds: reconnectDelays[attempt - 1]), () async {
      if (!mounted || generation != _generation) return;
      final ok = await _connect(
        device,
        generation,
        ConnectionStatus.reconnecting,
        reportErrors: false,
        reconnectAttempt: attempt,
      );
      if (!ok) _scheduleReconnect(device, generation, attempt + 1);
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _teardown() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _services = null;
    final device = state.bleDevice;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  /// Disconnects on user request (no automatic reconnection).
  Future<void> disconnect() async {
    _cancelReconnect();
    _generation++;
    await _teardown();
    if (mounted) state = const BleConnectionState();
  }

  String _describe(Object error) {
    if (error is _ConnectionError) return error.message;
    final text = '$error';
    if (text.contains('Timed out') || text.contains('timeout')) {
      return "Le home trainer ne répond pas. Vérifiez qu'il est allumé et "
          "qu'aucune autre application (Zwift…) n'y est connectée.";
    }
    return 'Connexion impossible : $text';
  }

  @override
  void dispose() {
    _generation++;
    _cancelReconnect();
    _connectionSubscription?.cancel();
    final device = state.bleDevice;
    if (device != null) device.disconnect().catchError((_) {});
    super.dispose();
  }
}

class _ConnectionError implements Exception {
  const _ConnectionError(this.message);
  final String message;
}
