# Validation — 24 octobre 2026

## Résultats constatés

| Vérification exécutée | Résultat |
|---|---|
| Inspection initiale du dossier | Dossier vide, aucun pubspec/code/config Android existant ; socle Android généré sur place |
| Métadonnées pub.dev puis `flutter pub get` | Dépendances compatibles résolues, lockfile généré, aucun override |
| `dart format lib test` | Réussi ; dernière exécution : 23 fichiers, aucun changement |
| `flutter analyze` | **Réussi**, sortie finale `No issues found!` (22,4 s) |
| `flutter test` (chemin court SDK) | **23 tests réussis**, sortie `All tests passed!` |
| `flutter build bundle --debug` (chemin court SDK) | **Réussi**, code de sortie 0 ; `build/flutter_assets/kernel_blob.bin` et `AssetManifest.bin` présents |
| `flutter build apk --debug` | **Échec**, Gradle : `java.io.IOException: Unable to establish loopback connection` |
| Même compilation APK avec `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true` | **Même échec** ; aucune modification permanente de configuration Java |
| `flutter doctor -v` | Flutter 3.47.7 / Dart 3.13.5 ; SDK Android 36.0.0, alerte sur les espaces dans son chemin ; aucun appareil Android connecté |

La compilation du bundle valide le code Flutter et ses ressources, mais ne produit pas un APK installable et ne valide pas l'intégration native Android. Aucun succès de build APK ni lancement Android n'est revendiqué.

## Tests

- 16 tests métier/calculs : capital unique, mots de passe salés, isolation, quantités, solde, double achat/vente, panier modifié, achat multiple atomique, ventes partielle/totale, gain réalisé, moyenne exacte, prix périmé/futur/mauvais mode, arrondis, péremption et migration.
- 5 tests réseau/Hive : décodage entier/date source, lecture réelle du cache, cache périmé + HTTP 429, réponses vides/erreur, endpoints des fournisseurs et séparation des caches, favoris persistants isolés par utilisateur/mode. Les réponses HTTP sont contrôlées par un adaptateur de test Dio.
- 1 test widget du formulaire de quantité sur écran 320 × 640 avec un inset clavier de 220 px : zéro, dépassement et quantité valide.
- 1 test de parcours sur écran 360 × 800 : accueil, marchés/recherche, favori, détail/graphique, profil/préférences, achat et calculs, déconnexion. Le service d'achat est appelé dans ce test ; les dialogues et mutations métier sont aussi couverts séparément.

## Particularité Windows

La commande standard de test a échoué avant exécution des tests sur les hooks natifs (`objective_c`), à cause d'un chemin SDK avec espace (`C:\Users\Sofiene` interprété comme une commande). La relance avec le chemin court **du même SDK** fonctionne :

```powershell
& 'C:\Users\SOFIEN~1\flutter\flutter\bin\flutter.bat' test
```

## À vérifier dans un environnement Android opérationnel

- Compiler l'APK après résolution de la connexion locale Gradle ; tenir également compte de l'alerte de `flutter doctor` sur les espaces du chemin Android SDK. Ne pas déplacer le SDK automatiquement.
- Lancer sur un appareil ou émulateur Android et effectuer un parcours tactile complet.
- Fournir ses propres clés avec les trois `--dart-define` décrits dans le README, puis vérifier les appels authentifiés aux API et les droits du compte gratuit. Aucune clé n'a été fournie ni ajoutée au projet ; ces appels n'ont pas été exécutés en conditions réelles.
- La volatilité historique optionnelle n'est pas implémentée.

