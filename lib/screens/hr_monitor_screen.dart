import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/heart_rate/hr_monitor_provider.dart';
import '../features/settings/user_settings_provider.dart';

class HrMonitorScreen extends ConsumerStatefulWidget {
  const HrMonitorScreen({super.key});

  @override
  ConsumerState<HrMonitorScreen> createState() => _HrMonitorScreenState();
}

class _HrMonitorScreenState extends ConsumerState<HrMonitorScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hrScannerProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    // Stop scanning when leaving
    ref.read(hrScannerProvider.notifier).stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(hrScannerProvider);
    final connectionState = ref.watch(hrConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Moniteur Cardiaque'),
        actions: [
          if (connectionState.isConnected)
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: () => ref.read(hrConnectionProvider.notifier).disconnect(),
              tooltip: 'Deconnecter',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connected device status
          if (connectionState.isConnected && connectionState.connectedDevice != null)
            _ConnectedDeviceCard(
              device: connectionState.connectedDevice!,
              heartRate: connectionState.currentHeartRate,
              onDisconnect: () => ref.read(hrConnectionProvider.notifier).disconnect(),
            ),

          // Error message
          if (scanState.error != null || connectionState.error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scanState.error ?? connectionState.error ?? '',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ),
            ),

          // Scanning indicator
          if (scanState.isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Recherche en cours...'),
                ],
              ),
            ),

          // Connecting indicator
          if (connectionState.isConnecting)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Connexion a ${connectionState.connectedDevice?.name}...'),
                ],
              ),
            ),

          // Device list
          if (!connectionState.isConnected)
            Expanded(
              child: scanState.devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.watch_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            scanState.isScanning
                                ? 'Recherche de moniteurs cardiaques...'
                                : 'Aucun moniteur trouve',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          if (!scanState.isScanning)
                            FilledButton.icon(
                              onPressed: () => ref.read(hrScannerProvider.notifier).startScan(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Relancer la recherche'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: scanState.devices.length,
                      itemBuilder: (context, index) {
                        final device = scanState.devices[index];
                        return _DeviceTile(
                          device: device,
                          onTap: () => _connectToDevice(device),
                        );
                      },
                    ),
            ),

          // Scan button
          if (!connectionState.isConnected && !scanState.isScanning && !connectionState.isConnecting)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref.read(hrScannerProvider.notifier).startScan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Rechercher'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(HrMonitorDevice device) async {
    await ref.read(hrScannerProvider.notifier).stopScan();
    await ref.read(hrConnectionProvider.notifier).connect(device);

    // Save the last connected device
    final settings = ref.read(userSettingsProvider).valueOrNull;
    if (settings != null) {
      // Note: We'd need to add lastHrMonitorId/Name to UserSettings
      // For now, just connect
    }
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  const _ConnectedDeviceCard({
    required this.device,
    required this.heartRate,
    required this.onDisconnect,
  });

  final HrMonitorDevice device;
  final int? heartRate;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.watch, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Connecte',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red.shade300),
                onPressed: onDisconnect,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Heart rate display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  size: 48,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 16),
                Text(
                  heartRate != null ? '$heartRate' : '--',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BPM',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red.shade400,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onTap,
  });

  final HrMonitorDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.watch, color: AppColors.primary),
        ),
        title: Text(device.name),
        subtitle: Text('Signal: ${_rssiToQuality(device.rssi)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _rssiToQuality(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Bon';
    if (rssi >= -70) return 'Moyen';
    return 'Faible';
  }
}
