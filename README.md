MarketLens Data Platform

Simulateur pédagogique d'investissement boursier : une application mobile Flutter et un backend Python qui calcule des indicateurs de risque sur des prix réels et les fait expliquer en français par un modèle de langage, sans jamais lui laisser inventer un chiffre.

Aucun ordre réel et aucun paiement réel ne sont exécutés. Les prix sont datés et peuvent être différés ou issus du cache : ils ne sont jamais présentés comme du temps réel. Les analyses sont des simulations pédagogiques, pas des conseils financiers.

Projet du module Mobile Software Engineering : Cross-Platform Flutter, prolongé par une extension Data et IA.

Dépôt : ghofranebenhaj/marketlens-data-platform

Dernière mise à jour : 5 novembre 2026.

Auteurs
Ghofrane Ben Haj (@ghofranebenhaj)
<!-- Ajoute ici ton collègue seulement s'il a contribué au code : - Prénom Nom (@compte) -->
Architecture
┌──────────────────────────┐        ┌─────────────────────────────────────────────┐
│  Application Flutter     │        │  Backend Python (FastAPI)                   │
│  SQLite, Hive, Riverpod  │        │                                             │
│                          │        │  Twelve Data ─► cache horodaté              │
│  Twelve Data, Finnhub,   │        │                    │                        │
│  Frankfurter, GNews      │        │                    ▼                        │
└──────────────────────────┘        │  Indicateurs (NumPy) ─► Signal ─► Scénario  │
                                    │                    │                        │
                                    │  Recherche documentaire (TF-IDF)            │
                                    │                    │                        │
                                    │                    ▼                        │
                                    │  Gemini : explique les chiffres calculés    │
                                    │  Serveur : sources + avertissement          │
                                    └─────────────────────────────────────────────┘

Principe central : les chiffres viennent du code, jamais du modèle de langage. Le modèle reçoit des résultats déjà calculés et les explique. Le serveur construit lui-même les sources et ajoute le rappel « Simulation pédagogique, pas un conseil financier. ». Si le modèle est absent ou si sa sortie contient un nombre inconnu, le serveur répond par un gabarit, clairement étiqueté.

L'écran Assistant n'est pas encore branché dans l'application Flutter : le backend se teste aujourd'hui avec http://localhost:8000/docs.

Partie 1 : application Flutter
Fonctionnalités
Inscription et connexion locales (authentification de démonstration, mot de passe haché avec PBKDF2 et un sel aléatoire).
Capital initial de 10 000 USD accordé une seule fois par utilisateur.
Catalogue d'actions avec recherche, favoris, détail, graphique historique, fiche entreprise et actualités.
Panier : quantités entières positives, vérification du solde, confirmation protégée contre la double validation.
Achat et vente dans une transaction SQLite unique.
Portefeuille : positions, prix moyen, valeur, gain ou perte non réalisé(e), gains réalisés et historique des transactions.
Profil : devise d'affichage (conversion pour l'affichage uniquement), thème, profil de risque, déconnexion.
Mode démonstration explicite, avec badge « Données de démonstration » et données séparées du mode normal.
Cache horodaté pour la lecture hors ligne, avec mention de l'ancienneté des données.
Technologies
Besoin	Choix
Interface	Flutter, Dart (null safety), Material 3
État et injection	flutter_riverpod
Navigation	go_router
HTTP	dio
Données métier	SQLite (sqflite, path)
Préférences, favoris, caches	Hive (hive, hive_flutter)
Graphiques	fl_chart
Formats	intl
Tests	flutter_test

Les montants sont stockés en cents USD (entiers) pour éviter les erreurs d'arrondi des nombres décimaux.

Services externes
Service	Usage
Twelve Data	Prix et historiques
Finnhub	Fiches entreprises
Frankfurter	Taux de change (sans clé)
GNews	Actualités

Les clés de l'application sont fournies à l'exécution avec --dart-define et ne sont jamais dans le dépôt. Une clé embarquée dans un APK n'est pas secrète : ne diffusez pas publiquement un APK construit avec vos clés. Les quotas dépendent de l'offre gratuite de chaque service.

Prérequis (Windows)
Flutter SDK (installé dans un dossier sans espace, par exemple C:\src\flutter)
Android Studio avec le SDK Android et un émulateur (ou un téléphone avec le débogage USB)
Git
flutter doctor -v
Installation
git clone https://github.com/ghofranebenhaj/marketlens-data-platform.git
cd marketlens-data-platform
flutter pub get

Placez le projet dans un chemin sans espace (par exemple C:\dev\MarketLens) : un espace dans le chemin casse la compilation des bibliothèques natives sous Windows.

