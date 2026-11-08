import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../features/bluetooth/ble_provider.dart';
import '../features/settings/user_settings_provider.dart';
import '../models/ftms_device.dart';

/// Finds and connects the trainer. Opened with `?next=ride` it continues to
/// the ride screen; otherwise it returns where it was opened from.
class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key, this.continueToRide = false});

  final bool continueToRide;

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  String? _connectingId;
  late final BleScannerNotifier _scanner;

  @override
  void initState() {
    super.initState();
    _scanner = ref.read(bleScannerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanner.startScan();
    });
  }

  @override
  void dispose() {
    _scanner.stopScan();
    super.dispose();
  }

  Future<void> _connect(FtmsDevice device) async {
    setState(() => _connectingId = device.id);
    await _scanner.stopScan();
    final ok = await ref.read(bleConnectionProvider.notifier).connect(device);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) _continue();
  }

  /// Goes on to riding, or back to the previous screen.
  void _continue() {
    if (widget.continueToRide) {
      context.pushReplacement('/ride');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/ride');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scan = ref.watch(bleScannerProvider);
    final connection = ref.watch(bleConnectionProvider);
    final settings = ref.watch(userSettingsProvider).valueOrNull;
    final lastId = settings?.lastDeviceId;

    // Last used trainer first, then by signal strength.
    final devices = [...scan.devices]..sort((a, b) {
        if (a.id == lastId) return -1;
        if (b.id == lastId) return 1;
        return b.rssi.compareTo(a.rssi);
      });

    final failedDevice = connection.status == ConnectionStatus.error
        ? connection.connectedDevice
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: const Text('Home trainer'),
        actions: [
          IconButton(
            tooltip: 'Aide',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _Steps(scanning: scan.isScanning),
          const SizedBox(height: 16),
          if (scan.issue != ScanIssue.none) ...[
            _IssueCard(issue: scan.issue, error: scan.error),
            const SizedBox(height: 16),
          ],
          if (failedDevice != null && _connectingId == null) ...[
            _MessageCard(
              icon: Icons.error_outline,
              color: AppColors.error,
              title: 'Connexion à ${failedDevice.name} impossible',
              text: connection.error ?? '',
              actionLabel: 'Réessayer',
              onAction: () => _connect(failedDevice),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text('HOME TRAINERS À PROXIMITÉ',
                  style: theme.textTheme.labelSmall),
              const SizedBox(width: 8),
              if (scan.isScanning)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              if (!scan.isScanning && scan.issue == ScanIssue.none)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(bleScannerProvider.notifier).startScan(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Rechercher'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final device in devices) ...[
            _DeviceTile(
              device: device,
              lastUsed: device.id == lastId,
              connecting: _connectingId == device.id,
              connected: connection.isReady &&
                  connection.connectedDevice?.id == device.id,
              enabled: _connectingId == null,
              onTap: () => _connect(device),
            ),
            const SizedBox(height: 8),
          ],
          if (devices.isEmpty && scan.isScanning)
            _MessageCard(
              icon: Icons.bluetooth_searching,
              color: AppColors.primary,
              title: 'Recherche en cours…',
              text:
                  'Pédalez quelques tours : la plupart des home trainers ne se '
                  'signalent que lorsqu\'ils sont réveillés.',
            ),
          if (devices.isEmpty &&
              !scan.isScanning &&
              scan.hasScanned &&
              scan.issue == ScanIssue.none)
            _MessageCard(
              icon: Icons.search_off,
              color: AppColors.warning,
              title: 'Aucun home trainer trouvé',
              text: '• Le home trainer est-il branché et allumé ?\n'
                  '• Pédalez quelques tours pour le réveiller.\n'
                  '• Fermez Zwift ou toute autre app qui y est connectée.\n'
                  '• Rapprochez le téléphone du home trainer.',
              actionLabel: 'Relancer la recherche',
              onAction: () => ref.read(bleScannerProvider.notifier).startScan(),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _continue,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  connection.isReady
                      ? 'Continuer'
                      : 'Continuer sans home trainer',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vous pourrez le connecter plus tard depuis l\'écran de sortie.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aide à la connexion'),
        content: const Text(
          'Xwift se connecte aux home trainers compatibles Bluetooth FTMS '
          '(Zwift Hub et Zwift Ride, Wahoo KICKR, Tacx, Elite…).\n\n'
          '1. Allumez le home trainer et pédalez quelques tours.\n'
          '2. Activez le Bluetooth du téléphone.\n'
          '3. Fermez les autres applications connectées au home trainer : '
          'un home trainer n\'accepte qu\'un seul pilote à la fois.\n'
          '4. Touchez son nom dans la liste.\n\n'
          'Xwift se souvient du dernier home trainer et s\'y reconnecte '
          'tout seul à l\'ouverture de l\'écran de sortie.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris')),
        ],
      ),
    );
  }
}

