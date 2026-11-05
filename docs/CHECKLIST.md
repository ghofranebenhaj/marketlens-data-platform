# MarektLens — état réel

## Tableau de référence après ajout de l'assistant — 4 novembre 2026

« Fait » décrit l'implémentation inspectée ou testée, pas une certification des
services externes. Les anciens résultats Flutter ci-dessous sont historiques,
non réexécutés dans cette intervention. Le README historique et VALIDATION.md
divergent sur le build Android : aucune nouvelle conclusion sur Android.

| Règle | État | Fichier concerné et limite |
|---|---|---|
| R1 | Fait | pubspec.yaml ; backend/requirements.txt ; exception backend volontaire dans AGENTS.md, aucune dépendance Flutter modifiée |
| R2 | Fait | lib/core/database.dart, lib/core/app_controller.dart, lib/core/network.dart, lib/features/watchlist/watchlist.dart ; lecture du stockage existant |
| R3 | Fait | lib/core/money.dart ; backend/app/calculations.py : prix Decimal, montants cents/chaînes, NumPy seulement pour rapports |
| R4 | Fait | lib/core/database.dart : PBKDF2, sel aléatoire, données locales isolées ; backend sans compte |
| R5 | Fait | lib/core/database.dart : capital initial unique ; backend ne touche pas aux comptes |
| R6 | Fait | lib/features/portfolio/trading_service.dart : transactions et identifiants ; aucun ordre dans backend |
| R7 | Partiel | lib/core/network.dart ; backend/app/history.py ; docs officielles consultées, accès authentifié et droits gratuits du compte non vérifiés |
| R8 | Fait | lib/core/models.dart, lib/features/portfolio/trading_service.dart ; backend/app/history.py et calculations.py : données datées, clôtures journalières |
| R9 | Fait | lib/core/app_controller.dart, lib/core/network.dart : démo existante ; backend sans fixtures en production, 503 si historique absent, cache distinct sans portefeuille |
| R10 | Fait | backend/app/calculations.py et chat.py : calculs seuls ; aucune courbe fictive ajoutée |
| R11 | Fait | Aucun écran Flutter ajouté ou modifié, aucun dépôt/retrait ni cadre ajouté |
| R12 | Fait | Présent journal et backend/README.md : résultats exécutés et limites séparés |
| R13 | Partiel | backend/.env.example, .gitignore, backend/app/config.py : secrets backend ; lib/core/network.dart conserve TWELVE_DATA_KEY via dart-define, migration Flutter explicitement hors périmètre |
| R14 | Fait | backend/app/chat.py : refus et renvois, signal pédagogique, scénario historique, sortie modèle contrainte |
| R15 | Fait | backend/app/calculations.py, chat.py, history.py : chiffres et sources serveur, contrôle des nombres des explications rédigées |
| R16 | Fait | backend/app/calculations.py, knowledge.py, chat.py : historique insuffisant, documentation insuffisante, demandes de précision |
| R17 | Partiel | backend/app/chat.py, main.py : gabarit étiqueté ou 503 ; état « Assistant indisponible » côté Flutter non intégré, conformément au périmètre |
| R18 | Fait | backend/app/config.py, chat.py, main.py : rappel serveur dans les réponses et erreurs applicatives |

### Hypothèses et décisions de cette passe

