import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class GearSelector extends StatelessWidget {
  const GearSelector({
    super.key,
    required this.currentGear,
    required this.totalGears,
    required this.onGearChanged,
  });

  final int currentGear;
  final int totalGears;
  final ValueChanged<int> onGearChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Down shift button
          _GearButton(
            icon: Icons.remove,
            onPressed: currentGear > 1
                ? () => onGearChanged(currentGear - 1)
                : null,
          ),

          // Current gear display
          Column(
            children: [
              Text(
                '$currentGear',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '/ $totalGears',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Gear',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),

          // Up shift button
          _GearButton(
            icon: Icons.add,
            onPressed: currentGear < totalGears
                ? () => onGearChanged(currentGear + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _GearButton extends StatelessWidget {
  const _GearButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed != null ? AppColors.surfaceLight : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onPressed != null
                  ? AppColors.primary
                  : AppColors.surfaceBorder,
            ),
          ),
          child: Icon(
            icon,
            color: onPressed != null ? AppColors.primary : AppColors.textTertiary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
