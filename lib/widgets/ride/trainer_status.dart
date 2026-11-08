import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/bluetooth/ble_provider.dart';
import '../../features/control/trainer_control_provider.dart';
import '../../features/ftms/ftms_provider.dart';
import '../../features/settings/user_settings_provider.dart';
import '../../models/ftms_device.dart';

/// Link with the trainer, as understood by the rider.
enum TrainerLink {
  connected,
  preparing,
  connecting,
  reconnecting,
  failed,
  offline,
  none
}

class TrainerLinkInfo {
  const TrainerLinkInfo(this.link, this.device, this.attempt);

  final TrainerLink link;

  /// Connected, connecting or last used trainer.
  final FtmsDevice? device;
  final int attempt;

  String get title => device?.name ?? 'Aucun home trainer';

  String get subtitle => switch (link) {
        TrainerLink.connected => 'Connecté',
        TrainerLink.preparing => 'Préparation…',
        TrainerLink.connecting => 'Connexion…',
        TrainerLink.reconnecting =>
          'Reconnexion… ($attempt/${BleConnectionNotifier.reconnectDelays.length})',
        TrainerLink.failed => 'Échec · toucher pour réessayer',
        TrainerLink.offline => 'Toucher pour reconnecter',
        TrainerLink.none => 'Toucher pour connecter',
      };

  Color get color => switch (link) {
        TrainerLink.connected => AppColors.success,
        TrainerLink.preparing ||
        TrainerLink.connecting ||
        TrainerLink.reconnecting =>
          AppColors.warning,
        TrainerLink.failed => AppColors.error,
        TrainerLink.offline || TrainerLink.none => AppColors.textTertiary,
      };

  bool get busy =>
      link == TrainerLink.preparing ||
      link == TrainerLink.connecting ||
      link == TrainerLink.reconnecting;
}

final trainerLinkProvider = Provider<TrainerLinkInfo>((ref) {
  final ble = ref.watch(bleConnectionProvider);
  final ftmsReady = ref.watch(ftmsControlProvider.select((s) => s.isReady));
  final settings = ref.watch(userSettingsProvider).valueOrNull;
  final lastDevice = settings?.lastDeviceId == null
      ? null
      : FtmsDevice(
          id: settings!.lastDeviceId!,
          name: settings.lastDeviceName ?? 'Home trainer',
          rssi: 0,
        );
  final device = ble.connectedDevice ?? lastDevice;
  final link = switch (ble.status) {
    ConnectionStatus.ready =>
      ftmsReady ? TrainerLink.connected : TrainerLink.preparing,
    ConnectionStatus.connecting ||
    ConnectionStatus.connected =>
      TrainerLink.connecting,
    ConnectionStatus.reconnecting => TrainerLink.reconnecting,
    ConnectionStatus.error => TrainerLink.failed,
    ConnectionStatus.disconnected =>
      device == null ? TrainerLink.none : TrainerLink.offline,
  };
  return TrainerLinkInfo(link, device, ble.reconnectAttempt);
});

/// Compact trainer status shown in the app bar. One tap does the obvious
/// thing: reconnect the known trainer, find one, or show the details.
class TrainerStatusPill extends ConsumerWidget {
  const TrainerStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(trainerLinkProvider);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Home trainer : ${info.title}, ${info.subtitle}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onTrainerTap(context, ref),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: info.color.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (info.busy)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: info.color),
                  )
                else
                  Icon(
                    info.link == TrainerLink.connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 16,
                    color: info.color,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        info.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: info.link == TrainerLink.connected
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a tap on the trainer status does.
void onTrainerTap(BuildContext context, WidgetRef ref) {
  final info = ref.read(trainerLinkProvider);
  switch (info.link) {
    case TrainerLink.offline:
      ref.read(bleConnectionProvider.notifier).connect(info.device!);
    case TrainerLink.none:
      context.push('/connect');
    case TrainerLink.connected:
    case TrainerLink.preparing:
    case TrainerLink.connecting:
    case TrainerLink.reconnecting:
    case TrainerLink.failed:
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (_) => const TrainerSheet(),
      );
  }
}

