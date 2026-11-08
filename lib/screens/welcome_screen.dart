import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/ride/ride_session_provider.dart';
import '../widgets/ride/ride_format.dart';
import '../widgets/ride/trainer_status.dart';

/// Home screen. Riding is always possible, with or without a trainer.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ride = ref.watch(rideSessionProvider);
    final trainer = ref.watch(trainerLinkProvider);

    final String trainerText = switch (trainer.link) {
      TrainerLink.connected => 'Connecté à ${trainer.title}.',
      TrainerLink.offline ||
      TrainerLink.failed =>
        '${trainer.title} sera reconnecté automatiquement.',
      TrainerLink.none =>
        'Pas de home trainer ? Vous pouvez quand même rouler et enregistrer, '
            'et le connecter à tout moment.',
      _ => 'Connexion à ${trainer.title}…',
    };

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.pedal_bike,
                            color: AppColors.primary, size: 28),
                        const SizedBox(width: 8),
                        Text('Xwift', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Profil et réglages',
                          icon: const Icon(Icons.person_outline),
                          onPressed: () => context.push('/profile'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Icon(
                        Icons.directions_bike,
                        size: 64,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Votre home trainer,',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'simplement',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Réglez la pente, la puissance ou la résistance, suivez vos '
                      'données en direct et envoyez vos sorties sur Strava.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    if (ride.isActive) ...[
                      _OngoingRide(ride: ride),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/ride'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                            ride.isActive ? 'Revenir à la sortie' : 'Rouler'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trainerText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          trainer.link == TrainerLink.connected
                              ? '/connect'
                              : '/connect?next=ride',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.bluetooth),
                        label: Text(
                          trainer.link == TrainerLink.connected
                              ? 'Changer de home trainer'
                              : 'Connecter un home trainer',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAccessButton(
                            icon: Icons.history,
                            label: 'Mes sorties',
                            onTap: () => context.push('/settings/export'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAccessButton(
                            icon: Icons.list_alt,
                            label: 'Entraînements',
                            onTap: () => context.push('/workouts'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAccessButton(
                            icon: Icons.favorite_border,
                            label: 'Cardio',
                            onTap: () => context.push('/hr-monitor'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OngoingRide extends StatelessWidget {
  const _OngoingRide({required this.ride});

  final RideSessionState ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ride.isPaused ? AppColors.warning : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ride.isPaused ? Icons.pause_circle : Icons.fiber_manual_record,
              color: color),
          const SizedBox(width: 10),
          Text(
            ride.isPaused ? 'Sortie en pause' : 'Sortie en cours',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          Text(
            formatClock(ride.elapsed),
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
