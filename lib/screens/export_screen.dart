import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/database_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/strava/strava_provider.dart';
import 'export/illustration_actions.dart';
import 'export/ride_actions.dart';
import 'export/ride_tile.dart';
import 'export/strava_banner.dart';

/// Saved rides: export (FIT/TCX), Strava upload, illustrations.
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
            StravaBanner(stravaState: stravaState),

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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vos sessions sauvegardees apparaitront ici',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        return RideTile(
                          ride: ride,
                          isStravaConnected: stravaState.status ==
                              StravaConnectionStatus.connected,
                          onShareFit: () => shareRideFile(context, ride, 'FIT'),
                          onShareTcx: () => shareRideFile(context, ride, 'TCX'),
                          onUploadStrava: () =>
                              uploadRideToStrava(context, ride),
                          onDelete: () => deleteRide(context, ride),
                          onEditName: () => editRideName(context, ride),
                          onIllustrate: () =>
                              showIllustrationDialog(context, ride),
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
}
