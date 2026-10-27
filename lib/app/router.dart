import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../features/auth/auth_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/market/market_screen.dart';
import '../features/market/detail_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/profile/profile_screen.dart';

GoRouter createRouter(AppController c) => GoRouter(
  initialLocation: '/home',
  refreshListenable: c,
  redirect: (context, state) {
    if (c.user == null && state.uri.path != '/auth') return '/auth';
    if (c.user != null && state.uri.path == '/auth') return '/home';
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page introuvable')),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/home'),
        child: const Text('Revenir à l’accueil'),
      ),
    ),
  ),
  routes: [
    GoRoute(
      path: '/auth',
      builder: (_, _) => live(c, () => AuthScreen(c), auth: false),
    ),
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'MarektLens',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Panier',
              onPressed: () => context.push('/cart'),
              icon: Badge(
                isLabelVisible: c.cart.isNotEmpty,
                label: Text('${c.cart.length}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            IconButton(
              tooltip: 'Profil',
              onPressed: () => context.push('/profile'),
              icon: CircleAvatar(
                radius: 17,
                child: Text(c.user?.name.substring(0, 1).toUpperCase() ?? '?'),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: state.uri.path == '/market'
              ? 1
              : state.uri.path == '/portfolio'
              ? 2
              : 0,
          onDestinationSelected: (i) =>
              context.go(['/home', '/market', '/portfolio'][i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.candlestick_chart_outlined),
              label: 'Marchés',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              label: 'Portefeuille',
            ),
          ],
        ),
      ),
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => live(c, () => DashboardScreen(c), auth: true),
        ),
        GoRoute(
          path: '/market',
          builder: (_, _) => live(c, () => MarketScreen(c), auth: true),
        ),
        GoRoute(
          path: '/portfolio',
          builder: (_, _) => live(c, () => PortfolioScreen(c), auth: true),
        ),
      ],
    ),
    GoRoute(
      path: '/asset/:symbol',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return catalog.any((a) => a.symbol == symbol)
            ? live(c, () => DetailScreen(c, symbol))
            : const Scaffold(body: Center(child: Text('Action inconnue.')));
      },
    ),
    GoRoute(
      path: '/cart',
      builder: (_, _) => live(c, () => CartScreen(c), auth: true),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, _) => live(c, () => ProfileScreen(c), auth: true),
    ),
  ],
);

Widget live(AppController c, Widget Function() child, {bool auth = true}) =>
    ListenableBuilder(
      listenable: c,
      builder: (context, _) =>
          auth && c.user == null ? const SizedBox.shrink() : child(),
    );
