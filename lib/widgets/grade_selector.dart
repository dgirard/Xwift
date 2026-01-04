import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class GradeSelector extends StatelessWidget {
  const GradeSelector({
    super.key,
    required this.currentGrade,
    required this.onGradeChanged,
    this.minGrade = -10.0,
    this.maxGrade = 10.0,
    this.step = 0.5,
  });

  final double currentGrade;
  final ValueChanged<double> onGradeChanged;
  final double minGrade;
  final double maxGrade;
  final double step;

  @override
  Widget build(BuildContext context) {
    final canDecrease = currentGrade > minGrade;
    final canIncrease = currentGrade < maxGrade;

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
          // Decrease grade (easier / downhill)
          _GradeButton(
            icon: Icons.remove,
            onPressed: canDecrease
                ? () => onGradeChanged((currentGrade - step).clamp(minGrade, maxGrade))
                : null,
          ),

          // Current grade display
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatGrade(currentGrade),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _gradeColor(currentGrade),
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _gradeColor(currentGrade),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gradeIcon(currentGrade),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _gradeLabel(currentGrade),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),

          // Increase grade (harder / uphill)
          _GradeButton(
            icon: Icons.add,
            onPressed: canIncrease
                ? () => onGradeChanged((currentGrade + step).clamp(minGrade, maxGrade))
                : null,
          ),
        ],
      ),
    );
  }

  String _formatGrade(double grade) {
    if (grade >= 0) {
      return '+${grade.toStringAsFixed(1)}';
    }
    return grade.toStringAsFixed(1);
  }

  Color _gradeColor(double grade) {
    if (grade > 3) return Colors.red;
    if (grade > 0) return Colors.orange;
    if (grade < -3) return Colors.green;
    if (grade < 0) return Colors.lightGreen;
    return AppColors.textPrimary;
  }

  IconData _gradeIcon(double grade) {
    if (grade > 0) return Icons.trending_up;
    if (grade < 0) return Icons.trending_down;
    return Icons.trending_flat;
  }

  String _gradeLabel(double grade) {
    if (grade > 5) return 'Montee raide';
    if (grade > 2) return 'Montee';
    if (grade > 0) return 'Faux-plat montant';
    if (grade < -5) return 'Descente raide';
    if (grade < -2) return 'Descente';
    if (grade < 0) return 'Faux-plat descendant';
    return 'Plat';
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
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
