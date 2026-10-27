import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../features/portfolio/trading_service.dart';
import '../features/watchlist/watchlist.dart';
import 'database.dart';
import 'models.dart';
import 'money.dart';
import 'network.dart';

final appProvider = Provider<AppController>(
  (ref) => throw StateError('Initialisation requise'),
);

class DetailData {
  const DetailData(
    this.quote,
    this.company,
    this.news,
    this.companyCache,
    this.newsCache,
  );
  final Quote quote;
  final Map<String, dynamic> company;
  final List<dynamic> news;
  final DateTime? companyCache, newsCache;
}

class AppController extends ChangeNotifier {
  AppController(this.stores, this.box, this.api, this.trading)
    : mode = hasKeys ? DataMode.normal : DataMode.demo;
  final Map<DataMode, LocalDatabase> stores;
  final Box<dynamic> box;
  final MarketApi api;
  final TradingService trading;
  DataMode mode;
  int _session = 0;
  Account? user;
  Map<String, Quote> quotes = {};
  Map<String, int> cart = {};
  List<Position> positions = [];
  List<Map<String, Object?>> trades = [];
  bool loading = false, tradingBusy = false;
  String? error;
  String notice = hasKeys
      ? 'Données API datées ; aucun ordre réel.'
      : 'Clés absentes : entraînement avec des fixtures déterministes.';
  LocalDatabase get store => stores[mode]!;
  String get scope => '${mode.name}:${user?.id ?? 0}';
  DateTime get now =>
      mode == DataMode.demo ? demoClock : DateTime.now().toUtc();
  String get currency =>
      box.get('$scope:currency', defaultValue: 'USD') as String;
  String get risk =>
      box.get('$scope:risk', defaultValue: 'Équilibré') as String;
  String get theme => box.get('$scope:theme', defaultValue: 'Sombre') as String;
  Set<String> get favorites => Watchlist(box).read(scope);
  int rateNum = 1, rateDen = 1;
  DateTime? rateAt, rateCache;
  String display(int usdCents) => currency != 'USD' && rateAt == null
      ? 'Taux de conversion en attente'
      : money(productRatio(usdCents, rateNum, rateDen), currency: currency);
  int positionCost(Position p) =>
      productRatio(p.quantity, p.averageNumerator, p.averageDenominator);
  bool get valuationReady =>
      positions.every((p) => quotes.containsKey(p.symbol));
  int positionValue(Position p) => p.quantity * (quotes[p.symbol]?.price ?? 0);
  int get positionsValue => positions.fold(0, (s, p) => s + positionValue(p));
  int get unrealized =>
      positionsValue - positions.fold(0, (s, p) => s + positionCost(p));
  int get total => (user?.balance ?? 0) + positionsValue;
  int get cartTotal =>
      cart.entries.fold(0, (s, e) => s + e.value * (quotes[e.key]?.price ?? 0));
  bool get freshCart =>
      cart.isNotEmpty && cart.keys.every((s) => quotes[s]?.fresh(now) ?? false);

  Future<void> authenticate(
    bool register,
    String name,
    String email,
    String password,
  ) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final session = _session;
    final local = store;
    try {
      final account = register
          ? await local.register(name, email, password)
          : await local.login(email, password);
      if (session != _session) return;
      user = account;
      await reload();
      await refresh();
      if (user != null && currency != 'USD') await setCurrency(currency);
    } catch (e) {
      error = e is AppFailure
          ? e.message
          : 'Impossible d’ouvrir le compte local.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final uid = user?.id;
    if (uid == null) return;
    final captured = scope;
    final local = store;
    final account = await local.account(uid);
    final items = await local.cart(uid);
    final holdings = await local.positions(uid);
    final history = await local.trades(uid);
    if (captured != scope) return;
    user = account;
    cart = items;
    positions = holdings;
    trades = history;
    notifyListeners();
  }

