import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Header with logo and skip
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pedal_bike,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Xwift',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/connect'),
                      child: Text(
                        'Passer',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Hero image placeholder
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bike,
                      size: 80,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Zwift Ride',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Title and subtitle
              Text(
                'Maitrisez votre',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(
                'Zwift Ride',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Controlez precis, shifting virtuel et donnees\nen temps reel. Connectez-vous et roulez\nplus fort.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 40),

              // Feature icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FeatureIcon(
                    icon: Icons.speed,
                    label: 'Virtual\nShifting',
                  ),
                  _FeatureIcon(
                    icon: Icons.bar_chart,
                    label: 'Telemetrie\nLive',
                  ),
                  _FeatureIcon(
                    icon: Icons.sync,
                    label: 'Sync\nStrava',
                  ),
                ],
              ),

              const Spacer(),

              // Connect button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/connect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text('Connecter mon Ride'),
                ),
              ),

              const SizedBox(height: 16),

              // Quick access buttons
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessButton(
                      icon: Icons.history,
                      label: 'Historique',
                      onTap: () => context.push('/profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessButton(
                      icon: Icons.fitness_center,
                      label: 'Workouts',
                      onTap: () => context.push('/workouts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessButton(
                      icon: Icons.upload_file,
                      label: 'Exporter',
                      onTap: () => context.push('/settings/export'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Terms
              Text(
                'En continuant, vous acceptez nos Conditions d\'utilisation.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
