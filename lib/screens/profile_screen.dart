import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/database/database_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/settings/user_settings_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final userSettingsAsync = ref.watch(userSettingsProvider);
    final rideHistoryAsync = ref.watch(rideHistoryProvider);
    final rideStatsAsync = ref.watch(rideStatsProvider);

    final userName = userSettingsAsync.valueOrNull?.userName ?? 'Cycliste';
    final ftp = userSettingsAsync.valueOrNull?.ftp ?? 200;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Show settings
              _showSettings();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Badge(label: 'STRAVA', color: Colors.orange),
                      const SizedBox(width: 8),
                      _Badge(label: 'RIDE', color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Stats grid
            rideStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e'),
              data: (stats) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: stats.formattedDistance,
                          unit: '',
                          label: 'DISTANCE',
                          icon: Icons.straighten,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          value: '${stats.totalRides}',
                          unit: '',
                          label: 'SORTIES',
                          icon: Icons.directions_bike,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: stats.formattedDuration,
                          unit: '',
                          label: 'TEMPS',
                          icon: Icons.timer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          value: '$ftp',
                          unit: 'W',
                          label: 'FTP',
                          icon: Icons.bolt,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Activity history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historique des Activites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => context.push('/settings/export'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            rideHistoryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e'),
              data: (rides) {
                if (rides.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Aucune sortie enregistree',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                // Show last 5 rides
                final recentRides = rides.take(5).toList();
                return Column(
                  children: recentRides.map((ride) => _RideTile(
                    ride: ride,
                    onDelete: () => _confirmDeleteRide(ride),
                  )).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Sync status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Derniere synchronisation',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'il y a 5 min',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    final userSettings = ref.read(userSettingsProvider).valueOrNull;
    final ftp = userSettings?.ftp ?? 200;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Modifier le nom'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditNameDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Configurer FTP'),
              subtitle: Text('$ftp W'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditFtpDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.watch),
              title: const Text('Moniteur cardiaque'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/hr-monitor');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Appareils connectes'),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/connect');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final currentName = ref.read(userSettingsProvider).valueOrNull?.userName ?? '';
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom',
            hintText: 'Entrez votre nom',
          ),
          maxLength: 30,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userSettingsProvider.notifier).updateUserName(newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showEditFtpDialog() {
    final currentFtp = ref.read(userSettingsProvider).valueOrNull?.ftp ?? 200;
    final controller = TextEditingController(text: '$currentFtp');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurer FTP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'FTP (watts)',
            hintText: 'Ex: 200',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final newFtp = int.tryParse(controller.text.trim());
              if (newFtp != null && newFtp > 0) {
                ref.read(userSettingsProvider.notifier).updateFtp(newFtp);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRide(RideSummary ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette sortie ?'),
        content: Text(
          'La sortie "${ride.workoutName ?? 'Sortie libre'}" du ${DateFormat('dd/MM/yyyy').format(ride.startTime)} sera definitivement supprimee.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(rideRepositoryProvider);
              await repo.deleteRide(ride.id);
              // Refresh the providers
              ref.invalidate(rideHistoryProvider);
              ref.invalidate(rideStatsProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sortie supprimee')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.icon,
  });

  final String value;
  final String unit;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride, required this.onDelete});

  final RideSummary ride;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final durationMinutes = ride.duration.inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.directions_bike, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.workoutName ?? 'Sortie libre',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${dateFormat.format(ride.startTime)} - $durationMinutes min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (ride.averagePower != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${ride.averagePower}W',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                Text(
                  'AVG',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
