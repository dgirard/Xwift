/// Configuration pour le generateur d'illustrations

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

/// Cles SharedPreferences pour les preferences illustration
class IllustrationPrefsKeys {
  static const String animal = 'illustration_pref_animal';
  static const String style = 'illustration_pref_style';
  static const String blackAndWhite = 'illustration_pref_bw';
  static const String geminiApiKey = 'gemini_api_key';
}
