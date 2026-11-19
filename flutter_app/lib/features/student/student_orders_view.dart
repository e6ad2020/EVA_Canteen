import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class StudentOrdersView extends ConsumerWidget {
  const StudentOrdersView({super.key, this.highlightedOrderId});

  final String? highlightedOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final (user, activeOrder, myOrders) = ref.watch(
      canteenStoreProvider.select(
        (s) => (s.currentUser, s.activeStudentOrder, s.myOrders),
      ),
    );

    final navClearance = EvaFloatingNavBar.bottomClearance(context);

    if (user == null || user.role == UserRole.guest) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navClearance),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: EvaSurfaceCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 52,
                    color: tokens.brandPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    i18n.t('live_pickup_pass'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.t('welcome_subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/welcome'),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(i18n.t('sign_in_tab')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    CanteenOrder? pinnedOrder;
    final targetId = highlightedOrderId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      for (final o in myOrders) {
        if (o.id == targetId) {
          pinnedOrder = o;
          break;
        }
      }
    }
    final displayActiveOrder = pinnedOrder ?? activeOrder;

    final pastOrders = myOrders
        .where((o) => displayActiveOrder == null || o.id != displayActiveOrder.id)
        .toList(growable: false);

    if (displayActiveOrder == null && pastOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navClearance),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: EvaSurfaceCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 52,
                    color: tokens.textSecondary.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    i18n.t('no_orders_yet'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/menu'),
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                    label: Text(i18n.t('nav_menu')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return EvaFloatingHeaderScaffold(
      initialHeaderHeight: 66.0,
      headerBuilder: (context, isScrolled) => EvaGlassBar(
        isScrolled: isScrolled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                i18n.t('nav_orders'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
      bodyBuilder: (context, topClearance, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, topClearance + 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (displayActiveOrder != null) ...[
                        EvaReveal(
                          index: 0,
                          child: _LivePickupPassCard(order: displayActiveOrder),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (pastOrders.isNotEmpty) ...[
                        Text(
                          i18n.t('past_orders_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (pastOrders.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + navClearance),
              sliver: SliverList.builder(
                itemCount: pastOrders.length,
                itemBuilder: (context, idx) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: EvaReveal(
                        index: (idx + 1).clamp(1, 8),
                        child: _PastOrderHistoryCard(order: pastOrders[idx]),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(height: 28 + navClearance),
            ),
        ],
      ),
    );
  }
}

class _LivePickupPassCard extends ConsumerWidget {
  const _LivePickupPassCard({required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final stepIndex = switch (order.status) {
      OrderStatus.pending => 0,
      OrderStatus.preparing => 1,
      OrderStatus.delivered => 2,
    };

    final isReady = order.status == OrderStatus.delivered;
    final headerBg = isReady ? tokens.statusDeliveredBg : tokens.brandSoftBg;
    final headerDivider = isReady
        ? tokens.statusDeliveredFg.withValues(alpha: 0.14)
        : tokens.brandPrimary.withValues(alpha: 0.12);

    return RepaintBoundary(
      child: EvaSurfaceCard(
        key: const ValueKey('live_pickup_pass_card'),
        borderRadius: 22,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(
                  bottom: BorderSide(color: headerDivider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isReady
                        ? Icons.celebration_rounded
                        : Icons.confirmation_number_rounded,
                    color: isReady
                        ? tokens.statusDeliveredFg
                        : tokens.brandPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i18n.t('live_pickup_pass'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isReady
                            ? tokens.statusDeliveredFg
                            : tokens.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EvaStatusBadge.forOrderStatus(
                    context: context,
                    status: order.status,
                    label: i18n.t('status_${order.status.name}'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    order.pickupNumber,
                    key: ValueKey(order.pickupNumber),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 48,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.id,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontFeatures: EvaThemeBuilder.tabularNums,
                  ),
                ),
                const SizedBox(height: 16),
                EvaPickupBarcodeBar(orderId: order.id),
                const SizedBox(height: 10),
                Text(
                  i18n.t('pickup_counter_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                _ThreeStageProgress(
                  currentIndex: stepIndex,
                  labels: [
                    i18n.t('status_pending'),
                    i18n.t('status_preparing'),
                    i18n.t('status_delivered'),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1),
                ),
                for (final item in order.regularItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}× ${i18n.t(item.nameKey)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          i18n.formatPrice(item.price * item.quantity),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFeatures: EvaThemeBuilder.tabularNums,
                              ),
                        ),
                      ],
                    ),
                  ),
                for (final disc in order.discountItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            i18n.t(disc.nameKey),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.statusDeliveredFg),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-${i18n.formatPrice(disc.price.abs())}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.statusDeliveredFg,
                                fontFeatures: EvaThemeBuilder.tabularNums,
                              ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i18n.t('total_label')} (${i18n.t('payment_${order.paymentMethod}')})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      i18n.formatPrice(order.totalAmount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tokens.brandPrimary,
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ThreeStageProgress extends StatelessWidget {
  const _ThreeStageProgress({
    required this.currentIndex,
    required this.labels,
  });

  final int currentIndex;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    const icons = [
      Icons.receipt_rounded,
      Icons.soup_kitchen_rounded,
      Icons.check_circle_rounded,
    ];

    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentIndex
                        ? (currentIndex == 2
                              ? tokens.statusDeliveredFg
                              : tokens.brandPrimary)
                        : tokens.surfaceSubtle,
                    border: Border.all(
                      color: i <= currentIndex
                          ? Colors.transparent
                          : tokens.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    icons[i],
                    size: 19,
                    color: i <= currentIndex
                        ? Colors.white
                        : tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i <= currentIndex
                        ? tokens.textPrimary
                        : tokens.textSecondary,
                    fontWeight: i <= currentIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (i < 2)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: i < currentIndex
                      ? (currentIndex == 2
                            ? tokens.statusDeliveredFg
                            : tokens.brandPrimary)
                      : tokens.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PastOrderHistoryCard extends ConsumerWidget {
  const _PastOrderHistoryCard({required this.order});

  static final _dateFmt = DateFormat('dd MMM yyyy • HH:mm');

  final CanteenOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final formattedDate = _dateFmt.format(order.timestamp.toLocal());

    return RepaintBoundary(
      child: EvaSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.pickupNumber,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFeatures: EvaThemeBuilder.tabularNums,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formattedDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                EvaStatusBadge.forOrderStatus(
                  context: context,
                  status: order.status,
                  label: i18n.t('status_${order.status.name}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              order.regularItems
                  .map((i) => '${i.quantity}× ${i18n.t(i.nameKey)}')
                  .join(' • '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.formatPrice(order.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final productsById = ref
                        .read(canteenStoreProvider)
                        .productsById;
                    final added = ref
                        .read(cartProvider.notifier)
                        .reorderAvailableItems(order, productsById);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added > 0
                              ? i18n.t('reordered_toast')
                              : i18n.t('out_of_stock'),
                        ),
                      ),
                    );
                    if (added > 0) {
                      context.go('/menu');
                    }
                  },
                  icon: const Icon(Icons.replay_rounded, size: 17),
                  label: Text(i18n.t('reorder_button')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
