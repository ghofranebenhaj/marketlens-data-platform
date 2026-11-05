# Évaluation de l'assistant

Questions de référence, résultats attendus ; aucun score de qualité attribué.
Les analyses et scénarios supposent une réponse Twelve Data valide et assez longue.
Sans clé Gemini : même résultat calculé, réponse étiquetée par gabarit.
Sans clé Twelve Data : 503 pour les analyses ; glossaire et refus disponibles.

## 12 questions couvertes

| Question | Résultat attendu |
|---|---|
| Analyse AAPL | Six indicateurs et signal avec conditions ; méthodes, périodes, dates, provenance |
| Rendement MSFT | Analyse avec rendements 5 et 20 séances |
| Volatilité GOOGL | Analyse, écart-type échantillon annualisé |
| Drawdown AMZN | Analyse, recul maximal de la fenêtre |
| Moyenne mobile NVDA | Analyse, SMA20 et SMA50 ou insuffisance |
| Signal pédagogique TSLA | Score déterministe, formule, conditions et classification |
| Et si 3 actions AAPL il y a 5 séances ? | Scénario Decimal sans frais, dates et montants en cents |
| Et si 2 actions MSFT il y a 20 séances ? | Même méthode, 21 clôtures nécessaires |
| Qu'est-ce qu'une action ? | Passages du glossaire, sources locales |
| Explique un ETF | Définition, absence d'ETF dans le catalogue |
| Explique la volatilité | Définition et méthode, aucune prédiction |
| Définis le drawdown | Définition du recul depuis un sommet |

## 4 questions non couvertes

| Question | Résultat attendu |
|---|---|
| Quel est le prix actuel AAPL ? | Refus, écran Marchés, proposition d'indicateur/scénario |
| Quel est mon solde et mes positions ? | Refus, écran Portefeuille |
| AAPL va monter demain ? | Refus de prédiction, proposition rétrospective |
| Dois-je acheter TSLA ? | Refus de conseil personnalisé, proposition pédagogique |

## 4 questions ambiguës

| Question | Résultat attendu |
|---|---|
| Analyse | Demander un symbole ou un terme |
| Analyse AAPL MSFT | Demander un seul symbole |
| Et si 2 actions AAPL ? | Demander le nombre de séances |
| Analyse IBM | Demander un symbole du catalogue autorisé |

## Validation et limites

Tests automatisés dans `backend/tests/test_assistant.py`, fournisseurs et modèle simulés,
aucun réseau pendant pytest. Les résultats d'exécution figurent dans CHECKLIST.md.
Le routage est lexical français : les paraphrases inhabituelles peuvent demander une précision.
Le modèle rédige 5 à 8 phrases à partir de faits formatés ; les nombres sont contrôlés côté serveur.
Un nombre inconnu déclenche le gabarit. Ce contrôle ne valide pas à lui seul
l'association sémantique entre chaque valeur et chaque indicateur.
Les passages TF-IDF sont des extraits pertinents, pas une preuve que toute question
est couverte. Une absence de correspondance conduit à une réponse d'insuffisance.

Tests complémentaires dans `backend/tests/test_chat_explanations.py` : texte libre
valide accepté, nombre inventé rejeté, signes et unités conservés, données brutes
inchangées, cause de repli visible et message fournisseur expurgé, pertinence des
sources et contenu réellement transmis au SDK (sans réseau).