- Autorisation explicite du backend = exception volontaire à l'interdiction backend de R1.
- Aucune modification de lib/, pubspec ou code plateforme ; l'assistant n'est pas encore accessible depuis Flutter.
- Catalogue copié de lib/core/models.dart, comparaison automatique dans pytest.
- Python minimal choisi : 3.14 ; vérification réelle sous 3.14.3 Windows x64.
- Fenêtre maximale 100 clôtures ; périodes mesurées en observations reçues, jours fériés non gérés. La date UTC du jour est exclue, même après fermeture : choix conservateur.
- SMA20/50 : convention conservatrice 21/51 points requis, moyenne des 20/50 derniers ; conforme à l'exemple de la demande, bien qu'une SMA50 mathématique ne nécessite que 50 points.
- Volatilité : au moins 3 clôtures ; drawdown : au moins 2. Si le signal manque d'un composant, pas de score partiel.
- Calculs monétaires Decimal avec arrondi au centime demi supérieur ; rapports NumPy en flottants sans unité, jamais montants monétaires en flottants.
- Cache réel en mémoire, durée 12 heures, borné à six symboles, verrou par symbole, aucun cache périmé de secours. Aucun mélange avec Hive ou une fixture de démonstration.
- Sans historique réel, réponse 503 plutôt qu'invention d'indicateurs ; le glossaire reste disponible sans clé. Aucun portefeuille serveur.
- Mise à jour du chat : le modèle rédige 5 à 8 phrases à partir de faits français déjà formatés ; contrôle serveur des nombres, dates, signes et pourcentages. Un texte invalide déclenche le gabarit. Les données brutes et le signal restent structurés dans data. Ce contrôle lexical ne certifie pas l'association sémantique des valeurs aux indicateurs.
- REQUIRE_LLM=false : repli par défaut ; true : absence/panne du modèle = 503. Routage lexical, pas de compréhension générale promise.
- Modèle de génération configurable, défaut gemini-3.6-flash relevé dans le catalogue officiel Google. Aucun accès réel avec une clé vérifié.
- Aucun quota chiffré affirmé. L'accès gratuit effectif aux six symboles dépend du compte et reste à vérifier.

### Vérifications de cette intervention

- AGENTS.md et ce fichier lus intégralement avant intervention ; relecture finale requise avant réponse.
- Documentation officielle Twelve Data time_series/erreurs et SDK Google consultée ; liens dans backend/README.md.
- Wheels PyPI vérifiées pour les sept dépendances directes et pydantic-core ; installation `--only-binary=:all:` réussie, y compris les transitives, sous Python 3.14.3.
- L'alias Windows python était inaccessible ; utilisation de l'exécutable réel. Création du venv partielle (ensurepip échoué), installation via le pip de l'interpréteur hôte avec `--python` dans le venv, sans installation globale.
- Premier pytest bloqué dans le bac à sable Windows, interrompu ; dernière exécution hors bac à sable : **45 tests réussis en 2,62 s**, 2 avertissements de dépréciation dans Starlette/AnyIO et google-genai. Aucun appel réseau dans les tests.
- `pip --python backend/.venv/Scripts/python.exe check` : « No broken requirements found. »
- `git check-ignore` confirme .env, .venv, __pycache__, .pytest_cache ignorés.
- Diff lib/, pubspec.yaml et pubspec.lock vide lors du contrôle.
- Aucun build, émulateur, serveur, commit ou push lancé. Aucun test Flutter relancé.
- Non vérifiés : appels Twelve Data/Gemini authentifiés, disponibilité et quotas du compte, intégration mobile, exécution Uvicorn, interface sur appareil.

## Historique de phase 1 (conservé, non réexécuté)

## Règles
- [x] R1 — stack imposée, compatibilité vérifiée, aucune substitution/backend.
- [x] R2 — SQLite, user_id, migration ; Hive préférences/favoris/caches.
- [x] R3 — montants entiers en cents USD, conversion uniquement à l'affichage.
- [x] R4 — PBKDF2, sel aléatoire, authentification locale, isolation.
- [x] R5 — capital initial unique de 10 000 USD.
- [x] R6 — achat/vente atomiques, identifiant unique, service Riverpod.
- [x] R7 — intégrations des quatre API Dio implémentées, clés dart-define, erreurs/quotas/cache, docs officielles, catalogue gratuit ; validation authentifiée restante ci-dessous.
- [x] R8 — prix datés, jamais annoncés en temps réel, blocage si périmés.
- [x] R9 — démo déterministe explicite, comptes et caches séparés.
- [x] R10 — chiffres calculés, aucune courbe de portefeuille fictive.
- [x] R11 — aucun dépôt/retrait/cadre de téléphone.
- [x] R12 — vérifications rapportées fidèlement.

