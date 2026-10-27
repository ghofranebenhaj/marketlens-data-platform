# Sources et intégration — vérifiées le 24 octobre 2026

Les accès ci-dessous sont implémentés avec Dio. Aucun appel authentifié n'a encore été vérifié avec une clé personnelle. Les droits du compte fournisseur restent déterminants.

| Fournisseur | Usage / endpoint | Politique locale |
|---|---|---|
| Twelve Data | `/quote` ; `/time_series?interval=1day&outputsize=30` | cache prix 5 min, historique 12 h ; prix refusé pour négociation après 15 min ; appels espacés de 8,1 s |
| Finnhub | `/api/v1/stock/profile2` ; en-tête `X-Finnhub-Token` | cache fiche 7 jours |
| Frankfurter | `/v2/rate/usd/eur` ou `/usd/gbp` | sans clé ; taux daté, cache 24 h ; conversion d'affichage uniquement |
| GNews | `/api/v4/search` ; nom entreprise, langue anglaise, 5 résultats | cache 12 h ; appels espacés de 1,1 s |

Catalogue : AAPL, MSFT, GOOGL, AMZN, NVDA, TSLA. Ce sont des actions américaines ; Twelve Data indique que son offre Basic couvre les actions américaines. Finnhub décrit `profile2` comme la version gratuite de la fiche entreprise. Le catalogue et l'abonnement ne garantissent pas le succès d'une requête : toute réponse refusée provoque le basculement explicite vers la démonstration.

Sources officielles :
- [Twelve Data — référence des endpoints](https://twelvedata.com/docs)
- [Twelve Data — couverture des actions et Basic](https://twelvedata.com/stocks)
- [Twelve Data — tarifs](https://twelvedata.com/pricing)
- [Twelve Data — crédits et erreurs 429](https://support.twelvedata.com/en/articles/5615854-credits)
- [Twelve Data — fuseaux horaires](https://support.twelvedata.com/en/articles/5745849-timezones)
- [Finnhub — Company Profile 2](https://finnhub.io/docs/api/company-profile2)
- [Schéma officiel Finnhub, description de profile2](https://github.com/Finnhub-Stock-API/finnhub-go/blob/master/api/openapi.yaml)
- [Frankfurter — référence v2](https://frankfurter.dev/)
- [GNews — documentation et offres](https://docs.gnews.io/)
- [GNews — erreurs, quotas et usage académique](https://gnews.io/faq)

Twelve Data documente une limite Basic de 800 crédits/jour et la réponse 429 en cas d'épuisement. La cadence locale est un choix conservateur, pas une promesse de quota. GNews documente 100 requêtes/jour, 10 articles maximum/requête, 1 requête/seconde et un retard de 12 heures pour l'offre Free, réservée notamment aux usages académiques non commerciaux. Aucun quota Finnhub chiffré n'est supposé par l'application.

Les dates de clôture journalière sont des dates de séance locales ; elles ne doivent pas être interprétées comme des heures de cotation UTC. Le cours de négociation utilise exclusivement `quote.timestamp` (epoch). Hors séance, un prix peut être trop ancien et les ordres restent bloqués : aucune exception implicite de week-end.

Une réponse vide, une erreur HTTP, un timeout, un quota ou un schéma invalide fait passer l'application en mode démo. Un cache encore valide évite l'appel ; un cache expiré n'est jamais utilisé pour masquer une panne. Le motif s'affiche à l'écran de connexion. La reconnexion au compte démo est volontaire : aucune opération API n'est transposée au portefeuille démo.

Les clés sont fournies exclusivement avec `--dart-define`. Elles ne sont jamais journalisées par Dio. Comme toute clé incluse dans une application cliente, elles restent extractibles du binaire : utiliser des clés personnelles dédiées au travail académique.

## Compatibilité des dépendances

Métadonnées de pub.dev consultées avant installation, SDK local Flutter 3.47.7 / Dart 3.13.5. `flutter pub get` a résolu les dépendances sans override ; les versions exactes sont dans `pubspec.lock`.

| Package | Version demandée | Contrainte SDK publiée |
|---|---|---|
| flutter_riverpod | 3.4.3 | Dart ^3.12.0 |
| go_router | 18.1.1 | Dart ^3.12.0, Flutter >=3.44.0 |
| dio | 5.11.1 | Dart >=2.18.0 <4.0.0 |
| sqflite | 2.4.5 | Dart ^3.12.0, Flutter >=3.44.0 |
| path | 1.9.1 | Dart ^3.4.0 |
| hive | 2.2.3 | Dart >=2.12.0 <3.0.0 (borne supérieure adaptée par Pub pour les packages null-safe Dart 2) |
| hive_flutter | 1.1.0 | Dart >=2.12.0 <3.0.0 (même adaptation Pub) |
| fl_chart | 1.3.0 | Dart >=3.6.2 <4.0.0, Flutter >=3.27.4 |
| intl | 0.20.3 | Dart ^3.9.0 |
| cryptography | 2.9.0 | Dart >=3.3.0 <4.0.0 |

`flutter_test` vient du SDK. `sqflite_common_ffi` est une dépendance de développement seulement pour exécuter les tests sur SQLite natif Windows.
