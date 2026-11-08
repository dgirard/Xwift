import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/illustration/gemini_image_service.dart';
import '../../features/illustration/gemini_key_storage.dart';
import '../../features/illustration/illustration_config.dart';
import '../../features/illustration/illustration_prompt_builder.dart';
import '../../features/illustration/illustration_storage.dart';
import '../../features/illustration/illustration_viewer_screen.dart';

/// Affiche le dialogue de configuration d'illustration
Future<void> showIllustrationDialog(
  BuildContext context,
  RideSummary ride,
) async {
  // Verifier si l'API key Gemini est configuree
  final keyStorage = GeminiKeyStorage();
  final apiKey = await keyStorage.read();
  if (apiKey == null || apiKey.isEmpty) {
    if (!context.mounted) return;
    final configured = await _showGeminiApiKeyDialog(context, keyStorage);
    if (!configured) return;
  }
  final prefs = await SharedPreferences.getInstance();

  // Charger les preferences
  String selectedAnimal =
      prefs.getString(IllustrationPrefsKeys.animal) ?? 'hedgehog';
  IllustrationStyle selectedStyle = IllustrationStyle.fromString(
    prefs.getString(IllustrationPrefsKeys.style),
  );
  bool useBlackAndWhite =
      prefs.getBool(IllustrationPrefsKeys.blackAndWhite) ?? true;

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
              const Text('Personnage',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...illustrationAnimals.map((animal) => _ChoiceTile(
                    title: animal['name']!,
                    subtitle: animal['desc']!,
                    selected: selectedAnimal == animal['id'],
                    onTap: () =>
                        setDialogState(() => selectedAnimal = animal['id']!),
                  )),

              const SizedBox(height: 16),

              // Style visuel
              const Text('Style',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...IllustrationStyle.values.map((style) => _ChoiceTile(
                    title: style.displayName,
                    subtitle: style.description,
                    selected: selectedStyle == style,
                    onTap: () => setDialogState(() {
                      selectedStyle = style;
                      // Manga et Print sont souvent en N&B
                      if (style == IllustrationStyle.manga ||
                          style == IllustrationStyle.print) {
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
  await prefs.setString(
      IllustrationPrefsKeys.animal, result['animal'] as String);
  await prefs.setString(
      IllustrationPrefsKeys.style, (result['style'] as IllustrationStyle).name);
  await prefs.setBool(
      IllustrationPrefsKeys.blackAndWhite, result['blackAndWhite'] as bool);

  // Generer l'illustration
  if (!context.mounted) return;
  await _generateIllustration(context, ride, result);
}

/// Dialogue pour configurer la cle API Gemini
Future<bool> _showGeminiApiKeyDialog(
  BuildContext context,
  GeminiKeyStorage keyStorage,
) async {
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
    await keyStorage.write(apiKey);
    return true;
  }
  return false;
}

/// Genere l'illustration avec Gemini
Future<void> _generateIllustration(
  BuildContext context,
  RideSummary ride,
  Map<String, dynamic> config,
) async {
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
          const Text('Generation de l\'illustration...'),
        ],
      ),
      duration: const Duration(seconds: 90),
      behavior: SnackBarBehavior.floating,
    ),
  );

  try {
    // Charger la session complete
    final session = await container
        .read(rideRepositoryProvider)
        .loadRideWithSamples(ride.id);
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

    if (kDebugMode) debugPrint('[ILLUSTRATION] Prompt: $prompt');

    // Generer l'image
    final apiKey = await GeminiKeyStorage().read();
    if (apiKey == null) throw Exception('Clé API Gemini non configurée');
    final service = GeminiImageService(apiKey: apiKey);
    final imageBytes = await service.generateImage(prompt);

    messenger.hideCurrentSnackBar();

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
    container.invalidate(rideHistoryProvider);

    // Afficher notification de sauvegarde
    if (downloadPath != null && context.mounted) {
      messenger.showSnackBar(
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
      onRegenerate: () => showIllustrationDialog(context, ride),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// One option of a single-choice list (radio-like, without the deprecated
/// Radio group API).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
