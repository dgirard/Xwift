import 'package:flutter/material.dart';

import '../core/constants/ftms_constants.dart';
import '../core/theme/app_colors.dart';

class PowerDisplay extends StatelessWidget {
  const PowerDisplay({
    super.key,
    required this.watts,
    required this.zone,
    required this.ftp,
  });

  final int watts;
  final PowerZone zone;
  final int ftp;

  Color get _zoneColor => switch (zone) {
        PowerZone.recovery => AppColors.zoneRecovery,
        PowerZone.endurance => AppColors.zoneEndurance,
        PowerZone.tempo => AppColors.zoneTempo,
        PowerZone.threshold => AppColors.zoneThreshold,
        PowerZone.vo2max => AppColors.zoneVo2max,
        PowerZone.anaerobic => AppColors.zoneAnaerobic,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Zone indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _zoneColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _zoneColor.withOpacity(0.5)),
          ),
          child: Text(
            'Zone ${zone.index + 1}: ${zone.name}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _zoneColor,
                ),
          ),
        ),
        const SizedBox(height: 8),

        // Power value
        Text(
          '$watts',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: _zoneColor,
                fontWeight: FontWeight.w700,
                fontSize: 96,
                height: 1.0,
              ),
        ),

        // Unit
        Text(
          'watts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),

        const SizedBox(height: 16),

        // FTP percentage
        Text(
          '${ftp > 0 ? (watts / ftp * 100).round() : 0}% FTP',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
      ],
    );
  }
}
