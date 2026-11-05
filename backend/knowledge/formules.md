# Formules et signal pédagogique

Rendement sur 5 ou 20 séances : C_fin / C_n_séances_avant − 1. Il faut respectivement 6 ou 21 clôtures. Les rendements sont des ratios sans unité ; multiplier par 100 donne un pourcentage.

Volatilité : r_t = C_t / C_t−1 − 1 ; écart-type échantillon de r_t (ddof=1) × racine de 252. Au moins 3 clôtures. Fenêtre limitée aux 100 dernières clôtures terminées reçues.

Drawdown maximum : min_t(C_t / max(C_0…C_t) − 1), sur au plus 100 clôtures. Au moins 2 clôtures.

Moyenne mobile simple 20 ou 50 : somme des 20 ou 50 dernières clôtures / 20 ou 50. Par convention conservatrice de ce projet, 21 ou 51 clôtures reçues sont exigées. Le point supplémentaire n'entre pas dans la moyenne.

Signal pédagogique : +1 si rendement20 > 0 ; +1 si dernière clôture > SMA50 ; −1 si volatilité annualisée > 40 % ; −1 si drawdown < −15 %. Score ≥ 2 : favorable ; score ≤ −1 : prudence ; sinon neutre. Si un indicateur requis manque : historique insuffisant, aucun score. Ces seuils pédagogiques ne constituent pas une stratégie validée.

Scénario « Et si ? » : quantité entière × clôture de la séance choisie et de la dernière séance terminée reçue. Gain = valeur finale − valeur initiale ; pourcentage = (valeur finale / valeur initiale − 1) × 100. Calcul Decimal, arrondi des montants à un centime, demi supérieur. Sans frais, dividendes, fiscalité ni exécution d'opération.
