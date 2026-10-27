# MarektLens

Application Flutter Android de simulation pédagogique, package Dart `marekt_lens`. Aucun paiement, courtage ou investissement réel.

## Lancer

Prérequis : Flutter >= 3.47 avec Dart >= 3.13, SDK Android, appareil ou émulateur.

```powershell
flutter pub get
flutter run
```

Sans clés, le mode démonstration est explicite et entièrement utilisable : créer un compte local, explorer les marchés, ajouter au panier, confirmer un achat, vendre, consulter l'historique et changer les préférences.

Avec des clés personnelles (ne pas enregistrer les valeurs dans le dépôt) :

```powershell
flutter run --dart-define=TWELVE_DATA_KEY=VOTRE_CLE --dart-define=FINNHUB_KEY=VOTRE_CLE --dart-define=GNEWS_KEY=VOTRE_CLE
```

Frankfurter ne nécessite pas de clé. Les comptes et portefeuilles sont séparés entre deux fichiers SQLite : `marekt_lens_demo.db` et `marekt_lens_normal.db`. Une panne API déclenche le mode démo et une reconnexion à l'environnement distinct. Le compte API est conservé. Chaque compte d'un environnement reçoit une seule fois 10 000 USD fictifs à sa création. Aucune session n'est conservée après fermeture de l'application.

## Choix de conception

- Riverpod fournit le contrôleur applicatif et le service de négociation ; `go_router` protège les pages et assure les trois destinations principales. Le contrôleur observable garde une architecture courte, adaptée à un projet individuel.
- SQLite conserve utilisateurs, catalogue par utilisateur, panier, positions et achats/ventes. Les mutations financières s'effectuent exclusivement dans `TradingService`, avec `db.transaction` et un identifiant aléatoire d'opération unique. La migration v1 → v2 ajoute la date d'observation du prix aux opérations existantes.
- Hive conserve réellement préférences, favoris et réponses API datées, avec des clés préfixées par mode et utilisateur. Aucun cache API n'est partagé entre utilisateurs.
- Mots de passe dérivés par PBKDF2-HMAC-SHA256, 210 000 itérations, sel aléatoire de 24 octets, clé de 256 bits. Il s'agit d'une authentification locale de démonstration ; le stockage n'est pas un coffre-fort chiffré.
- Montants en cents USD entiers. Le prix moyen est une fraction d'entiers réduite pour rester inchangé à la vente partielle. Les gains sont arrondis au cent le plus proche, demi-cent à l'opposé de zéro. Les `double` du graphique servent uniquement au tracé. Les taux de conversion sont également traités comme fractions décimales.
- La valeur totale est calculée à partir du solde et des positions. Aucun historique fictif de portefeuille. Les seules séries fictives sont les fixtures de cours clairement signalées en démo.
- Démo reproductible : horloge fixe au 23 octobre 2026 à 20:00 UTC et valeurs fixes ; les dates des opérations y utilisent cette horloge simulée. En mode API, l'horloge réelle s'applique. Un cours âgé de plus de 15 minutes bloque la négociation, même hors séance.
- La recherche porte sur six actions américaines : AAPL, MSFT, GOOGL, AMZN, NVDA, TSLA. L'historique de cours utilise jusqu'à 30 clôtures de séances ; la variation est calculée depuis la clôture précédente.

Les sources officielles, les politiques de cache et les versions sont dans [docs/API.md](docs/API.md). L'état de réalisation est dans [docs/CHECKLIST.md](docs/CHECKLIST.md).

## Vérifier

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Sur cette installation Windows, les hooks natifs des tests échouent si le chemin du SDK contient un espace. Le même SDK est accessible via son chemin court :

```powershell
& 'C:\Users\SOFIEN~1\flutter\flutter\bin\flutter.bat' test
```

Ce chemin est propre à cette machine. Consulter `docs/VALIDATION.md` pour les commandes réellement exécutées et leurs résultats.

## Structure

`lib/app` : thème et routeur ; `lib/core` : base, réseau, modèles, erreurs/formatage, widgets partagés ; `lib/features/{auth,dashboard,market,watchlist,cart,portfolio,profile}` : écrans et service métier.

Le parcours « mot de passe oublié » explique la récupération simulée sans envoyer de courriel ni changer le mot de passe. La volatilité optionnelle n'est pas incluse.
