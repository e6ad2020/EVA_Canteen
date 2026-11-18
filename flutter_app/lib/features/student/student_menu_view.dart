import 'dart:math' as math;

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
  bool _isScrolled = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final nextScrolled = notification.metrics.pixels > 8;
      if (nextScrolled != _isScrolled) {
        setState(() => _isScrolled = nextScrolled);
      }
    }
    return false;
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
    final isGuest = user == null || user.role == UserRole.guest;
    final showWalletInHeader =
        !isGuest && user.role == UserRole.student && store.paymentMethods.wallet;

    return Column(
      children: [
        // Floating Rounded Animated Top Bar
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1204),
            child: EvaGlassBar(
              isScrolled: _isScrolled,
              borderRadius: 22,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: EdgeInsets.symmetric(
                horizontal: 13,
                vertical: _isScrolled ? 8 : 11,
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _isScrolled ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: const EvaBrandLogo(size: 38),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [
                                  ...previousChildren,
                                  ?currentChild,
                                ],
                              ),
                          child: Text(
                            i18n.t('canteen_name'),
                            key: ValueKey<String>(i18n.t('canteen_name')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 1),
                        if (showWalletInHeader)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 12.5,
                                color: tokens.brandPrimary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    i18n.formatPrice(user.balance),
                                    key: ValueKey<double>(user.balance),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: tokens.brandPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures:
                                              EvaThemeBuilder.tabularNums,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            isGuest ? i18n.t('guest_mode_short') : user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isGuest) ...[
                                  EvaSurfaceCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    borderRadius: 16,
                                    child: Row(
                                      children: [
                                        EvaAvatar(
                                          profilePic: user?.profilePic ?? 'pic2',
                                          radius: 14,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            i18n.t('guest_mode_short'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: tokens.textPrimary,
                                                ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              context.go('/welcome'),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(0, 32),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.login_rounded,
                                            size: 15,
                                          ),
                                          label: Text(i18n.t('sign_in_tab')),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                if (!store.isCanteenOpen) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: tokens.statusClosedBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: tokens.statusClosedFg.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
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
                                            i18n.t(
                                              'canteen_closed_browse_banner',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: tokens.statusClosedFg,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                if (activeOrder != null) ...[
                                  EvaSurfaceCard(
                                    onTap: () => context.go('/orders'),
                                    backgroundColor: tokens.brandSoftBg,
                                    borderColor: tokens.brandPrimary.withValues(
                                      alpha: 0.35,
                                    ),
                                    borderRadius: 16,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.confirmation_number_outlined,
                                          color: tokens.brandPrimary,
                                          size: 20,
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
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: tokens.brandPrimary,
                                                ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color: tokens.brandPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
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

                    // Featured Combos & Deals Carousel
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
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 20,
                                        color: tokens.accentAppetite,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          i18n.t('smart_combos_title'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 170,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: activeBundles.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, idx) {
                                      return EvaReveal(
                                        index: idx,
                                        child: _SmartBundleCard(
                                          bundle: activeBundles[idx],
                                        ),
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
                            height: 52,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              scrollDirection: Axis.horizontal,
                              children: [
                                _CategoryFilterChip(
                                  label: i18n.t('all_categories'),
                                  selected: _selectedCategoryKey == null,
                                  onTap: () => setState(
                                    () => _selectedCategoryKey = null,
                                  ),
                                ),
                                for (final cat in visibleCategories) ...[
                                  const SizedBox(width: 8),
                                  _CategoryFilterChip(
                                    label: i18n.t(cat.nameKey),
                                    selected: _selectedCategoryKey == cat.key,
                                    onTap: () => setState(
                                      () => _selectedCategoryKey = cat.key,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // True Multi-Column Product Grid (2 cols on phones, 3 on tablet, 4 on desktop)
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final totalW = constraints.crossAxisExtent;
                        final sidePad = totalW < 420
                            ? 12.0
                            : math.max(16.0, (totalW - 1180) / 2);
                        final gridW = math.max(220.0, totalW - sidePad * 2);

                        final int cols = gridW < 260
                            ? 1
                            : (gridW < 620 ? 2 : (gridW < 920 ? 3 : 4));
                        final double spacing = cols <= 2 ? 10 : 14;
                        final double cardHeight = cols <= 2 ? 258 : 276;

                        final navClearance = EvaFloatingNavBar.bottomClearance(
                          context,
                        );

                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            sidePad,
                            8,
                            sidePad,
                            (cartSummary.isEmpty ? 24.0 : 96.0) + navClearance,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                  mainAxisExtent: cardHeight,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = filteredProducts[index];
                                return EvaReveal(
                                  index: index,
                                  child: _MenuProductCard(
                                    product: product,
                                    isCompactGrid: cols <= 2,
                                    onOpenDetails: () =>
                                        _showItemDetailSheet(context, product),
                                  ),
                                );
                              },
                              childCount: filteredProducts.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Animated Floating Checkout Dock (lifts cleanly above EvaFloatingNavBar on mobile)
              Positioned(
                left: 16,
                right: 16,
                bottom:
                    MediaQuery.sizeOf(context).width <
                        EvaFloatingNavBar.shellWideBreakpoint
                    ? 84
                    : 14,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.35),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: cartSummary.isEmpty
                      ? const SizedBox.shrink()
                      : Center(
                          key: const ValueKey('checkout_dock_visible'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: EvaPressable(
                              child: Material(
                                color: tokens.brandPrimary,
                                elevation: 8,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.25,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => showCartCheckoutSheet(context),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.brandOnPrimary
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            child: Text(
                                              '${cartSummary.totalItemCount}',
                                              key: ValueKey<int>(
                                                cartSummary.totalItemCount,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color:
                                                        tokens.brandOnPrimary,
                                                    fontFeatures:
                                                        EvaThemeBuilder
                                                            .tabularNums,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                i18n.t('review_order_cta'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color:
                                                          tokens.brandOnPrimary,
                                                    ),
                                              ),
                                              if (cartSummary.totalDiscount > 0)
                                                Text(
                                                  '-${i18n.formatPrice(cartSummary.totalDiscount)} ${i18n.t('bundle_savings_label')}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: tokens
                                                            .brandOnPrimary
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          i18n.formatPrice(
                                            cartSummary.finalTotal,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: tokens.brandOnPrimary,
                                                fontFeatures:
                                                    EvaThemeBuilder.tabularNums,
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
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
                ),
              ),
            ],
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
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = math.max(250.0, math.min(304.0, screenW - 44));

    return SizedBox(
      width: cardW,
      child: EvaSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: EvaStatusBadge(
                    label: bundle.isSuggestion
                        ? i18n.t('meal_ideas_badge')
                        : i18n.t('discount_badge', {
                            'percent': bundle.discountPercent
                                .toInt()
                                .toString(),
                          }),
                    background: bundle.isSuggestion
                        ? tokens.brandSoftBg
                        : tokens.accentAppetite.withValues(alpha: 0.14),
                    foreground: bundle.isSuggestion
                        ? tokens.brandPrimary
                        : tokens.accentAppetite,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in resolvedItems.take(3))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
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
                Expanded(
                  child: Row(
                    children: [
                      if (!bundle.isSuggestion && finalPrice < originalSum) ...[
                        Flexible(
                          child: Text(
                            i18n.formatPrice(originalSum),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  fontFeatures: EvaThemeBuilder.tabularNums,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          i18n.formatPrice(finalPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: tokens.brandPrimary,
                                fontFeatures: EvaThemeBuilder.tabularNums,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: tokens.brandPrimary.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                  child: Text(
                    i18n.t('add_combo_button'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.brandPrimary : tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: tokens.borderWidth,
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

class _MenuProductCard extends ConsumerWidget {
  const _MenuProductCard({
    required this.product,
    required this.onOpenDetails,
    this.isCompactGrid = false,
  });

  final ProductItem product;
  final VoidCallback onOpenDetails;
  final bool isCompactGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final qtyInCart = ref.watch(cartProvider.select((m) => m[product.id] ?? 0));
    final cartNotifier = ref.read(cartProvider.notifier);

    return EvaSurfaceCard(
      onTap: onOpenDetails,
      padding: EdgeInsets.all(isCompactGrid ? 9 : 11),
      borderRadius: 18,
      borderColor: qtyInCart > 0
          ? tokens.brandPrimary.withValues(alpha: 0.72)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: isCompactGrid ? 108 : 122,
                width: double.infinity,
                child: EvaProductImage(
                  imageUrl: product.image,
                  borderRadius: 13,
                ),
              ),
              if (product.isOutOfStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(13),
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
                  top: 7,
                  start: 7,
                  child: EvaStatusBadge(
                    label: i18n.t('low_stock_left', {
                      'count': '${product.quantity}',
                    }),
                    background: tokens.statusPendingBg,
                    foreground: tokens.statusPendingFg,
                  ),
                ),
              if (qtyInCart > 0 && !product.isOutOfStock)
                PositionedDirectional(
                  top: 7,
                  end: 7,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Container(
                      key: ValueKey<int>(qtyInCart),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.brandPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '×$qtyInCart',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.brandOnPrimary,
                          fontWeight: FontWeight.w800,
                          fontFeatures: EvaThemeBuilder.tabularNums,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i18n.t(product.nameKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: isCompactGrid ? 14 : 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            i18n.t(product.descriptionKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: isCompactGrid ? 11.5 : 12.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            i18n.formatPrice(product.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.brandPrimary,
              fontWeight: FontWeight.w800,
              fontSize: isCompactGrid ? 14.5 : 15.5,
              fontFeatures: EvaThemeBuilder.tabularNums,
            ),
          ),
          const Spacer(),
          EvaQuantityStepper(
            quantity: qtyInCart,
            addLabel: i18n.t('add_button'),
            compact: true,
            fullWidth: true,
            disabled: product.isOutOfStock,
            maxReached: !product.isUnlimited && qtyInCart >= product.quantity,
            onIncrement: () => cartNotifier.increment(product),
            onDecrement: () => cartNotifier.decrement(product.id),
          ),
        ],
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

    return SingleChildScrollView(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  i18n.t(product.nameKey),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: 12),
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
              Flexible(
                child: EvaStatusBadge(
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
          EvaPressable(
            child: FilledButton(
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
          ),
        ],
      ),
    );
  }
}
