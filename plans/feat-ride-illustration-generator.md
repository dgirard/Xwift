# ✨ feat: Generateur d'illustrations humoristiques pour sessions de velo

Ajouter un generateur d'images humoristiques sur les cartes d'activites dans l'ecran Export. L'image est generee par Gemini 2.0 Flash Image avec un prompt incluant les donnees de la session et un personnage animal configurable.

## Contexte

L'utilisateur termine une session de velo sur son home trainer. Il peut exporter ses donnees en FIT/TCX ou vers Strava. On veut ajouter une fonctionnalite creative: generer un **dessin de presse humoristique** representant un animal sur un velo avec les statistiques de la session.

**Exemple de prompt:**
> "Faire un dessin de presse humoristique d'un herisson sur un velo de type hometrainer. Il vient de faire 10 min, a 130W et 90 Calories depensees. Le faire en noir et blanc dans un style manga futuriste."

## Acceptance Criteria

- [ ] Ajouter un bouton "Generer illustration" sur chaque carte d'activite (`_RideTile`)
- [ ] Afficher un dialogue de configuration avec:
  - [ ] Selection de l'animal (meme liste que plaud comics)
  - [ ] Selection du style (Manga, Franco-belge, Super-heros, Impression)
  - [ ] Toggle noir et blanc / couleur
- [ ] Sauvegarder les preferences utilisateur via SharedPreferences
- [ ] Construire le prompt avec toutes les donnees de la session
- [ ] Appeler l'API Gemini `gemini-2.0-flash-exp-image-generation` pour generer l'image
- [ ] Afficher l'image generee dans un dialogue
- [ ] Permettre de partager/sauvegarder l'image

## MVP

### Liste des animaux (identique a plaud)

```dart
// lib/features/illustration/illustration_config.dart

/// Animaux disponibles pour l'illustration
const List<Map<String, String>> illustrationAnimals = [
  {'id': 'hedgehog', 'name': 'Herisson', 'desc': 'Le sportif determine'},
  {'id': 'rooster', 'name': 'Coq', 'desc': 'Le chef depasse / Syndicaliste'},
  {'id': 'poodle', 'name': 'Caniche Royal', 'desc': 'L\'Aristocrate ruine'},
  {'id': 'pigeon', 'name': 'Pigeon', 'desc': 'Le Titi Parisien / Gavroche'},
  {'id': 'fox', 'name': 'Renarde', 'desc': 'La Femme Fatale / Espionne'},
  {'id': 'boar', 'name': 'Laie', 'desc': 'La "Maman" Costaud / Matriarche'},
  {'id': 'cat', 'name': 'Chatte de Gouttiere', 'desc': 'L\'Intellectuelle Blasee'},
];

/// Styles visuels disponibles
enum IllustrationStyle {
  manga('Manga', 'Style japonais, expressif, dynamique'),
  francoBelge('Franco-belge', 'Style Asterix/Tintin, ligne claire'),
  superhero('Super-heros', 'Style Marvel/DC, dynamique'),
  print('Impression', 'Optimise pour le papier, contraste eleve');

  final String displayName;
  final String description;
  const IllustrationStyle(this.displayName, this.description);

  static IllustrationStyle fromString(String? value) {
    return IllustrationStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => IllustrationStyle.manga,
    );
  }
}

/// Cles SharedPreferences
class IllustrationPrefsKeys {
  static const String animal = 'illustration_pref_animal';
  static const String style = 'illustration_pref_style';
  static const String blackAndWhite = 'illustration_pref_bw';
}
```

### Service Gemini Image

```dart
// lib/features/illustration/gemini_image_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiImageService {
  static const String _modelName = 'gemini-2.0-flash-exp-image-generation';
  final String apiKey;

  GeminiImageService({required this.apiKey});

  /// Genere une image a partir d'un prompt
  Future<Uint8List?> generateImage(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent'
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
      }
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: body,
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      print('[GEMINI_IMAGE] Error: ${response.statusCode} - ${response.body}');
      return null;
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

    // Extraire l'image de la reponse
    final candidates = jsonResponse['candidates'] as List<dynamic>?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          final inlineData = part['inlineData'] as Map<String, dynamic>?;
          if (inlineData != null && inlineData['data'] != null) {
            final base64Data = inlineData['data'] as String;
            return base64Decode(base64Data);
          }
        }
      }
    }

    return null;
  }
}
```

### Constructeur de prompt

