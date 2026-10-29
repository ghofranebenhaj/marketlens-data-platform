# MarektLens

Application mobile Flutter de **simulation d'investissement boursier** à but pédagogique. L'utilisateur reçoit un capital virtuel de 10 000 USD, consulte des actions, prépare des achats, vend, et suit la performance de son portefeuille.

> **Aucun ordre réel et aucun paiement réel ne sont exécutés.** Les prix peuvent être différés ou issus du cache : ils ne sont pas présentés comme du temps réel.

Projet du module *Mobile Software Engineering : Cross-Platform Flutter*.

## Auteurs

- Sofiene Landolsi ([@sofien91](https://github.com/sofien91))
- Ghofrane Ben Haj ([@ghofranebenhaj](https://github.com/ghofranebenhaj))

## Fonctionnalités

- Inscription et connexion locales (authentification de démonstration, mot de passe haché avec PBKDF2 et un sel aléatoire).
- Capital initial de 10 000 USD accordé une seule fois par utilisateur.
- Catalogue d'actions avec recherche, favoris, détail, graphique historique, fiche entreprise et actualités.
- Panier : quantités entières positives, vérification du solde, confirmation protégée contre la double validation.
- Achat et vente dans une transaction SQLite unique.
- Portefeuille : positions, prix moyen, valeur, gain ou perte non réalisé(e), gains réalisés et historique des transactions.
- Profil : devise d'affichage (conversion pour l'affichage uniquement), thème, profil de risque, déconnexion.
- Mode démonstration explicite, avec badge « Données de démonstration » et données séparées du mode normal.
- Cache horodaté pour la lecture hors ligne, avec mention de l'ancienneté des données.

## Technologies

| Besoin | Choix |
|---|---|
| Interface | Flutter, Dart (null safety), Material 3 |
| État et injection | flutter_riverpod |
| Navigation | go_router |
| HTTP | dio |
| Données métier | SQLite (sqflite, path) |
| Préférences, favoris, caches | Hive (hive, hive_flutter) |
| Graphiques | fl_chart |
| Formats | intl |
| Tests | flutter_test |

Les montants sont stockés en **cents USD (entiers)** pour éviter les erreurs d'arrondi des nombres décimaux.

## Services externes

| Service | Usage |
|---|---|
| Twelve Data | Prix et historiques |
| Finnhub | Fiches entreprises |
| Frankfurter | Taux de change (sans clé) |
| GNews | Actualités |

Les clés sont fournies à l'exécution avec `--dart-define` et ne sont **jamais** dans le dépôt. Une clé embarquée dans un APK n'est pas secrète : ne diffusez pas publiquement un APK construit avec vos clés. Les quotas dépendent de l'offre gratuite de chaque service.

## Prérequis (Windows)

- Flutter SDK (installé dans un dossier **sans espace**, par exemple `C:\src\flutter`)
- Android Studio avec le SDK Android et un émulateur (ou un téléphone avec le débogage USB)
- Git

Vérifiez l'installation :

```
flutter doctor -v
```

## Installation

```
git clone https://github.com/sofien91/MarketLens.git
cd MarketLens
flutter pub get
```

Placez le projet dans un chemin sans espace (par exemple `C:\dev\MarketLens`) : un espace dans le chemin casse la compilation des bibliothèques natives sous Windows.

## Lancer l'application

Démarrez un émulateur, puis :

```
flutter devices
flutter run -d emulator-5554
```

Sans clé API, l'application démarre en **mode démonstration**. Avec les vraies données :

```
flutter run -d emulator-5554 ^
  --dart-define=TWELVEDATA_KEY=<votre_cle> ^
  --dart-define=FINNHUB_KEY=<votre_cle> ^
  --dart-define=GNEWS_KEY=<votre_cle>
```

(Le caractère `^` continue la commande sur la ligne suivante dans cmd. Dans PowerShell, utilisez `` ` ``, ou écrivez tout sur une seule ligne.)

## Règles de simulation

- Devise comptable : USD. La conversion ne sert qu'à l'affichage.
- Valeur d'une position = quantité × dernier prix.
- Prix moyen = coût total / quantité.
- Gain non réalisé = valeur actuelle − coût.
- Gain réalisé d'une vente = (prix de vente − prix moyen) × quantité.
- Valeur totale du compte = solde + valeur des positions.
- Un achat ou une vente est refusé si le prix est trop ancien (au-delà de 15 minutes en séance).
- Seules les quantités entières strictement positives sont acceptées.

## Stockage local

- **SQLite** : utilisateurs, actifs, éléments du panier, positions, transactions (achats et ventes). Les données sont isolées par utilisateur (`user_id`) et la base est versionnée.
- **Hive** : préférences, favoris et caches de réponses API horodatés.

## Structure du projet

```
lib/
  app/          thème, routeur
  core/         base de données, réseau, modèles, argent, widgets partagés
  features/
    auth/  dashboard/  market/  watchlist/  cart/  portfolio/  profile/
test/           tests unitaires et de widgets
docs/           API.md, CHECKLIST.md, VALIDATION.md
```

## Tests

```
dart format .
flutter analyze
flutter test
```

Les tests couvrent notamment le capital initial unique, l'isolation entre utilisateurs, la quantité invalide, le solde insuffisant, la double validation, les calculs et arrondis, et la vente d'une quantité supérieure à celle détenue.

## Générer l'APK

```
flutter build apk --release ^
  --dart-define=TWELVEDATA_KEY=<votre_cle> ^
  --dart-define=FINNHUB_KEY=<votre_cle> ^
  --dart-define=GNEWS_KEY=<votre_cle>
```

Le fichier se trouve dans `build\app\outputs\flutter-apk\app-release.apk`.

## Limites connues

- Authentification **locale de démonstration** : pas de serveur de comptes ni de vrai envoi d'e-mail. Le « mot de passe oublié » est un parcours simulé.
- Les prix dépendent des données et des quotas des fournisseurs gratuits ; ils peuvent être différés.
- Aucun historique de portefeuille n'est inventé : sans données suffisantes, l'application l'indique.
- L'application est testée sur Android uniquement.

## Pistes d'extension

- Volatilité historique (écart-type des rendements, avec période et méthode indiquées).
- Assistant conversationnel documentaire (RAG) avec un petit backend FastAPI.

## Avertissement

MarektLens est un outil pédagogique. Il ne constitue pas un conseil financier.
