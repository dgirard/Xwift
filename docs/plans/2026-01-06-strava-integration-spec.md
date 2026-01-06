# **Rapport Technique Exhaustif : Architecture, Ingénierie et Implémentation de l'Intégration Strava au sein de l'Écosystème Xwift via Flutter**

## **1. Introduction Stratégique et Définition du Périmètre**

### **1.1 Contexte et Enjeux de l'Intégration**

Dans le paysage actuel des applications de fitness connecté, la perméabilité des données entre les plateformes d'acquisition (telles que **Xwift**, une application de cyclisme virtuel codée en Flutter) et les plateformes d'agrégation sociale est un vecteur critique de rétention utilisateur. **Strava**, positionné comme le leader mondial du suivi athlétique social, ne représente pas seulement un carnet d'entraînement numérique, mais agit comme un validateur social de l'effort physique. Pour une application comme Xwift, l'incapacité à synchroniser les données d'activité vers Strava constituerait une friction majeure, potentiellement rédhibitoire pour une base d'utilisateurs cyclistes particulièrement exigeante sur la télémétrie de performance (puissance, cadence, fréquence cardiaque).

Ce rapport détaille une feuille de route technique exhaustive pour l'intégration de l'API Strava V3 au sein de l'architecture Flutter de Xwift. L'analyse dépasse la simple implémentation de requêtes HTTP pour aborder les défis structurels : la gestion sécurisée du cycle de vie de l'authentification OAuth2 mobile, l'ingénierie complexe du format de fichier binaire FIT (Flexible and Interoperable Data Transfer), et la robustesse des transactions réseau asynchrones dans un environnement mobile contraint.

### **1.2 Analyse de la Stack Technologique**

L'écosystème Flutter, bien que puissant pour le rendu UI multiplateforme, impose des contraintes spécifiques lorsqu'il s'agit d'interagir avec des API natives et des systèmes de fichiers bas niveau. L'architecture proposée repose sur une sélection rigoureuse de bibliothèques Dart, validées pour leur stabilité et leur compatibilité avec les exigences de Strava.

| Composant Technique | Solution Recommandée | Justification Technique |
| :---- | :---- | :---- |
| **Langage** | Dart 3.x | Typage fort, null-safety, et performance native via AOT compilation. |
| **Architecture** | Clean Architecture | Découplage strict entre la logique métier (Xwift), les données (Strava API) et l'UI. |
| **Gestion d'État** | Riverpod | Gestion réactive des flux d'authentification et de progression d'upload. |
| **Réseau** | http | Support robuste pour les requêtes multipart/form-data complexes requises par l'upload de fichiers. |
| **Format de Données** | FIT natif | Manipulation bas niveau du protocole binaire FIT, supérieur au XML (TCX/GPX) pour les données de puissance. |
| **Sécurité** | flutter_secure_storage | Stockage crypté des tokens OAuth (Keychain sur iOS, Keystore sur Android). |
| **Deep Linking** | app_links | Gestion des redirections OAuth2 (App-to-App). |

---

## **2. Architecture Logicielle et Design Patterns**

### **2.1 Structuration des Couches**

#### **2.1.1 La Couche Data (Infrastructure)**

* **StravaAuthService:** Gère l'échange de codes d'autorisation et le rafraîchissement des tokens. Elle interagit directement avec flutter_secure_storage pour la persistance.
* **StravaUploadService:** Responsable de la construction des requêtes MultipartRequest, de la sérialisation des fichiers FIT, et du polling de l'état de traitement.
* **FitExporter:** Service dédié qui transforme les RideSession en flux d'octets conforme au protocole FIT.

#### **2.1.2 La Couche Domain (Business Logic)**

* **StravaRepository:** Interface définissant les contrats d'authentification et d'upload.
* **Providers Riverpod:** Gestion réactive de l'état de connexion Strava.

#### **2.1.3 La Couche Presentation (UI)**

* ExportScreen avec bouton de connexion Strava
* Indicateurs de progression d'upload
* Gestion des états (connecté, déconnecté, upload en cours)

---

## **3. Protocole d'Authentification OAuth 2.0**

### **3.1 Le Flux d'Autorisation (Authorization Code Grant)**

1. **Initiation:** Xwift construit une URL d'autorisation pointant vers `https://www.strava.com/oauth/mobile/authorize`.
2. **Délégation Système:** Xwift demande au système d'exploitation d'ouvrir cette URL.
3. **Consentement Utilisateur:** L'utilisateur valide les permissions (scopes) demandées.
4. **Redirection (Callback):** Strava redirige vers `xwift://strava-callback` contenant un code d'autorisation.
5. **Échange de Token:** Xwift intercepte cette URL, extrait le code, et effectue une requête POST pour obtenir les tokens.

### **3.2 Configuration des Scopes**

| Scope | Nécessité | Description |
| :---- | :---- | :---- |
| activity:read_all | Recommandé | Lire l'historique pour éviter les doublons |
| activity:write | **Critique** | Indispensable pour uploader des fichiers |
| profile:read_all | Optionnel | Afficher l'avatar et nom utilisateur |

### **3.3 Configuration Deep Links**

#### Android (AndroidManifest.xml)
```xml
<intent-filter android:label="strava_callback">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="xwift" android:host="strava-callback" />
</intent-filter>
```

#### iOS (Info.plist)
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
```

### **3.4 Gestion des Tokens**

Les access_tokens Strava expirent après 6 heures. Xwift doit:
1. Vérifier la date d'expiration stockée (expires_at)
2. Si proche de l'expiration, rafraîchir avec le refresh_token
3. Mettre à jour le stockage sécurisé

---

## **4. Upload vers Strava**

### **4.1 Endpoint et Format**

`POST https://www.strava.com/api/v3/uploads`

Paramètres:
* `file`: Fichier FIT (binaire)
* `data_type`: "fit"
* `activity_type`: "VirtualRide"
* `name`: Nom de la sortie
* `external_id`: UUID unique pour détecter les doublons

### **4.2 Polling Asynchrone**

1. Réponse initiale (201): Strava renvoie un `upload_id`
2. Polling `GET /uploads/{upload_id}` jusqu'à:
   - `status: "Your activity is ready."` → Succès
   - `error` non null → Échec

---

## **5. Références**

- Strava API Documentation: https://developers.strava.com/docs/
- OAuth Authentication: https://developers.strava.com/docs/authentication/
- Upload Documentation: https://developers.strava.com/docs/uploads/
- FIT Protocol: https://developer.garmin.com/fit/protocol/