```dart
// lib/features/illustration/illustration_prompt_builder.dart

import '../../models/ride_session.dart';
import 'illustration_config.dart';

class IllustrationPromptBuilder {
  /// Construit le prompt pour la generation d'image
  static String build({
    required RideSession session,
    required String animalId,
    required IllustrationStyle style,
    required bool blackAndWhite,
  }) {
    // Trouver l'animal
    final animal = illustrationAnimals.firstWhere(
      (a) => a['id'] == animalId,
      orElse: () => illustrationAnimals.first,
    );
    final animalName = animal['name']!.toLowerCase();

    // Formater les stats
    final durationMinutes = session.duration.inMinutes;
    final avgPower = session.averagePower;
    final maxPower = session.maxPower;
    final calories = session.totalCalories;
    final distance = (session.totalDistance / 1000).toStringAsFixed(1);
    final avgCadence = session.averageCadence;
    final avgSpeed = session.averageSpeed?.toStringAsFixed(1);
    final avgHr = session.averageHeartRate;
    final mode = session.mode == RideMode.erg ? 'mode ERG' : 'mode simulation';

    // Construire la description de la session
    final statsBuffer = StringBuffer();
    statsBuffer.write('Il vient de faire $durationMinutes minutes');
    if (avgPower != null) statsBuffer.write(', puissance moyenne de ${avgPower}W');
    if (maxPower != null) statsBuffer.write(' (max ${maxPower}W)');
    if (calories > 0) statsBuffer.write(', $calories calories depensees');
    if (avgCadence != null) statsBuffer.write(', cadence ${avgCadence} rpm');
    if (avgSpeed != null) statsBuffer.write(', vitesse ${avgSpeed} km/h');
    if (avgHr != null) statsBuffer.write(', FC moyenne ${avgHr} bpm');
    statsBuffer.write(', en $mode');
    statsBuffer.write('.');

    // Style visuel
    final styleDesc = _getStyleDescription(style, blackAndWhite);

    // Assembler le prompt final
    return '''Cree un dessin de presse humoristique d'un $animalName anthropomorphe sur un velo de type home trainer (velo d'appartement connecte).

CONTEXTE SPORTIF:
${statsBuffer.toString()}

STYLE ARTISTIQUE:
$styleDesc

INSTRUCTIONS:
- Le personnage doit avoir une expression qui reflete l'effort physique
- Inclure des elements visuels representant les statistiques (compteur, sueur, etc.)
- L'ambiance doit etre humoristique et sympathique
- L'image doit etre haute qualite et detaillee
- Pas de texte dans l'image (sauf sur un eventuel compteur)''';
  }

  static String _getStyleDescription(IllustrationStyle style, bool blackAndWhite) {
    final colorMode = blackAndWhite
        ? 'En noir et blanc avec des contrastes forts'
        : 'En couleurs vives et dynamiques';

    switch (style) {
      case IllustrationStyle.manga:
        return '''Style manga japonais:
- Lignes de vitesse et effets de mouvement
- Expressions faciales exagerees
- Proportions manga caracteristiques
- $colorMode, avec des trames si noir et blanc''';

      case IllustrationStyle.francoBelge:
        return '''Style bande dessinee franco-belge (Asterix, Tintin):
- Ligne claire avec contours nets
- Personnage expressif et cartoonesque
- Decor detaille style europeen
- $colorMode''';

      case IllustrationStyle.superhero:
        return '''Style comics super-heros americain (Marvel/DC):
- Poses dynamiques et heroiques
- Angles dramatiques
- Musculature exageree
- $colorMode avec eclairage dramatique''';

      case IllustrationStyle.print:
        return '''Style optimise pour impression:
- Contrastes eleves
- Lignes epaisses et nettes
- Compositions claires sans details fins
- $colorMode avec palette limitee''';
    }
  }
}
```

### Dialogue de configuration

```dart
// Dans export_screen.dart - Ajouter dans _RideTile

/// Affiche le dialogue de configuration et genere l'illustration
Future<void> _showIllustrationDialog(
  BuildContext context,
  WidgetRef ref,
  RideSummary ride,
) async {
  final prefs = await SharedPreferences.getInstance();

  // Charger les preferences
  String selectedAnimal = prefs.getString(IllustrationPrefsKeys.animal) ?? 'hedgehog';
  IllustrationStyle selectedStyle = IllustrationStyle.fromString(
    prefs.getString(IllustrationPrefsKeys.style),
  );
  bool useBlackAndWhite = prefs.getBool(IllustrationPrefsKeys.blackAndWhite) ?? true;

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
                subtitle: Text(animal['desc']!),
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
                subtitle: Text(style.description),
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
            onPressed: () async {
              // Sauvegarder les preferences
              await prefs.setString(IllustrationPrefsKeys.animal, selectedAnimal);
              await prefs.setString(IllustrationPrefsKeys.style, selectedStyle.name);
              await prefs.setBool(IllustrationPrefsKeys.blackAndWhite, useBlackAndWhite);

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

  if (result == null) return;

  // Generer l'illustration
  await _generateIllustration(context, ref, ride, result);
}
```

### UI Preview - Bouton sur la carte

