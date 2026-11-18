import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

Future<void> showCartCheckoutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => const CartCheckoutSheet(),
  );
}

class CartCheckoutSheet extends ConsumerStatefulWidget {
  const CartCheckoutSheet({super.key});

  @override
  ConsumerState<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends ConsumerState<CartCheckoutSheet> {
  String _selectedMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final summary = ref.watch(cartPricingProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    final enabledMethods = store.paymentMethods.enabledKeys;
    final activeMethod = enabledMethods.contains(_selectedMethod)
        ? _selectedMethod
        : (enabledMethods.firstOrNull ?? 'cash');

    final user = store.currentUser;
    final isGuest = user == null || user.role == UserRole.guest;
    final walletInsufficient =
        !isGuest &&
        activeMethod == 'wallet' &&
        user.balance + 1e-6 < summary.finalTotal;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.t('cart_title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (!summary.isEmpty)
                    TextButton.icon(
                      onPressed: cartNotifier.clear,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: Text(i18n.t('clear_cart')),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (summary.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 56,
                          color: tokens.textSecondary.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          i18n.t('cart_empty_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i18n.t('cart_empty_subtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    for (final entry in summary.quantities.entries)
                      if (store.productsById[entry.key] != null)
                        _CartProductRow(
                          product: store.productsById[entry.key]!,
                          quantity: entry.value,
                        ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          _ReceiptLine(
                            label: i18n.t('subtotal_label'),
                            value: i18n.formatPrice(summary.subtotal),
                          ),
                          for (final discount in summary.appliedDiscounts) ...[
                            const SizedBox(height: 8),
                            _ReceiptLine(
                              label:
                                  '${i18n.t(discount.bundle.nameKey)} (-${discount.bundle.discountPercent.toInt()}%)',
                              value:
                                  '-${i18n.formatPrice(discount.discountAmount)}',
                              highlightColor: tokens.statusDeliveredFg,
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),
                          _ReceiptLine(
                            label: i18n.t('total_label'),
                            value: i18n.formatPrice(summary.finalTotal),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      i18n.t('payment_method_label'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (store.paymentMethods.cash)
                          _PaymentOptionChip(
                            icon: Icons.payments_outlined,
                            label: i18n.t('payment_cash'),
                            selected: activeMethod == 'cash',
                            onTap: () =>
                                setState(() => _selectedMethod = 'cash'),
                          ),
                        if (store.paymentMethods.card)
                          _PaymentOptionChip(
                            icon: Icons.credit_card_rounded,
                            label: i18n.t('payment_card'),
                            selected: activeMethod == 'card',
                            onTap: () =>
                                setState(() => _selectedMethod = 'card'),
                          ),
                        if (store.paymentMethods.wallet)
                          _PaymentOptionChip(
                            icon: Icons.account_balance_wallet_outlined,
                            label: isGuest
                                ? i18n.t('payment_wallet')
                                : '${i18n.t('payment_wallet')} (${i18n.formatPrice(user.balance)})',
                            selected: activeMethod == 'wallet',
                            onTap: () =>
                                setState(() => _selectedMethod = 'wallet'),
                          ),
                      ],
                    ),
                    if (walletInsufficient) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.statusClosedBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          i18n.t('insufficient_wallet_hint', {
                            'balance': i18n.formatPrice(user.balance),
                          }),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.statusClosedFg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  border: Border(top: BorderSide(color: tokens.borderSubtle)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: isGuest
                      ? FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.go('/welcome');
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: Text(i18n.t('sign_in_to_checkout')),
                        )
                      : FilledButton(
                          onPressed:
                              (!store.isCanteenOpen ||
                                  store.checkoutBusy ||
                                  walletInsufficient)
                              ? null
                              : () async {
                                  HapticFeedback.mediumImpact();
                                  final confirmed = await ref
                                      .read(canteenStoreProvider.notifier)
                                      .submitOrder(paymentMethod: activeMethod);
                                  if (!context.mounted) return;
                                  if (confirmed != null) {
                                    Navigator.pop(context);
                                    context.go('/orders');
                                  }
                                },
                          child: store.checkoutBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  store.isCanteenOpen
                                      ? '${i18n.t('place_order_cta')} • ${i18n.formatPrice(summary.finalTotal)}'
                                      : i18n.t('canteen_closed_badge'),
                                ),
                        ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CartProductRow extends ConsumerWidget {
  const _CartProductRow({required this.product, required this.quantity});

  final ProductItem product;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Dismissible(
      key: ValueKey('cart_${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cartNotifier.removeItem(product.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: tokens.statusClosedBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: tokens.statusClosedFg),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: EvaProductImage(imageUrl: product.image, borderRadius: 10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t(product.nameKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${i18n.formatPrice(product.price)} × $quantity = ${i18n.formatPrice(product.price * quantity)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EvaQuantityStepper(
              quantity: quantity,
              addLabel: i18n.t('add_button'),
              compact: true,
              maxReached: !product.isUnlimited && quantity >= product.quantity,
              onIncrement: () => cartNotifier.increment(product),
              onDecrement: () => cartNotifier.decrement(product.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
    this.isBold = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label, style: style?.copyWith(color: highlightColor)),
        ),
        Text(
          value,
          style: style?.copyWith(
            color: highlightColor,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontFeatures: EvaThemeBuilder.tabularNums,
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionChip extends StatelessWidget {
  const _PaymentOptionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? tokens.brandPrimary : tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? tokens.brandPrimary : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
