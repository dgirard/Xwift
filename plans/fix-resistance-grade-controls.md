# fix: Les boutons de résistance et pente ne fonctionnent pas

## Overview

Les boutons +/- pour changer le grade (pente) et le slider de résistance ne semblent pas affecter le home trainer. L'UI se met à jour mais la commande FTMS n'est pas appliquée au vélo.

## Analyse du Problème

### Flux actuel des commandes

```
UI (GradeSelector)
  → _onGradeChanged()
    → ftmsControlProvider.setGrade()
      → setSimulationParams()
        → _sendCommand()
          → _processNextCommand()
            → _controlPoint.write()
```

### Points de défaillance potentiels identifiés

1. **`_controlPoint` est null** (`ftms_provider.dart:414`)
   - Si le service FTMS n'est pas trouvé ou si la caractéristique Control Point n'existe pas
   - Toutes les commandes échouent silencieusement

2. **`requestControl()` échoue** (`ftms_provider.dart:280-286`)
   - Appelé dans `initState()` du dashboard mais sans vérification du résultat
   - Si échoue, `hasControl = false` mais les commandes sont quand même envoyées

3. **Aucun logging de debug**
   - Impossible de savoir si les commandes sont envoyées
   - Impossible de savoir si le vélo répond

4. **Timeout silencieux** (`ftms_provider.dart:434-444`)
   - 5 secondes de timeout sans feedback utilisateur
   - Commandes expirées sans notification

5. **Pas de vérification `hasControl` avant envoi**
   - `setGrade()` et `setResistance()` ne vérifient pas si on a le contrôle

## Acceptance Criteria

- [ ] Ajouter des logs de debug pour tracer le flux des commandes FTMS
- [ ] Afficher un indicateur visuel quand `hasControl = false`
- [ ] Vérifier `hasControl` avant d'envoyer des commandes
- [ ] Ré-acquérir le contrôle automatiquement si perdu
- [ ] Afficher un feedback utilisateur si une commande échoue

## MVP - Ajout de debug logging

### 1. ftms_provider.dart - Ajouter logging

```dart
Future<void> _init() async {
  if (!_connectionState.isConnected) {
    print('[FTMS] Not connected, skipping init');
    return;
  }

  try {
    final services = _ref.read(bleConnectionProvider.notifier).services;
    if (services == null) {
      print('[FTMS] No services found');
      return;
    }

    final ftmsService = services.firstWhere(
      (s) => s.uuid == FtmsConstants.serviceUuid,
      orElse: () => throw Exception('FTMS service not found'),
    );
    print('[FTMS] Found FTMS service');

    for (final char in ftmsService.characteristics) {
      if (char.uuid == FtmsConstants.controlPoint) {
        _controlPoint = char;
        print('[FTMS] Found Control Point characteristic');
      }
      // ...
    }

    if (_controlPoint == null) {
      print('[FTMS] WARNING: Control Point characteristic not found!');
    }
    // ...
  } catch (e) {
    print('[FTMS] Error initializing: $e');
    state = state.copyWith(error: 'Failed to initialize FTMS: $e');
  }
}

Future<bool> requestControl() async {
  print('[FTMS] Requesting control...');
  final response = await _sendCommand([FtmsConstants.opCodeRequestControl]);
  print('[FTMS] Request control response: ${response.isSuccess} (code: ${response.resultCode})');
  if (response.isSuccess) {
    state = state.copyWith(hasControl: true);
  }
  return response.isSuccess;
}

Future<bool> setGrade(double grade) async {
  print('[FTMS] setGrade($grade) - hasControl: ${state.hasControl}');
  if (!state.hasControl) {
    print('[FTMS] No control, requesting...');
    final acquired = await requestControl();
    if (!acquired) {
      print('[FTMS] Failed to acquire control');
      return false;
    }
  }
  return setSimulationParams(grade: grade);
}

void _processNextCommand() {
  if (_isProcessingCommand || _commandQueue.isEmpty) return;
  if (_controlPoint == null) {
    print('[FTMS] ERROR: Control Point is null, cannot send command');
    // ...
    return;
  }

  final command = _commandQueue.removeAt(0);
  print('[FTMS] Sending command: ${command.bytes.map((b) => '0x${b.toRadixString(16)}').join(' ')}');
  // ...
}
```

### 2. dashboard_screen.dart - Afficher état du contrôle

```dart
@override
Widget build(BuildContext context) {
  final ftmsState = ref.watch(ftmsControlProvider);

  // Afficher un warning si pas de contrôle
  if (!ftmsState.hasControl) {
    return Banner(
      message: 'Pas de contrôle',
      color: Colors.orange,
      // ...
    );
  }
  // ...
}
```

## Étapes de Debug

1. **Déployer avec logs** et observer la console Flutter
2. **Vérifier l'initialisation**:
   - `[FTMS] Found FTMS service` doit apparaître
   - `[FTMS] Found Control Point characteristic` doit apparaître
3. **Vérifier requestControl**:
   - `[FTMS] Requesting control...` doit apparaître
   - `[FTMS] Request control response: true` attendu
4. **Tester les commandes**:
   - Appuyer sur +/- pour le grade
   - Observer `[FTMS] setGrade(X.X)` et `[FTMS] Sending command: ...`

## References

- `lib/features/ftms/ftms_provider.dart` - Provider FTMS
- `lib/widgets/grade_selector.dart` - Widget sélecteur de pente
- `lib/screens/dashboard_screen.dart:458-461` - Callback grade
- `lib/core/constants/ftms_constants.dart` - Constantes FTMS
