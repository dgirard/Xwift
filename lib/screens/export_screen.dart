import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/database/database_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/export/fit_exporter.dart';
import '../features/export/tcx_exporter.dart';
import '../features/strava/strava_provider.dart';

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(rideHistoryProvider);
    final stravaState = ref.watch(stravaConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Export'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(rideHistoryProvider);
              ref.read(stravaConnectionProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erreur: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(rideHistoryProvider),
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
        data: (rides) => Column(
          children: [
            // Strava connect banner
            _StravaBanner(stravaState: stravaState),

            // Export list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'ACTIVITES EXPORTABLES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${rides.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Export list
            Expanded(
              child: rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_bike_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune activite',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vos sessions sauvegardees apparaitront ici',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rides.length,
                      itemBuilder: (context, index) {
                        final ride = rides[index];
                        return _RideTile(
                          ride: ride,
                          isStravaConnected: stravaState.status == StravaConnectionStatus.connected,
                          onShareFit: () => _shareFile(context, ref, ride, 'FIT'),
                          onShareTcx: () => _shareFile(context, ref, ride, 'TCX'),
                          onUploadStrava: () => _uploadToStrava(context, ref, ride),
                          onDelete: () => _deleteRide(context, ref, ride),
                          onEditName: () => _editRideName(context, ref, ride),
                        );
                      },
                    ),
            ),

            // Help text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                stravaState.status == StravaConnectionStatus.connected
                    ? 'Envoyez directement vers Strava ou partagez vos fichiers .FIT/.TCX'
                    : 'Partagez vos fichiers .FIT ou .TCX pour les importer manuellement dans Strava',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRide(BuildContext context, WidgetRef ref, RideSummary ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'activite ?'),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(rideRepositoryProvider).deleteRide(ride.id);
      ref.invalidate(rideHistoryProvider);
      ref.invalidate(rideStatsProvider);
    }
  }

  Future<void> _editRideName(BuildContext context, WidgetRef ref, RideSummary ride) async {
    final controller = TextEditingController(text: ride.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom de la session',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName != null && newName.isNotEmpty) {
      await ref.read(rideRepositoryProvider).updateRideName(ride.id, newName);
      ref.invalidate(rideHistoryProvider);
    }
  }

  Future<void> _uploadToStrava(BuildContext context, WidgetRef ref, RideSummary ride) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Envoi vers Strava...'),
          ],
        ),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // Load full session
      final session = await ref.read(rideRepositoryProvider).loadRideWithSamples(ride.id);
      if (session == null) {
        throw Exception('Session introuvable');
      }

      // Upload
      await ref.read(stravaUploadProvider.notifier).uploadActivity(
        session,
        name: ride.displayName,
      );

      final uploadState = ref.read(stravaUploadProvider);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (uploadState.status == StravaUploadStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Activite envoyee vers Strava!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: uploadState.activityId != null
                ? SnackBarAction(
                    label: 'Voir',
                    textColor: Colors.white,
                    onPressed: () {
                      launchUrl(
                        Uri.parse('https://www.strava.com/activities/${uploadState.activityId}'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  )
                : null,
          ),
        );
      } else if (uploadState.status == StravaUploadStatus.duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Activite deja presente sur Strava'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (uploadState.status == StravaUploadStatus.error) {
        throw Exception(uploadState.error ?? 'Erreur inconnue');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    ref.read(stravaUploadProvider.notifier).reset();
  }

  Future<void> _shareFile(BuildContext context, WidgetRef ref, RideSummary ride, String format) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Generation du fichier $format...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final session = await ref.read(rideRepositoryProvider).loadRideWithSamples(ride.id);
      if (session == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur: session introuvable'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final String filePath;
      if (format == 'FIT') {
        filePath = await FitExporter.export(session);
      } else {
        filePath = await TcxExporter.export(session);
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'ride_${DateFormat('yyyyMMdd_HHmm').format(ride.startTime)}.$format',
      );

      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fichier $format partage avec succes'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Strava connection banner widget
class _StravaBanner extends ConsumerWidget {
  final StravaConnectionState stravaState;

  const _StravaBanner({required this.stravaState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = stravaState.status == StravaConnectionStatus.connected;
    final isConnecting = stravaState.status == StravaConnectionStatus.connecting;
    final needsConfig = stravaState.status == StravaConnectionStatus.notConfigured;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.orange.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isConnected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : const Icon(Icons.directions_bike, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Strava Connecte' : 'Strava Sync',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                Text(
                  isConnected
                      ? stravaState.athlete?.fullName ?? 'Connecte'
                      : needsConfig
                          ? 'Configurez vos identifiants'
                          : 'Connectez pour sync automatique',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          if (isConnecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (isConnected)
            TextButton(
              onPressed: () => _showDisconnectDialog(context, ref),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Deconnecter'),
            )
          else
            ElevatedButton(
              onPressed: () {
                if (needsConfig) {
                  _showConfigDialog(context, ref);
                } else {
                  ref.read(stravaConnectionProvider.notifier).connect();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
              ),
              child: Text(needsConfig ? 'Configurer' : 'Connecter'),
            ),
        ],
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deconnecter Strava ?'),
        content: const Text('Vous devrez vous reconnecter pour envoyer des activites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(stravaConnectionProvider.notifier).disconnect();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );
  }

  void _showConfigDialog(BuildContext context, WidgetRef ref) {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuration Strava'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Allez sur strava.com/settings/api\n'
                '2. Creez une application\n'
                '3. Copiez Client ID et Secret',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientSecretController,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final clientId = clientIdController.text.trim();
              final clientSecret = clientSecretController.text.trim();

              if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
                await ref.read(stravaConnectionProvider.notifier).saveCredentials(
                      clientId,
                      clientSecret,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({
    required this.ride,
    required this.isStravaConnected,
    required this.onShareFit,
    required this.onShareTcx,
    required this.onUploadStrava,
    required this.onDelete,
    required this.onEditName,
  });

  final RideSummary ride;
  final bool isStravaConnected;
  final VoidCallback onShareFit;
  final VoidCallback onShareTcx;
  final VoidCallback onUploadStrava;
  final VoidCallback onDelete;
  final VoidCallback onEditName;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy - HH:mm').format(ride.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                    GestureDetector(
                      onTap: onEditName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              ride.displayName,
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.timer,
                value: _formatDuration(ride.duration),
              ),
              const SizedBox(width: 8),
              if (ride.averagePower != null)
                _StatChip(
                  icon: Icons.flash_on,
                  value: '${ride.averagePower}W',
                ),
              if (ride.averagePower != null) const SizedBox(width: 8),
              if (ride.averageCadence != null)
                _StatChip(
                  icon: Icons.rotate_right,
                  value: '${ride.averageCadence} rpm',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (isStravaConnected)
            Column(
              children: [
                // Strava upload button (prominent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onUploadStrava,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Envoyer vers Strava'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Share buttons (secondary)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onShareFit,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.FIT'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onShareTcx,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.TCX'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareFit,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('.FIT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareTcx,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('.TCX'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
