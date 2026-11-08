import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/export/fit_exporter.dart';
import '../../features/export/tcx_exporter.dart';
import '../../features/illustration/illustration_storage.dart';
import '../../features/illustration/image_format.dart';
import '../../features/strava/strava_provider.dart';

/// Deletes a ride (after confirmation) and its illustration.
Future<void> deleteRide(BuildContext context, RideSummary ride) async {
  // Captured before any await: still valid if the screen is closed meanwhile.
  final container = ProviderScope.containerOf(context, listen: false);
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
    await container.read(rideRepositoryProvider).deleteRide(ride.id);
    try {
      await IllustrationStorage.delete(ride.id);
    } catch (e) {
      // The ride is gone; a leftover image must not turn this into an error.
      if (kDebugMode) debugPrint('[Export] illustration not deleted: $e');
    }
    container.invalidate(rideHistoryProvider);
    container.invalidate(rideStatsProvider);
  }
}

/// Renames a ride.
Future<void> editRideName(BuildContext context, RideSummary ride) async {
  // Captured before any await: still valid if the screen is closed meanwhile.
  final container = ProviderScope.containerOf(context, listen: false);
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
    await container
        .read(rideRepositoryProvider)
        .updateRideName(ride.id, newName);
    container.invalidate(rideHistoryProvider);
  }
}

/// Uploads a ride to Strava, then offers to share its illustration.
Future<void> uploadRideToStrava(BuildContext context, RideSummary ride) async {
  // Captured before any await: still valid if the screen is closed meanwhile.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  // Show loading
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    final session = await container
        .read(rideRepositoryProvider)
        .loadRideWithSamples(ride.id);
    if (session == null) {
      throw Exception('Session introuvable');
    }

    // Upload
    await container.read(stravaUploadProvider.notifier).uploadActivity(
          session,
          name: ride.displayName,
        );

    final uploadState = container.read(stravaUploadProvider);

    messenger.hideCurrentSnackBar();

    if (uploadState.status == StravaUploadStatus.success) {
      // Verifier si une illustration existe
      final illustrationBytes = await IllustrationStorage.load(ride.id);

      if (illustrationBytes != null && context.mounted) {
        // Proposer de partager l'illustration
        await _proposeShareIllustration(
          context,
          ride,
          illustrationBytes,
          uploadState.activityId,
        );
      } else if (context.mounted) {
        messenger.showSnackBar(
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
                        Uri.parse(
                            'https://www.strava.com/activities/${uploadState.activityId}'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } else if (uploadState.status == StravaUploadStatus.duplicate) {
      messenger.showSnackBar(
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
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  container.read(stravaUploadProvider.notifier).reset();
}

/// Propose de partager l'illustration apres upload Strava
Future<void> _proposeShareIllustration(
  BuildContext context,
  RideSummary ride,
  Uint8List illustrationBytes,
  int? activityId,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Activite envoyee!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              illustrationBytes,
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Voulez-vous partager l\'illustration?\n'
            'Vous pourrez l\'ajouter a votre activite Strava.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Non merci'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Partager'),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    // Partager l'illustration
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/illustration_$timestamp.'
        '${imageFileExtension(illustrationBytes)}');
    await file.writeAsBytes(illustrationBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Illustration - ${ride.displayName}',
      text: activityId != null
          ? 'Mon illustration pour https://www.strava.com/activities/$activityId'
          : 'Mon illustration pour ${ride.displayName}',
    );
  } else if (activityId != null && context.mounted) {
    // Juste afficher le lien vers l'activite
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Activite envoyee vers Strava!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {
            launchUrl(
              Uri.parse('https://www.strava.com/activities/$activityId'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ),
    );
  }
}

/// Exports a ride as FIT or TCX and opens the share sheet.
Future<void> shareRideFile(
    BuildContext context, RideSummary ride, String format) async {
  // Captured before any await: still valid if the screen is closed meanwhile.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    final session = await container
        .read(rideRepositoryProvider)
        .loadRideWithSamples(ride.id);
    if (session == null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
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

    messenger.hideCurrentSnackBar();

    final result = await Share.shareXFiles(
      [XFile(filePath)],
      subject:
          'ride_${DateFormat('yyyyMMdd_HHmm').format(ride.startTime)}.$format',
    );

    if (result.status == ShareResultStatus.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fichier $format partage avec succes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