Lancer l'application

Démarrez un émulateur, puis :

flutter devices
flutter run -d emulator-5554

Sans clé API, l'application démarre en mode démonstration. Avec les vraies données :

flutter run -d emulator-5554 ^
  --dart-define=TWELVEDATA_KEY=<votre_cle> ^
  --dart-define=FINNHUB_KEY=<votre_cle> ^
  --dart-define=GNEWS_KEY=<votre_cle>

(Le caractère ^ continue la commande sur la ligne suivante dans cmd. Dans PowerShell, utilisez `, ou écrivez tout sur une seule ligne.)

Règles de simulation
Devise comptable : USD. La conversion ne sert qu'à l'affichage.
Valeur d'une position = quantité × dernier prix.
Prix moyen = coût total / quantité.
Gain non réalisé = valeur actuelle − coût.
Gain réalisé d'une vente = (prix de vente − prix moyen) × quantité.
Valeur totale du compte = solde + valeur des positions.
Un achat ou une vente est refusé si le prix est trop ancien (au-delà de 15 minutes en séance). Quand le marché est fermé, l'opération reste bloquée tant que le prix n'est pas actualisé : règle à affiner pour la dernière séance.
Seules les quantités entières strictement positives sont acceptées.
Stockage local
SQLite : utilisateurs, actifs, éléments du panier, positions, transactions (achats et ventes). Les données sont isolées par utilisateur (user_id) et la base est versionnée.
Hive : préférences, favoris et caches de réponses API horodatés.
Tests Flutter
dart format .
flutter analyze
flutter test

Les tests couvrent notamment le capital initial unique, l'isolation entre utilisateurs, la quantité invalide, le solde insuffisant, la double validation, les calculs et arrondis, et la vente d'une quantité supérieure à celle détenue.

Générer l'APK
flutter build apk --release ^
  --dart-define=TWELVEDATA_KEY=<votre_cle> ^
  --dart-define=FINNHUB_KEY=<votre_cle> ^
  --dart-define=GNEWS_KEY=<votre_cle>

Le fichier se trouve dans build\app\outputs\flutter-apk\app-release.apk.

Partie 2 : backend d'analyse (Python)

Un petit backend FastAPI, dans le dossier backend/, ajoute une couche Data et IA :

Ingestion : historique journalier via Twelve Data, avec délai d'attente, reprises limitées, gestion des erreurs HTTP, des quotas et des réponses vides, et cache serveur horodaté.
Catalogue : seuls les symboles du catalogue de l'application sont acceptés.
Indicateurs (NumPy, fonctions pures testées) : rendement, volatilité, drawdown maximum, moyennes mobiles. Chaque résultat indique sa période, sa méthode et ses dates de début et de fin. Si l'historique est trop court, le résultat est « historique insuffisant » au lieu d'une valeur inventée.
Signal pédagogique : score à règles visibles, avec la liste des conditions remplies.
Scénario « Et si ? » : résultat d'un achat passé comparé à la dernière clôture connue, calculé sans frais avec Decimal, jamais en flottants.
Assistant : question en français, routage déterministe (symbole et intention), recherche de passages dans un petit corpus de documentation (TF-IDF avec NumPy), puis explication rédigée par Gemini.
Endpoints
Endpoint	Rôle
GET /health	Vérification du serveur
GET /assets/{symbol}/indicators	Rendements, volatilité, drawdown, moyennes mobiles
GET /assets/{symbol}/signal	Signal pédagogique et conditions remplies
GET /assets/{symbol}/scenario?quantity=&sessions=	Scénario « Et si ? »
POST /chat	Question de 500 caractères maximum ; réponse { answer, data, sources, disclaimer, generated_by }

generated_by vaut "llm" quand Gemini a rédigé la réponse, et "template" quand elle vient d'un gabarit construit par le code. data contient toujours les valeurs brutes calculées.

Formules
Indicateur	Méthode
Rendement sur N séances	C_fin / C_N_séances_avant − 1
Volatilité annualisée	écart-type (échantillon, ddof=1) des rendements journaliers simples × √252
Drawdown maximum	min(C_t / max(C_0…C_t) − 1) sur la fenêtre
Moyenne mobile simple (20 et 50)	somme des N dernières clôtures / N

Signal pédagogique (valeurs par défaut ; les constantes sont nommées et documentées dans le fichier de configuration du backend) :

+1 si le rendement sur 20 séances est positif ;
+1 si le dernier cours est au-dessus de la moyenne mobile 50 ;
−1 si la volatilité annualisée dépasse 40 % ;
−1 si le drawdown maximum est pire que −15 %.

Score ≥ 2 : « favorable » ; score ≤ −1 : « prudence » ; sinon « neutre ». Le signal ne dit jamais d'acheter ou de vendre.

Règles de l'assistant
Aucune clé (modèle de langage, Twelve Data) dans Flutter, les assets ou le dépôt : elles vivent dans backend/.env, ignoré par Git.
L'assistant ne prédit jamais un prix ni un rendement futur, et ne donne pas d'ordre d'achat ou de vente. Il présente des indicateurs et un signal pédagogique avec leur formule, leur période et la date des données.
Il ne donne ni prix actuel, ni solde, ni positions : il renvoie vers l'écran Marchés ou Portefeuille.
Tous les chiffres viennent du code. Les sources affichées sont construites par le serveur.
Si les données ou la documentation sont insuffisantes, il le dit (« historique insuffisant », « la documentation ne permet pas de répondre »).
Sans clé de modèle, ou si le modèle échoue, la réponse est un gabarit clairement étiqueté template, avec la cause du repli.
Chaque réponse porte le rappel « Simulation pédagogique, pas un conseil financier. », ajouté par le serveur.
Lancer le backend (Windows)

Depuis le dossier backend, dans cmd :

python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
notepad .env
pytest
uvicorn app.main:app --host 0.0.0.0 --port 8000

Puis ouvrez http://localhost:8000/docs pour essayer les endpoints.

Testé avec Python 3.14.3 sous Windows ; les autres versions ne sont pas vérifiées. Les versions des dépendances sont figées dans backend/requirements.txt.

Si le port 8000 est déjà occupé, un ancien serveur tourne encore : netstat -ano | findstr :8000, puis taskkill /PID <numéro> /F.

Variables d'environnement (backend/.env)
Variable	Rôle
TWELVEDATA_KEY	Clé Twelve Data (historique de prix)
GEMINI_API_KEY	Clé Gemini (explications ; facultative, sinon gabarit)
GEMINI_MODEL	Nom du modèle de génération, configurable (exemple : gemini-3.6-flash)
REQUIRE_LLM	false : repli par gabarit ; true : erreur 503 si le modèle est indisponible

Le fichier backend/.env.example ne contient aucun secret. Ne commitez jamais backend/.env. Les noms de modèles évoluent : vérifiez-les dans la documentation officielle de Google.

Tests du backend
cd backend
pytest

Les tests s'exécutent sans réseau (client Twelve Data et modèle simulés). Ils couvrent les indicateurs sur des séries connues, l'historique insuffisant, le signal, le scénario vérifié à la main, les refus (prix actuel, solde, prédiction, conseil d'achat), la question trop longue, le symbole inconnu, le repli par gabarit, l'absence de clé et le cache.

Évaluation de l'assistant

docs/CHATBOT_EVAL.md liste des questions couvertes, non couvertes et ambiguës, avec le résultat attendu pour chacune. Aucun score n'y est inventé.

Limites connues
Authentification locale de démonstration : pas de serveur de comptes ni de vrai envoi d'e-mail. Le « mot de passe oublié » est un parcours simulé.
Les prix dépendent des données et des quotas des fournisseurs gratuits ; ils peuvent être différés. Les quotas sont à vérifier dans la documentation de chaque fournisseur.
Données journalières uniquement ; jours fériés non gérés ; historique limité (quelques mois pour la fenêtre actuelle).
La recherche documentaire est lexicale (TF-IDF), pas vectorielle : une question sans mot commun avec le corpus peut ne rien retrouver.
Le contrôle des nombres vérifie qu'un chiffre cité par le modèle existe dans les données calculées, mais pas qu'il est rattaché au bon indicateur.
Le signal repose sur quatre règles et un historique court : il ne prédit rien et n'a pas été validé statistiquement.
Les appels réels à Gemini et à Twelve Data dépendent de tes clés, de tes quotas et de l'accès de ton compte.
L'application est testée sur Android uniquement. Un APK release ne pourra pas joindre un backend en HTTP non chiffré.
Pistes d'amélioration
Brancher l'écran Assistant dans l'application Flutter (URL du backend via --dart-define=BACKEND_URL, http://10.0.2.2:8000 sur l'émulateur Android).
Rapport de qualité des données (jours manquants, doublons, valeurs aberrantes).
Recherche documentaire par embeddings, avec repli TF-IDF.
Prévision de volatilité évaluée contre une référence simple, jamais de prévision de prix.
Limite de débit sur /chat, Docker et intégration continue.
Avertissement

MarketLens est un outil pédagogique. Il ne constitue pas un conseil financier.