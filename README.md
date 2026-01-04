# Xwift

Application Android pour controler les home trainers connectes via Bluetooth FTMS (Fitness Machine Service).

## Description

Xwift est une application Flutter qui permet de controler votre velo d'appartement ou home trainer compatible FTMS directement depuis votre smartphone Android. L'application communique via Bluetooth Low Energy (BLE) avec votre equipement pour ajuster la resistance et collecter les donnees d'entrainement en temps reel.

### Fonctionnalites principales

- **Connexion Bluetooth FTMS** : Detection et connexion automatique aux home trainers compatibles FTMS
- **Mode SIM** : Simulation de pente (-10% a +10%) pour reproduire les conditions de terrain
- **Mode ERG** : Maintien d'une puissance cible constante (ideal pour les entrainements structures)
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

1. **Ecran d'accueil** : Lancez l'application et appuyez sur "Connecter"
2. **Connexion** : Selectionnez votre home trainer dans la liste des appareils detectes
3. **Dashboard** : Une fois connecte, vous arrivez sur l'ecran principal
   - Choisissez le mode SIM ou ERG
   - En mode SIM, ajustez la pente avec les boutons +/-
   - En mode ERG, definissez votre puissance cible
4. **Demarrer** : Appuyez sur "Demarrer" pour lancer la session
5. **Fin de session** : Appuyez sur "Arreter" puis "Sauvegarder" pour conserver vos donnees

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
