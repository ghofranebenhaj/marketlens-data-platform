import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:marekt_lens/main.dart';
import 'package:marekt_lens/core/app_controller.dart';
import 'package:marekt_lens/core/database.dart';
import 'package:marekt_lens/core/models.dart';
import 'package:marekt_lens/core/network.dart';
import 'package:marekt_lens/features/portfolio/trading_service.dart';

void main() {
  testWidgets(
    'navigation démo, préférences, panier et déconnexion sur écran 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory dir;
      late LocalDatabase store;
      late Box<dynamic> box;
      late AppController c;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('marekt_flow_');
        Hive.init(dir.path);
        box = await Hive.openBox<dynamic>('flow');
        sqfliteFfiInit();
        store = await LocalDatabase.open(
          DataMode.demo,
          factory: databaseFactoryFfi,
          file: inMemoryDatabasePath,
        );
        c = AppController(
          {DataMode.demo: store},
          box,
          MarketApi(box),
          const TradingService(),
        );
        await c.authenticate(
          true,
          'Camille',
          'camille@example.test',
          'motdepasse123',
        );
      });
      expect(c.user, isNotNull);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWithValue(c)],
          child: const MarektLensApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MarektLens'), findsOneWidget);
      expect(find.text('Données de démonstration'), findsOneWidget);
      expect(find.text('10\u202f000,00 USD'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Marchés'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Apple');
      await tester.pumpAndSettle();
      expect(find.text('AAPL'), findsOneWidget);
      await tester.tap(find.byTooltip('Favori Apple'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(c.favorites, contains('AAPL'));
      await tester.tap(find.text('AAPL'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ajouter au panier'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Ajouter au panier'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Camille'), findsOneWidget);
      await tester.runAsync(() async {
        await c.preference('risk', 'Dynamique');
        await c.setCurrency('EUR');
      });
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dynamique'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Dynamique'), findsOneWidget);
      expect(c.currency, 'EUR');
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await c.setCart('AAPL', 2);
        await c.buy('flow-buy', {'AAPL': 2}, Map.of(c.quotes));
      });
      await tester.pumpAndSettle();
      expect(c.positions.single.quantity, 2);
      expect(c.user!.balance, 956000);
      expect(c.positionsValue, 44000);
      expect(c.positionCost(c.positions.single), 44000);
      expect(c.unrealized, 0);
      expect(c.total, 1000000);
      c.logout();
      await tester.pumpAndSettle();
      expect(find.text('Se connecter'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await store.db.close();
        await box.close();
        await dir.delete(recursive: true);
      });
      c.dispose();
    },
  );
}
