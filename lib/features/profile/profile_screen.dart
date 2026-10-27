import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen(this.c, {super.key});
  final AppController c;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Votre profil')),
    body: SafeArea(
      child: PageBody(
        children: [
          ModeBanner(c),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.user!.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(c.user!.email),
                const SizedBox(height: 12),
                const Text(
                  'Compte local · simulation pédagogique\nAucun investissement ni paiement réel.',
                ),
              ],
            ),
          ),
          const SectionTitle('Vos préférences'),
          _choice(context, 'Devise d’affichage', c.currency, [
            'USD',
            'EUR',
            'GBP',
          ], (v) => c.setCurrency(v)),
          if (c.currency != 'USD')
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.mode == DataMode.demo
                        ? 'Taux de démonstration fixe : 1 USD = ${c.currency == 'EUR' ? '0,92 EUR' : '0,77 GBP'}'
                        : 'Frankfurter · taux journalier',
                  ),
                  if (c.rateAt != null)
                    Text('Date du taux : ${stamp(c.rateAt!)}'),
                  if (c.rateCache != null)
                    Text('donnée en cache du ${stamp(c.rateCache!)}'),
                  const Text(
                    'Conversion réservée à l’affichage. Comptabilité et historique en USD.',
                  ),
                ],
              ),
            ),
          _choice(context, 'Thème', c.theme, [
            'Sombre',
            'Clair',
          ], (v) => c.preference('theme', v)),
          _choice(context, 'Profil de risque', c.risk, [
            'Conservateur',
            'Équilibré',
            'Dynamique',
          ], (v) => c.preference('risk', v)),
          const Panel(
            child: Text(
              'Le profil de risque est une préférence pédagogique ; il ne constitue pas un conseil d’investissement. Une action peut perdre de la valeur.',
            ),
          ),
          const SectionTitle('Environnement'),
          Text(c.notice),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => attempt(
              context,
              () async => c.changeMode(
                c.mode == DataMode.demo ? DataMode.normal : DataMode.demo,
              ),
            ),
            child: Text(
              c.mode == DataMode.demo
                  ? 'Passer aux données API'
                  : 'Passer en démonstration',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: c.tradingBusy ? null : c.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    ),
  );
  Widget _choice(
    BuildContext context,
    String label,
    String value,
    List<String> options,
    Future<void> Function(String) change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey('$label:$value'),
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        if (v != null) attempt(context, () => change(v));
      },
    ),
  );
}
