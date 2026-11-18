import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final isOpen = ref.watch(
      canteenStoreProvider.select((s) => s.isCanteenOpen),
    );
    final activeKdsCount = ref.watch(
      canteenStoreProvider.select(
        (s) => s.adminOrders
            .where((o) => o.isToday && o.status != OrderStatus.delivered)
            .length,
      ),
    );

    // Chime & haptic alert whenever a new live order arrives in the kitchen!
    ref.listen(canteenStoreProvider.select((s) => s.adminNewOrderTick), (
      prev,
      next,
    ) {
      if (prev != null && next > prev) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        final latest = ref.read(canteenStoreProvider).adminOrders.firstOrNull;
        if (latest != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: tokens.brandPrimary,
              content: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: tokens.brandOnPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i18n.isRtl
                          ? 'طلب جديد ${latest.pickupNumber} من ${latest.userEmail}'
                          : 'New order ${latest.pickupNumber} from ${latest.userEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.brandOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    });

    ref.listen(canteenStoreProvider.select((s) => s.notice), (prev, next) {
      if (next != null && next.id != prev?.id) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

        Widget? bottomBar;
        if (!isWide) {
          bottomBar = Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              border: Border(
                top: BorderSide(
                  color: tokens.borderSubtle,
                  width: tokens.borderWidth,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: tokens.surfaceElevated,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (idx) {
                HapticFeedback.selectionClick();
                navigationShell.goBranch(idx);
              },
              destinations: [
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: activeKdsCount > 0,
                    label: Text('$activeKdsCount'),
                    child: const Icon(Icons.kitchen_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: activeKdsCount > 0,
                    label: Text('$activeKdsCount'),
                    child: const Icon(Icons.kitchen_rounded),
                  ),
                  label: i18n.t('admin_kds_tab'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2_rounded),
                  label: i18n.t('admin_catalog_tab'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights_rounded),
                  label: i18n.t('admin_analytics_tab'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(
                    Icons.account_balance_wallet_rounded,
                  ),
                  label: i18n.t('admin_ops_tab'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.tune_outlined),
                  selectedIcon: const Icon(Icons.tune_rounded),
                  label: i18n.t('nav_settings'),
                ),
              ],
            ),
          );
        }

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
                                selectedIndex: navigationShell.currentIndex,
                                onDestinationSelected: (idx) {
                                  HapticFeedback.selectionClick();
                                  navigationShell.goBranch(idx);
                                },
                                labelType: NavigationRailLabelType.all,
                                minWidth: 92,
                                leading: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    children: [
                                      const EvaBrandLogo(size: 40),
                                      const SizedBox(height: 10),
                                      Tooltip(
                                        message: i18n.t(
                                          'storefront_status_card',
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            ref
                                                .read(
                                                  canteenStoreProvider.notifier,
                                                )
                                                .setCanteenOpen(!isOpen);
                                          },
                                          child: EvaStatusBadge(
                                            label: isOpen
                                                ? i18n.t('canteen_open_badge')
                                                : i18n.t(
                                                    'canteen_closed_badge',
                                                  ),
                                            background: isOpen
                                                ? tokens.statusDeliveredBg
                                                : tokens.statusClosedBg,
                                            foreground: isOpen
                                                ? tokens.statusDeliveredFg
                                                : tokens.statusClosedFg,
                                            pulsing: isOpen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: LanguageQuickToggle(),
                                    ),
                                  ),
                                ),
                                destinations: [
                                  NavigationRailDestination(
                                    icon: Badge(
                                      isLabelVisible: activeKdsCount > 0,
                                      label: Text('$activeKdsCount'),
                                      child: const Icon(Icons.kitchen_outlined),
                                    ),
                                    selectedIcon: Badge(
                                      isLabelVisible: activeKdsCount > 0,
                                      label: Text('$activeKdsCount'),
                                      child: const Icon(Icons.kitchen_rounded),
                                    ),
                                    label: Text(i18n.t('admin_kds_tab')),
                                  ),
                                  NavigationRailDestination(
                                    icon: const Icon(
                                      Icons.inventory_2_outlined,
                                    ),
                                    selectedIcon: const Icon(
                                      Icons.inventory_2_rounded,
                                    ),
                                    label: Text(i18n.t('admin_catalog_tab')),
                                  ),
                                  NavigationRailDestination(
                                    icon: const Icon(Icons.insights_outlined),
                                    selectedIcon: const Icon(
                                      Icons.insights_rounded,
                                    ),
                                    label: Text(i18n.t('admin_analytics_tab')),
                                  ),
                                  NavigationRailDestination(
                                    icon: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                    ),
                                    selectedIcon: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                    ),
                                    label: Text(i18n.t('admin_ops_tab')),
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
                              Expanded(child: animatedBody),
                            ],
                          )
                        : animatedBody,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: bottomBar,
        );
      },
    );
  }
}
