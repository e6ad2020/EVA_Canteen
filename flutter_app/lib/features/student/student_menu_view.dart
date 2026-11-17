import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';
import 'cart_checkout_sheet.dart';

class StudentMenuView extends ConsumerStatefulWidget {
  const StudentMenuView({super.key});

  @override
  ConsumerState<StudentMenuView> createState() => _StudentMenuViewState();
}

class _StudentMenuViewState extends ConsumerState<StudentMenuView> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryKey;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final cartSummary = ref.watch(cartPricingProvider);
    final user = store.currentUser;

    final visibleCategories = store.studentCategories;
    final rawProducts = store.orderedProductsForCategory(_selectedCategoryKey);
    final filteredProducts = _searchQuery.trim().isEmpty
        ? rawProducts
        : rawProducts
              .where(
                (p) =>
                    i18n.matchesBilingualQuery(p.nameKey, _searchQuery) ||
                    i18n.matchesBilingualQuery(p.descriptionKey, _searchQuery),
              )
              .toList(growable: false);

    final activeBundles = store.bundles
        .where((b) => b.active)
        .toList(growable: false);
    final activeOrder = store.activeStudentOrder;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            EvaAvatar(
                              profilePic: user?.profilePic ?? 'pic2',
                              radius: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i18n.t('canteen_name'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    user?.email ?? i18n.t('browse_menu_guest'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (user != null &&
                                user.role == UserRole.student &&
                                store.paymentMethods.wallet) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.brandSoftBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 15,
                                      color: tokens.brandPrimary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      i18n.formatPrice(user.balance),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: tokens.brandPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures:
                                                EvaThemeBuilder.tabularNums,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            EvaStatusBadge(
                              label: store.isCanteenOpen
                                  ? i18n.t('canteen_open_badge')
                                  : i18n.t('canteen_closed_badge'),
                              background: store.isCanteenOpen
                                  ? tokens.statusDeliveredBg
                                  : tokens.statusClosedBg,
                              foreground: store.isCanteenOpen
                                  ? tokens.statusDeliveredFg
                                  : tokens.statusClosedFg,
                              pulsing: store.isCanteenOpen,
                            ),
                            const SizedBox(width: 8),
                            const LanguageQuickToggle(),
                          ],
                        ),
                        if (!store.isCanteenOpen) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.statusClosedBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  color: tokens.statusClosedFg,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    i18n.t('canteen_closed_browse_banner'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: tokens.statusClosedFg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (activeOrder != null) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => context.go('/orders'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.brandSoftBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: tokens.brandPrimary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.confirmation_number_outlined,
                                    color: tokens.brandPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      i18n.t('active_order_pill', {
                                        'num': activeOrder.pickupNumber,
                                        'status': i18n.t(
                                          'status_${activeOrder.status.name}',
                                        ),
                                      }),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: tokens.brandPrimary,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: tokens.brandPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: i18n.t('search_hint'),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Smart Combos & Deals Carousel
            if (_searchQuery.trim().isEmpty &&
                _selectedCategoryKey == null &&
                activeBundles.isNotEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 20,
                                color: tokens.accentAppetite,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                i18n.t('smart_combos_title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 168,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: activeBundles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              return _SmartBundleCard(
                                bundle: activeBundles[idx],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: SizedBox(
                    height: 54,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryFilterChip(
                          label: i18n.t('all_categories'),
                          selected: _selectedCategoryKey == null,
                          onTap: () =>
                              setState(() => _selectedCategoryKey = null),
                        ),
                        for (final cat in visibleCategories) ...[
                          const SizedBox(width: 8),
                          _CategoryFilterChip(
                            label: i18n.t(cat.nameKey),
                            selected: _selectedCategoryKey == cat.key,
                            onTap: () =>
                                setState(() => _selectedCategoryKey = cat.key),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Product Grid
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                cartSummary.isEmpty ? 28 : 104,
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 268,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 264,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = filteredProducts[index];
                      return _StudentProductCard(
                        product: product,
                        onOpenDetails: () =>
                            _showItemDetailSheet(context, product),
                      );
                    }, childCount: filteredProducts.length),
                  );
                },
              ),
            ),
          ],
        ),

        // Persistent Floating Checkout Bar
        if (!cartSummary.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: tokens.brandPrimary,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => showCartCheckoutSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.brandOnPrimary.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${cartSummary.totalItemCount}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: tokens.brandOnPrimary,
                                    fontFeatures: EvaThemeBuilder.tabularNums,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  i18n.t('review_order_cta'),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: tokens.brandOnPrimary),
                                ),
                                if (cartSummary.totalDiscount > 0)
                                  Text(
                                    '-${i18n.formatPrice(cartSummary.totalDiscount)} ${i18n.t('bundle_savings_label')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: tokens.brandOnPrimary
                                              .withValues(alpha: 0.85),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            i18n.formatPrice(cartSummary.finalTotal),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: tokens.brandOnPrimary,
                                  fontFeatures: EvaThemeBuilder.tabularNums,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: tokens.brandOnPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showItemDetailSheet(BuildContext context, ProductItem product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (_) => _ItemDetailBottomSheet(productId: product.id),
    );
  }
}

class _SmartBundleCard extends ConsumerWidget {
  const _SmartBundleCard({required this.bundle});

  final BundleOffer bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final productsById = ref.watch(
      canteenStoreProvider.select((s) => s.productsById),
    );

    final resolvedItems = <ProductItem>[];
    double originalSum = 0;
    bool allAvailable = true;

