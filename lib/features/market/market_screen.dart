import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen(this.c, {super.key});
  final AppController c;
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String query = '';
  bool onlyFavorites = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final assets = catalog
        .where(
          (a) =>
              '${a.symbol} ${a.name}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (!onlyFavorites || c.favorites.contains(a.symbol)),
        )
        .toList();
    return PageBody(
      children: [
        Text('Les marchés', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text('Six entreprises. À vous de les découvrir.'),
        const SizedBox(height: 16),
        ModeBanner(c),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Symbole ou entreprise',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            FilterChip(
              label: const Text('Mes favoris'),
              selected: onlyFavorites,
              onSelected: (v) => setState(() => onlyFavorites = v),
            ),
            TextButton.icon(
              onPressed: c.loading ? null : () => c.refresh(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (assets.isEmpty)
          const EmptyState(
            'Aucun résultat',
            'Essayez un autre symbole ou désactivez le filtre favoris.',
          ),
        for (final a in assets) AssetTile(a, c),
        const Text(
          'Source : Twelve Data en mode API. Variation depuis la clôture précédente. Cours datés, sans promesse de temps réel.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
