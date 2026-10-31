# MarketLens

**MarketLens** est une application mobile développée avec Flutter et Dart dans le cadre du module **Mobile Software Engineering: Cross-Platform Flutter**.

Elle permet de simuler des investissements boursiers dans un environnement pédagogique. Chaque utilisateur dispose d'un capital virtuel initial de **10 000 USD** pour découvrir les marchés financiers, consulter des actions, effectuer des achats et des ventes simulés et suivre l'évolution de son portefeuille.

> **Important :** MarketLens est exclusivement une application de simulation. Aucun ordre boursier réel ni aucun paiement réel ne sont exécutés. Les prix affichés peuvent être différés ou provenir du cache et ne sont pas nécessairement en temps réel.

---

## Auteurs

- **Sofiene Landolsi** — [@sofien91](https://github.com/sofien91)
- **Ghofrane Ben Haj** — [@ghofranebenhaj](https://github.com/ghofranebenhaj)

**Repository :** [github.com/sofien91/MarketLens](https://github.com/sofien91/MarketLens)

---

## Fonctionnalités principales

### 1. Authentification et gestion des comptes
- Inscription et connexion locales.
- Hachage des mots de passe avec PBKDF2 et sel aléatoire.
- Validation des informations de connexion.
- Attribution d'un capital initial de 10 000 USD, une seule fois par utilisateur.
- Isolation des données entre les différents comptes.
- Parcours de récupération de mot de passe simulé.

### 2. Exploration des marchés
- Catalogue de six actions.
- Recherche d'actions.
- Gestion des favoris.
- Consultation des prix avec horodatage.
- Graphiques historiques.
- Fiches d'informations sur les entreprises.
- Consultation des actualités financières.

### 3. Simulation des achats et des ventes
- Ajout d'actions au panier.
- Saisie de quantités entières positives.
- Vérification du solde disponible.
- Protection contre la double validation.
- Exécution des achats et ventes simulés.
- Transactions SQLite atomiques.
- Refus des opérations lorsque le prix est trop ancien.

### 4. Gestion du portefeuille
- Consultation des positions détenues.
- Calcul du prix moyen d'achat.
- Calcul de la valeur actuelle du portefeuille.
- Suivi des gains et pertes non réalisés.
- Calcul des gains et pertes réalisés.
- Historique des transactions.
- Consultation du solde et du capital total.

### 5. Profil et préférences
- Gestion des préférences utilisateur.
- Choix de la devise d'affichage.
- Personnalisation du thème.
- Paramètres de profil de risque.
- Déconnexion.

### 6. Mode démonstration et fonctionnement hors ligne
- Mode démonstration avec données prédéfinies.
- Badge identifiant les données de démonstration.
- Stockage séparé des données de démonstration.
- Mise en cache horodatée des réponses API.
- Consultation des données mises en cache hors ligne.
- Indication de l'ancienneté des données.

---

## Technologies utilisées

| Domaine | Technologies |
|---|---|
| Application mobile | Flutter, Dart |
| Interface utilisateur | Material 3 |
| Gestion d'état | Riverpod |
| Navigation | GoRouter |
| Communication HTTP | Dio |
| Base de données locale | SQLite, sqflite |
| Chemins et stockage | path |
| Préférences et cache | Hive, hive_flutter |
| Graphiques | fl_chart |
| Formatage et dates | intl |
| Tests | flutter_test |

Les montants financiers sont stockés sous forme de **centimes USD (entiers)** afin de limiter les erreurs d'arrondi liées aux nombres décimaux.

---

## Services et API externes

MarketLens utilise plusieurs services pour enrichir les informations financières affichées dans l'application.

| Service | Utilisation |
|---|---|
| [Twelve Data](https://twelvedata.com/) | Prix des actions et données historiques |
| [Finnhub](https://finnhub.io/) | Informations et profils des entreprises |
| [Frankfurter](https://www.frankfurter.app/) | Taux de change |
| [GNews](https://gnews.io/) | Actualités financières |

### Configuration des clés API

Les clés API sont transmises au lancement avec `--dart-define`.

Les variables utilisées sont :

- `TWELVE_DATA_KEY`
- `FINNHUB_KEY`
- `GNEWS_KEY`

Frankfurter ne nécessite pas de clé API.

**Sécurité :**
- Ne jamais publier les clés API dans le dépôt GitHub.
- Ne jamais intégrer directement les clés dans le code source.
- Une clé transmise à une application mobile via `--dart-define` peut être extraite de l'APK : cette méthode ne constitue donc pas une protection contre la récupération des clés.
- Éviter de distribuer publiquement un APK contenant des clés personnelles.

Les quotas et les limitations dépendent des offres des fournisseurs.

---

## Prérequis

Pour installer et exécuter le projet sous Windows :

- Windows 10 ou Windows 11.
- Flutter SDK.
- Dart SDK (fourni avec Flutter).
- Android Studio.
- Android SDK.
- Un émulateur Android ou un téléphone Android avec le débogage USB activé.
- Git.
- Visual Studio Code (recommandé).

Vérifier l'environnement :

```cmd
flutter doctor -v
```

---

## Installation du projet

Cloner le dépôt GitHub :

```cmd
git clone https://github.com/sofien91/MarketLens.git
```

Accéder au dossier :

```cmd
cd MarketLens
```

Installer les dépendances :

```cmd
flutter pub get
```

**Important sous Windows :** privilégier un chemin de projet sans espaces, par exemple :

```text
C:\dev\MarketLens
```

---

## Exécution de l'application

### 1. Vérifier les appareils disponibles

```cmd
flutter devices
```

Démarrer un émulateur Android depuis Android Studio ou connecter un téléphone.

### 2. Lancer l'application

```cmd
flutter run
```

Pour utiliser un émulateur précis :

```cmd
flutter run -d emulator-5554
```

### 3. Lancer avec les clés API

Dans Windows CMD :

```cmd
flutter run -d emulator-5554 ^
  --dart-define=TWELVE_DATA_KEY=YOUR_TWELVE_DATA_KEY ^
  --dart-define=FINNHUB_KEY=YOUR_FINNHUB_KEY ^
  --dart-define=GNEWS_KEY=YOUR_GNEWS_KEY
```

Remplacer les valeurs `YOUR_..._KEY` par les clés personnelles correspondantes.

Pour PowerShell, utiliser une commande sur une seule ligne ou remplacer le caractère de continuation CMD `^` par le caractère de continuation PowerShell `` ` ``.

---

## Règles de simulation financière

Les opérations sont calculées en USD.

| Indicateur | Formule |
|---|---|
| Valeur d'une position | Quantité × Dernier prix |
| Prix moyen d'achat | Coût total / Quantité détenue |
| Gain ou perte non réalisé(e) | Valeur actuelle − Coût de revient |
| Gain ou perte réalisé(e) | (Prix de vente − Prix moyen) × Quantité vendue |
| Valeur totale du compte | Solde disponible + Valeur des positions |

Autres règles :

- La devise comptable reste le USD.
- La conversion monétaire concerne uniquement l'affichage.
- Les quantités doivent être des nombres entiers strictement positifs.
- Un achat ou une vente est refusé lorsque le prix utilisé est trop ancien (plus de 15 minutes en séance).
- Les opérations financières sont enregistrées dans des transactions SQLite.

---

## Stockage et persistance des données

MarketLens utilise deux solutions de stockage local complémentaires.

### SQLite

SQLite assure la persistance des données métier :

- Utilisateurs.
- Actifs financiers.
- Éléments du panier.
- Positions du portefeuille.
- Transactions d'achat et de vente.

La base de données est versionnée et prévoit la gestion des migrations.

Les données sont isolées par utilisateur grâce à l'identifiant `user_id`.

### Hive

Hive est utilisé pour :

- Les préférences utilisateur.
- Les favoris.
- Les caches des réponses API.
- Les informations nécessaires au fonctionnement hors ligne.

---

## Structure du projet

```text
MarketLens/
│
├── lib/
│   ├── app/
│   │   ├── theme/
│   │   └── router/
│   │
│   ├── core/
│   │   ├── database/
│   │   ├── network/
│   │   ├── models/
│   │   ├── money/
│   │   └── widgets/
│   │
│   └── features/
│       ├── auth/
│       ├── dashboard/
│       ├── market/
│       ├── watchlist/
│       ├── cart/
│       ├── portfolio/
│       └── profile/
│
├── test/
│
├── docs/
│   ├── API.md
│   ├── CHECKLIST.md
│   └── VALIDATION.md
│
├── android/
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

---

## Tests et qualité du code

Les commandes suivantes permettent de vérifier le projet.

### Formater le code

```cmd
dart format .
```

### Vérifier les erreurs et avertissements

```cmd
flutter analyze
```

### Exécuter les tests automatisés

```cmd
flutter test
```

Les tests couvrent notamment :

- L'attribution unique du capital initial.
- L'isolation des comptes utilisateurs.
- La validation des quantités.
- Le contrôle du solde disponible.
- La protection contre la double validation.
- Les calculs financiers et les arrondis.
- La validation des opérations de vente.
- La prévention des ventes supérieures aux quantités détenues.

### Résultats des dernières vérifications

| Vérification | Résultat |
|---|---|
| `flutter pub get` | Réussi |
| `flutter analyze` | Aucune anomalie |
| `flutter test` | 23 tests réussis |
| Build Android Release | Réussi |
| Installation de l'APK sur émulateur | Réussie |

**Dernière validation locale : 31 octobre 2026.**

Le build Release de 52,9 MB a été généré le 30 octobre 2026 et installé avec succès sur un émulateur Android.

Les résultats des tests automatisés ne remplacent pas une validation fonctionnelle complète de chaque écran et de chaque intégration API.

---

## Génération de l'APK Android

Pour générer une version Release :

```cmd
flutter build apk --release ^
  --dart-define=TWELVE_DATA_KEY=YOUR_TWELVE_DATA_KEY ^
  --dart-define=FINNHUB_KEY=YOUR_FINNHUB_KEY ^
  --dart-define=GNEWS_KEY=YOUR_GNEWS_KEY
```

Le fichier APK est généré dans :

```text
build\app\outputs\flutter-apk\app-release.apk
```

Pour installer l'APK sur un appareil Android connecté :

```cmd
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## Limites connues

- L'authentification est locale et pédagogique : aucun serveur de comptes n'est utilisé.
- La récupération du mot de passe est simulée et ne réalise pas de véritable réinitialisation par e-mail.
- Les prix dépendent des fournisseurs de données et de leurs quotas.
- Les prix peuvent être différés ou provenir du cache.
- Les fonctionnalités de simulation ne permettent aucune transaction boursière réelle.
- La volatilité historique n'est pas incluse dans la version actuelle.
- L'application a été testée sur Android ; les autres plateformes ne sont pas validées.

---

## Perspectives d'amélioration

Plusieurs évolutions peuvent être envisagées :

- Ajouter des indicateurs de risque financier, notamment la volatilité historique calculée à partir des rendements.
- Enrichir les graphiques et les analyses de performance.
- Ajouter des fonctionnalités avancées de comparaison des actifs.
- Développer un assistant conversationnel documentaire basé sur une architecture RAG avec un backend FastAPI.
- Améliorer la couverture des tests et la validation sur différents appareils.

---

## Avertissement

MarketLens est un projet académique à vocation pédagogique.

Il permet de découvrir les mécanismes de base de la gestion d'un portefeuille d'investissement à travers des opérations fictives.

**Cette application ne constitue pas un conseil financier et ne doit pas être utilisée pour prendre des décisions d'investissement réelles.**

---

**Développé par Sofiene Landolsi et Ghofrane Ben Haj.**