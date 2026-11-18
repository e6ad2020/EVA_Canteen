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
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => const CartCheckoutSheet(),
  );
}

class _CartAnimatedEntry {
  _CartAnimatedEntry({
    required this.productId,
    required this.product,
    required this.lastQuantity,
    required this.ctrl,
  });

  final String productId;
  ProductItem product;
  int lastQuantity;
  final AnimationController ctrl;
  bool isExiting = false;
  bool dismissedBySwipe = false;
}

class CartCheckoutSheet extends ConsumerStatefulWidget {
  const CartCheckoutSheet({super.key});

  @override
  ConsumerState<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends ConsumerState<CartCheckoutSheet>
    with TickerProviderStateMixin {
  String _selectedMethod = 'cash';
  final List<_CartAnimatedEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    final initialSummary = ref.read(cartPricingProvider);
    final productsById = ref.read(canteenStoreProvider).productsById;
    for (final mapEntry in initialSummary.quantities.entries) {
      final prod = productsById[mapEntry.key];
      if (prod != null) {
        _entries.add(
          _CartAnimatedEntry(
            productId: mapEntry.key,
            product: prod,
            lastQuantity: mapEntry.value,
            ctrl: AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 250),
              value: 1.0,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.ctrl.dispose();
    }
    _entries.clear();
    super.dispose();
  }

  void _syncCartEntries(
    CartPricingSummary nextSummary,
    Map<String, ProductItem> productsById,
  ) {
    final disableMotion =
        mounted && (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final nextQuantities = nextSummary.quantities;

    // 1. Update existing entries or trigger smooth exit animation on removed items
    for (final entry in List<_CartAnimatedEntry>.of(_entries)) {
      final nextQty = nextQuantities[entry.productId];
      if (nextQty != null && nextQty > 0) {
        final updatedProd = productsById[entry.productId];
        if (updatedProd != null) {
          entry.product = updatedProd;
        }
        entry.lastQuantity = nextQty;
        if (entry.isExiting) {
          entry.isExiting = false;
          entry.ctrl.forward();
        }
      } else if (!entry.isExiting) {
        if (entry.dismissedBySwipe || disableMotion) {
          _entries.remove(entry);
          entry.ctrl.dispose();
        } else {
          entry.isExiting = true;
          entry.ctrl.reverse().whenCompleteOrCancel(() {
            if (!mounted) return;
            if (entry.isExiting && _entries.remove(entry)) {
              entry.ctrl.dispose();
              setState(() {});
            }
          });
        }
      }
    }

    // 2. Animate in any newly added items (e.g., combo added while sheet open)
    for (final mapEntry in nextQuantities.entries) {
      final exists = _entries.any((e) => e.productId == mapEntry.key);
      if (!exists) {
        final prod = productsById[mapEntry.key];
        if (prod != null) {
          final ctrl = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 240),
            value: disableMotion ? 1.0 : 0.0,
          );
          final newEntry = _CartAnimatedEntry(
            productId: mapEntry.key,
            product: prod,
            lastQuantity: mapEntry.value,
            ctrl: ctrl,
          );
          _entries.add(newEntry);
          if (!disableMotion) {
            ctrl.forward();
          }
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final (paymentMethods, user, isCanteenOpen, checkoutBusy) = ref.watch(
      canteenStoreProvider.select(
        (s) => (
          s.paymentMethods,
          s.currentUser,
          s.isCanteenOpen,
          s.checkoutBusy,
        ),
      ),
    );
    final summary = ref.watch(cartPricingProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    ref.listen<CartPricingSummary>(cartPricingProvider, (prev, next) {
      _syncCartEntries(next, ref.read(canteenStoreProvider).productsById);
    });

    final enabledMethods = paymentMethods.enabledKeys;
    final activeMethod = enabledMethods.contains(_selectedMethod)
        ? _selectedMethod
        : (enabledMethods.firstOrNull ?? 'cash');

    final isGuest = user == null || user.role == UserRole.guest;
    final walletInsufficient =
        !isGuest &&
        activeMethod == 'wallet' &&
        user.balance + 1e-6 < summary.finalTotal;

    final showEmptyState = summary.isEmpty && _entries.isEmpty;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final methodLabel = switch (activeMethod) {
      'card' => i18n.t('payment_card'),
      'wallet' => i18n.t('payment_wallet'),
      _ => i18n.t('payment_cash'),
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
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
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            i18n.t('cart_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (summary.totalItemCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.brandSoftBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: EvaAnimatedCounterText(
                              text: '${summary.totalItemCount}',
                              numericValue: summary.totalItemCount,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: tokens.brandPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: summary.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            key: const ValueKey('clear_cart_btn'),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              cartNotifier.clear();
                            },
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                            ),
                            label: Text(i18n.t('clear_cart')),
                          ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: showEmptyState
                    ? Center(
                        key: const ValueKey('cart_empty_view'),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 56,
                                color: tokens.textSecondary.withValues(
                                  alpha: 0.45,
                                ),
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
                      )
                    : Column(
                        key: const ValueKey('cart_populated_view'),
                        children: [
                          // 1. Dedicated Scrollable Item List (+ Active Bundle Discounts Banner)
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                              children: [
                                for (final entry in _entries)
                                  _AnimatedCartEntryShell(
                                    key: ValueKey(
                                      'cart_entry_${entry.productId}',
                                    ),
                                    entry: entry,
                                    isRtl: isRtl,
                                    child: _CartProductRow(
                                      product: entry.product,
                                      quantity: entry.lastQuantity,
                                      isExiting: entry.isExiting,
                                      onSwipeDismissed: () {
                                        entry.dismissedBySwipe = true;
                                        cartNotifier.removeItem(
                                          entry.productId,
                                        );
                                      },
                                    ),
                                  ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: summary.appliedDiscounts.isEmpty
                                      ? const SizedBox.shrink()
                                      : Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.statusDeliveredBg,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: tokens.statusDeliveredFg
                                                  .withValues(alpha: 0.28),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              for (final discount
                                                  in summary.appliedDiscounts)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: _ReceiptLine(
                                                    label:
                                                        '${i18n.t(discount.bundle.nameKey)} (-${discount.bundle.discountPercent.toInt()}%)',
                                                    value:
                                                        '-${i18n.formatPrice(discount.discountAmount)}',
                                                    numericValue:
                                                        discount.discountAmount,
                                                    highlightColor:
                                                        tokens.statusDeliveredFg,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          // 2. Unified Fixed Checkout Dock: Always-Visible Payment Method + Totals + Confirm Button
                          Container(
                            key: const ValueKey('cart_fixed_checkout_dock'),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated,
                              border: Border(
                                top: BorderSide(
                                  color: tokens.borderSubtle,
                                  width: tokens.borderWidth,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: tokens.isNight ? 0.28 : 0.07,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Payment Method Header + Live Wallet Balance Pill
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: tokens.brandPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          i18n.t('payment_method_label'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (!isGuest &&
                                          paymentMethods.wallet)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: walletInsufficient
                                                ? tokens.statusClosedBg
                                                : tokens.brandSoftBg,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                                size: 12,
                                                color: walletInsufficient
                                                    ? tokens.statusClosedFg
                                                    : tokens.brandPrimary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                i18n.formatPrice(user.balance),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: walletInsufficient
                                                          ? tokens
                                                                .statusClosedFg
                                                          : tokens.brandPrimary,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontFeatures:
                                                          EvaThemeBuilder
                                                              .tabularNums,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Segmented Always-Visible Payment Method Selector Pills
                                  if (enabledMethods.isNotEmpty)
                                    Row(
                                      children: [
                                        if (paymentMethods.cash)
                                          Expanded(
                                            child: _PaymentOptionChip(
                                              key: const ValueKey(
                                                'pay_method_cash',
                                              ),
                                              icon: Icons.payments_outlined,
                                              label: i18n.t('payment_cash'),
                                              selected: activeMethod == 'cash',
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(
                                                  () =>
                                                      _selectedMethod = 'cash',
                                                );
                                              },
                                            ),
                                          ),
                                        if (paymentMethods.cash &&
                                            (paymentMethods.card ||
                                                paymentMethods.wallet))
                                          const SizedBox(width: 8),
                                        if (paymentMethods.card)
                                          Expanded(
                                            child: _PaymentOptionChip(
                                              key: const ValueKey(
                                                'pay_method_card',
                                              ),
                                              icon: Icons.credit_card_rounded,
                                              label: i18n.t('payment_card'),
                                              selected: activeMethod == 'card',
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(
                                                  () =>
                                                      _selectedMethod = 'card',
                                                );
                                              },
                                            ),
                                          ),
                                        if (paymentMethods.card &&
                                            paymentMethods.wallet)
                                          const SizedBox(width: 8),
                                        if (paymentMethods.wallet)
                                          Expanded(
                                            child: _PaymentOptionChip(
                                              key: const ValueKey(
                                                'pay_method_wallet',
                                              ),
                                              icon: Icons
                                                  .account_balance_wallet_outlined,
                                              label: i18n.t('payment_wallet'),
                                              selected:
                                                  activeMethod == 'wallet',
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(
                                                  () => _selectedMethod =
                                                      'wallet',
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),

                                  // Insufficient Wallet Balance Alert (if Wallet is selected)
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    child: walletInsufficient
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: tokens.statusClosedBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                i18n.t(
                                                  'insufficient_wallet_hint',
                                                  {
                                                    'balance': i18n.formatPrice(
                                                      user.balance,
                                                    ),
                                                  },
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          tokens.statusClosedFg,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),

                                  const SizedBox(height: 10),

                                  // Compact Totals Strip (Subtotal/Discount + Bold Final Total)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          i18n.t('total_label'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        if (summary.totalDiscount > 0) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              i18n.formatPrice(
                                                summary.subtotal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: tokens.textSecondary,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    fontFeatures:
                                                        EvaThemeBuilder
                                                            .tabularNums,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tokens.statusDeliveredBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '-${i18n.formatPrice(summary.totalDiscount)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: tokens
                                                        .statusDeliveredFg,
                                                    fontWeight: FontWeight.w800,
                                                    fontFeatures:
                                                        EvaThemeBuilder
                                                            .tabularNums,
                                                  ),
                                            ),
                                          ),
                                        ] else
                                          const Spacer(),
                                        if (summary.totalDiscount > 0)
                                          const Spacer(),
                                        EvaAnimatedCounterText(
                                          text: i18n.formatPrice(
                                            summary.finalTotal,
                                          ),
                                          numericValue: summary.finalTotal,
                                          textAlign: TextAlign.end,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: tokens.brandPrimary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Fixed Primary Confirm Button (explicitly showing chosen payment way)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: isGuest
                                        ? FilledButton.icon(
                                            key: const ValueKey(
                                              'cart_confirm_order_btn',
                                            ),
                                            onPressed: summary.isEmpty
                                                ? null
                                                : () {
                                                    Navigator.pop(context);
                                                    context.go('/welcome');
                                                  },
                                            icon: const Icon(
                                              Icons.login_rounded,
                                            ),
                                            label: Text(
                                              i18n.t('sign_in_to_checkout'),
                                            ),
                                          )
                                        : FilledButton(
                                            key: const ValueKey(
                                              'cart_confirm_order_btn',
                                            ),
                                            onPressed:
                                                (summary.isEmpty ||
                                                    !isCanteenOpen ||
                                                    checkoutBusy ||
                                                    walletInsufficient)
                                                ? null
                                                : () async {
                                                    HapticFeedback.mediumImpact();
                                                    final confirmed = await ref
                                                        .read(
                                                          canteenStoreProvider
                                                              .notifier,
                                                        )
                                                        .submitOrder(
                                                          paymentMethod:
                                                              activeMethod,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    if (confirmed != null) {
                                                      Navigator.pop(context);
                                                      context.go('/orders');
                                                    }
                                                  },
                                            child: checkoutBusy
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.3,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : !isCanteenOpen
                                                ? Text(
                                                    i18n.t(
                                                      'canteen_closed_badge',
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          '${i18n.t('place_order_cta')} ($methodLabel) • ',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      EvaAnimatedCounterText(
                                                        text: i18n.formatPrice(
                                                          summary.finalTotal,
                                                        ),
                                                        numericValue:
                                                            summary.finalTotal,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedCartEntryShell extends StatelessWidget {
  const _AnimatedCartEntryShell({
    super.key,
    required this.entry,
    required this.isRtl,
    required this.child,
  });

  final _CartAnimatedEntry entry;
  final bool isRtl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizeAnim = CurvedAnimation(
      parent: entry.ctrl,
      curve: const Interval(0.0, 0.78, curve: Curves.easeInOutCubic),
    );
    final fadeScaleAnim = CurvedAnimation(
      parent: entry.ctrl,
      curve: const Interval(0.18, 1.0, curve: Curves.easeOutCubic),
    );
    final exitSlideDx = isRtl ? 0.18 : -0.18;

    return IgnorePointer(
      ignoring: entry.isExiting,
      child: SizeTransition(
        sizeFactor: sizeAnim,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: fadeScaleAnim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(exitSlideDx, 0.0),
              end: Offset.zero,
            ).animate(fadeScaleAnim),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.94,
                end: 1.0,
              ).animate(fadeScaleAnim),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartProductRow extends ConsumerStatefulWidget {
  const _CartProductRow({
    required this.product,
    required this.quantity,
    required this.isExiting,
    required this.onSwipeDismissed,
  });

  final ProductItem product;
  final int quantity;
  final bool isExiting;
  final VoidCallback onSwipeDismissed;

  @override
  ConsumerState<_CartProductRow> createState() => _CartProductRowState();
}

class _CartProductRowState extends ConsumerState<_CartProductRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _qtyPulseCtrl;
  late final Animation<double> _pulseCurve;

  @override
  void initState() {
    super.initState();
    _qtyPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pulseCurve = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 62,
      ),
    ]).animate(_qtyPulseCtrl);
  }

  @override
  void didUpdateWidget(covariant _CartProductRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity != oldWidget.quantity && !widget.isExiting) {
      final disableMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!disableMotion) {
        _qtyPulseCtrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _qtyPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);
    final cartNotifier = ref.read(cartProvider.notifier);
    final product = widget.product;
    final quantity = widget.quantity;
    final lineTotal = product.price * quantity;

    return Dismissible(
      key: ValueKey('cart_${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onSwipeDismissed(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: tokens.statusClosedBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: tokens.statusClosedFg),
      ),
      child: AnimatedBuilder(
        animation: _pulseCurve,
        builder: (context, child) {
          final p = _pulseCurve.value;
          final bgColor = widget.isExiting
              ? Color.lerp(tokens.surfaceCard, tokens.statusClosedBg, 0.35)!
              : Color.lerp(tokens.surfaceCard, tokens.brandSoftBg, p * 0.42)!;
          final borderColor = widget.isExiting
              ? tokens.statusClosedFg.withValues(alpha: 0.35)
              : Color.lerp(
                  tokens.borderSubtle,
                  tokens.brandPrimary,
                  p * 0.65,
                )!;
          return Transform.scale(
            scale: 1.0 + 0.015 * p,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: p > 0.05 ? 1.35 : 1.0,
                ),
              ),
              child: child,
            ),
          );
        },
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: EvaProductImage(imageUrl: product.image, borderRadius: 10),
            ),
            const SizedBox(width: 11),
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
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${i18n.formatPrice(product.price)} × ',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.textSecondary,
                                  fontFeatures: EvaThemeBuilder.tabularNums,
                                ),
                          ),
                          EvaAnimatedCounterText(
                            text: '$quantity',
                            numericValue: quantity,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            ' = ',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                          EvaAnimatedCounterText(
                            text: i18n.formatPrice(lineTotal),
                            numericValue: lineTotal,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.brandPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
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
              highlightRemoveAtOne: true,
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
    required this.numericValue,
    this.highlightColor,
  });

  final String label;
  final String value;
  final num numericValue;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        EvaAnimatedCounterText(
          text: value,
          numericValue: numericValue,
          textAlign: TextAlign.end,
          style: style?.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionChip extends StatelessWidget {
  const _PaymentOptionChip({
    super.key,
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
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.75 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : icon,
              size: 15.5,
              color: selected ? tokens.brandPrimary : tokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? tokens.brandPrimary : tokens.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
