import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/not_found_screen.dart';
import '../core/widgets/section_placeholder_screen.dart';
import '../features/auth/presentation/providers/auth_view_model.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/customers/presentation/screens/customers_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/inbox/presentation/screens/nihong_store_inbox_screen.dart';
import '../features/menu/presentation/screens/menu_screen.dart';
import '../features/navigation/presentation/app_shell.dart';
import '../features/orders/presentation/screens/orders_screen.dart';
import '../features/pre_orders/presentation/screens/pre_orders_screen.dart';
import '../features/pre_orders/presentation/screens/pre_order_detail_screen.dart';
import '../features/public_links/presentation/screens/public_link_placeholder_screen.dart';
import '../features/schedules/presentation/screens/schedule_detail_screen.dart';
import '../features/schedules/presentation/screens/schedules_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionRefresh = ValueNotifier(ref.read(authViewModelProvider));
  ref.listen<AuthViewState>(authViewModelProvider, (_, authState) {
    sessionRefresh.value = authState;
  });

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: sessionRefresh,
    redirect: (context, state) {
      final authState = sessionRefresh.value;
      final location = state.matchedLocation;
      final isLoginRoute = location == '/login';
      final isPublicRoute = location.startsWith('/public/');

      if (isPublicRoute) return null;
      if (authState.status == AuthStatus.loading && isLoginRoute) return null;
      if (!authState.isAuthenticated && !isLoginRoute) {
        return Uri(
          path: '/login',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      if (authState.isAuthenticated && isLoginRoute) {
        return _safeRedirectLocation(state.uri.queryParameters['from']) ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                name: 'orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/preorders',
                name: 'preorders',
                builder: (context, state) => const PreOrdersScreen(),
              ),
              GoRoute(
                path: '/preorders/:preOrderId',
                builder: (context, state) => PreOrderDetailScreen(
                  preOrderId: state.pathParameters['preOrderId']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu',
                name: 'menu',
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/schedules',
        builder: (context, state) => const SchedulesScreen(),
      ),
      GoRoute(
        path: '/schedules/:scheduleId',
        builder: (context, state) => ScheduleDetailScreen(
          scheduleId: state.pathParameters['scheduleId']!,
        ),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/cash',
        builder: (context, state) => const SectionPlaceholderScreen(
          title: 'Kas',
          description: 'Fitur kas akan dibuat setelah aturan akses ditinjau.',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const NihongStoreInboxScreen(),
      ),
      GoRoute(
        path: '/jastipers',
        builder: (context, state) => const SectionPlaceholderScreen(
          title: 'Jastiper',
          description: 'Direktori jastiper akan ditambahkan pada tahap fitur.',
          icon: Icons.badge_outlined,
        ),
      ),
      GoRoute(
        path: '/public/schedule/:scheduleId',
        builder: (context, state) =>
            const PublicLinkPlaceholderScreen(title: 'Pratinjau jadwal'),
      ),
      GoRoute(
        path: '/public/products/:token',
        builder: (context, state) =>
            const PublicLinkPlaceholderScreen(title: 'Produk booking'),
      ),
      GoRoute(
        path: '/public/delivery/:token',
        builder: (context, state) =>
            const PublicLinkPlaceholderScreen(title: 'Alamat pengiriman'),
      ),
      GoRoute(
        path: '/public/ledger/:token',
        builder: (context, state) =>
            const PublicLinkPlaceholderScreen(title: 'Laporan kas'),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );

  ref.onDispose(() {
    router.dispose();
    sessionRefresh.dispose();
  });

  return router;
});

String? _safeRedirectLocation(String? destination) {
  if (destination == null || destination.isEmpty) return null;
  final uri = Uri.tryParse(destination);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path == '/login') {
    return null;
  }
  return destination;
}
