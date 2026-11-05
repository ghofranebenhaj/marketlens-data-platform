# Assistant pédagogique MarketLens

Python minimal : **3.14**, version vérifiée localement : **3.14.3 Windows x64**.
Service indépendant ; aucune intégration Flutter réalisée dans cette intervention.

## Installation Windows PowerShell

Depuis `C:\dev\MarketLens` :

```powershell
py -3.14 -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install --only-binary=:all: -r backend\requirements.txt
Copy-Item backend\.env.example backend\.env
notepad backend\.env
Set-Location backend
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Ne pas recopier `.env.example` par-dessus une configuration locale existante.
Si le venv partiel de cette intervention ne contient pas pip :

```powershell
backend\.venv\Scripts\python.exe -m ensurepip --upgrade
```

L'interface OpenAPI se trouve à `http://localhost:8000/docs` après lancement.
Ce prototype local n'a ni authentification serveur ni protection des quotas par client :
le réserver au développement sur un réseau de confiance ; aucune donnée de compte
n'est lue ou écrite. Aucun CORS global ajouté.

## Configuration

| Variable | Rôle |
|---|---|
| TWELVEDATA_KEY | Historique réel, obligatoire pour les calculs |
| GEMINI_API_KEY | Optionnelle ; absence = gabarit explicite |
| GEMINI_MODEL | Modèle de génération configurable, défaut `gemini-3.6-flash` |
| REQUIRE_LLM | `false` par défaut ; `true` exige un modèle disponible ou renvoie 503 |

Le fichier `backend/.env` est lu en UTF-8 ; format simple `KEY=value`, guillemets
externes acceptés, sans interpolation ni commentaires en fin de valeur. Les variables
du processus ont priorité. Aucune clé dans Flutter ni dans les assets pour l'assistant.
Le Flutter existant conserve son ancien mécanisme `dart-define` : migration requise
avant de considérer R13 globalement satisfaite.

