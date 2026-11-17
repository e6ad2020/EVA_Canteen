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
  const StudentOrdersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final user = store.currentUser;

    if (user == null || user.role == UserRole.guest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 56,
                  color: tokens.brandPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  i18n.t('live_pickup_pass'),
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
      );
    }

    final activeOrder = store.activeStudentOrder;
    final pastOrders = store.myOrders
        .where((o) => activeOrder == null || o.id != activeOrder.id)
        .toList(growable: false);

    if (activeOrder == null && pastOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 56,
                color: tokens.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                i18n.t('no_orders_yet'),
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
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeOrder != null) ...[
                  _LivePickupPassCard(order: activeOrder),
                  const SizedBox(height: 24),
                ],
                if (pastOrders.isNotEmpty) ...[
                  Text(
                    i18n.t('past_orders_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final order in pastOrders) ...[
                    _PastOrderHistoryCard(order: order),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: order.status == OrderStatus.delivered
                ? tokens.statusDeliveredBg
                : tokens.brandSoftBg,
            child: Row(
              children: [
                Icon(
                  order.status == OrderStatus.delivered
                      ? Icons.celebration_rounded
                      : Icons.confirmation_number_rounded,
                  color: order.status == OrderStatus.delivered
                      ? tokens.statusDeliveredFg
                      : tokens.brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    i18n.t('live_pickup_pass'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: order.status == OrderStatus.delivered
                          ? tokens.statusDeliveredFg
                          : tokens.brandPrimary,
                    ),
                  ),
                ),
                EvaStatusBadge.forOrderStatus(
                  context: context,
                  status: order.status,
                  label: i18n.t('status_${order.status.name}'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  order.pickupNumber,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 48,
                    color: tokens.textPrimary,
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
                const SizedBox(height: 24),
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
                        Text(
                          i18n.t(disc.nameKey),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.statusDeliveredFg),
                        ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${i18n.t('total_label')} (${i18n.t('payment_${order.paymentMethod}')})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
    final icons = const [
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
                  duration: const Duration(milliseconds: 240),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentIndex
                        ? (currentIndex == 2
                              ? tokens.statusDeliveredFg
                              : tokens.brandPrimary)
                        : tokens.surfaceSubtle,
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
              child: Container(
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

  final CanteenOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final productsById = ref.watch(
      canteenStoreProvider.select((s) => s.productsById),
    );
    final formattedDate = DateFormat(
      'dd MMM yyyy • HH:mm',
    ).format(order.timestamp.toLocal());

    return Card(
      child: Padding(
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
                Text(
                  i18n.formatPrice(order.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: EvaThemeBuilder.tabularNums,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
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
