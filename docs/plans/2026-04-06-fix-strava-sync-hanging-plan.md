---
title: "Fix Strava sync hanging indefinitely after phone change"
type: fix
date: 2026-04-06
---

# Fix: Strava sync tourne sans fin apres changement de telephone

## Overview

Apres un changement de telephone (Pixel 10a, Android 16 API 36), la synchronisation Strava reste bloquee indefiniment (spinner infini). Le probleme est probablement multi-facteur : deep link OAuth qui ne revient pas dans l'app + perte des credentials stockees + absence de logs pour diagnostiquer.

## Analyse des causes racines

### 1. CRITIQUE : `android:autoVerify="true"` sur un custom scheme

**Fichier :** `android/app/src/main/AndroidManifest.xml:41`

```xml
<intent-filter android:autoVerify="true">
    <data android:scheme="xwift" android:host="localhost" android:pathPrefix="/callback" />
</intent-filter>
```

`autoVerify` est concu pour les App Links HTTPS et necessite un fichier `/.well-known/assetlinks.json` sur le domaine. Pour un scheme custom (`xwift://`), la verification echoue systematiquement. **Sur Android 12+ et surtout Android 16, cela peut empecher la livraison de l'intent a l'app**, ce qui expliquerait que le callback OAuth ne revient jamais et que l'app reste a l'etat "connecting" indefiniment.

### 2. HAUTE : Perte des credentials au changement de telephone

`flutter_secure_storage` est lie au device. En changeant de telephone, toutes les donnees sont perdues :
- Client ID / Client Secret
- Access token / Refresh token
- Info athlete

L'utilisateur doit reconfigurer ses credentials, mais si l'UI ne le signale pas clairement, il peut essayer de se connecter sans credentials valides.

### 3. HAUTE : Aucun timeout sur l'etat "connecting"

**Fichier :** `lib/features/strava/strava_provider.dart:116-126`

Quand `connect()` est appele, l'etat passe a `connecting` et ne revient jamais si le deep link n'est pas recu. Il n'y a aucun timeout pour revenir a un etat d'erreur.

### 4. MOYENNE : Erreurs avalees silencieusement

**Fichier :** `lib/features/strava/strava_auth_service.dart:23-29`

```dart
try {
  await refreshToken();
  return true;
} catch (e) {
  return false; // Aucun log, aucun feedback
}
```

Aucun logging nulle part dans le flux OAuth et upload, rendant le diagnostic impossible.

### 5. MOYENNE : Pas de retry sur 401 pendant l'upload

**Fichier :** `lib/features/strava/strava_upload_service.dart:76-77`

Si le token expire pendant l'upload, l'erreur 401 demande de se reconnecter au lieu de tenter un refresh automatique.

## Proposed Solution

### Phase 1 : Fix critique - Deep link et diagnostic

#### 1.1 Retirer `android:autoVerify="true"`

**`android/app/src/main/AndroidManifest.xml`**

```xml
<!-- AVANT -->
<intent-filter android:autoVerify="true">

<!-- APRES -->
<intent-filter>
```

#### 1.2 Ajouter du logging dans tout le flux Strava

Ajouter des `debugPrint()` dans :
- `StravaAuthService.isConnected()` - loguer les erreurs de refresh
- `StravaAuthService.initiateAuth()` - loguer l'URL construite
- `StravaAuthService.handleCallback()` - loguer l'URI recue
- `StravaAuthService.exchangeCodeForToken()` - loguer le status HTTP
- `StravaAuthService.refreshToken()` - loguer le status HTTP
- `StravaConnectionNotifier._listenForDeepLinks()` - loguer tous les deep links recus
- `StravaConnectionNotifier.handleCallback()` - loguer succes/erreur
- `StravaUploadService.uploadActivity()` - loguer chaque etape
- `StravaUploadService._pollForCompletion()` - loguer chaque tentative de polling

#### 1.3 Ajouter un timeout sur l'etat "connecting"

**`lib/features/strava/strava_provider.dart`**

Apres `initiateAuth()`, demarrer un timer de 2 minutes. Si le callback n'est pas recu, revenir a l'etat `error` avec un message explicatif.

```dart
Future<void> connect() async {
  try {
    state = state.copyWith(status: StravaConnectionStatus.connecting);
    await _authService.initiateAuth();

    // Timeout si le callback n'arrive pas
    Future.delayed(const Duration(minutes: 2), () {
      if (state.status == StravaConnectionStatus.connecting) {
        state = state.copyWith(
          status: StravaConnectionStatus.error,
          error: 'Le retour de Strava n\'a pas ete recu. '
              'Verifiez que l\'app Strava est installee ou reessayez.',
        );
      }
    });
  } catch (e) {
    state = state.copyWith(
      status: StravaConnectionStatus.error,
      error: e.toString(),
    );
  }
}
```

### Phase 2 : Robustesse

#### 2.1 Retry automatique sur 401 pendant l'upload

**`lib/features/strava/strava_upload_service.dart`**

Si l'upload recoit un 401, tenter un refresh token + retry une seule fois avant d'echouer.

#### 2.2 Meilleur feedback UI sur l'etat des credentials

**`lib/screens/export_screen.dart`**

Quand l'etat est `notConfigured`, afficher un message clair demandant de reconfigurer les credentials API Strava (client ID + secret).

#### 2.3 Test du deep link via ADB

Ajouter une commande de test documentee :
```bash
adb shell am start -W -a android.intent.action.VIEW -d "xwift://localhost/callback?code=test"
```
Cela permet de verifier que le deep link est bien recu par l'app sans passer par Strava.

## Acceptance Criteria

- [x] Le deep link OAuth fonctionne sur Android 16 (Pixel 10a)
- [x] L'etat "connecting" a un timeout de 2 minutes avec message d'erreur clair
- [x] Les logs permettent de diagnostiquer les problemes (visibles dans `flutter run` / logcat)
- [x] Un 401 pendant l'upload tente automatiquement un refresh token
- [ ] Le changement de telephone est gere proprement (message clair pour reconfigurer)
- [x] Le test ADB `adb shell am start ... xwift://localhost/callback?code=test` declenche bien le callback dans l'app

## Fichiers a modifier

| Fichier | Modification |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Retirer `android:autoVerify="true"` |
| `lib/features/strava/strava_auth_service.dart` | Ajouter logging partout |
| `lib/features/strava/strava_provider.dart` | Timeout sur connecting, logging deep links |
| `lib/features/strava/strava_upload_service.dart` | Retry sur 401, logging |
| `lib/screens/export_screen.dart` | Meilleur feedback UI pour etat notConfigured |

## Priorite de correction

1. **Immediat** : Retirer `autoVerify` + ajouter logs → rebuilder et tester
2. **Diagnostic** : Tester le deep link via ADB sur le nouveau telephone
3. **Si le deep link fonctionne** : Le probleme etait `autoVerify` → completer phase 2
4. **Si le deep link ne fonctionne pas** : Investiguer le comportement d'Android 16 avec les custom schemes, potentiellement migrer vers un verified HTTPS deep link

## References

- Commit original Strava : `f9fade1`
- Fix export FIT/TCX : `7129b4f`
- Spec Strava : `docs/plans/2026-01-06-strava-integration-spec.md`
- [Android App Links docs](https://developer.android.com/training/app-links)
- [Android 12+ deep link changes](https://developer.android.com/about/versions/12/behavior-changes-all#web-intent-resolution)