/// Details of the trainer link: is data flowing, is control granted, what the
/// trainer supports, and the actions to fix or change the connection.
class TrainerSheet extends ConsumerStatefulWidget {
  const TrainerSheet({super.key});

  @override
  ConsumerState<TrainerSheet> createState() => _TrainerSheetState();
}

class _TrainerSheetState extends ConsumerState<TrainerSheet> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // "Last data N s ago" must keep counting even when nothing arrives.
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ref.watch(trainerLinkProvider);
    final ftms = ref.watch(ftmsControlProvider);
    final control = ref.watch(trainerControlProvider);
    final connected = info.link == TrainerLink.connected;

    final lastPacket = ftms.lastPacketAt;
    final silence =
        lastPacket == null ? null : DateTime.now().difference(lastPacket);
    final String dataText;
    final bool dataOk;
    if (!connected) {
      dataText = '—';
      dataOk = false;
    } else if (lastPacket == null) {
      dataText =
          'Aucune donnée reçue. Pédalez quelques tours pour réveiller le home trainer.';
      dataOk = false;
    } else if (silence! > const Duration(seconds: 3)) {
      dataText =
          'Plus de données depuis ${silence.inSeconds} s. Pédalez pour réveiller le home trainer.';
      dataOk = false;
    } else {
      dataText =
          'En direct · ${ftms.packetsPerSecond} message${ftms.packetsPerSecond > 1 ? 's' : ''} par seconde';
      dataOk = true;
    }

    final features = ftms.features;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pedal_bike, color: info.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.title, style: theme.textTheme.titleMedium),
                      Text(
                        info.link == TrainerLink.failed
                            ? (ref.watch(bleConnectionProvider).error ??
                                'Échec de la connexion')
                            : info.subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 16),
              _DiagnosticRow(
                icon: Icons.sensors,
                label: 'Données',
                value: dataText,
                ok: dataOk,
              ),
              _DiagnosticRow(
                icon: Icons.gamepad_outlined,
                label: 'Contrôle',
                value: ftms.hasControl
                    ? 'Obtenu : les réglages sont appliqués.'
                    : 'Non obtenu. Une autre application (Zwift…) pilote peut-être le home trainer.',
                ok: ftms.hasControl,
                action: ftms.hasControl
                    ? null
                    : TextButton(
                        onPressed: () =>
                            ref.read(trainerControlProvider.notifier).retry(),
                        child: const Text('Reprendre la main'),
                      ),
              ),
              _DiagnosticRow(
                icon: Icons.tune,
                label: 'Modes',
                value: features == null
                    ? 'Non annoncés par le home trainer.'
                    : [
                        if (features.supportsSimulation) 'Pente',
                        if (features.supportsTargetPower) 'Puissance',
                        if (features.supportsTargetResistance) 'Résistance',
                      ].join(' · '),
                ok: true,
              ),
              if (control.status == ApplyStatus.noResponse)
                _DiagnosticRow(
                  icon: Icons.warning_amber,
                  label: 'Commandes',
                  value: 'Le home trainer ne répond pas aux commandes.',
                  ok: false,
                ),
            ],
            const SizedBox(height: 16),
            if (info.link == TrainerLink.failed ||
                info.link == TrainerLink.offline)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ref
                        .read(bleConnectionProvider.notifier)
                        .connect(info.device!);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text('Reconnecter ${info.device?.name ?? ''}'.trim()),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/connect');
                    },
                    child: const Text('Autre appareil'),
                  ),
                ),
                if (connected || info.busy) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(bleConnectionProvider.notifier).disconnect();
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error),
                      child: Text(info.busy ? 'Annuler' : 'Déconnecter'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18, color: ok ? AppColors.success : AppColors.warning),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    )),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