```
┌─────────────────────────────────────────────────────────────┐
│  [bike icon]  Session du 6 Jan 2025              [delete]   │
│               06 Jan 2025 - 15:30                           │
│                                                             │
│  [timer] 25 min   [flash] 145W   [rotate] 85 rpm           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          [Envoyer vers Strava]                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [.FIT]              [.TCX]              [Illustrer]        │  ← NOUVEAU
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### UI Preview - Dialogue de configuration

```
┌─────────────────────────────────────────┐
│      Generer une illustration           │
├─────────────────────────────────────────┤
│ Personnage                              │
│   ● Herisson - Le sportif determine     │
│   ○ Coq - Le chef depasse               │
│   ○ Caniche Royal - L'Aristocrate       │
│   ○ Pigeon - Le Titi Parisien           │
│   ○ Renarde - La Femme Fatale           │
│   ○ Laie - La Matriarche costaud        │
│   ○ Chatte - L'Intellectuelle blasee    │
│                                         │
│ Style                                   │
│   ● Manga - Style japonais, expressif   │
│   ○ Franco-belge - Style Asterix        │
│   ○ Super-heros - Style Marvel/DC       │
│   ○ Impression - Optimise papier        │
│                                         │
│ ☑ Noir et blanc                         │
│                                         │
│         [Annuler]    [Generer]          │
└─────────────────────────────────────────┘
```

## Donnees de session utilisees dans le prompt

| Donnee | Source | Exemple |
|--------|--------|---------|
| Duree | `session.duration.inMinutes` | "25 minutes" |
| Puissance moyenne | `session.averagePower` | "145W" |
| Puissance max | `session.maxPower` | "max 280W" |
| Calories | `session.totalCalories` | "320 calories" |
| Distance | `session.totalDistance / 1000` | "12.5 km" |
| Cadence moyenne | `session.averageCadence` | "85 rpm" |
| Vitesse moyenne | `session.averageSpeed` | "28.5 km/h" |
| FC moyenne | `session.averageHeartRate` | "142 bpm" |
| Mode | `session.mode` | "ERG" ou "SIM" |

## Fichiers a creer

| Fichier | Description |
|---------|-------------|
| `lib/features/illustration/illustration_config.dart` | Configuration (animaux, styles, prefs keys) |
| `lib/features/illustration/gemini_image_service.dart` | Service d'appel API Gemini |
| `lib/features/illustration/illustration_prompt_builder.dart` | Construction du prompt |
| `lib/features/illustration/illustration_result_dialog.dart` | Affichage du resultat |

## Fichiers a modifier

| Fichier | Modification |
|---------|-------------|
| `lib/screens/export_screen.dart` | Ajouter bouton "Illustrer" + dialogue config |
| `pubspec.yaml` | Ajouter dependance `http` si absente |

## Flux de donnees

```
┌─────────────────────────────────────────────────────────────┐
│                    SharedPreferences                         │
│  illustration_pref_animal: "hedgehog"                       │
│  illustration_pref_style: "manga"                           │
│  illustration_pref_bw: true                                 │
└─────────────────────┬───────────────────────────────────────┘
                      │ load on dialog open
                      ▼
┌─────────────────────────────────────────────────────────────┐
│           _showIllustrationDialog                            │
│  - Affiche les preferences                                  │
│  - Utilisateur configure                                    │
│  - Sauvegarde et retourne config                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ {animal, style, blackAndWhite}
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         IllustrationPromptBuilder.build()                    │
│  - Charge les donnees RideSession completes                 │
│  - Formate les statistiques                                 │
│  - Construit le prompt avec style                           │
└─────────────────────┬───────────────────────────────────────┘
                      │ prompt string
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          GeminiImageService.generateImage()                  │
│  - Appel API gemini-2.0-flash-exp-image-generation          │
│  - Retourne Uint8List (bytes PNG)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │ image bytes
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          IllustrationResultDialog                            │
│  - Affiche l'image generee                                  │
│  - Boutons: Partager, Sauvegarder, Fermer                   │
└─────────────────────────────────────────────────────────────┘
```

## Configuration API Gemini

L'application doit stocker la cle API Gemini. Options:
1. **SharedPreferences** (comme plaud) - L'utilisateur entre sa cle
2. **Variable d'environnement** - Pour le build
3. **Fichier .env** - Via flutter_dotenv

**Recommandation:** Utiliser SharedPreferences avec un dialogue de configuration dans les settings, identique a la configuration Strava.

## References

- Mecanique comics plaud : `plaud_app/lib/services/agents/agent_service.dart:512-639`
- Style instructions plaud : `plaud/plans/feat-comics-color-mode.md`
- Animal selection plaud : `plaud/plans/feat-comics-animal-selection.md`
- Gemini image API : `plaud_app/lib/services/gemini/gemini_service.dart:565-640`
- Export screen Xwift : `xwift/lib/screens/export_screen.dart`
- RideSession model : `xwift/lib/models/ride_session.dart`
