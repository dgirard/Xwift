# Plan d'Implémentation - Intégration Strava

## Vue d'ensemble

Implémenter l'authentification OAuth2 Strava et l'upload automatique des sessions vers Strava.

## Phases d'Implémentation

### Phase 1: Configuration et Dépendances

1. **Ajouter les dépendances** dans `pubspec.yaml`:
   - `flutter_secure_storage` - Stockage sécurisé des tokens
   - `app_links` - Gestion des deep links pour OAuth callback
   - `url_launcher` - Ouverture de l'URL d'autorisation
   - `archive` - Compression GZIP des fichiers FIT

2. **Configurer les deep links**:
   - Android: Ajouter intent-filter dans `AndroidManifest.xml`
   - iOS: Configurer `CFBundleURLTypes` dans `Info.plist`

### Phase 2: Service d'Authentification Strava

3. **Créer `lib/features/strava/strava_config.dart`**:
   - Client ID et Client Secret (à configurer par l'utilisateur)
   - URLs d'autorisation et de token
   - Scopes requis

4. **Créer `lib/features/strava/strava_auth_service.dart`**:
   - `initiateAuth()` - Lancer le flux OAuth
   - `handleCallback(Uri uri)` - Traiter le callback avec le code
   - `exchangeCodeForToken(String code)` - Échanger le code pour les tokens
   - `refreshToken()` - Rafraîchir le token expiré
   - `getValidToken()` - Obtenir un token valide (rafraîchit si nécessaire)
   - `logout()` - Déconnecter et supprimer les tokens

5. **Créer `lib/features/strava/strava_token_storage.dart`**:
   - Stockage sécurisé avec `flutter_secure_storage`
   - `saveTokens()`, `getTokens()`, `clearTokens()`
   - Vérification de l'expiration

### Phase 3: Service d'Upload Strava

6. **Créer `lib/features/strava/strava_upload_service.dart`**:
   - `uploadActivity(RideSession session)` - Upload complet
   - `_buildMultipartRequest()` - Construction de la requête
   - `_pollUploadStatus(uploadId)` - Polling jusqu'à traitement terminé
   - Gestion des erreurs (doublons, rate limits)

7. **Améliorer `lib/features/export/fit_exporter.dart`**:
   - Ajouter compression GZIP optionnelle
   - S'assurer que le format est 100% compatible Strava

### Phase 4: Providers Riverpod

8. **Créer `lib/features/strava/strava_provider.dart`**:
   - `stravaConnectionProvider` - État de connexion (connecté/déconnecté)
   - `stravaUserProvider` - Informations utilisateur Strava
   - `stravaUploadProvider` - État de l'upload en cours

### Phase 5: Interface Utilisateur

9. **Modifier `lib/screens/export_screen.dart`**:
   - Remplacer le banner "Strava Sync" par un vrai bouton de connexion
   - Afficher l'état de connexion (connecté avec nom/avatar)
   - Bouton "Déconnecter" quand connecté
   - Pour chaque session: bouton "Envoyer vers Strava"

10. **Créer `lib/screens/strava_connect_screen.dart`** (optionnel):
    - Page dédiée pour la configuration Strava
    - Instructions pour créer une app Strava
    - Champs pour Client ID et Secret

### Phase 6: Intégration Post-Ride

11. **Modifier `lib/screens/dashboard_screen.dart`**:
    - Dans `_EndRideDialog`, ajouter option "Envoyer vers Strava"
    - Upload automatique si l'utilisateur est connecté et l'option activée

### Phase 7: File d'Attente Hors-Ligne

12. **Créer système de file d'attente**:
    - Si pas de connexion internet, sauvegarder l'upload en attente
    - Réessayer automatiquement quand la connexion revient

## Structure des Fichiers

```
lib/features/strava/
├── strava_config.dart        # Configuration (URLs, scopes)
├── strava_auth_service.dart  # Authentification OAuth2
├── strava_token_storage.dart # Stockage sécurisé des tokens
├── strava_upload_service.dart # Upload des activités
├── strava_provider.dart      # Providers Riverpod
└── strava_models.dart        # Modèles (StravaAthlete, UploadStatus)
```

## Dépendances à Ajouter

```yaml
dependencies:
  flutter_secure_storage: ^9.2.4
  app_links: ^6.3.3
  url_launcher: ^6.3.1
  archive: ^4.0.2
```

## Configuration Android

Dans `android/app/src/main/AndroidManifest.xml`, ajouter dans `<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="xwift" android:host="strava-callback" />
</intent-filter>
```

## Configuration iOS

Dans `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>xwift</string>
        </array>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>strava</string>
</array>
```

## Ordre d'Implémentation

1. Dépendances et configuration native (deep links)
2. Token storage et auth service
3. Provider pour l'état de connexion
4. UI de connexion dans ExportScreen
5. Upload service
6. Intégration dans ExportScreen (upload par session)
7. Intégration post-ride optionnelle

## Tests Manuels

1. Connexion OAuth complète
2. Refresh token après expiration
3. Upload d'une session
4. Gestion des doublons
5. Déconnexion et reconnexion
