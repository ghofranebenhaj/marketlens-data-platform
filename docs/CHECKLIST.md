# MarektLens — état réel

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

