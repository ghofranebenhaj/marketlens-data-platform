import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/database.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import 'quantity_dialog.dart';

class CartScreen extends StatelessWidget {
  const CartScreen(this.c, {super.key});
  final AppController c;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Votre panier')),
    body: SafeArea(
      child: PageBody(
        children: [
          ModeBanner(c),
          if (c.cart.isEmpty)
            const EmptyState(
              'Le panier est vide',
              'Ajoutez une action depuis sa fiche pour préparer un achat simulé.',
            ),
          for (final item in c.cart.entries)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.key, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${item.value} action(s) × ${c.display(c.quotes[item.key]?.price ?? 0)}',
                  ),
                  if (c.quotes[item.key] != null)
                    PriceLabel(c.quotes[item.key]!, c),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: c.tradingBusy
                            ? null
                            : () async {
                                final q = await quantityDialog(
                                  context,
                                  title: 'Modifier ${item.key}',
                                  initial: item.value,
                                );
                                if (q != null && context.mounted) {
                                  await attempt(
                                    context,
                                    () => c.setCart(item.key, q),
                                  );
                                }
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                      TextButton.icon(
                        onPressed: c.tradingBusy
                            ? null
                            : () => attempt(
                                context,
                                () => c.setCart(item.key, 0),
                              ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (c.cart.isNotEmpty) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total estimé : ${c.display(c.cartTotal)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Solde disponible : ${c.display(c.user!.balance)}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Le débit comptable est effectué en cents USD. Aucun frais ni paiement réel.',
                  ),
                  if (!c.freshCart)
                    const Text(
                      'Actualisez les cours : un prix est absent ou périmé.',
                    ),
                  if (c.cartTotal > c.user!.balance)
                    const Text('Solde insuffisant.'),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: c.loading ? null : () => c.refresh(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser les prix'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  c.tradingBusy ||
                      c.loading ||
                      !c.freshCart ||
                      c.cartTotal > c.user!.balance
                  ? null
                  : () async {
                      final operation = operationId();
                      final expected = Map<String, int>.of(c.cart);
                      final expectedQuotes = Map.of(c.quotes);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmer l’achat simulé'),
                          content: SingleChildScrollView(
                            child: Text(
                              '${expected.entries.map((e) => '${e.key} × ${e.value} · ${money(expectedQuotes[e.key]!.price)}\nPrix : ${stamp(expectedQuotes[e.key]!.at)}').join('\n\n')}\n\nTotal : ${money(c.cartTotal)}\nLe capital fictif sera débité une seule fois.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Confirmer'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await attempt(
                          context,
                          () => c.buy(operation, expected, expectedQuotes),
                          success: 'Achat simulé enregistré.',
                        );
                      }
                    },
              child: Text(
                c.tradingBusy ? 'Validation…' : 'Vérifier et confirmer',
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
