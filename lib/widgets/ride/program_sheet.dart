import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/control/trainer_control_provider.dart';
import '../../features/settings/user_settings_provider.dart';
import '../../features/workout/builtin_workouts.dart';
import '../../models/workout_plan.dart';
import 'ride_format.dart';

/// Picker for ERG programs: the rider's imported workouts and ready-made ones.
class ProgramSheet extends ConsumerWidget {
  const ProgramSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ftp = ref.watch(userSettingsProvider).valueOrNull?.ftp ?? 200;
    final saved = ref.watch(savedWorkoutsProvider);
    final builtins = builtinWorkouts(ftp);

    void start(WorkoutPlan plan) {
      ref.read(trainerControlProvider.notifier).startProgram(plan);
      Navigator.pop(context);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Suivre un programme', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'La puissance suit les intervalles pendant l\'enregistrement de la sortie. '
            'Les puissances sont calculées sur votre FTP ($ftp W).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('MES ENTRAÎNEMENTS', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          ...saved.when(
            loading: () => [const LinearProgressIndicator()],
            error: (e, _) => [Text('Erreur : $e')],
            data: (plans) => plans.isEmpty
                ? [
                    Text(
                      'Aucun entraînement importé. Vous pouvez importer des '
                      'fichiers .zwo, .erg ou .mrc.',
                      style: theme.textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/workouts');
                        },
                        icon: const Icon(Icons.file_open_outlined, size: 18),
                        label: const Text('Importer un entraînement'),
                      ),
                    ),
                  ]
                : [
                    for (final plan in plans)
                      _ProgramTile(plan: plan, onTap: () => start(plan))
                  ],
          ),
          const SizedBox(height: 16),
          Text('EXEMPLES', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final plan in builtins)
            _ProgramTile(plan: plan, onTap: () => start(plan)),
        ],
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.plan, required this.onTap});

  final WorkoutPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPower = plan.intervals
        .map((i) => i.targetPower)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: AppColors.primaryLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${formatMinutes(plan.totalDuration)} · '
                        '${plan.intervals.length} intervalles · max $maxPower W'
                        '${plan.description != null ? ' · ${plan.description}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