Modèle vérifié dans le [catalogue officiel Google](https://aistudio.google.com/docs/models)
le 4 novembre 2026 : `gemini-3.6-flash` est indiqué stable pour la génération de texte.
L'accès avec votre compte n'a pas été essayé. API du SDK vérifiée dans la
[documentation google-genai](https://googleapis.github.io/python-genai/).

## Endpoints

- `GET /health` : état du service et présence des configurations, sans secret.
- `GET /assets/AAPL/indicators` : six indicateurs.
- `GET /assets/AAPL/signal` : signal pédagogique et détail des conditions.
- `GET /assets/AAPL/scenario?quantity=3&sessions=5` : scénario rétrospectif.
- `POST /chat` avec `{"question":"Analyse AAPL"}` : 1 à 500 caractères.

Catalogue exact : AAPL, MSFT, GOOGL, AMZN, NVDA, TSLA, extrait de
`lib/core/models.dart` et comparé dans un test pour prévenir une divergence.
Symboles des endpoints en majuscules. Dans le chat, symboles sans casse et noms
Apple, Microsoft, Alphabet, Amazon, NVIDIA, Tesla acceptés.
Scénario français : quantité entière suivie de « actions » et « il y a X séances ».

Réponse chat : `answer`, `data`, `sources`, `disclaimer`, `generated_by`.
`generated_by=llm` signifie que le modèle a rédigé une explication française de
5 à 8 phrases à partir de faits déjà formatés par le serveur : libellés français,
pourcentages avec virgule et deux décimales, dates et signal avec ses conditions.
Les données brutes ne sont pas envoyées au modèle ; elles restent dans `data`.
Pour une analyse, `data.indicators` contient les indicateurs bruts et `data.signal`
le signal brut avec ses conditions. Les endpoints déterministes sont inchangés.

Le serveur extrait tous les jetons numériques du texte et vérifie leur présence
dans les faits ou les passages réellement fournis. Les dates sont comparées en
entier ; signes et suffixes % sont conservés. Un nombre inconnu, un texte hors
limite de phrases ou une sortie interdite déclenche le gabarit (`template`), même
si `REQUIRE_LLM=true`. Les nombres écrits en lettres sont interdits par la consigne
et un filtre lexical conservateur. Ce contrôle de présence ne prouve pas que le
modèle associe chaque valeur au bon indicateur : les cartes doivent utiliser `data`.

Absence de clé, quota HTTP 429, erreur d'accès, timeout ou indisponibilité : cause
française dans `answer` et `fallback_reason`, sans publication du message brut du
fournisseur. `REQUIRE_LLM=true` conserve le 503 en cas de clé absente ou de panne.
Les refus et demandes de précision n'appellent pas le modèle.
La question brute n'est pas envoyée au modèle. Les extraits sont traités comme
données. Les calculs citent uniquement Twelve Data ; les questions documentaires
citent les passages retenus par TF-IDF (similarité minimale 0,18 et couverture
lexicale minimale de la moitié des termes utiles de la question).
Sources et rappel légal sont toujours assemblés par le serveur.

Les réponses déterministes contiennent `data`, `sources`, `disclaimer`.
Erreur de paramètre : 422 ; symbole inconnu sur endpoint : 404 ; historique
inaccessible/clé absente : 503 ; refus ou demande de précision du chat : 200.
Historique trop court : résultat structuré « historique insuffisant » avec valeur nulle.

## Formules et conventions

Les prix et montants restent en `Decimal` ; les montants exposés sont des entiers
en cents ou des chaînes décimales USD. NumPy traite uniquement les rapports sans unité.

| Calcul | Formule et minimum |
|---|---|
| Rendement 5/20 | C_fin / C_n_séances_avant − 1 ; 6/21 clôtures |
| Volatilité | std(C_t/C_t−1 − 1, ddof=1) × √252 ; 3 clôtures |
| Drawdown maximum | min(C_t / max(C_0…C_t) − 1) ; 2 clôtures |
| SMA20 / SMA50 | Somme des 20/50 dernières clôtures / 20/50 ; convention conservatrice : 21/51 points reçus |
| Scénario | N × clôture initiale/finale ; différence en cents ; (final/initial−1)×100 |

Les indicateurs indiquent méthode, période, dates, nombre disponible et minimum.
Fenêtre : au plus 100 clôtures terminées. Les séances correspondent aux observations
reçues et ne reconstituent pas les jours absents. SMA : le point supplémentaire
exigé ne participe pas à la moyenne. Rendements/volatilité/drawdown exposés en ratios.
Scénario : 1 à 1 000 000 actions, 1 à 99 séances ; sans frais, dividendes ou fiscalité ;
arrondi monétaire au centime avec `ROUND_HALF_UP`, après calcul Decimal.

Toutes les constantes du signal sont dans `app/config.py` :
`POSITIVE_WEIGHT=1`, `RISK_WEIGHT=-1`, `VOLATILITY_LIMIT=0.40`,
`DRAWDOWN_LIMIT=-0.15`, `FAVORABLE_SCORE=2`, `CAUTION_SCORE=-1`,
`ANNUAL_SESSIONS=252`.
Contribution +1 si rendement20 > 0 ; +1 si dernière clôture > SMA50 ;
−1 si volatilité > 40 % ; −1 si drawdown < −15 %.
Score ≥ 2 favorable ; score ≤ −1 prudence ; sinon neutre.
Si un des quatre indicateurs manque, aucun score n'est produit.
Ce signal arbitraire n'a aucune validation prédictive.

## Historique, cache et limites

[Twelve Data time_series](https://twelvedata.com/docs/market-data/time-series),
[erreurs officielles](https://twelvedata.com/docs/introduction/errors) consultés
le 4 novembre 2026. HTTP via httpx, timeout 10 secondes par phase, 2 reprises
maximum après erreur réseau, quota ou HTTP 5xx, délais 0,5 puis 1 seconde.
Le chat a une limite globale de 40 secondes ; le modèle de 15 secondes.
Pas de reprise sur erreur HTTP permanente ou historique invalide.
Réponse non USD, symbole divergent, prix non positif/non fini, dates futures ou
dupliquées refusés. La date UTC du jour est exclue pour éviter un cours provisoire.

Cache mémoire borné aux six symboles, 12 heures, verrou par symbole, horodatage
de récupération et dates des observations. Mention « donnée en cache du … ».
Cache perdu au redémarrage, propre à chaque processus ; aucune donnée de compte,
aucun mélange avec Hive ou les fixtures Flutter. Une entrée expirée n'est pas servie.
Sans données réelles : 503, jamais de fixture financière cachée dans l'assistant.

Jours fériés non gérés, historique limité, données journalières différées,
ajustements de cours laissés au fournisseur, aucun résultat intrajournalier.
Les quotas et droits gratuits sont à vérifier dans la documentation du fournisseur
et le tableau de bord du compte ; aucun quota numérique ni accès garanti promis.
Pas d'appel authentifié réel effectué pendant l'implémentation.

Corpus Markdown français, recherche TF-IDF avec NumPy, sans embeddings ni framework RAG.
Les questions hors corpus ne sont pas complétées avec des connaissances inventées.
Le routage lexical demande une précision si le symbole ou le scénario est ambigu.

## Versions et wheels

Versions directes figées dans `requirements.txt`, Uvicorn sans extras compilés.
Fichiers vérifiés sur PyPI :
[FastAPI 0.128.0](https://pypi.org/project/fastapi/0.128.0/#files),
[Uvicorn 0.40.0](https://pypi.org/project/uvicorn/0.40.0/#files),
[Pydantic 2.12.5](https://pypi.org/project/pydantic/2.12.5/#files),
[httpx 0.28.1](https://pypi.org/project/httpx/0.28.1/#files),
[google-genai 1.56.0](https://pypi.org/project/google-genai/1.56.0/#files),
[pytest 9.0.2](https://pypi.org/project/pytest/9.0.2/#files) : wheels Python universelles ;
[NumPy 2.3.5](https://pypi.org/project/numpy/2.3.5/#files) et
[pydantic-core 2.41.5](https://pypi.org/project/pydantic-core/2.41.5/#files) :
wheels `cp314-cp314-win_amd64`. Installation complète `--only-binary=:all:`
réussie localement sous Python 3.14.3, incluant les dépendances transitives.
Les transitives ne sont pas toutes figées ; une résolution future peut évoluer.

Tests hors réseau : séries connues, insuffisance, signal, scénario, routage,
refus, entrées, cache, erreurs fournisseurs et modèle simulé. Voir
`../docs/CHATBOT_EVAL.md` pour les questions de référence.
