import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:marekt_lens/core/database.dart';
import 'package:marekt_lens/core/models.dart';
import 'package:marekt_lens/core/money.dart';
import 'package:marekt_lens/core/network.dart';
import 'package:marekt_lens/features/portfolio/trading_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase store;
  late Account alice, bob;
  const service = TradingService();
  Quote quote({
    int price = 10000,
    String symbol = 'AAPL',
    DateTime? at,
    DataMode mode = DataMode.demo,
  }) => Quote(
    symbol: symbol,
    price: price,
    previous: 9900,
    at: at ?? demoClock,
    mode: mode,
    points: const [],
  );
  Future<void> buy(int qty, {int price = 10000, String op = 'buy'}) async {
    await store.setCart(alice.id, 'AAPL', qty);
    await service.buy(
      store,
      alice.id,
      op,
      {'AAPL': qty},
      {'AAPL': quote(price: price)},
      demoClock,
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    store = await LocalDatabase.open(
      DataMode.demo,
      factory: databaseFactoryFfi,
      file: inMemoryDatabasePath,
    );
    alice = await store.register(
      'Alice',
      'alice@example.test',
      'motdepasse123',
    );
    bob = await store.register('Bob', 'bob@example.test', 'motdepasse123');
  });
  tearDownAll(() async => store.db.close());
  setUp(() async {
    for (final table in ['transactions', 'positions', 'cart_items']) {
      await store.db.delete(table);
    }
    await store.db.update('users', {'balance_cents': 1000000});
  });
  test('capital initial unique, ne revient pas à la connexion', () async {
    await buy(2);
    final logged = await store.login('ALICE@example.test', 'motdepasse123');
    expect(logged.balance, 980000);
    await expectLater(
      store.register('Alice', 'alice@example.test', 'motdepasse123'),
      throwsA(isA<AppFailure>()),
    );
    expect((await store.account(alice.id)).balance, 980000);
  });
  test(
    'PBKDF2 salé, aucun mot de passe en clair, mauvaise connexion refusée',
    () async {
      final rows = await store.db.query('users');
      expect(rows[0]['salt'], isNot(rows[1]['salt']));
      expect(rows[0]['password_hash'], isNot(rows[1]['password_hash']));
      expect(rows[0].values, isNot(contains('motdepasse123')));
      await expectLater(
        store.login('alice@example.test', 'incorrect'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'isolation utilisateurs des paniers, positions et transactions',
    () async {
      await buy(3);
      expect(await store.positions(bob.id), isEmpty);
      expect(await store.cart(bob.id), isEmpty);
      expect(await store.trades(bob.id), isEmpty);
      expect((await store.account(bob.id)).balance, 1000000);
      await expectLater(
        service.sell(store, bob.id, 'foreign', 'AAPL', 1, quote(), demoClock),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('quantité invalide refusée', () async {
    await expectLater(
      store.setCart(alice.id, 'AAPL', -1),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      store.setCart(alice.id, 'AAPL', 1000001),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      service.sell(store, alice.id, 's', 'AAPL', 0, quote(), demoClock),
      throwsA(isA<AppFailure>()),
    );
  });
  test('solde insuffisant : aucune mutation partielle', () async {
    await expectLater(buy(101), throwsA(isA<AppFailure>()));
    expect((await store.account(alice.id)).balance, 1000000);
    expect(await store.positions(alice.id), isEmpty);
    expect(await store.trades(alice.id), isEmpty);
    expect(await store.cart(alice.id), {'AAPL': 101});
  });
  test(
    'double validation achat refusée même après reconstruction du panier',
    () async {
      await buy(1);
      await store.setCart(alice.id, 'AAPL', 1);
      await expectLater(
        service.buy(
          store,
          alice.id,
          'buy',
          {'AAPL': 1},
          {'AAPL': quote()},
          demoClock,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect((await store.account(alice.id)).balance, 990000);
      expect((await store.positions(alice.id)).single.quantity, 1);
    },
  );
  test('confirmation rejetée si panier modifié', () async {
    await store.setCart(alice.id, 'AAPL', 3);
    await expectLater(
      service.buy(
        store,
        alice.id,
        'b',
        {'AAPL': 2},
        {'AAPL': quote()},
        demoClock,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(await store.trades(alice.id), isEmpty);
  });
  test('achat multi-action atomique si un seul prix est périmé', () async {
    await store.setCart(alice.id, 'AAPL', 1);
    await store.setCart(alice.id, 'MSFT', 1);
    await expectLater(
      service.buy(
        store,
        alice.id,
        'multi',
        {'AAPL': 1, 'MSFT': 1},
        {
          'AAPL': quote(),
          'MSFT': quote(
            symbol: 'MSFT',
            at: demoClock.subtract(const Duration(hours: 1)),
          ),
        },
        demoClock,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(await store.positions(alice.id), isEmpty);
    expect(await store.trades(alice.id), isEmpty);
    expect((await store.account(alice.id)).balance, 1000000);
  });
  test('vente supérieure à quantité détenue refusée', () async {
    await buy(2);
    await expectLater(
      service.sell(store, alice.id, 's', 'AAPL', 3, quote(), demoClock),
      throwsA(isA<AppFailure>()),
    );
    expect((await store.positions(alice.id)).single.quantity, 2);
  });
  test(
    'vente totale : position supprimée, solde crédité et gain réalisé',
    () async {
      await buy(2);
      await service.sell(
        store,
        alice.id,
        'sell',
        'AAPL',
        2,
        quote(price: 12000),
        demoClock,
      );
      expect(await store.positions(alice.id), isEmpty);
      expect((await store.account(alice.id)).balance, 1004000);
      expect((await store.trades(alice.id)).first['realized_cents'], 4000);
    },
  );
  test('coût moyen exact conservé après vente partielle', () async {
    await buy(2, price: 10001);
    await buy(1, price: 10002, op: 'b2');
    final p = (await store.positions(alice.id)).single;
    expect(p.averageNumerator, 30004);
    expect(p.averageDenominator, 3);
    await service.sell(
      store,
      alice.id,
      's',
      'AAPL',
      1,
      quote(price: 11000),
      demoClock,
    );
    final after = (await store.positions(alice.id)).single;
    expect(after.quantity, 2);
    expect(after.averageNumerator, p.averageNumerator);
    expect(after.averageDenominator, p.averageDenominator);
    expect((await store.trades(alice.id)).first['realized_cents'], 999);
  });
  test('double vente refusée', () async {
    await buy(3);
    await service.sell(store, alice.id, 'sell', 'AAPL', 1, quote(), demoClock);
    await expectLater(
      service.sell(store, alice.id, 'sell', 'AAPL', 1, quote(), demoClock),
      throwsA(isA<AppFailure>()),
    );
    expect((await store.positions(alice.id)).single.quantity, 2);
  });
  test('prix périmé, futur, ou mauvais mode bloqués', () async {
    await buy(3);
    for (final q in [
      quote(at: demoClock.subtract(const Duration(minutes: 16))),
      quote(at: demoClock.add(const Duration(hours: 1))),
      quote(mode: DataMode.normal),
    ]) {
      await expectLater(
        service.sell(store, alice.id, 's', 'AAPL', 1, q, demoClock),
        throwsA(isA<AppFailure>()),
      );
    }
    expect((await store.positions(alice.id)).single.quantity, 3);
  });
  test('calculs et arrondis décimaux sans flottant', () {
    expect(cents('123.455'), 12346);
    expect(cents('-0.005'), -1);
    expect(cents('0.004'), 0);
    expect(roundedRatio(10001 * 3, 2), 15002);
    expect(percent(1500, 10000), '+15,00 %');
    expect(percent(-1500, 10000), '−15,00 %');
    expect(percent(1, 0), '—');
    expect(money(1000000), contains('000,00 USD'));
  });
  test('cache périmé et horloge future invalides', () {
    expect(
      cacheFresh(
        demoClock,
        demoClock.add(const Duration(minutes: 4)),
        const Duration(minutes: 5),
      ),
      isTrue,
    );
    expect(
      cacheFresh(
        demoClock,
        demoClock.add(const Duration(minutes: 5)),
        const Duration(minutes: 5),
      ),
      isFalse,
    );
    expect(
      cacheFresh(
        demoClock,
        demoClock.subtract(const Duration(seconds: 1)),
        const Duration(minutes: 5),
      ),
      isFalse,
    );
  });
  test('migration v1 vers v2 conserve les opérations et renseigne date prix', () async {
    final path =
        '${await databaseFactoryFfi.getDatabasesPath()}/migration_marekt_test.db';
    await databaseFactoryFfi.deleteDatabase(path);
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE transactions(id INTEGER PRIMARY KEY, created_at TEXT NOT NULL)',
          );
          await db.insert('transactions', {
            'created_at': demoClock.toIso8601String(),
          });
        },
      ),
    );
    await v1.close();
    final upgraded = await LocalDatabase.open(
      DataMode.demo,
      factory: databaseFactoryFfi,
      file: path,
    );
    expect(
      (await upgraded.db.query('transactions')).single['price_at'],
      demoClock.toIso8601String(),
    );
    await upgraded.db.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });
}
