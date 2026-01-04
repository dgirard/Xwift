# Plan: Configuration du Profil Xwift

## Objectif

Permettre la configuration complète du profil utilisateur :
1. Renommer le profil (nom d'utilisateur)
2. Supprimer des rides avec mise à jour des statistiques
3. Connecter un moniteur de fréquence cardiaque (montre/ceinture)

## État Actuel

### Profile Screen (`lib/screens/profile_screen.dart`)
- Utilise des données **hardcodées** (mock data)
- Nom "Alex Rider" en dur (ligne 88)
- Statistiques fictives (lignes 16-21)
- Activités fictives (lignes 23-42)
- Boutons settings avec callbacks vides (`onTap: () {}`)

### UserSettings (`lib/models/user_settings.dart`)
- Champ `userName` existe mais **non utilisé** dans l'UI
- Persistance via SharedPreferences fonctionnelle
- Méthodes `load()`, `save()`, `copyWith()` prêtes

### Database (`lib/core/database/app_database.dart`)
- Méthodes `deleteRide()` et `deleteSamplesForRide()` **déjà implémentées**
- Statistiques calculées via `getTotalRides()`, `getTotalDuration()`, `getTotalDistance()`
- Après suppression, les stats seront automatiquement recalculées

### BLE Architecture (`lib/features/ftms/ftms_provider.dart`)
- Connexion FTMS existante pour le vélo
- Le vélo peut envoyer HR (bit 9 du Indoor Bike Data) mais c'est rare
- **Besoin d'un provider séparé** pour les moniteurs HR dédiés

---

## Tâches d'Implémentation

### 1. Connecter le Profile Screen aux vraies données

**Fichiers à modifier :**
- `lib/screens/profile_screen.dart`

**Actions :**
1. Importer `userSettingsProvider` et `databaseProvider`
2. Remplacer le nom hardcodé par `userSettings.userName ?? 'Cycliste'`
3. Charger les vraies rides depuis la base de données
4. Calculer les vraies statistiques depuis les rides

**Code pattern :**
```dart
final userSettings = ref.watch(userSettingsProvider);
final ridesAsync = ref.watch(ridesProvider);
```

### 2. Implémenter l'édition du nom de profil

**Fichiers à modifier :**
- `lib/screens/profile_screen.dart` (dialog)
- `lib/providers/user_settings_provider.dart` (si nécessaire)

**Actions :**
1. Créer un dialog avec TextField pour le nouveau nom
2. Valider (non vide, longueur max 30 caractères)
3. Sauvegarder via `userSettings.copyWith(userName: newName).save()`
4. Mettre à jour l'UI via le provider

### 3. Implémenter la suppression des rides

**Fichiers à modifier :**
- `lib/screens/profile_screen.dart` (UI)
- Créer `lib/screens/ride_history_screen.dart` (liste détaillée)

**Actions :**
1. Ajouter icône de suppression sur chaque ride
2. Dialog de confirmation avant suppression
3. Appeler `database.deleteSamplesForRide(id)` puis `database.deleteRide(id)`
4. Rafraîchir la liste et les statistiques
5. Afficher snackbar de confirmation

**UX Flow :**
```
[Tap suppression] → [Dialog "Supprimer cette sortie ?"] → [Confirmer] → [Suppression + Toast]
```

### 4. Créer le HR Monitor Provider

**Nouveaux fichiers :**
- `lib/features/heart_rate/hr_monitor_provider.dart`
- `lib/features/heart_rate/hr_constants.dart`

**Actions :**
1. Scanner les appareils avec service UUID `0x180D` (Heart Rate Service)
2. Se connecter au moniteur sélectionné
3. Souscrire à la caractéristique `0x2A37` (Heart Rate Measurement)
4. Parser les données HR (format BLE standard)
5. Exposer via `StreamProvider<int>` pour le HR en temps réel

**Constants :**
```dart
class HrConstants {
  static final serviceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
  static final measurementChar = Guid('00002a37-0000-1000-8000-00805f9b34fb');
}
```

### 5. Intégrer le HR Monitor dans l'UI

**Fichiers à modifier :**
- `lib/screens/profile_screen.dart` (settings menu)
- `lib/screens/dashboard_screen.dart` (affichage HR)
- `lib/screens/erg_mode_screen.dart` (affichage HR)

**Actions :**
1. Ajouter option "Connecter moniteur HR" dans les settings
2. Scanner et afficher liste des appareils HR disponibles
3. Permettre sélection et connexion
4. Afficher HR en temps réel sur le dashboard (icône coeur + BPM)
5. Sauvegarder le dernier appareil HR dans UserSettings

### 6. Persister les paramètres HR

**Fichiers à modifier :**
- `lib/models/user_settings.dart`

**Actions :**
1. Ajouter champ `lastHrMonitorId: String?`
2. Ajouter champ `lastHrMonitorName: String?`
3. Auto-reconnexion au dernier moniteur HR connu

---

## Architecture BLE Multi-Appareils

```
┌─────────────────┐     ┌─────────────────┐
│  FTMS Provider  │     │ HR Mon Provider │
│   (Zwift Ride)  │     │ (Montre/Ceinture)│
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│          flutter_blue_plus              │
│     (Gère connexions multiples BLE)     │
└─────────────────────────────────────────┘
```

**Note :** flutter_blue_plus supporte les connexions multiples. Le vélo et le moniteur HR peuvent être connectés simultanément.

---

## Ordre d'Implémentation Recommandé

1. **Connecter profile aux vraies données** - Foundation
2. **Édition du nom** - Quick win, simple
3. **Suppression des rides** - Utilise l'existant
4. **HR Monitor Provider** - Nouveau composant isolé
5. **Intégration HR dans l'UI** - Connexion finale

---

## Tests à Effectuer

- [ ] Le nom s'affiche correctement depuis UserSettings
- [ ] Le nom peut être modifié et persiste après redémarrage
- [ ] Les vraies rides s'affichent dans l'historique
- [ ] La suppression d'une ride fonctionne
- [ ] Les stats se recalculent après suppression
- [ ] Le scanner trouve les montres/ceintures HR
- [ ] La connexion HR fonctionne
- [ ] Le HR s'affiche en temps réel sur le dashboard
- [ ] Le dernier appareil HR est sauvegardé