  Future<void> refresh({bool force = false}) async {
    if (user == null) return;
    loading = true;
    error = null;
    notifyListeners();
    final capturedScope = scope;
    try {
      final result = <String, Quote>{};
      for (final a in catalog) {
        result[a.symbol] = mode == DataMode.demo
            ? api.demoQuote(a)
            : await api.quote(capturedScope, a, force: force);
        if (scope != capturedScope) return;
      }
      quotes = result;
      if (mode == DataMode.demo) {
        await box.put('$scope:fixture-cache', {
          'at': demoClock.toIso8601String(),
          'source': 'fixtures-v1',
        });
      }
    } on ApiFallback catch (e) {
      if (capturedScope == scope) fallback(e.reason);
    } catch (_) {
      if (capturedScope == scope) fallback('Données de marché invalides.');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void fallback(String reason) {
    mode = DataMode.demo;
    logout();
    notice =
        '$reason Mode démo activé. Connectez-vous ou créez un compte démo distinct ; le portefeuille API est conservé.';
    notifyListeners();
  }

  void changeMode(DataMode next) {
    if (next == DataMode.normal && !hasKeys) {
      throw const AppFailure('Les trois clés dart-define sont requises.');
    }
    mode = next;
    logout();
    notice =
        'Mode ${next == DataMode.demo ? 'démo' : 'API'} : comptes et portefeuilles séparés. Connectez-vous dans ce mode.';
    notifyListeners();
  }

  void logout() {
    _session++;
    user = null;
    quotes = {};
    cart = {};
    positions = [];
    trades = [];
    rateNum = 1;
    rateDen = 1;
    rateAt = null;
    rateCache = null;
    error = null;
    notifyListeners();
  }

  Future<void> favorite(String symbol) async {
    await Watchlist(box).toggle(scope, symbol);
    notifyListeners();
  }

  Future<void> preference(String key, String value) async {
    await box.put('$scope:$key', value);
    notifyListeners();
  }

  Future<void> setCurrency(String value) async {
    final captured = scope;
    if (value == 'USD') {
      rateNum = 1;
      rateDen = 1;
      rateAt = null;
      rateCache = null;
      await preference('currency', value);
      return;
    }
    try {
      late final String rate;
      if (mode == DataMode.demo) {
        rate = value == 'EUR' ? '0.92' : '0.77';
        rateAt = demoClock;
        rateCache = null;
      } else {
        final d = await api.rate(scope, value);
        if (captured != scope) return;
        rate = '${d.data['rate']}';
        rateAt = DateTime.parse('${d.data['date']}');
        rateCache = d.fromCache ? d.fetchedAt : null;
      }
      final r = decimalRatio(rate);
      if (r.numerator <= 0) {
        throw const ApiFallback('Taux de conversion invalide.');
      }
      rateNum = r.numerator;
      rateDen = r.denominator;
      await preference('currency', value);
    } on ApiFallback catch (e) {
      if (captured == scope) fallback(e.reason);
    } catch (_) {
      if (captured == scope) fallback('Taux de conversion invalide.');
    }
  }

  Future<DetailData> detail(String symbol) async {
    final a = assetFor(symbol);
    if (mode == DataMode.demo) {
      final q = api.demoQuote(a);
      return DetailData(
        q,
        {
          'name': a.name,
          'finnhubIndustry': a.sector,
          'country': 'US',
          'exchange': 'Marché américain',
          'weburl': 'Fiche pédagogique — données de démonstration',
        },
        [
          {
            'title': 'Comprendre les risques liés à ${a.name}',
            'description': 'Exemple pédagogique : une action peut gagner ou perdre de la valeur. Ce texte est une fixture, pas une actualité.',
            'publishedAt': demoClock.toIso8601String(),
            'source': {'name': 'MarektLens · Démonstration'},
          },
        ],
        null,
        null,
      );
    }
    final captured = scope;
    try {
      final q = await api.quote(scope, a, history: true);
      final company = await api.company(scope, symbol);
      final news = await api.news(scope, a);
      if (captured != scope) throw const AppFailure('Session modifiée.');
      quotes[symbol] = q;
      notifyListeners();
      return DetailData(
        q,
        Map<String, dynamic>.from(company.data as Map),
        List<dynamic>.from(news.data['articles'] as List),
        company.fromCache ? company.fetchedAt : null,
        news.fromCache ? news.fetchedAt : null,
      );
    } on ApiFallback catch (e) {
      if (captured == scope) fallback(e.reason);
      throw const AppFailure(
        'Mode démo activé. Reconnectez-vous au compte démo.',
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      if (captured == scope) fallback('Réponse API de détail invalide.');
      throw const AppFailure('Mode démo activé après une réponse invalide.');
    }
  }

  Future<void> setCart(String symbol, int quantity) async {
    if (tradingBusy) throw const AppFailure('Une opération est en cours.');
    await store.setCart(user!.id, symbol, quantity);
    await reload();
  }

  Future<void> buy(
    String operation,
    Map<String, int> expected,
    Map<String, Quote> confirmedQuotes,
  ) async {
    if (tradingBusy) throw const AppFailure('Validation déjà en cours.');
    for (final symbol in expected.keys) {
      if (confirmedQuotes[symbol]?.price != quotes[symbol]?.price ||
          confirmedQuotes[symbol]?.at != quotes[symbol]?.at) {
        throw const AppFailure(
          'Un cours a changé. Vérifiez le nouveau prix avant de confirmer.',
        );
      }
    }
    tradingBusy = true;
    notifyListeners();
    try {
      await trading.buy(
        store,
        user!.id,
        operation,
        expected,
        confirmedQuotes,
        now,
      );
      await reload();
    } finally {
      tradingBusy = false;
      notifyListeners();
    }
  }

  Future<void> sell(
    String operation,
    String symbol,
    int quantity,
    Quote expected,
  ) async {
    if (tradingBusy) throw const AppFailure('Validation déjà en cours.');
    if (expected.price != quotes[symbol]?.price ||
        expected.at != quotes[symbol]?.at) {
      throw const AppFailure(
        'Le cours a changé. Rechargez le détail avant de vendre.',
      );
    }
    tradingBusy = true;
    notifyListeners();
    try {
      await trading.sell(
        store,
        user!.id,
        operation,
        symbol,
        quantity,
        expected,
        now,
      );
      await reload();
    } finally {
      tradingBusy = false;
      notifyListeners();
    }
  }
}
