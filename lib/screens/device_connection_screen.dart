import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/bluetooth/ble_provider.dart';
import '../models/ftms_device.dart';

class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bleScannerProvider.notifier).startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(bleScannerProvider);
    final connectionState = ref.watch(bleConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion Appareil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
              _showHelpDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scan animation area
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _ScanAnimation(isScanning: scanState.isScanning),
                const SizedBox(height: 24),
                Text(
                  scanState.isScanning
                      ? 'Recherche d\'appareils...'
                      : 'Recherche terminee',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Assurez-vous que votre Zwift Ride est\nallume et pret a etre couple.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Error message
          if (scanState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scanState.error!,
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Devices list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'APPAREILS DETECTES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                      ),
                ),
                const Spacer(),
                if (scanState.devices.isNotEmpty)
                  Text(
                    '${scanState.devices.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Devices list
          Expanded(
            child: scanState.devices.isEmpty
                ? Center(
                    child: scanState.isScanning
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun appareil trouve',
                                style:
                                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                              ),
                            ],
                          ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: scanState.devices.length,
                    itemBuilder: (context, index) {
                      final device = scanState.devices[index];
                      final isConnecting =
                          connectionState.status == ConnectionStatus.connecting &&
                              connectionState.connectedDevice?.id == device.id;
                      final isConnected =
                          connectionState.status == ConnectionStatus.ready &&
                              connectionState.connectedDevice?.id == device.id;

                      return _DeviceListTile(
                        device: device,
                        isConnecting: isConnecting,
                        isConnected: isConnected,
                        onConnect: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),

          // Troubleshooting link
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () => _showHelpDialog(context),
              icon: Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
              label: Text(
                'Problemes de connexion ?',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),

          // Scan again button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: scanState.isScanning
                    ? null
                    : () => ref.read(bleScannerProvider.notifier).startScan(),
                icon: Icon(
                  scanState.isScanning ? Icons.hourglass_empty : Icons.refresh,
                ),
                label: Text(
                  scanState.isScanning ? 'Recherche en cours...' : 'Scanner a nouveau',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(FtmsDevice device) async {
    await ref.read(bleConnectionProvider.notifier).connect(device);

    final state = ref.read(bleConnectionProvider);
    if (state.status == ConnectionStatus.ready && mounted) {
      context.go('/ride');
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aide a la connexion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(
              number: '1',
              text: 'Verifiez que le Bluetooth est active sur votre telephone',
            ),
            _HelpItem(
              number: '2',
              text: 'Assurez-vous que votre trainer est allume',
            ),
            _HelpItem(
              number: '3',
              text: 'Fermez les autres applications utilisant le Bluetooth',
            ),
            _HelpItem(
              number: '4',
              text: 'Rapprochez-vous de votre trainer',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

class _ScanAnimation extends StatefulWidget {
  const _ScanAnimation({required this.isScanning});

  final bool isScanning;

  @override
  State<_ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<_ScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_ScanAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isScanning)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 100 * _controller.value,
                  height: 100 * _controller.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(1 - _controller.value),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(
              Icons.bluetooth,
              color: widget.isScanning ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  const _DeviceListTile({
    required this.device,
    required this.isConnecting,
    required this.isConnected,
    required this.onConnect,
  });

  final FtmsDevice device;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final signalColor = switch (device.signalQuality) {
      SignalQuality.excellent => AppColors.signalExcellent,
      SignalQuality.good => AppColors.signalGood,
      SignalQuality.fair => AppColors.signalFair,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.surfaceBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.pedal_bike,
            color: isConnected ? AppColors.success : AppColors.primary,
          ),
        ),
        title: Text(
          device.name,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 12, color: signalColor),
            const SizedBox(width: 4),
            Text(
              device.signalQuality.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: signalColor,
                  ),
            ),
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isConnected
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Connecte',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onConnect,
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Connecter'),
                  ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
