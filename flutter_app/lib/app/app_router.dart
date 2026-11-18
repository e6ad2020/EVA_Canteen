import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/models/domain_models.dart';
import '../core/state/canteen_providers.dart';
import '../features/admin/admin_analytics_view.dart';
import '../features/admin/admin_catalog_studio_view.dart';
import '../features/admin/admin_kds_view.dart';
import '../features/admin/admin_ops_wallet_view.dart';
import '../features/admin/admin_shell_screen.dart';
import '../features/auth/welcome_auth_screen.dart';
import '../features/settings/shared_settings_view.dart';
import '../features/student/student_menu_view.dart';
import '../features/student/student_orders_view.dart';
import '../features/student/student_shell_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<UserProfile?>(
    ref.read(canteenStoreProvider).currentUser,
  );

  ref.listen<UserProfile?>(
    canteenStoreProvider.select((s) => s.currentUser),
    (_, next) => authRefresh.value = next,
  );
  ref.onDispose(authRefresh.dispose);

  final initialUser = authRefresh.value;
  final initialLocation = initialUser == null
      ? '/welcome'
      : (initialUser.isAdmin ? '/admin/kds' : '/menu');

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final user = authRefresh.value;
      final loc = state.matchedLocation;

      if (loc == '/') {
        if (user == null) return '/welcome';
        return user.isAdmin ? '/admin/kds' : '/menu';
      }

      if (loc.startsWith('/admin')) {
        if (user == null || !user.isAdmin) {
          return '/welcome?admin=1';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) {
          final isAdmin = state.uri.queryParameters['admin'] == '1';
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 240),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            child: WelcomeAuthScreen(initialAdminMode: isAdmin),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudentShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu',
                builder: (context, state) => const StudentMenuView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const StudentOrdersView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SharedSettingsView(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/kds',
                builder: (context, state) => const AdminKdsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/catalog',
                builder: (context, state) => const AdminCatalogStudioView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/analytics',
                builder: (context, state) => const AdminAnalyticsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/ops',
                builder: (context, state) => const AdminOpsWalletView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/settings',
                builder: (context, state) => const SharedSettingsView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
