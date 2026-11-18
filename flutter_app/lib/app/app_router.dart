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

final Animatable<double> _kRouteFadeTween = CurveTween(
  curve: Curves.easeOutCubic,
);
final Animatable<double> _kRouteScaleTween = Tween<double>(
  begin: 0.985,
  end: 1.0,
).chain(CurveTween(curve: Curves.easeOutCubic));

CustomTransitionPage<void> _buildEvaTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: RepaintBoundary(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      return FadeTransition(
        opacity: _kRouteFadeTween.animate(animation),
        child: ScaleTransition(
          scale: _kRouteScaleTween.animate(animation),
          child: pageChild,
        ),
      );
    },
  );
}

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
          return _buildEvaTransitionPage(
            key: state.pageKey,
            child: WelcomeAuthScreen(initialAdminMode: isAdmin),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) {
          return _buildEvaTransitionPage(
            key: state.pageKey,
            child: StudentShellScreen(navigationShell: navigationShell),
          );
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
        pageBuilder: (context, state, navigationShell) {
          return _buildEvaTransitionPage(
            key: state.pageKey,
            child: AdminShellScreen(navigationShell: navigationShell),
          );
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
