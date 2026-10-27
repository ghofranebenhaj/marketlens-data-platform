import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database.dart';
import '../../core/models.dart';
import '../../core/money.dart';

final tradingServiceProvider = Provider<TradingService>(
  (ref) => const TradingService(),
);

/// Toutes les mutations financières sont ici, sous une transaction SQLite.
class TradingService {
  const TradingService();
  void _validate(Quote? q, String symbol, LocalDatabase store, DateTime now) {
    if (q == null ||
        q.symbol != symbol ||
        q.mode != store.mode ||
        q.price <= 0 ||
        !q.fresh(now)) {
      throw const AppFailure(
        'Prix absent ou périmé (15 min). Actualisez les données avant de confirmer.',
      );
    }
  }

  Future<void> buy(
    LocalDatabase store,
    int uid,
    String operation,
    Map<String, int> expectedCart,
    Map<String, Quote> quotes,
    DateTime now,
  ) async {
    if (operation.isEmpty) {
      throw const AppFailure('Identifiant d’opération manquant.');
    }
    await store.db.transaction((tx) async {
      if ((await tx.query(
        'transactions',
        where: 'user_id = ? AND operation_id = ?',
        whereArgs: [uid, operation],
      )).isNotEmpty) {
        throw const AppFailure('Cette opération a déjà été validée.');
      }
      final rows = await tx.query(
        'cart_items',
        where: 'user_id = ?',
        whereArgs: [uid],
      );
      if (rows.isEmpty) throw const AppFailure('Votre panier est vide.');
      if (rows.length != expectedCart.length ||
          rows.any((r) => expectedCart[r['symbol']] != r['quantity'])) {
        throw const AppFailure(
          'Le panier a changé. Vérifiez le nouveau total.',
        );
      }
      var total = 0;
      for (final r in rows) {
        final symbol = r['symbol'] as String;
        final qty = r['quantity'] as int;
        if (qty <= 0 || qty > 1000000) {
          throw const AppFailure('Quantité invalide.');
        }
        _validate(quotes[symbol], symbol, store, now);
        total += qty * quotes[symbol]!.price;
      }
      final user = (await tx.query(
        'users',
        where: 'id = ?',
        whereArgs: [uid],
      )).single;
      final balance = user['balance_cents'] as int;
      if (total > balance) {
        throw const AppFailure('Solde insuffisant pour cet achat.');
      }
      for (final r in rows) {
        final symbol = r['symbol'] as String;
        final qty = r['quantity'] as int;
        final q = quotes[symbol]!;
        final old = await tx.query(
          'positions',
          where: 'user_id = ? AND symbol = ?',
          whereArgs: [uid, symbol],
        );
        final oldQty = old.isEmpty ? 0 : old.single['quantity'] as int;
        final oldNum = old.isEmpty ? 0 : old.single['average_num'] as int;
        final oldDen = old.isEmpty ? 1 : old.single['average_den'] as int;
        final numerator =
            BigInt.from(oldNum) * BigInt.from(oldQty) +
            BigInt.from(q.price * qty) * BigInt.from(oldDen);
        final denominator = BigInt.from(oldDen) * BigInt.from(oldQty + qty);
        final gcd = numerator.gcd(denominator);
        final n = numerator ~/ gcd, d = denominator ~/ gcd;
        if (n.bitLength > 62 || d.bitLength > 62) {
          throw const AppFailure(
            'Limite de précision atteinte pour cette position.',
          );
        }
        if (old.isEmpty) {
          await tx.insert('positions', {
            'user_id': uid,
            'symbol': symbol,
            'quantity': qty,
            'average_num': n.toInt(),
            'average_den': d.toInt(),
          });
        } else {
          await tx.update(
            'positions',
            {
              'quantity': oldQty + qty,
              'average_num': n.toInt(),
              'average_den': d.toInt(),
            },
            where: 'user_id = ? AND symbol = ?',
            whereArgs: [uid, symbol],
          );
        }
        await tx.insert('transactions', {
          'user_id': uid,
          'operation_id': operation,
          'symbol': symbol,
          'side': 'buy',
          'quantity': qty,
          'price_cents': q.price,
          'created_at': now.toIso8601String(),
          'price_at': q.at.toIso8601String(),
        });
      }
      await tx.update(
        'users',
        {'balance_cents': balance - total},
        where: 'id = ?',
        whereArgs: [uid],
      );
      await tx.delete('cart_items', where: 'user_id = ?', whereArgs: [uid]);
    });
  }

  Future<void> sell(
    LocalDatabase store,
    int uid,
    String operation,
    String symbol,
    int qty,
    Quote quote,
    DateTime now,
  ) async {
    if (qty <= 0 || qty > 1000000) {
      throw const AppFailure(
        'La quantité doit être un entier strictement positif.',
      );
    }
    if (operation.isEmpty) {
      throw const AppFailure('Identifiant d’opération manquant.');
    }
    await store.db.transaction((tx) async {
      if ((await tx.query(
        'transactions',
        where: 'user_id = ? AND operation_id = ?',
        whereArgs: [uid, operation],
      )).isNotEmpty) {
        throw const AppFailure('Cette opération a déjà été validée.');
      }
      _validate(quote, symbol, store, now);
      final rows = await tx.query(
        'positions',
        where: 'user_id = ? AND symbol = ?',
        whereArgs: [uid, symbol],
      );
      if (rows.isEmpty || qty > (rows.single['quantity'] as int)) {
        throw const AppFailure('Quantité supérieure à la position détenue.');
      }
      final r = rows.single;
      final remaining = (r['quantity'] as int) - qty;
      final realized = realizedGain(
        quote.price,
        qty,
        r['average_num'] as int,
        r['average_den'] as int,
      );
      if (remaining == 0) {
        await tx.delete(
          'positions',
          where: 'user_id = ? AND symbol = ?',
          whereArgs: [uid, symbol],
        );
      } else {
        // La fraction du coût moyen est conservée exactement après une vente.
        await tx.update(
          'positions',
          {'quantity': remaining},
          where: 'user_id = ? AND symbol = ?',
          whereArgs: [uid, symbol],
        );
      }
      await tx.rawUpdate(
        'UPDATE users SET balance_cents = balance_cents + ? WHERE id = ?',
        [qty * quote.price, uid],
      );
      await tx.insert('transactions', {
        'user_id': uid,
        'operation_id': operation,
        'symbol': symbol,
        'side': 'sell',
        'quantity': qty,
        'price_cents': quote.price,
        'realized_cents': realized,
        'created_at': now.toIso8601String(),
        'price_at': quote.at.toIso8601String(),
      });
    });
  }
}
