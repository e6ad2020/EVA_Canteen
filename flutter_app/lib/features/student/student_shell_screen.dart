import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/network/eva_socket_client.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class StudentShellScreen extends ConsumerWidget {
  const StudentShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final navBehavior = ref.watch(
      appPreferencesProvider.select((p) => p.navBarBehavior),
    );
    final activeOrder = ref.watch(
      canteenStoreProvider.select((s) => s.activeStudentOrder),
    );
    final hasLiveInFlight =
        activeOrder != null && activeOrder.status != OrderStatus.delivered;

    ref.listen(canteenStoreProvider.select((s) => s.notice), (prev, next) {
      if (next != null && next.id != prev?.id) {
        if (next.isCelebration) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: next.isError
                ? tokens.statusClosedFg
                : (next.isCelebration ? tokens.statusDeliveredFg : null),
            content: Text(next.message),
          ),
        );
        ref.read(canteenStoreProvider.notifier).clearNotice();
      }
    });

    final animatedBody = EvaShellTransition(
      currentIndex: navigationShell.currentIndex,
      child: navigationShell,
    );

    final isConnected = ref.watch(
      canteenStoreProvider.select(
        (s) => s.connectionPhase == SocketConnectionPhase.connected,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= EvaFloatingNavBar.shellWideBreakpoint;

        return Scaffold(
          body: EvaScaffoldBackground(
            child: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: !isConnected,
                    child: isWide
                        ? Row(
                            children: [
                              SafeArea(
                                right: false,
                                child: NavigationRail(
                                  selectedIndex: navigationShell.currentIndex,
                                  onDestinationSelected: (idx) {
                                    HapticFeedback.selectionClick();
                                    navigationShell.goBranch(idx);
                                  },
                                  labelType: NavigationRailLabelType.all,
                                  minWidth: 88,
                                  leading: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: EvaBrandLogo(size: 40),
                                  ),
                                  destinations: [
                                    NavigationRailDestination(
                                      icon: const Icon(
                                        Icons.restaurant_menu_outlined,
                                      ),
                                      selectedIcon: const Icon(
                                        Icons.restaurant_menu_rounded,
                                      ),
                                      label: Text(i18n.t('nav_menu')),
                                    ),
                                    NavigationRailDestination(
                                      icon: Badge(
                                        isLabelVisible: hasLiveInFlight,
                                        child: const Icon(
                                          Icons.confirmation_number_outlined,
                                        ),
                                      ),
                                      selectedIcon: Badge(
                                        isLabelVisible: hasLiveInFlight,
                                        child: const Icon(
                                          Icons.confirmation_number_rounded,
                                        ),
                                      ),
                                      label: Text(i18n.t('nav_orders')),
                                    ),
                                    NavigationRailDestination(
                                      icon: const Icon(Icons.tune_outlined),
                                      selectedIcon: const Icon(
                                        Icons.tune_rounded,
                                      ),
                                      label: Text(i18n.t('nav_settings')),
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: tokens.borderSubtle,
                              ),
                              Expanded(child: animatedBody),
                            ],
                          )
                        : EvaNavScrollTracker(
                            currentIndex: navigationShell.currentIndex,
                            behavior: navBehavior,
                            builder: (context, showLabels) => Stack(
                              fit: StackFit.expand,
                              children: [
                                animatedBody,
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: EvaFloatingNavBar(
                                    selectedIndex: navigationShell.currentIndex,
                                    showLabels: showLabels,
                                    onDestinationSelected: (idx) {
                                      HapticFeedback.selectionClick();
                                      navigationShell.goBranch(idx);
                                    },
                                    items: [
                                      EvaFloatingNavItem(
                                        icon: Icons.restaurant_menu_outlined,
                                        selectedIcon:
                                            Icons.restaurant_menu_rounded,
                                        label: i18n.t('nav_menu'),
                                      ),
                                      EvaFloatingNavItem(
                                        icon:
                                            Icons.confirmation_number_outlined,
                                        selectedIcon:
                                            Icons.confirmation_number_rounded,
                                        label: i18n.t('nav_orders'),
                                        showDotBadge: hasLiveInFlight,
                                      ),
                                      EvaFloatingNavItem(
                                        icon: Icons.tune_outlined,
                                        selectedIcon: Icons.tune_rounded,
                                        label: i18n.t('nav_settings'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
