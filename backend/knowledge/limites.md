# Limites des données

Les clôtures journalières proviennent de Twelve Data, pour AAPL, MSFT, GOOGL, AMZN, NVDA et TSLA. Elles sont datées, différées et ne sont jamais présentées comme du temps réel. Le serveur exclut la date UTC du jour pour éviter une séance non terminée. Les jours fériés ne sont pas gérés ; les séances désignent uniquement les observations reçues.

Le cache serveur en mémoire dure 12 heures et porte sa date de récupération ainsi que les dates de début et de fin des observations. Il est perdu au redémarrage et indépendant de Hive. Une entrée expirée n'est pas utilisée en cas de panne. Marché fermé : la dernière clôture peut être ancienne ; aucune fraîcheur intrajournalière n'est garantie.

Les quotas, droits d'accès et profondeurs d'historique dépendent du fournisseur et du compte. Les vérifier dans la documentation Twelve Data et le tableau de bord du compte. Aucun quota chiffré n'est promis ici. Historique vide, invalide ou absent : assistant indisponible ; historique trop court : historique insuffisant pour les indicateurs concernés.

Les cours ne permettent pas de prédire un prix ou un rendement futur. Les scénarios sont rétrospectifs, sans frais, dividendes ni fiscalité. Les ajustements de cours du fournisseur ne sont pas neutralisés par le serveur. Le signal est une règle pédagogique arbitraire et transparente, sans validation prédictive.
