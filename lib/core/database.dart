import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'money.dart';

String operationId() => base64UrlEncode(
  List<int>.generate(24, (_) => Random.secure().nextInt(256)),
);

class LocalDatabase {
  LocalDatabase(this.db, this.mode);
  final Database db;
  final DataMode mode;
  static Future<LocalDatabase> open(
    DataMode mode, {
    DatabaseFactory? factory,
    String? file,
  }) async {
    final f = factory ?? databaseFactory;
    final filePath =
        file ??
        p.join(await f.getDatabasesPath(), 'marekt_lens_${mode.name}.db');
    final db = await f.openDatabase(
      filePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            '''CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER UNIQUE,
          name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, password_hash TEXT NOT NULL,
          balance_cents INTEGER NOT NULL DEFAULT 1000000 CHECK(balance_cents >= 0),
          capital_granted INTEGER NOT NULL DEFAULT 1 CHECK(capital_granted = 1))''',
          );
          await db.execute(
            '''CREATE TABLE assets (user_id INTEGER NOT NULL REFERENCES users(id),
          symbol TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY(user_id, symbol))''',
          );
          await db.execute('''CREATE TABLE cart_items (user_id INTEGER NOT NULL, symbol TEXT NOT NULL,
          quantity INTEGER NOT NULL CHECK(quantity > 0), PRIMARY KEY(user_id, symbol),
          FOREIGN KEY(user_id, symbol) REFERENCES assets(user_id, symbol))''');
          await db.execute('''CREATE TABLE positions (user_id INTEGER NOT NULL, symbol TEXT NOT NULL,
          quantity INTEGER NOT NULL CHECK(quantity > 0), average_num INTEGER NOT NULL,
          average_den INTEGER NOT NULL CHECK(average_den > 0), PRIMARY KEY(user_id, symbol),
          FOREIGN KEY(user_id, symbol) REFERENCES assets(user_id, symbol))''');
          await db.execute(
            '''CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL, operation_id TEXT NOT NULL, symbol TEXT NOT NULL,
          side TEXT NOT NULL CHECK(side IN ('buy','sell')), quantity INTEGER NOT NULL CHECK(quantity > 0),
          price_cents INTEGER NOT NULL, realized_cents INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, price_at TEXT NOT NULL, UNIQUE(user_id, operation_id, symbol),
          FOREIGN KEY(user_id, symbol) REFERENCES assets(user_id, symbol))''',
          );
          await db.execute(
            'CREATE INDEX transactions_user_date ON transactions(user_id, created_at)',
          );
        },
        onUpgrade: (db, old, version) async {
          if (old < 2) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN price_at TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "UPDATE transactions SET price_at = created_at WHERE price_at = ''",
            );
          }
        },
      ),
    );
    return LocalDatabase(db, mode);
  }

  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  Future<String> _hash(String password, List<int> salt) async => base64Encode(
    await (await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    )).extractBytes(),
  );
  Future<Account> register(String name, String email, String password) async {
    name = name.trim();
    email = email.trim().toLowerCase();
    if (name.isEmpty || name.length > 60) {
      throw const AppFailure('Nom requis, de 1 à 60 caractères.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const AppFailure('Adresse e-mail invalide.');
    }
    if (password.length < 8 || password.length > 128) {
      throw const AppFailure('Mot de passe : 8 à 128 caractères.');
    }
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final hash = await _hash(password, salt);
    try {
      final id = await db.transaction((tx) async {
        final id = await tx.insert('users', {
          'name': name,
          'email': email,
          'salt': base64Encode(salt),
          'password_hash': hash,
        });
        await tx.update(
          'users',
          {'user_id': id},
          where: 'id = ?',
          whereArgs: [id],
        );
        for (final a in catalog) {
          await tx.insert('assets', {
            'user_id': id,
            'symbol': a.symbol,
            'name': a.name,
          });
        }
        return id;
      });
      return await account(id);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AppFailure(
          'Cette adresse possède déjà un compte dans ce mode.',
        );
      }
      rethrow;
    }
  }

  Future<Account> login(String email, String password) async {
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    final salt = rows.isEmpty
        ? List<int>.filled(24, 0)
        : base64Decode(rows.first['salt'] as String);
    final actual = base64Decode(await _hash(password, salt));
    final expected = rows.isEmpty
        ? List<int>.filled(32, 0)
        : base64Decode(rows.first['password_hash'] as String);
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    if (rows.isEmpty || diff != 0) {
      throw const AppFailure('E-mail ou mot de passe incorrect.');
    }
    return account(rows.first['id'] as int);
  }

  Future<Account> account(int uid) async {
    final r = (await db.query(
      'users',
      where: 'id = ? AND user_id = ?',
      whereArgs: [uid, uid],
    )).single;
    return Account(
      uid,
      r['name'] as String,
      r['email'] as String,
      r['balance_cents'] as int,
    );
  }

  Future<Map<String, int>> cart(int uid) async => {
    for (final r in await db.query(
      'cart_items',
      where: 'user_id = ?',
      whereArgs: [uid],
    ))
      r['symbol'] as String: r['quantity'] as int,
  };
  Future<void> setCart(int uid, String symbol, int qty) async {
    assetFor(symbol);
    if (qty < 0 || qty > 1000000) {
      throw const AppFailure('Quantité entière requise, entre 1 et 1 000 000.');
    }
    if (qty == 0) {
      await db.delete(
        'cart_items',
        where: 'user_id = ? AND symbol = ?',
        whereArgs: [uid, symbol],
      );
    } else {
      await db.insert('cart_items', {
        'user_id': uid,
        'symbol': symbol,
        'quantity': qty,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Position>> positions(int uid) async => [
    for (final r in await db.query(
      'positions',
      where: 'user_id = ?',
      whereArgs: [uid],
    ))
      Position(
        r['symbol'] as String,
        r['quantity'] as int,
        r['average_num'] as int,
        r['average_den'] as int,
      ),
  ];
  Future<List<Map<String, Object?>>> trades(int uid) => db.query(
    'transactions',
    where: 'user_id = ?',
    whereArgs: [uid],
    orderBy: 'id DESC',
  );
}
