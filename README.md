# Xwift

Application Android pour controler les home trainers connectes via Bluetooth FTMS (Fitness Machine Service).

## Description

Xwift est une application Flutter qui permet de controler votre velo d'appartement ou home trainer compatible FTMS directement depuis votre smartphone Android. L'application communique via Bluetooth Low Energy (BLE) avec votre equipement pour ajuster la resistance et collecter les donnees d'entrainement en temps reel.

### Fonctionnalites principales

- **Connexion Bluetooth FTMS** : Detection et connexion automatique aux home trainers compatibles FTMS
- **Un seul écran de sortie** : trois modes exclusifs pour régler l'effort, Pente (simulation, −10 % à +20 %), Puissance (ERG) et Résistance, avec gros boutons −/+, raccourcis et confirmation de ce que le home trainer a appliqué
- **Programmes ERG** : exemples calculés sur votre FTP ou fichiers .zwo/.erg/.mrc importés, intervalle suivant, « Passer », intensité ±5 %
- **Fonctionne sans home trainer** : les réglages sont gardés et envoyés à la connexion ; reconnexion automatique au dernier appareil
- **Moniteur cardiaque** : Connexion a une ceinture ou montre cardiaque Bluetooth
- **Telemetrie en temps reel** : Affichage de la puissance, cadence, vitesse et frequence cardiaque
- **Zones de puissance** : Visualisation coloree basee sur votre FTP
- **Historique des sessions** : Sauvegarde et consultation de vos entrainements
- **Export FIT/TCX** : Partage de vos activites vers Strava ou autres applications

### Equipements compatibles

L'application fonctionne avec tout home trainer supportant le protocole Bluetooth FTMS, notamment :
- Zwift Ride
- Wahoo KICKR (toutes versions)
- Tacx Neo / Flux
- Elite Direto / Suito
- Saris H3
- Et bien d'autres...

## Installation

### Prerequis

- Flutter SDK 3.x
- Android SDK
- Un appareil Android avec Bluetooth Low Energy

### Build

```bash
# Cloner le repository
git clone https://github.com/dgirard/Xwift.git
cd Xwift

# Installer les dependances
flutter pub get

# Generer les fichiers Drift (base de donnees)
dart run build_runner build

# Lancer sur un appareil connecte
flutter run
```

### Permissions requises

L'application necessite les permissions suivantes sur Android :
- `BLUETOOTH_SCAN` : Pour rechercher les appareils Bluetooth
- `BLUETOOTH_CONNECT` : Pour se connecter aux appareils
- `ACCESS_FINE_LOCATION` : Requis par Android pour le scan Bluetooth

## Utilisation

1. **Accueil** : touchez « Rouler ». L'application fonctionne aussi sans home trainer (chrono, cardio) ; « Connecter un home trainer » ouvre la recherche.
2. **Connexion** : allumez le home trainer, pédalez quelques tours, puis touchez son nom. Xwift s'en souvient et s'y reconnecte seul, au lancement et après une coupure. En haut de l'écran de sortie, la pastille montre l'état de la connexion. Un toucher reconnecte le home trainer ou ouvre le diagnostic : données reçues par seconde, contrôle obtenu, modes pris en charge.
3. **Régler l'effort** : choisissez Pente, Puissance ou Résistance, puis utilisez les boutons − / + (maintenir pour répéter) ou les raccourcis. La ligne d'état indique si le home trainer a appliqué le réglage, ou pourquoi il l'a refusé.
4. **Programme** : en mode Puissance, « Suivre un programme » lance un entraînement ; la puissance suit les intervalles pendant l'enregistrement.
5. **Enregistrer** : « Démarrer la sortie », puis « Pause » ; en pause, « Terminer » pour nommer et enregistrer la sortie (ou la supprimer).

Les valeurs affichent « -- » quand le home trainer n'envoie rien : jamais de valeur figée.

### Tests

```bash
flutter test
```

## Architecture technique

- **Flutter/Dart** : Framework UI cross-platform
- **Riverpod** : Gestion d'etat reactive
- **flutter_blue_plus** : Communication Bluetooth Low Energy
- **Drift** : Base de donnees SQLite locale
- **GoRouter** : Navigation declarative

## Protocole FTMS

L'application utilise le protocole Bluetooth FTMS (Fitness Machine Service - UUID 0x1826) standardise par le Bluetooth SIG pour communiquer avec les equipements de fitness. Les caracteristiques utilisees incluent :

- `Indoor Bike Data (0x2AD2)` : Reception des donnees de telemetrie
- `Fitness Machine Control Point (0x2AD9)` : Envoi des commandes de controle
- `Fitness Machine Status (0x2ADA)` : Notifications d'etat

## Licence

Ce projet est sous licence MIT.

## Auteur

Didier Girard - [@dgirard](https://github.com/dgirard)