## Fonctionnalités
- [x] Inscription/connexion, validation et messages clairs.
- [x] Mot de passe oublié : parcours simulé explicite.
- [x] Accueil : salutation/avatar, valeur totale, solde, positions, gain non réalisé, favoris.
- [x] Marchés : liste, recherche, prix/horodatage, variation avec période, favoris.
- [x] Détail : logo, nom/symbole, prix, fl_chart, entreprise, actualités, panier/vente.
- [x] Panier : quantités entières, modification/suppression, total/solde/confirmation.
- [x] Portefeuille : positions, quantité/prix moyen/valeur/gain/% et historique achats/ventes.
- [x] Vente : validation, prix frais, réduction/suppression, crédit, coût moyen conservé, gain réalisé.
- [x] Profil : infos/devise Frankfurter/thème/risque/simulation/déconnexion, accessible via avatar.
- [x] Navigation basse : Accueil, Marchés, Portefeuille.
- [x] États vides et chargement/erreurs.
- [x] Calculs : valeur, coût moyen, gains réalisés/non réalisés, %, total.
- [x] Design : palette, dégradé, cartes arrondies, marges, cibles 48 px, signes/libellés, thème centralisé, petits écrans/clavier.
- [x] Organisation lib/app, lib/core, lib/features demandée.
- [ ] Optionnel : volatilité historique (non incluse).

## Tests unitaires et vérifications
- [x] Capital unique.
- [x] Isolation utilisateurs.
- [x] Quantité invalide.
- [x] Solde insuffisant.
- [x] Double validation.
- [x] Vente supérieure à la quantité détenue.
- [x] Vente à zéro : suppression position.
- [x] Gain réalisé.
- [x] Calculs et arrondis.
- [x] Cache périmé.
- [x] dart format exécuté.
- [x] flutter analyze exécuté sans erreur.
- [x] flutter test exécuté avec succès.
- [ ] APK Android compilé : deux tentatives échouées, Gradle `Unable to establish loopback connection`.

## Limites de validation
- [ ] Appels authentifiés aux fournisseurs avec des clés personnelles (clés non fournies ; intégrations Dio testées avec réponses contrôlées).
- [ ] Exécution sur appareil ou émulateur Android (aucun appareil Android connecté).
- [x] Tests : 23 réussis, incluant SQLite réel, migration, Hive persistant, réseau simulé, navigation 360 px et formulaire/clavier 320 px.

Voir `VALIDATION.md` pour les résultats et les particularités de cet environnement Windows.
- [x] Bundle Flutter debug compilé avec succès (ne constitue pas un APK Android).


## Amélioration de POST /chat — 5 novembre 2026

- Fichiers : backend/app/chat.py, presentation.py, knowledge.py ; backend/tests/test_assistant.py et test_chat_explanations.py ; README.md, backend/README.md, docs/CHATBOT_EVAL.md, présente checklist.
- Présentation : libellés français, pourcentages à deux décimales, calculs bruts conservés ; analyse avec data.indicators et data.signal, incluant conditions et formule.
- Modèle : véritable rédaction, uniquement faits formatés et passages utiles, 5 à 8 phrases contrôlées avant rappel serveur. Nombres supplémentaires ou format invalide : template, même en mode REQUIRE_LLM.
- Causes de repli sûres : clé absente, quota (code 429), accès refusé, délai dépassé ou modèle indisponible ; jamais de message fournisseur brut. Champ fallback_reason et cause lisible dans answer.
- Sources : provenance Twelve Data seule pour les calculs ; corpus réservé aux questions documentaires avec seuil TF-IDF et couverture lexicale. Pas d'extrait décoratif pour une analyse.
- Vérification finale : **61 tests réussis en 3,41 s**, deux avertissements de dépréciation de dépendances ; clients fournisseur et modèle simulés, aucun appel réseau pendant les tests.
- Aucune modification Flutter ; aucun serveur, commit ou push lancé. Appels réels Gemini/Twelve Data et qualité rédactionnelle du modèle réel non vérifiés.
