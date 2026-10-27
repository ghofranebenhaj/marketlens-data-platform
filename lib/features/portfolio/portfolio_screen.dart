import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/app_controller.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen(this.c, {super.key});
  final AppController c;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text(
        'Votre portefeuille',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 16),
      ModeBanner(c),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Valeur des positions'),
            Text(
              c.valuationReady
                  ? c.display(c.positionsValue)
                  : 'En attente des prix',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              c.valuationReady
                  ? 'Gain non réalisé : ${c.unrealized >= 0 ? '+' : ''}${c.display(c.unrealized)}'
                  : 'Gain non réalisé : en attente des prix',
            ),
            Text(
              'Gain réalisé cumulé : ${c.display(c.trades.fold<int>(0, (s, t) => s + (t['realized_cents'] as int)))}',
            ),
          ],
        ),
      ),
      const SectionTitle('Positions'),
      if (c.positions.isEmpty)
        const EmptyState(
          'Pas encore de position',
          'Explorez les marchés et simulez votre premier achat depuis le panier.',
        ),
      for (final p in c.positions)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.symbol,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/asset/${p.symbol}'),
                    child: const Text('Détail / vendre'),
                  ),
                ],
              ),
              Text(
                '${p.quantity} action(s) · Prix moyen : ${c.display(roundedRatio(p.averageNumerator, p.averageDenominator))}',
              ),
              Text('Coût : ${c.display(c.positionCost(p))}'),
              Text(
                c.quotes.containsKey(p.symbol)
                    ? 'Valeur : ${c.display(c.positionValue(p))}'
                    : 'Valeur : en attente du prix',
              ),
              if (c.quotes.containsKey(p.symbol))
                Text(
                  'Gain non réalisé : ${c.positionValue(p) >= c.positionCost(p) ? '+' : ''}${c.display(c.positionValue(p) - c.positionCost(p))} (${percent(c.positionValue(p) - c.positionCost(p), c.positionCost(p))})',
                  style: TextStyle(
                    color: c.positionValue(p) >= c.positionCost(p)
                        ? lime
                        : negative,
                  ),
                ),
              if (c.quotes[p.symbol] != null)
                PriceLabel(c.quotes[p.symbol]!, c),
            ],
          ),
        ),
      const SectionTitle('Historique des opérations'),
      if (c.trades.isEmpty)
        const EmptyState(
          'Une page encore blanche',
          'Vos achats et ventes simulés apparaîtront ici, avec leur prix et leur date.',
        ),
      for (final t in c.trades)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t['side'] == 'buy' ? 'ACHAT' : 'VENTE'} · ${t['symbol']} × ${t['quantity']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${c.display(t['price_cents'] as int)} par action · total ${c.display((t['price_cents'] as int) * (t['quantity'] as int))}',
              ),
              Text(
                'Opération : ${stamp(DateTime.parse(t['created_at'] as String))}',
              ),
              Text(
                'Prix observé : ${stamp(DateTime.parse(t['price_at'] as String))}',
              ),
              if (t['side'] == 'sell')
                Text(
                  'Gain réalisé : ${(t['realized_cents'] as int) >= 0 ? '+' : ''}${c.display(t['realized_cents'] as int)}',
                ),
            ],
          ),
        ),
    ],
  );
}
