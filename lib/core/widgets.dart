import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import 'app_controller.dart';
import 'models.dart';
import 'money.dart';

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> attempt(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) toast(context, success);
  } catch (e) {
    if (context.mounted) {
      toast(
        context,
        e is AppFailure ? e.message : 'Action impossible. Réessayez.',
      );
    }
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [deepGreen.withValues(alpha: .35), Colors.transparent],
        stops: const [0, .45],
      ),
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: children,
        ),
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.body, {super.key});
  final String title, body;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const Icon(Icons.eco_outlined, color: lime, size: 36),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );
}

class ModeBanner extends StatelessWidget {
  const ModeBanner(this.c, {super.key});
  final AppController c;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: Icon(
            c.mode == DataMode.demo ? Icons.science_outlined : Icons.schedule,
            size: 18,
          ),
          label: Text(
            c.mode == DataMode.demo
                ? 'Données de démonstration'
                : 'Simulation · données API datées',
          ),
        ),
        if (c.mode == DataMode.demo)
          const Text(
            'Horloge simulée : 23/10/2026, 20:00 UTC. Prix fictifs fixes.',
            style: TextStyle(fontSize: 12),
          ),
        if (c.loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  );
}

class PriceLabel extends StatelessWidget {
  const PriceLabel(this.q, this.c, {super.key});
  final Quote q;
  final AppController c;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Prix observé : ${stamp(q.at)}',
        style: const TextStyle(fontSize: 11),
      ),
      if (q.cachedAt != null)
        Text(
          'donnée en cache du ${stamp(q.cachedAt!)}',
          style: const TextStyle(fontSize: 11),
        ),
      if (!q.fresh(c.now))
        const Text(
          'Prix périmé · opérations bloquées',
          style: TextStyle(color: negative, fontSize: 12),
        ),
    ],
  );
}

class AssetTile extends StatelessWidget {
  const AssetTile(this.asset, this.c, {super.key});
  final Asset asset;
  final AppController c;
  @override
  Widget build(BuildContext context) {
    final q = c.quotes[asset.symbol];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/asset/${asset.symbol}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: deepGreen,
                    foregroundColor: lime,
                    child: Text(asset.symbol.substring(0, 1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.symbol,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(asset.name),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      q == null ? '—' : c.display(q.price),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favori ${asset.name}',
                    onPressed: () =>
                        attempt(context, () => c.favorite(asset.symbol)),
                    icon: Icon(
                      c.favorites.contains(asset.symbol)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: lime,
                    ),
                  ),
                ],
              ),
              if (q != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${percent(q.price - q.previous, q.previous)} · depuis clôture précédente',
                  style: TextStyle(
                    color: q.price >= q.previous ? lime : negative,
                    fontSize: 12,
                  ),
                ),
                PriceLabel(q, c),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
