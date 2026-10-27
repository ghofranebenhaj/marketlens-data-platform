import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import 'models.dart';
import 'money.dart';

const twelveKey = String.fromEnvironment('TWELVE_DATA_KEY');
const finnhubKey = String.fromEnvironment('FINNHUB_KEY');
const gnewsKey = String.fromEnvironment('GNEWS_KEY');
bool get hasKeys =>
    twelveKey.isNotEmpty && finnhubKey.isNotEmpty && gnewsKey.isNotEmpty;

class ApiFallback implements Exception {
  const ApiFallback(this.reason);
  final String reason;
}

class CachedData {
  const CachedData(this.data, this.fetchedAt, this.fromCache);
  final dynamic data;
  final DateTime fetchedAt;
  final bool fromCache;
}

bool cacheFresh(DateTime at, DateTime now, Duration ttl) =>
    !at.isAfter(now) && now.difference(at) < ttl;

class MarketApi {
  MarketApi(this.box, {Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 8),
            ),
          );
  final Box<dynamic> box;
  final Dio dio;
  DateTime? _lastTwelve, _lastNews;
  final Map<String, Future<CachedData>> _pending = {};

  Future<CachedData> get(
    String namespace,
    String key,
    String url,
    Map<String, dynamic> params,
    Duration ttl, {
    Map<String, dynamic>? headers,
    bool force = false,
    required bool Function(dynamic) valid,
  }) {
    final full = '$namespace:$key';
    return _pending.putIfAbsent(
      full,
      () => _fetch(full, key, url, params, ttl, headers, force, valid)
          .whenComplete(() {
            _pending.remove(full);
          }),
    );
  }

  Future<CachedData> _fetch(
    String full,
    String key,
    String url,
    Map<String, dynamic> params,
    Duration ttl,
    Map<String, dynamic>? headers,
    bool force,
    bool Function(dynamic) valid,
  ) async {
    final saved = box.get(full);
    if (!force && saved is String) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        final at = DateTime.parse(map['at'] as String);
        if (cacheFresh(at, DateTime.now().toUtc(), ttl) && valid(map['data'])) {
          return CachedData(map['data'], at, true);
        }
      } catch (_) {
        await box.delete(full);
      }
    }
    try {
      // Espacement local prudent : pas de rafales ni de boucle de retry sur quota.
      final isTwelve = url.contains('twelvedata');
      final isNews = url.contains('gnews');
      final last = isTwelve
          ? _lastTwelve
          : isNews
          ? _lastNews
          : null;
      final spacing = Duration(milliseconds: isTwelve ? 8100 : 1100);
      if (last != null && DateTime.now().difference(last) < spacing) {
        await Future<void>.delayed(spacing - DateTime.now().difference(last));
      }
      if (isTwelve) _lastTwelve = DateTime.now();
      if (isNews) _lastNews = DateTime.now();
      final response = await dio.get<dynamic>(
        url,
        queryParameters: params,
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data is Map && (data['status'] == 'error' || data['error'] != null)) {
        final quota = data['code'] == 429;
        throw ApiFallback(
          quota ? 'Quota API atteint.' : 'Le fournisseur a refusé la requête.',
        );
      }
      if (!valid(data)) {
        throw const ApiFallback('Réponse API vide ou invalide.');
      }
      final at = DateTime.now().toUtc();
      await box.put(
        full,
        jsonEncode({'at': at.toIso8601String(), 'data': data}),
      );
      return CachedData(data, at, false);
    } on ApiFallback {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiFallback(
        status == 429 || status == 403
            ? 'Quota ou accès API refusé (HTTP $status).'
            : status != null
            ? 'Service indisponible (HTTP $status).'
            : 'Connexion indisponible ou délai dépassé.',
      );
    } catch (_) {
      throw const ApiFallback('Réponse API impossible à interpréter.');
    }
  }

  Quote demoQuote(Asset a) {
    const offsets = [-360, -190, -260, -80, -120, 90, 30, 160, 100, 0];
    return Quote(
      symbol: a.symbol,
      price: a.fixture,
      previous: a.fixture - 160,
      at: demoClock,
      mode: DataMode.demo,
      points: [
        for (var i = 0; i < offsets.length; i++)
          PricePoint(
            demoClock.subtract(Duration(days: offsets.length - 1 - i)),
            a.fixture + offsets[i],
          ),
      ],
    );
  }

  Future<Quote> quote(
    String ns,
    Asset a, {
    bool force = false,
    bool history = false,
  }) async {
    final q = await get(
      ns,
      'quote:${a.symbol}',
      'https://api.twelvedata.com/quote',
      {'symbol': a.symbol, 'apikey': twelveKey},
      const Duration(minutes: 5),
      force: force,
      valid: (d) =>
          d is Map &&
          d['close'] != null &&
          d['previous_close'] != null &&
          d['timestamp'] != null,
    );
    final data = q.data as Map;
    final price = cents('${data['close']}');
    if (price <= 0 || '${data['currency']}' != 'USD') {
      throw const ApiFallback('Prix ou devise inattendu.');
    }
    List<PricePoint> points = [];
    DateTime? historyCachedAt;
    if (history) {
      final h = await get(
        ns,
        'history:${a.symbol}',
        'https://api.twelvedata.com/time_series',
        {
          'symbol': a.symbol,
          'interval': '1day',
          'outputsize': 30,
          'apikey': twelveKey,
        },
        const Duration(hours: 12),
        valid: (d) =>
            d is Map && d['values'] is List && (d['values'] as List).isNotEmpty,
      );
      historyCachedAt = h.fromCache ? h.fetchedAt : null;
      points = [
        for (final row in h.data['values'])
          PricePoint(
            DateTime.parse('${row['datetime']}T00:00:00Z'),
            cents('${row['close']}'),
          ),
      ];
      points.sort((a, b) => a.at.compareTo(b.at));
    }
    return Quote(
      symbol: a.symbol,
      price: price,
      previous: cents('${data['previous_close']}'),
      at: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num).toInt() * 1000,
        isUtc: true,
      ),
      mode: DataMode.normal,
      points: points,
      cachedAt: q.fromCache ? q.fetchedAt : null,
      historyCachedAt: historyCachedAt,
    );
  }

  Future<CachedData> company(String ns, String symbol) => get(
    ns,
    'company:$symbol',
    'https://finnhub.io/api/v1/stock/profile2',
    {'symbol': symbol},
    const Duration(days: 7),
    headers: {'X-Finnhub-Token': finnhubKey},
    valid: (d) => d is Map && d['name'] is String && '${d['name']}'.isNotEmpty,
  );
  Future<CachedData> news(String ns, Asset a) => get(
    ns,
    'news:${a.symbol}',
    'https://gnews.io/api/v4/search',
    {'q': '"${a.name}"', 'lang': 'en', 'max': 5, 'apikey': gnewsKey},
    const Duration(hours: 12),
    valid: (d) =>
        d is Map && d['articles'] is List && (d['articles'] as List).isNotEmpty,
  );
  Future<CachedData> rate(String ns, String currency) => get(
    ns,
    'fx:$currency',
    'https://api.frankfurter.dev/v2/rate/usd/${currency.toLowerCase()}',
    {},
    const Duration(hours: 24),
    valid: (d) => d is Map && d['rate'] != null && d['date'] != null,
  );
}
