import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen(this.c, {super.key});
  final AppController c;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text(
        'Bonjour, ${c.user!.name} 👋',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 4),
      const Text('Votre avenir commence par la pratique.'),
      const SizedBox(height: 16),
      ModeBanner(c),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: lime,
          borderRadius: BorderRadius.circular(24),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: background, height: 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: background,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VALEUR TOTALE SIMULÉE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                c.valuationReady ? c.display(c.total) : 'Valorisation…',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Solde disponible + valeur des positions'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Panel(
        child: Column(
          children: [
            _row('Solde disponible', c.display(c.user!.balance)),
            const Divider(height: 28),
            _row(
              'Valeur des positions',
              c.valuationReady
                  ? c.display(c.positionsValue)
                  : 'En attente des prix',
            ),
            const Divider(height: 28),
            _row(
              'Gain non réalisé',
              c.valuationReady
                  ? '${c.unrealized >= 0 ? '+' : ''}${c.display(c.unrealized)}'
                  : 'En attente des prix',
            ),
          ],
        ),
      ),
      const Text(
        'La valorisation utilise les derniers prix datés disponibles. Les prix périmés restent visibles mais ne permettent pas de négocier.',
        style: TextStyle(fontSize: 12),
      ),
      SectionTitle(
        'Vos favoris',
        action: TextButton(
          onPressed: () => context.go('/market'),
          child: const Text('Explorer'),
        ),
      ),
      if (c.favorites.isEmpty)
        const EmptyState(
          'Votre sélection commence ici',
          'Ajoutez une étoile aux actions que vous souhaitez suivre.',
        ),
      for (final a in catalog.where((a) => c.favorites.contains(a.symbol)))
        AssetTile(a, c),
      const SectionTitle('Apprendre, un ordre à la fois'),
      const Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_outlined, color: lime),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Le gain non réalisé évolue avec les cours. Il devient réalisé lorsque vous vendez. La variation quotidienne du cours est un indicateur différent.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _row(String label, String value) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 20,
    runSpacing: 4,
    children: [
      Text(label),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