/// The three steps, so that the rider knows what to do.
class _Steps extends StatelessWidget {
  const _Steps({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(String number, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(number,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryLight,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        step('1', 'Allumez le home trainer et pédalez quelques tours.'),
        step('2', 'Touchez son nom dans la liste ci-dessous.'),
        step('3',
            'C\'est tout : Xwift s\'y reconnectera tout seul la prochaine fois.'),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.lastUsed,
    required this.connecting,
    required this.connected,
    required this.enabled,
    required this.onTap,
  });

  final FtmsDevice device;
  final bool lastUsed;
  final bool connecting;
  final bool connected;
  final bool enabled;
  final VoidCallback onTap;

  int get _bars => device.rssi >= -60
      ? 3
      : device.rssi >= -78
          ? 2
          : 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      'Home trainer',
      if (lastUsed) 'dernier utilisé',
      if (_bars == 1) 'signal faible, rapprochez-vous',
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${device.name}, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled && !connected ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: lastUsed || connected
                    ? AppColors.primary
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pedal_bike,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _SignalBars(bars: _bars),
                const SizedBox(width: 14),
                if (connecting)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else if (connected)
                  const Icon(Icons.check_circle, color: AppColors.success)
                else
                  Text(
                    'Connecter',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: AppColors.primaryLight),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 3; i++)
          Container(
            width: 4,
            height: 5.0 + i * 4,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color:
                  i <= bars ? AppColors.textSecondary : AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class _IssueCard extends ConsumerWidget {
  const _IssueCard({required this.issue, this.error});

  final ScanIssue issue;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanner = ref.read(bleScannerProvider.notifier);
    return switch (issue) {
      ScanIssue.bluetoothOff => _MessageCard(
          icon: Icons.bluetooth_disabled,
          color: AppColors.warning,
          title: 'Le Bluetooth est désactivé',
          text: 'Activez-le pour trouver le home trainer.',
          actionLabel: 'Activer le Bluetooth',
          onAction: () async {
            try {
              await FlutterBluePlus.turnOn();
            } catch (_) {}
            await scanner.startScan();
          },
        ),
      ScanIssue.permissionDenied => _MessageCard(
          icon: Icons.lock_outline,
          color: AppColors.warning,
          title: 'Autorisation nécessaire',
          text: 'Xwift a besoin de l\'autorisation « Appareils à proximité » '
              'pour trouver le home trainer.',
          actionLabel: 'Autoriser',
          onAction: scanner.startScan,
        ),
      ScanIssue.permissionBlocked => _MessageCard(
          icon: Icons.lock_outline,
          color: AppColors.warning,
          title: 'Autorisation refusée',
          text: 'Autorisez « Appareils à proximité » pour Xwift dans les '
              'réglages du téléphone, puis revenez ici.',
          actionLabel: 'Ouvrir les réglages',
          onAction: openAppSettings,
        ),
      ScanIssue.failed => _MessageCard(
          icon: Icons.error_outline,
          color: AppColors.error,
          title: 'La recherche a échoué',
          text: error ?? '',
          actionLabel: 'Réessayer',
          onAction: scanner.startScan,
        ),
      ScanIssue.none => const SizedBox.shrink(),
    };
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
