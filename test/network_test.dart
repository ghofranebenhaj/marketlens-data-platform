import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:marekt_lens/core/models.dart';
import 'package:marekt_lens/core/network.dart';
import 'package:marekt_lens/features/watchlist/watchlist.dart';

class FixtureAdapter implements HttpClientAdapter {
  int calls = 0;
  int status = 200;
  dynamic payload;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    last = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late FixtureAdapter adapter;
  late MarketApi api;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('marekt_hive_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('api_test');
    adapter = FixtureAdapter();
    api = MarketApi(box, client: Dio()..httpClientAdapter = adapter);
  });
  tearDown(() async {
    await box.close();
    await dir.delete(recursive: true);
  });
  test('Dio décode le prix en cents, conserve le timestamp fournisseur, puis lit Hive', () async {
    adapter.payload = {
      'close': '220.125',
      'previous_close': '219.00',
      'timestamp': demoClock.millisecondsSinceEpoch ~/ 1000,
      'currency': 'USD',
    };
    final first = await api.quote('normal:1', catalog.first);
    expect(first.price, 22013);
    expect(first.at, demoClock);
    expect(first.cachedAt, isNull);
    final second = await api.quote('normal:1', catalog.first);
    expect(second.cachedAt, isNotNull);
    expect(second.at, first.at);
    expect(adapter.calls, 1);
  });
  test('cache Hive expiré ne masque pas un quota HTTP 429', () async {
    await box.put(
      'normal:1:quote:AAPL',
      jsonEncode({
        'at': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'data': {
          'close': '220',
          'previous_close': '219',
          'timestamp': 1,
          'currency': 'USD',
        },
      }),
    );
    adapter.status = 429;
    adapter.payload = {'message': 'quota'};
    await expectLater(
      api.quote('normal:1', catalog.first),
      throwsA(isA<ApiFallback>()),
    );
    expect(adapter.calls, 1);
  });
  test(
    'réponse vide et erreur fournisseur HTTP 200 déclenchent la démo',
    () async {
      adapter.payload = {};
      await expectLater(
        api.company('normal:1', 'AAPL'),
        throwsA(isA<ApiFallback>()),
      );
      adapter.payload = {'status': 'error', 'code': 429};
      await expectLater(
        api.quote('normal:1', catalog.first),
        throwsA(isA<ApiFallback>()),
      );
    },
  );
  test('Finnhub, GNews et Frankfurter utilisent leurs endpoints réels et des caches isolés', () async {
    adapter.payload = {'name': 'Apple', 'country': 'US'};
    await api.company('normal:1', 'AAPL');
    expect(adapter.last!.uri.path, '/api/v1/stock/profile2');
    expect(adapter.last!.headers, contains('X-Finnhub-Token'));
    adapter.payload = {
      'articles': [
        {
          'title': 'Fixture',
          'source': {'name': 'Test'},
        },
      ],
    };
    await api.news('normal:1', catalog.first);
    expect(adapter.last!.uri.path, '/api/v4/search');
    adapter.payload = {'rate': 0.92, 'date': '2026-10-23'};
    await api.rate('normal:1', 'EUR');
    expect(adapter.last!.uri.path, '/v2/rate/usd/eur');
    await api.rate('normal:2', 'EUR');
    expect(adapter.calls, 4);
    expect(box.containsKey('normal:1:fx:EUR'), isTrue);
    expect(box.containsKey('normal:2:fx:EUR'), isTrue);
    expect(box.containsKey('demo:1:fx:EUR'), isFalse);
  });
  test('favoris Hive isolés par utilisateur et par mode, persistés après réouverture', () async {
    await Watchlist(box).toggle('demo:1', 'AAPL');
    expect(Watchlist(box).read('demo:1'), {'AAPL'});
    expect(Watchlist(box).read('normal:1'), isEmpty);
    expect(Watchlist(box).read('demo:2'), isEmpty);
    await box.close();
    box = await Hive.openBox<dynamic>('api_test');
    expect(Watchlist(box).read('demo:1'), {'AAPL'});
  });
}
