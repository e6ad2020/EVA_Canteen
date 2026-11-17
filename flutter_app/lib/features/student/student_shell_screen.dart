import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;

        return Scaffold(
          body: EvaScaffoldBackground(
            child: SafeArea(
              child: Column(
                children: [
                  const ConnectionStatusBanner(),
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              NavigationRail(
                                backgroundColor: tokens.surfaceCard,
                                selectedIndex: navigationShell.currentIndex,
                                onDestinationSelected: (idx) =>
                                    navigationShell.goBranch(idx),
                                labelType: NavigationRailLabelType.all,
                                leading: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: EvaBrandLogo(size: 42),
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
                              VerticalDivider(
                                width: 1,
                                color: tokens.borderSubtle,
                              ),
                              Expanded(child: navigationShell),
                            ],
                          )
                        : navigationShell,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  backgroundColor: tokens.surfaceCard,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: tokens.brandSoftBg,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (idx) => navigationShell.goBranch(idx),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: Icon(
                        Icons.restaurant_menu_rounded,
                        color: tokens.brandPrimary,
                      ),
                      label: i18n.t('nav_menu'),
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: hasLiveInFlight,
                        child: const Icon(Icons.confirmation_number_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: hasLiveInFlight,
                        child: Icon(
                          Icons.confirmation_number_rounded,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      label: i18n.t('nav_orders'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.tune_outlined),
                      selectedIcon: Icon(
                        Icons.tune_rounded,
                        color: tokens.brandPrimary,
                      ),
                      label: i18n.t('nav_settings'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
