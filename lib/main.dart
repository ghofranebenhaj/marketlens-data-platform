import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/app_controller.dart';
import 'core/database.dart';
import 'core/models.dart';
import 'core/network.dart';
import 'features/portfolio/trading_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>('marekt_lens_local');
    final stores = <DataMode, LocalDatabase>{};
    for (final mode in DataMode.values) {
      stores[mode] = await LocalDatabase.open(mode);
    }
    runApp(
      ProviderScope(
        overrides: [
          appProvider.overrideWith(
            (ref) => AppController(
              stores,
              box,
              MarketApi(box),
              ref.read(tradingServiceProvider),
            ),
          ),
        ],
        child: const MarektLensApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme(),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Stockage local indisponible. Libérez de l’espace puis relancez MarektLens.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MarektLensApp extends ConsumerStatefulWidget {
  const MarektLensApp({super.key});
  @override
  ConsumerState<MarektLensApp> createState() => _MarektLensAppState();
}

class _MarektLensAppState extends ConsumerState<MarektLensApp> {
  late final router = createRouter(ref.read(appProvider));
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => MaterialApp.router(
        title: 'MarektLens',
        debugShowCheckedModeBanner: false,
        theme: appTheme(light: c.theme == 'Clair'),
        routerConfig: router,
      ),
    );
  }
}
