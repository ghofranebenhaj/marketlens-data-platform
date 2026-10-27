import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/app_controller.dart';
import '../../core/database.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../cart/quantity_dialog.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen(this.c, this.symbol, {super.key});
  final AppController c;
  final String symbol;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<DetailData> future = widget.c.detail(widget.symbol);
  @override
  Widget build(BuildContext context) {
    final c = widget.c, a = assetFor(widget.symbol);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.symbol),
        actions: [
          IconButton(
            tooltip: 'Favori',
            onPressed: () => attempt(context, () => c.favorite(a.symbol)),
            icon: Icon(
              c.favorites.contains(a.symbol) ? Icons.star : Icons.star_outline,
              color: lime,
            ),
          ),
          IconButton(
            tooltip: 'Recharger le détail',
            onPressed: () => setState(() => future = c.detail(a.symbol)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<DetailData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement du cours, de la fiche et des actualités…'),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return PageBody(
                children: [
                  EmptyState('Données indisponibles', '${snapshot.error}'),
                  FilledButton(
                    onPressed: () =>
                        setState(() => future = c.detail(a.symbol)),
                    child: const Text('Réessayer'),
                  ),
                ],
              );
            }
            final d = snapshot.requireData, q = d.quote;
            return PageBody(
              children: [
                ModeBanner(c),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          d.company['logo'] is String &&
                              '${d.company['logo']}'.startsWith('https://')
                          ? Image.network(
                              '${d.company['logo']}',
                              width: 56,
                              height: 56,
                              errorBuilder: (_, _, _) => _logo(a),
                            )
                          : _logo(a),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text('${a.symbol} · USD'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  c.display(q.price),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  '${percent(q.price - q.previous, q.previous)} · depuis clôture précédente',
                  style: TextStyle(
                    color: q.price >= q.previous ? lime : negative,
                  ),
                ),
                const SizedBox(height: 8),
                PriceLabel(q, c),
                const SectionTitle('Historique du cours'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.points.length >= 2)
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (spots) => spots.map((s) {
                                    final point = q.points[s.x.toInt()];
                                    return LineTooltipItem(
                                      '${stamp(point.at)}\n${c.display(point.cents)}',
                                      const TextStyle(color: ink),
                                    );
                                  }).toList(),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: false,
                                  color: lime,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        lime.withValues(alpha: .18),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  spots: [
                                    for (var i = 0; i < q.points.length; i++)
                                      FlSpot(
                                        i.toDouble(),
                                        q.points[i].cents.toDouble(),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        c.mode == DataMode.demo
                            ? 'Série pédagogique fictive · 10 observations fixes'
                            : 'Twelve Data · clôtures journalières · jusqu’à 30 séances',
                      ),
                      if (q.points.isNotEmpty)
                        Text(
                          '${stamp(q.points.first.at)} → ${stamp(q.points.last.at)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (c.mode == DataMode.normal)
                        const Text(
                          'Les dates journalières sont des dates de séance, sans heure de cotation.',
                          style: TextStyle(fontSize: 11),
                        ),
                      if (q.historyCachedAt != null)
                        Text(
                          'donnée en cache du ${stamp(q.historyCachedAt!)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: c.tradingBusy
                          ? null
                          : () async {
                              final qty = await quantityDialog(
                                context,
                                title: 'Ajouter ${a.symbol} au panier',
                                initial: (c.cart[a.symbol] ?? 0) + 1,
                              );
                              if (qty != null && context.mounted) {
                                await attempt(
                                  context,
                                  () => c.setCart(a.symbol, qty),
                                  success: 'Panier mis à jour.',
                                );
                              }
                            },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Ajouter au panier'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          c.tradingBusy ||
                              !q.fresh(c.now) ||
                              !c.positions.any((p) => p.symbol == a.symbol)
                          ? null
                          : () async {
                              final held = c.positions.firstWhere(
                                (p) => p.symbol == a.symbol,
                              );
                              final qty = await quantityDialog(
                                context,
                                title: 'Vendre ${a.symbol}',
                                maximum: held.quantity,
                                subtitle:
                                    'Prix daté : ${c.display(q.price)} par action.\n${stamp(q.at)}\nLe solde sera crédité en USD fictifs.',
                              );
                              if (qty == null || !context.mounted) return;
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text(
                                    'Confirmer la vente simulée',
                                  ),
                                  content: Text(
                                    '$qty × ${a.symbol}\nMontant : ${c.display(qty * q.price)}\nGain réalisé estimé : ${c.display(realizedGain(q.price, qty, held.averageNumerator, held.averageDenominator))}\nPrix : ${stamp(q.at)}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Annuler'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Confirmer'),
                                    ),
                                  ],
                                ),
                              );
                              final op = operationId();
                              if (confirmed == true && context.mounted) {
                                await attempt(
                                  context,
                                  () => c.sell(op, a.symbol, qty, q),
                                  success: 'Vente simulée enregistrée.',
                                );
                              }
                            },
                      icon: const Icon(Icons.sell_outlined),
                      label: const Text('Vendre'),
                    ),
                  ],
                ),
                const SectionTitle('À propos de l’entreprise'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.company['name'] ?? a.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secteur : ${d.company['finnhubIndustry'] ?? 'Non renseigné'}',
                      ),
                      Text('Pays : ${d.company['country'] ?? 'Non renseigné'}'),
                      Text(
                        'Place : ${d.company['exchange'] ?? 'Non renseignée'}',
                      ),
                      SelectableText('${d.company['weburl'] ?? ''}'),
                      if (d.companyCache != null)
                        Text('donnée en cache du ${stamp(d.companyCache!)}'),
                      Text(
                        c.mode == DataMode.demo
                            ? 'Fiche pédagogique de démonstration'
                            : 'Source : Finnhub · Company Profile 2',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Actualités'),
                if (d.newsCache != null)
                  Text('donnée en cache du ${stamp(d.newsCache!)}'),
                if (c.mode == DataMode.normal)
                  const Text(
                    'Source : GNews · l’offre gratuite retarde les articles de 12 heures.',
                    style: TextStyle(fontSize: 12),
                  ),
                for (final article in d.news)
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${article['source']?['name'] ?? 'Source non renseignée'} · ${article['publishedAt'] ?? ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${article['title']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (article['description'] != null)
                          Text('${article['description']}'),
                        if (article['url'] != null)
                          SelectableText(
                            '${article['url']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _logo(Asset a) => Container(
    width: 56,
    height: 56,
    color: deepGreen,
    alignment: Alignment.center,
    child: Text(
      a.symbol.substring(0, 1),
      style: const TextStyle(color: lime, fontSize: 28),
    ),
  );
}
