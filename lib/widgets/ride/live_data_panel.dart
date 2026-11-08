import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/ftms_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/control/trainer_control_provider.dart';
import '../../features/ftms/ftms_provider.dart';
import '../../features/heart_rate/hr_monitor_provider.dart';
import '../../features/settings/user_settings_provider.dart';
import 'ride_format.dart';
import 'trainer_status.dart';

Color zoneColor(PowerZone zone) => switch (zone) {
      PowerZone.recovery => AppColors.zoneRecovery,
      PowerZone.endurance => AppColors.zoneEndurance,
      PowerZone.tempo => AppColors.zoneTempo,
      PowerZone.threshold => AppColors.zoneThreshold,
      PowerZone.vo2max => AppColors.zoneVo2max,
      PowerZone.anaerobic => AppColors.zoneAnaerobic,
    };

String zoneLabel(PowerZone zone) => switch (zone) {
      PowerZone.recovery => 'Récupération',
      PowerZone.endurance => 'Endurance',
      PowerZone.tempo => 'Tempo',
      PowerZone.threshold => 'Seuil',
      PowerZone.vo2max => 'PMA',
      PowerZone.anaerobic => 'Anaérobie',
    };

/// What the rider produces: power (large), zone, ERG target, cadence, speed,
/// heart rate. Shows "--" when there is no data, never a stale value.
class LiveDataPanel extends ConsumerWidget {
  const LiveDataPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final telemetry = ref.watch(currentTelemetryProvider);
    final hrMonitor = ref.watch(hrConnectionProvider);
    final ftp = ref.watch(userSettingsProvider).valueOrNull?.ftp ?? 200;
    final link = ref.watch(trainerLinkProvider).link;
    final mode = ref.watch(trainerControlProvider.select((s) => s.mode));
    final target =
        ref.watch(trainerControlProvider.select((s) => s.effectiveTargetPower));

    final power = telemetry.instantPower;
    final zone = power == null ? null : PowerZone.fromPowerAndFtp(power, ftp);
    final color = zone == null ? AppColors.textTertiary : zoneColor(zone);
    final heartRate = hrMonitor.isConnected
        ? hrMonitor.currentHeartRate
        : telemetry.heartRate;

    final String? notice = switch (link) {
      TrainerLink.connected when !telemetry.hasData =>
        'En attente des données · pédalez pour réveiller le home trainer',
      TrainerLink.connected => null,
      TrainerLink.preparing ||
      TrainerLink.connecting ||
      TrainerLink.reconnecting =>
        'Connexion au home trainer…',
      _ =>
        'Home trainer non connecté · les données s\'afficheront à la connexion',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                      child: Text(
                        notice,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  Semantics(
                    label: power == null
                        ? 'Puissance : pas de donnée'
                        : 'Puissance : $power watts',
                    excludeSemantics: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            power?.toString() ?? '--',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 104,
                              height: 1.0,
                              color: power == null
                                  ? AppColors.textTertiary
                                  : color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'W',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (zone != null)
                    _Pill(
                      text: 'Z${zone.index + 1} · ${zoneLabel(zone)} · '
                          '${(power! / ftp * 100).round()} % FTP',
                      color: color,
                    )
                  else
                    const SizedBox(height: 26),
                  if (mode == ControlMode.power) ...[
                    const SizedBox(height: 8),
                    _TargetLine(target: target, power: power),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            icon: Icons.sync,
                            label: 'Cadence',
                            value: telemetry.instantCadence?.round().toString(),
                            unit: 'rpm',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Icons.speed,
                            label: 'Vitesse',
                            value: telemetry.instantSpeed == null
                                ? null
                                : formatDecimal(telemetry.instantSpeed!),
                            unit: 'km/h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Icons.favorite,
                            iconColor: AppColors.error,
                            label: 'Cardio',
                            value: heartRate?.toString(),
                            unit: 'bpm',
                            // No heart rate: offer to pair a monitor.
                            action: heartRate == null && !hrMonitor.isConnected
                                ? 'Connecter'
                                : null,
                            onTap: () => context.push('/hr-monitor'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TargetLine extends StatelessWidget {
  const _TargetLine({required this.target, required this.power});

  final int target;
  final int? power;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = power;
    final delta = p == null ? null : p - target;
    Color deltaColor = AppColors.textSecondary;
    if (delta != null && target > 0) {
      final ratio = delta.abs() / target;
      deltaColor = ratio <= 0.05
          ? AppColors.success
          : ratio <= 0.15
              ? AppColors.warning
              : AppColors.error;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            target > 0 ? 'Cible $target W' : 'Cible : roue libre',
            style: theme.textTheme.titleMedium,
          ),
          if (delta != null && target > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${formatSigned(delta)} W',
              style: theme.textTheme.titleMedium?.copyWith(color: deltaColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.iconColor,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  final Color? iconColor;

  /// Shown instead of the value when there is none (e.g. "Connecter").
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAction = value == null && action != null;
    return Semantics(
      button: onTap != null,
      label: '$label : ${value ?? (action ?? 'pas de donnée')} '
          '${value == null ? '' : unit}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 13, color: iconColor ?? AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (showAction)
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(
                        action!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value ?? '--',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: value == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(unit, style: theme.textTheme.labelSmall),
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
