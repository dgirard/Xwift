import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/database/database_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/export/fit_exporter.dart';
import '../features/export/tcx_exporter.dart';
import '../features/illustration/gemini_image_service.dart';
import '../features/illustration/illustration_config.dart';
import '../features/illustration/illustration_prompt_builder.dart';
import '../features/illustration/illustration_storage.dart';
import '../features/illustration/illustration_viewer_screen.dart';
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
                          onIllustrate: () => _showIllustrationDialog(context, ref, ride),
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
        }
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
      final file = File('${directory.path}/illustration_$timestamp.png');
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

  /// Affiche le dialogue de configuration d'illustration
  Future<void> _showIllustrationDialog(
    BuildContext context,
    WidgetRef ref,
    RideSummary ride,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Verifier si l'API key Gemini est configuree
    final apiKey = prefs.getString(IllustrationPrefsKeys.geminiApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      final configured = await _showGeminiApiKeyDialog(context, prefs);
      if (!configured) return;
    }

    // Charger les preferences
    String selectedAnimal = prefs.getString(IllustrationPrefsKeys.animal) ?? 'hedgehog';
    IllustrationStyle selectedStyle = IllustrationStyle.fromString(
      prefs.getString(IllustrationPrefsKeys.style),
    );
    bool useBlackAndWhite = prefs.getBool(IllustrationPrefsKeys.blackAndWhite) ?? true;

    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generer une illustration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection de l'animal
                const Text('Personnage', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...illustrationAnimals.map((animal) => RadioListTile<String>(
                  title: Text(animal['name']!),
                  subtitle: Text(animal['desc']!, style: const TextStyle(fontSize: 12)),
                  value: animal['id']!,
                  groupValue: selectedAnimal,
                  dense: true,
                  onChanged: (v) => setDialogState(() => selectedAnimal = v!),
                )),

                const SizedBox(height: 16),

                // Style visuel
                const Text('Style', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...IllustrationStyle.values.map((style) => RadioListTile<IllustrationStyle>(
                  title: Text(style.displayName),
                  subtitle: Text(style.description, style: const TextStyle(fontSize: 12)),
                  value: style,
                  groupValue: selectedStyle,
                  dense: true,
                  onChanged: (v) => setDialogState(() {
                    selectedStyle = v!;
                    // Manga et Print sont souvent en N&B
                    if (v == IllustrationStyle.manga || v == IllustrationStyle.print) {
                      useBlackAndWhite = true;
                    }
                  }),
                )),

                const SizedBox(height: 8),

                // Toggle couleur
                SwitchListTile(
                  title: const Text('Noir et blanc'),
                  value: useBlackAndWhite,
                  onChanged: (v) => setDialogState(() => useBlackAndWhite = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'animal': selectedAnimal,
                  'style': selectedStyle,
                  'blackAndWhite': useBlackAndWhite,
                });
              },
              child: const Text('Generer'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    // Sauvegarder les preferences (apres fermeture du dialogue)
    await prefs.setString(IllustrationPrefsKeys.animal, result['animal'] as String);
    await prefs.setString(IllustrationPrefsKeys.style, (result['style'] as IllustrationStyle).name);
    await prefs.setBool(IllustrationPrefsKeys.blackAndWhite, result['blackAndWhite'] as bool);

    // Generer l'illustration
    await _generateIllustration(context, ref, ride, result);
  }

  /// Dialogue pour configurer la cle API Gemini
  Future<bool> _showGeminiApiKeyDialog(BuildContext context, SharedPreferences prefs) async {
    final controller = TextEditingController();

    final apiKey = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuration Gemini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pour generer des illustrations, vous avez besoin d\'une cle API Google Gemini.\n\n'
              '1. Allez sur aistudio.google.com\n'
              '2. Creez une cle API\n'
              '3. Collez-la ci-dessous',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cle API Gemini',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (apiKey != null && apiKey.isNotEmpty) {
      await prefs.setString(IllustrationPrefsKeys.geminiApiKey, apiKey);
      return true;
    }
    return false;
  }

  /// Genere l'illustration avec Gemini
  Future<void> _generateIllustration(
    BuildContext context,
    WidgetRef ref,
    RideSummary ride,
    Map<String, dynamic> config,
  ) async {
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
            const Text('Generation de l\'illustration...'),
          ],
        ),
        duration: const Duration(seconds: 90),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // Charger la session complete
      final session = await ref.read(rideRepositoryProvider).loadRideWithSamples(ride.id);
      if (session == null) {
        throw Exception('Session introuvable');
      }

      // Construire le prompt
      final prompt = IllustrationPromptBuilder.build(
        session: session,
        animalId: config['animal'] as String,
        style: config['style'] as IllustrationStyle,
        blackAndWhite: config['blackAndWhite'] as bool,
      );

      print('[ILLUSTRATION] Prompt: $prompt');

      // Generer l'image
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(IllustrationPrefsKeys.geminiApiKey)!;
      final service = GeminiImageService(apiKey: apiKey);
      final imageBytes = await service.generateImage(prompt);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (imageBytes == null) {
        throw Exception('Aucune image generee');
      }

      // Sauvegarder l'illustration associee au ride
      await IllustrationStorage.save(ride.id, imageBytes);

      // Sauvegarder aussi dans le dossier Download du telephone
      final downloadPath = await IllustrationStorage.saveToDownloads(
        ride.id,
        imageBytes,
        ride.displayName,
      );

      // Rafraichir la liste pour afficher la miniature
      ref.invalidate(rideHistoryProvider);

      // Afficher notification de sauvegarde
      if (downloadPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image sauvegardee dans Download'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (!context.mounted) return;

      // Afficher le resultat avec viewer plein ecran
      await showIllustrationViewer(
        context,
        imageBytes: imageBytes,
        sessionName: ride.displayName,
        onRegenerate: () => _showIllustrationDialog(context, ref, ride),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (context.mounted) {
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

class _RideTile extends StatefulWidget {
  const _RideTile({
    required this.ride,
    required this.isStravaConnected,
    required this.onShareFit,
    required this.onShareTcx,
    required this.onUploadStrava,
    required this.onDelete,
    required this.onEditName,
    required this.onIllustrate,
  });

  final RideSummary ride;
  final bool isStravaConnected;
  final VoidCallback onShareFit;
  final VoidCallback onShareTcx;
  final VoidCallback onUploadStrava;
  final VoidCallback onDelete;
  final VoidCallback onEditName;
  final VoidCallback onIllustrate;

  @override
  State<_RideTile> createState() => _RideTileState();
}

class _RideTileState extends State<_RideTile> {
  Uint8List? _illustrationBytes;

  @override
  void initState() {
    super.initState();
    _loadIllustration();
  }

  @override
  void didUpdateWidget(_RideTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Toujours recharger l'illustration (peut avoir ete regeneree)
    _loadIllustration();
  }

  Future<void> _loadIllustration() async {
    final bytes = await IllustrationStorage.load(widget.ride.id);
    if (mounted) {
      setState(() {
        _illustrationBytes = bytes;
      });
    }
  }

  void _openIllustrationViewer() {
    if (_illustrationBytes != null) {
      showIllustrationViewer(
        context,
        imageBytes: _illustrationBytes!,
        sessionName: widget.ride.displayName,
        onRegenerate: widget.onIllustrate,
      );
    }
  }

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
    final dateStr = DateFormat('dd MMM yyyy - HH:mm').format(widget.ride.startTime);

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
              // Miniature illustration ou icone velo
              GestureDetector(
                onTap: _illustrationBytes != null ? _openIllustrationViewer : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    image: _illustrationBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_illustrationBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _illustrationBytes == null
                      ? Icon(Icons.directions_bike, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onEditName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.ride.displayName,
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
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.timer,
                value: _formatDuration(widget.ride.duration),
              ),
              const SizedBox(width: 8),
              if (widget.ride.averagePower != null)
                _StatChip(
                  icon: Icons.flash_on,
                  value: '${widget.ride.averagePower}W',
                ),
              if (widget.ride.averagePower != null) const SizedBox(width: 8),
              if (widget.ride.averageCadence != null)
                _StatChip(
                  icon: Icons.rotate_right,
                  value: '${widget.ride.averageCadence} rpm',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (widget.isStravaConnected)
            Column(
              children: [
                // Strava upload button (prominent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onUploadStrava,
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
                        onPressed: widget.onShareFit,
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
                        onPressed: widget.onShareTcx,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.TCX'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Illustration button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onIllustrate,
                    icon: Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    label: const Text('Illustrer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShareFit,
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
                        onPressed: widget.onShareTcx,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.TCX'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Illustration button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onIllustrate,
                    icon: Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    label: const Text('Illustrer'),
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