    for (final id in bundle.itemIds) {
      final prod = productsById[id];
      if (prod == null || prod.isOutOfStock || prod.isArchived) {
        allAvailable = false;
      } else {
        resolvedItems.add(prod);
        originalSum += prod.price;
      }
    }

    if (resolvedItems.isEmpty) return const SizedBox.shrink();

    final finalPrice = bundle.isSuggestion
        ? originalSum
        : (originalSum * ((100 - bundle.discountPercent) / 100))
              .roundToDouble();

    return Container(
      width: 312,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EvaStatusBadge(
                label: bundle.isSuggestion
                    ? i18n.t('meal_ideas_badge')
                    : i18n.t('discount_badge', {
                        'percent': bundle.discountPercent.toInt().toString(),
                      }),
                background: bundle.isSuggestion
                    ? tokens.brandSoftBg
                    : tokens.accentAppetite.withValues(alpha: 0.14),
                foreground: bundle.isSuggestion
                    ? tokens.brandPrimary
                    : tokens.accentAppetite,
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (final item in resolvedItems.take(3))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: EvaProductImage(
                            imageUrl: item.image,
                            borderRadius: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.t(bundle.nameKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            resolvedItems.map((e) => i18n.t(e.nameKey)).join(' + '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Row(
            children: [
              if (!bundle.isSuggestion && finalPrice < originalSum) ...[
                Text(
                  i18n.formatPrice(originalSum),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    fontFeatures: EvaThemeBuilder.tabularNums,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                i18n.formatPrice(finalPrice),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.brandPrimary,
                  fontFeatures: EvaThemeBuilder.tabularNums,
                ),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: !allAvailable
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        final ok = ref
                            .read(cartProvider.notifier)
                            .addBundleOrCombo(bundle, productsById);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(i18n.t('out_of_stock'))),
                          );
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.brandSoftBg,
                  foregroundColor: tokens.brandPrimary,
                  minimumSize: const Size(84, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(i18n.t('add_combo_button')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.brandPrimary : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? tokens.brandOnPrimary : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StudentProductCard extends ConsumerWidget {
  const _StudentProductCard({
    required this.product,
    required this.onOpenDetails,
  });

  final ProductItem product;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final qtyInCart = ref.watch(cartProvider.select((m) => m[product.id] ?? 0));
    final cartNotifier = ref.read(cartProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 128,
                    width: double.infinity,
                    child: EvaProductImage(
                      imageUrl: product.image,
                      borderRadius: 12,
                    ),
                  ),
                  if (product.isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: EvaStatusBadge(
                          label: i18n.t('out_of_stock'),
                          background: tokens.statusClosedBg,
                          foreground: tokens.statusClosedFg,
                        ),
                      ),
                    )
                  else if (product.isLowStock)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: EvaStatusBadge(
                        label: i18n.t('low_stock_left', {
                          'count': '${product.quantity}',
                        }),
                        background: tokens.statusPendingBg,
                        foreground: tokens.statusPendingFg,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                i18n.t(product.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                i18n.t(product.descriptionKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.formatPrice(product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ),
                  EvaQuantityStepper(
                    quantity: qtyInCart,
                    addLabel: i18n.t('add_button'),
                    compact: true,
                    disabled: product.isOutOfStock,
                    maxReached:
                        !product.isUnlimited && qtyInCart >= product.quantity,
                    onIncrement: () => cartNotifier.increment(product),
                    onDecrement: () => cartNotifier.decrement(product.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemDetailBottomSheet extends ConsumerWidget {
  const _ItemDetailBottomSheet({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final product = ref.watch(
      canteenStoreProvider.select((s) => s.productsById[productId]),
    );
    final qtyInCart = ref.watch(cartProvider.select((m) => m[productId] ?? 0));
    final cartNotifier = ref.read(cartProvider.notifier);

    if (product == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: EvaProductImage(imageUrl: product.image, borderRadius: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  i18n.t(product.nameKey),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                i18n.formatPrice(product.price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tokens.brandPrimary,
                  fontFeatures: EvaThemeBuilder.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i18n.t(product.descriptionKey),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              EvaStatusBadge(
                label: product.isOutOfStock
                    ? i18n.t('out_of_stock')
                    : (product.isUnlimited
                          ? i18n.t('unlimited_stock')
                          : i18n.t('low_stock_left', {
                              'count': '${product.quantity}',
                            })),
                background: product.isOutOfStock
                    ? tokens.statusClosedBg
                    : tokens.statusDeliveredBg,
                foreground: product.isOutOfStock
                    ? tokens.statusClosedFg
                    : tokens.statusDeliveredFg,
              ),
              const Spacer(),
              EvaQuantityStepper(
                quantity: qtyInCart,
                addLabel: i18n.t('add_button'),
                disabled: product.isOutOfStock,
                maxReached:
                    !product.isUnlimited && qtyInCart >= product.quantity,
                onIncrement: () => cartNotifier.increment(product),
                onDecrement: () => cartNotifier.decrement(product.id),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (qtyInCart == 0 && !product.isOutOfStock) {
                cartNotifier.increment(product);
              }
              Navigator.pop(context);
            },
            child: Text(
              qtyInCart > 0
                  ? '${i18n.t('review_order_cta')} ($qtyInCart)'
                  : '${i18n.t('add_button')} • ${i18n.formatPrice(product.price)}',
            ),
          ),
        ],
      ),
    );
  }
}
