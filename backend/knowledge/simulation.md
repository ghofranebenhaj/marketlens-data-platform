# Simulation MarketLens

Chaque compte local reçoit une seule fois un capital virtuel de 10 000 USD lors de sa création. Les mots de passe utilisent PBKDF2 avec sel aléatoire. Les comptes et les bases de démonstration sont séparés du mode normal.

Les achats simulés valident le panier, une quantité entière positive au plus égale à 1 000 000, un solde suffisant et un identifiant d'opération inédit. Le panier et les prix confirmés doivent encore correspondre à ceux affichés. Chaque achat est atomique dans SQLite via le service Riverpod.

Les ventes simulées exigent une quantité détenue suffisante, une quantité positive et un identifiant inédit. Une vente complète supprime la position ; une vente partielle conserve le coût moyen exact. Le solde est crédité et le gain réalisé est calculé. Chaque vente est atomique dans SQLite.

Achats et ventes sont refusés si le prix manque, est nul, correspond à un autre actif ou mode, date de plus de 15 minutes, ou de plus d'une minute dans le futur. Cette règle Flutter s'applique aussi hors séance ; aucun calendrier boursier n'y intervient. L'assistant ne consulte ni ne modifie le compte : les informations personnelles se trouvent dans l'écran Portefeuille, les prix dans Marchés.
