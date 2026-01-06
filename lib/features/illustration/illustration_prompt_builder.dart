import '../../models/ride_session.dart';
import 'illustration_config.dart';

/// Constructeur de prompt pour la generation d'illustrations
class IllustrationPromptBuilder {
  /// Construit le prompt complet pour la generation d'image
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
    final statsDesc = _buildStatsDescription(session);

    // Style visuel
    final styleDesc = _getStyleDescription(style, blackAndWhite);

    // Assembler le prompt final
    return '''Cree un dessin de presse humoristique d'un $animalName anthropomorphe sur un velo de type home trainer (velo d'appartement connecte).

CONTEXTE SPORTIF:
$statsDesc

STYLE ARTISTIQUE:
$styleDesc

INSTRUCTIONS:
- Le personnage doit avoir une expression qui reflete l'effort physique
- Inclure des elements visuels representant les statistiques (compteur, sueur, etc.)
- L'ambiance doit etre humoristique et sympathique
- L'image doit etre haute qualite et detaillee
- IMPORTANT: Ajouter une touche humoristique avec du texte: une bulle de parole ou de pensee du personnage, un sous-titre, ou une voix "off" d'un personnage invisible qui commente la scene. Le texte doit etre drole et en rapport avec l'effort physique ou les statistiques de la session.''';
  }

  /// Construit la description des statistiques de la session
  static String _buildStatsDescription(RideSession session) {
    final buffer = StringBuffer();

    // Duree
    final durationMinutes = session.duration.inMinutes;
    buffer.write('Il vient de faire $durationMinutes minutes de velo');

    // Puissance
    final avgPower = session.averagePower;
    final maxPower = session.maxPower;
    if (avgPower != null) {
      buffer.write(', puissance moyenne de ${avgPower}W');
      if (maxPower != null && maxPower > avgPower) {
        buffer.write(' (max ${maxPower}W)');
      }
    }

    // Calories
    final calories = session.totalCalories;
    if (calories > 0) {
      buffer.write(', $calories calories depensees');
    }

    // Distance
    final distanceKm = session.totalDistance / 1000;
    if (distanceKm > 0.1) {
      buffer.write(', ${distanceKm.toStringAsFixed(1)} km parcourus');
    }

    // Cadence
    final avgCadence = session.averageCadence;
    if (avgCadence != null) {
      buffer.write(', cadence de ${avgCadence} rpm');
    }

    // Vitesse
    final avgSpeed = session.averageSpeed;
    if (avgSpeed != null && avgSpeed > 0) {
      buffer.write(', vitesse moyenne ${avgSpeed.toStringAsFixed(1)} km/h');
    }

    // Frequence cardiaque
    final avgHr = session.averageHeartRate;
    if (avgHr != null) {
      buffer.write(', frequence cardiaque ${avgHr} bpm');
    }

    // Mode
    final mode = session.mode == RideMode.erg ? 'mode ERG (puissance cible)' : 'mode simulation';
    buffer.write(', en $mode');

    buffer.write('.');
    return buffer.toString();
  }

  /// Retourne les instructions de style selon le choix
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
