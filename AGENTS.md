# RÈGLES NON NÉGOCIABLES

R1. Stack imposée : flutter_riverpod, go_router, dio, sqflite, path, hive, hive_flutter, fl_chart, intl, cryptography, flutter_test. Aucun backend, Firebase ou dependency_overrides. Vérifie la compatibilité des versions avant installation.
R2. SQLite (sqflite) : users, assets, cart_items, positions, transactions (achats et ventes), colonne user_id partout, versionnement avec onUpgrade. Hive : préférences (devise, thème, profil de risque), favoris, caches API horodatés. Les deux doivent être utilisés réellement.
R3. Montants en entiers (cents), jamais en double. Devise comptable USD ; la conversion ne sert qu'à l'affichage.
R4. Mots de passe : PBKDF2 avec sel aléatoire, jamais en clair ni SHA-256 simple. C'est une authentification locale de démonstration. Données isolées par utilisateur.
R5. Capital de 10 000 USD accordé une seule fois par utilisateur.
R6. Achat et vente s'exécutent chacun dans UNE transaction SQLite (db.transaction), avec identifiant d'opération unique contre la double validation. Logique dans un service Riverpod, jamais dans les widgets.
R7. Quatre API réelles appelées avec dio : Twelve Data (prix et historique), Finnhub (fiche entreprise), Frankfurter (taux), GNews (actualités). Clés via --dart-define, jamais dans le code ni le dépôt. Gère timeouts, erreurs HTTP, quotas, réponses vides, états de chargement, cache Hive avec mention « donnée en cache du … ». Vérifie les docs officielles ; n'invente pas les quotas. Catalogue de 5 à 8 actions réellement accessibles en offre gratuite.
R8. Les prix portent leur date, ne sont jamais présentés comme du temps réel, et un achat ou une vente est bloqué si le prix est trop ancien.
R9. Si les clés manquent ou si une API tombe : mode démo explicite (fixtures déterministes) avec badge « Données de démonstration », portefeuille et caches séparés du mode normal.
R10. Aucun chiffre financier inventé : tout vient des calculs de l'app. Pas de courbe historique du portefeuille inventée.
R11. Pas de boutons dépôt/retrait, pas de cadre de téléphone.
R12. Ne dis jamais qu'un test, un build ou une vérification a été exécuté s'il ne l'a pas été.
