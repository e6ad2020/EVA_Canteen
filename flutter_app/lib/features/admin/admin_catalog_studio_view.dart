import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/eva_i18n.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

enum _StudioSection { products, categories, bundles }

class AdminCatalogStudioView extends ConsumerStatefulWidget {
  const AdminCatalogStudioView({super.key});

  @override
  ConsumerState<AdminCatalogStudioView> createState() =>
      _AdminCatalogStudioViewState();
}

class _AdminCatalogStudioViewState
    extends ConsumerState<AdminCatalogStudioView> {
  _StudioSection _section = _StudioSection.products;
  String? _selectedCategoryKey; // null = All active, 'archive' = Archive shelf
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _productsScrollCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _productsScrollCtrl.dispose();
    super.dispose();
  }

  void _reorderProductInCategory({
    required CanteenStoreState store,
    required String categoryKey,
    required String draggedProductId,
    required int newIndexInCategory,
  }) {
    if (categoryKey == 'archive') return;
    final ordered = store.orderedProductsForCategory(
      categoryKey,
      includeArchived: false,
    );
    final ids = ordered.map((p) => p.id).toList();
    final oldIndex = ids.indexOf(draggedProductId);
    if (oldIndex == -1) return;
    final clampedNew = newIndexInCategory.clamp(0, ids.length - 1);
    if (oldIndex == clampedNew) return;

    final moved = ids.removeAt(oldIndex);
    ids.insert(clampedNew, moved);

    final updatedCategories = [
      for (final cat in store.categories)
        if (cat.key == categoryKey) cat.copyWith(productIds: ids) else cat,
    ];
    HapticFeedback.selectionClick();
    ref
        .read(canteenStoreProvider.notifier)
        .reorderCategories(updatedCategories);
  }

  void _handleDragAutoScroll(
    BuildContext scrollAreaContext,
    DragUpdateDetails details,
    double topClearance,
  ) {
    if (!_productsScrollCtrl.hasClients) return;
    final renderBox = scrollAreaContext.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return;
    final localY = renderBox.globalToLocal(details.globalPosition).dy;
    final topZone = topClearance + 52.0;
    const bottomZone = 96.0;
    const maxStep = 14.0;

    double delta = 0.0;
    if (localY < topZone) {
      delta = -maxStep * ((topZone - localY) / 64.0).clamp(0.15, 1.0);
    } else if (localY > renderBox.size.height - bottomZone) {
      delta =
          maxStep *
          ((localY - (renderBox.size.height - bottomZone)) / bottomZone).clamp(
            0.15,
            1.0,
          );
    }
    if (delta != 0.0) {
      final pos = _productsScrollCtrl.position;
      final target = (pos.pixels + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (target != pos.pixels) {
        _productsScrollCtrl.jumpTo(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final showSegmentIcons = MediaQuery.sizeOf(context).width >= 400;

    return EvaFloatingHeaderScaffold(
      initialHeaderHeight: 118.0,
      headerBuilder: (context, isScrolled) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1204),
          child: EvaGlassBar(
            isScrolled: isScrolled,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('admin_catalog_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_section == _StudioSection.products)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _openProductEditor(
                          context,
                          existing: null,
                          defaultCategoryKey:
                              (_selectedCategoryKey != null &&
                                  _selectedCategoryKey != 'archive')
                              ? _selectedCategoryKey!
                              : (store.studentCategories.firstOrNull?.key ??
                                    'sandwiches'),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(i18n.t('new_product_cta')),
                      )
                    else if (_section == _StudioSection.categories)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () =>
                            _openCategoryDialog(context, existing: null),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(i18n.t('new_category_cta')),
                      )
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () =>
                            _openBundleEditor(context, existing: null),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(i18n.t('new_bundle_cta')),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_StudioSection>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: _StudioSection.products,
                        icon: showSegmentIcons
                            ? const Icon(Icons.lunch_dining_rounded, size: 15)
                            : null,
                        label: Text(
                          i18n.t('studio_products_tab'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment(
                        value: _StudioSection.categories,
                        icon: showSegmentIcons
                            ? const Icon(Icons.category_rounded, size: 15)
                            : null,
                        label: Text(
                          i18n.t('studio_categories_tab'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment(
                        value: _StudioSection.bundles,
                        icon: showSegmentIcons
                            ? const Icon(Icons.local_offer_rounded, size: 15)
                            : null,
                        label: Text(
                          i18n.t('studio_bundles_tab'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (sel) {
                      setState(() => _section = sel.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bodyBuilder: (context, topClearance, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        child: KeyedSubtree(
          key: ValueKey(_section),
          child: switch (_section) {
            _StudioSection.products => _buildProductsSection(
              context,
              store,
              i18n,
              tokens,
              topClearance,
            ),
            _StudioSection.categories => _buildCategoriesSection(
              context,
              store,
              i18n,
              tokens,
              topClearance,
            ),
            _StudioSection.bundles => _buildBundlesSection(
              context,
              store,
              i18n,
              tokens,
              topClearance,
            ),
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. PRODUCTS STUDIO — LIVE MENU-MATCHED GRID & 2D RANKING
  // ===========================================================================
  Widget _buildProductsSection(
    BuildContext context,
    CanteenStoreState store,
    EvaTranslator i18n,
    EvaTokens tokens,
    double topClearance,
  ) {
    final archivedCount = store.products.where((p) => p.isArchived).length;
    final baseList = _selectedCategoryKey == null
        ? store.orderedProductsForCategory(null, includeArchived: false)
        : store.orderedProductsForCategory(
            _selectedCategoryKey,
            includeArchived: true,
          );

    final filtered = baseList.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      return i18n.matchesBilingualQuery(p.nameKey, _searchQuery) ||
          i18n.matchesBilingualQuery(p.descriptionKey, _searchQuery);
    }).toList(growable: false);

    // Precompute 0-based rank index & category size for every active product
    final rankIndexByProductId = <String, int>{};
    final categoryCountByKey = <String, int>{};
    final categoryNameKeyByKey = <String, String>{};
    for (final cat in store.studentCategories) {
      categoryNameKeyByKey[cat.key] = cat.nameKey;
      final catOrdered = store.orderedProductsForCategory(
        cat.key,
        includeArchived: false,
      );
      categoryCountByKey[cat.key] = catOrdered.length;
      for (int i = 0; i < catOrdered.length; i++) {
        rankIndexByProductId[catOrdered[i].id] = i;
      }
    }

    final isRankingActive =
        _selectedCategoryKey != 'archive' &&
        _searchQuery.trim().isEmpty &&
        filtered.length > 1;
    final navClearance = EvaFloatingNavBar.bottomClearance(context);
    final restoreCatKey =
        store.studentCategories.firstOrNull?.key ?? 'sandwiches';

    return Builder(
      builder: (scrollAreaContext) => CustomScrollView(
        controller: _productsScrollCtrl,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, topClearance + 6, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: i18n.t('search_hint'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              selected: _selectedCategoryKey == null,
                              label: Text(i18n.t('all_categories')),
                              onSelected: (_) =>
                                  setState(() => _selectedCategoryKey = null),
                            ),
                            const SizedBox(width: 8),
                            for (final cat in store.studentCategories) ...[
                              ChoiceChip(
                                selected: _selectedCategoryKey == cat.key,
                                label: Text(i18n.t(cat.nameKey)),
                                onSelected: (_) => setState(
                                  () => _selectedCategoryKey = cat.key,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ChoiceChip(
                              selected: _selectedCategoryKey == 'archive',
                              avatar: Icon(
                                Icons.archive_outlined,
                                size: 16,
                                color: _selectedCategoryKey == 'archive'
                                    ? tokens.brandPrimary
                                    : tokens.textSecondary,
                              ),
                              label: Text(
                                '${i18n.t('archive_shelf_label')} ($archivedCount)',
                              ),
                              onSelected: (_) => setState(
                                () => _selectedCategoryKey = 'archive',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRankingActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 15,
                                color: tokens.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  i18n.t('catalog_grid_rank_hint'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: tokens.brandPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: navClearance),
                child: Center(
                  child: Text(
                    i18n.isRtl
                        ? 'لا توجد أصناف في هذا القسم.'
                        : 'No items in this section.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                // Exact column & spacing geometry from StudentMenuView so admin ranking mirrors the live menu 1:1
                final totalW = constraints.crossAxisExtent;
                final sidePad = totalW < 420
                    ? 12.0
                    : math.max(16.0, (totalW - 1180) / 2);
                final gridW = math.max(220.0, totalW - sidePad * 2);

                final int cols = gridW < 260
                    ? 1
                    : (gridW < 620 ? 2 : (gridW < 920 ? 3 : 4));
                final double spacing = cols <= 2 ? 10.0 : 14.0;
                final double cardHeight = cols <= 2 ? 258.0 : 276.0;
                final double cellWidth = (gridW - spacing * (cols - 1)) / cols;

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sidePad,
                    8,
                    sidePad,
                    24 + navClearance,
                  ),
                  sliver: SliverGrid(
                    key: const ValueKey('admin_catalog_items_grid'),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: cardHeight,
                    ),
                    delegate: SliverChildBuilderDelegate((context, idx) {
                      final prod = filtered[idx];
                      final rankIdx = rankIndexByProductId[prod.id] ?? 0;
                      final catCount =
                          categoryCountByKey[prod.categoryKey] ?? 1;
                      final catNameKey = categoryNameKeyByKey[prod.categoryKey];
                      final canRankItem =
                          !prod.isArchived &&
                          _searchQuery.trim().isEmpty &&
                          catCount > 1;

                      Widget buildCard({bool isDropTarget = false}) {
                        return _AdminProductStudioCard(
                          key: ValueKey('admin_prod_card_${prod.id}'),
                          product: prod,
                          isCompactGrid: cols <= 2,
                          showCategoryLabel: _selectedCategoryKey == null,
                          categoryLabel: catNameKey != null
                              ? i18n.t(catNameKey)
                              : prod.categoryKey,
                          rankNumber: prod.isArchived ? null : (rankIdx + 1),
                          canRank: canRankItem,
                          isDropHighlighted: isDropTarget,
                          defaultRestoreCategoryKey: restoreCatKey,
                          onEdit: () => _openProductEditor(
                            context,
                            existing: prod,
                            defaultCategoryKey: prod.categoryKey,
                          ),
                          onMoveRankEarlier: canRankItem && rankIdx > 0
                              ? () => _reorderProductInCategory(
                                  store: store,
                                  categoryKey: prod.categoryKey,
                                  draggedProductId: prod.id,
                                  newIndexInCategory: rankIdx - 1,
                                )
                              : null,
                          onMoveRankLater: canRankItem && rankIdx < catCount - 1
                              ? () => _reorderProductInCategory(
                                  store: store,
                                  categoryKey: prod.categoryKey,
                                  draggedProductId: prod.id,
                                  newIndexInCategory: rankIdx + 1,
                                )
                              : null,
                        );
                      }

                      if (!canRankItem) {
                        return EvaReveal(index: idx, child: buildCard());
                      }

                      return DragTarget<ProductItem>(
                        key: ValueKey('admin_prod_target_${prod.id}'),
                        onWillAcceptWithDetails: (details) {
                          final dragged = details.data;
                          return dragged.id != prod.id &&
                              dragged.categoryKey == prod.categoryKey &&
                              !prod.isArchived;
                        },
                        onAcceptWithDetails: (details) {
                          _reorderProductInCategory(
                            store: store,
                            categoryKey: prod.categoryKey,
                            draggedProductId: details.data.id,
                            newIndexInCategory: rankIdx,
                          );
                        },
                        builder: (context, candidateData, _) {
                          final isHovering = candidateData.isNotEmpty;
                          return AnimatedScale(
                            scale: isHovering ? 1.03 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            child: LongPressDraggable<ProductItem>(
                              data: prod,
                              delay: const Duration(milliseconds: 220),
                              hapticFeedbackOnStart: true,
                              onDragUpdate: (details) => _handleDragAutoScroll(
                                scrollAreaContext,
                                details,
                                topClearance,
                              ),
                              feedback: Material(
                                type: MaterialType.transparency,
                                child: SizedBox(
                                  width: cellWidth,
                                  height: cardHeight,
                                  child: Transform.scale(
                                    scale: 1.04,
                                    child: IgnorePointer(
                                      child: buildCard(isDropTarget: true),
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.32,
                                child: buildCard(),
                              ),
                              child: EvaReveal(
                                index: idx,
                                child: buildCard(isDropTarget: isHovering),
                              ),
                            ),
                          );
                        },
                      );
                    }, childCount: filtered.length),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. CATEGORIES STUDIO
  // ===========================================================================
  Widget _buildCategoriesSection(
    BuildContext context,
    CanteenStoreState store,
    EvaTranslator i18n,
    EvaTokens tokens,
    double topClearance,
  ) {
    final activeCats = store.studentCategories;

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        topClearance + 8,
        16,
        24 + EvaFloatingNavBar.bottomClearance(context),
      ),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          i18n.isRtl
              ? 'اسحب الفئات لإعادة ترتيب أقسام القائمة. يجب إفراغ الفئة من الأصناف قبل حذفها.'
              : 'Drag categories to reorder menu sections. Empty a category before deleting it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      buildDefaultDragHandles: false,
      itemCount: activeCats.length,
      onReorderItem: (oldIndex, newIndex) {
        final list = List<CategoryItem>.from(activeCats);
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        final archives = store.categories.where((c) => c.isArchive).toList();
        HapticFeedback.selectionClick();
        ref.read(canteenStoreProvider.notifier).reorderCategories([
          ...list,
          ...archives,
        ]);
      },
      itemBuilder: (context, idx) {
        final cat = activeCats[idx];
        final prodCount = store.products
            .where((p) => p.categoryKey == cat.key)
            .length;
        final enName = i18n.rawForLang(cat.nameKey, 'en');
        final arName = i18n.rawForLang(cat.nameKey, 'ar');

        return Padding(
          key: ValueKey('cat_row_${cat.key}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: EvaSurfaceCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: ReorderableDragStartListener(
                index: idx,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              title: Text(
                enName.isNotEmpty && arName.isNotEmpty
                    ? '$enName  •  $arName'
                    : i18n.t(cat.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Key: ${cat.key}  •  $prodCount items',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: i18n.t('edit_button'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _openCategoryDialog(context, existing: cat),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  Tooltip(
                    message: prodCount > 0
                        ? (i18n.isRtl
                              ? 'انقل الأصناف للأرشيف أولاً قبل حذف الفئة'
                              : 'Move or archive $prodCount items before deleting')
                        : i18n.t('delete_cta'),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: prodCount > 0
                          ? null
                          : () => ref
                                .read(canteenStoreProvider.notifier)
                                .deleteCategory(cat.key),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: prodCount > 0
                            ? tokens.textSecondary.withValues(alpha: 0.35)
                            : tokens.statusClosedFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3. BUNDLES & COMBOS STUDIO
  // ===========================================================================
  Widget _buildBundlesSection(
    BuildContext context,
    CanteenStoreState store,
    EvaTranslator i18n,
    EvaTokens tokens,
    double topClearance,
  ) {
    final allBundles = store.adminBundles.isNotEmpty
        ? store.adminBundles
        : store.bundles;
    final productsMap = store.productsById;

    if (allBundles.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topClearance),
        child: Center(
          child: Text(
            i18n.isRtl
                ? 'لا توجد عروض مسجلة بعد.'
                : 'No bundles configured yet.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        topClearance + 8,
        16,
        24 + EvaFloatingNavBar.bottomClearance(context),
      ),
      itemCount: allBundles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final bundle = allBundles[idx];
        final enTitle = i18n.rawForLang(bundle.nameKey, 'en');
        final arTitle = i18n.rawForLang(bundle.nameKey, 'ar');
        final originalSum = bundle.itemIds.fold<double>(
          0,
          (sum, id) => sum + (productsMap[id]?.price ?? 0),
        );
        final finalPrice = bundle.isSuggestion
            ? originalSum
            : (originalSum * ((100 - bundle.discountPercent) / 100))
                  .roundToDouble();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: EvaReveal(
              index: idx,
              child: EvaSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: EvaStatusBadge(
                              label: bundle.isSuggestion
                                  ? i18n.t('meal_ideas_badge')
                                  : i18n.t('discount_badge', {
                                      'percent': bundle.discountPercent
                                          .toStringAsFixed(0),
                                    }),
                              background: bundle.isSuggestion
                                  ? tokens.brandSoftBg
                                  : tokens.statusDeliveredBg,
                              foreground: bundle.isSuggestion
                                  ? tokens.brandPrimary
                                  : tokens.statusDeliveredFg,
                              icon: bundle.isSuggestion
                                  ? Icons.auto_awesome_rounded
                                  : Icons.local_offer_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: bundle.active,
                          onChanged: (val) {
                            ref.read(canteenStoreProvider.notifier).saveBundle(
                              bundle: bundle.copyWith(active: val),
                              nameEn: enTitle.isNotEmpty
                                  ? enTitle
                                  : i18n.t(bundle.nameKey),
                              nameAr: arTitle.isNotEmpty
                                  ? arTitle
                                  : i18n.t(bundle.nameKey),
                              descEn: i18n.rawForLang(
                                bundle.descriptionKey,
                                'en',
                              ),
                              descAr: i18n.rawForLang(
                                bundle.descriptionKey,
                                'ar',
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: i18n.t('edit_button'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _openBundleEditor(context, existing: bundle),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: i18n.t('delete_cta'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ref
                              .read(canteenStoreProvider.notifier)
                              .deleteBundle(bundle.id),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: tokens.statusClosedFg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      enTitle.isNotEmpty && arTitle.isNotEmpty
                          ? '$enTitle  •  $arTitle'
                          : i18n.t(bundle.nameKey),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i18n.t(bundle.descriptionKey),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in bundle.itemIds)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              productsMap[id] != null
                                  ? i18n.t(productsMap[id]!.nameKey)
                                  : id,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (!bundle.isSuggestion && originalSum > finalPrice)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Text(
                              i18n.formatPrice(originalSum),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          ),
                        Text(
                          i18n.formatPrice(finalPrice),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: tokens.brandPrimary,
                                fontFeatures: EvaThemeBuilder.tabularNums,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DIALOGS & SHEETS
  // ===========================================================================
  Future<void> _openCategoryDialog(
    BuildContext context, {
    required CategoryItem? existing,
  }) async {
    final i18n = ref.read(i18nProvider);
    final enCtrl = TextEditingController(
      text: existing != null ? i18n.rawForLang(existing.nameKey, 'en') : '',
    );
    final arCtrl = TextEditingController(
      text: existing != null ? i18n.rawForLang(existing.nameKey, 'ar') : '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? i18n.t('new_category_cta') : i18n.t('edit_button'),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: enCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'Category Name (English)',
                  hintText: 'e.g. Fresh Pastries',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: arCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'اسم الفئة (بالعربية)',
                  hintText: 'مثال: المخبوزات الطازجة',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel_cta')),
          ),
          FilledButton(
            onPressed: () {
              final en = enCtrl.text.trim();
              final ar = arCtrl.text.trim();
              if (en.isEmpty && ar.isEmpty) return;
              final resolvedEn = en.isEmpty ? ar : en;
              final resolvedAr = ar.isEmpty ? en : ar;

              final slug = resolvedEn
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                  .replaceAll(RegExp(r'^_+|_+$'), '');
              final key =
                  existing?.key ??
                  (slug.isNotEmpty
                      ? '${slug}_${DateTime.now().millisecondsSinceEpoch % 1000}'
                      : 'cat_${DateTime.now().millisecondsSinceEpoch}');
              final nameKey = existing?.nameKey ?? 'category_$key';

              ref.read(canteenStoreProvider.notifier).saveCategory(
                isNew: existing == null,
                key: key,
                nameKey: nameKey,
                nameEn: resolvedEn,
                nameAr: resolvedAr,
              );
              Navigator.of(ctx).pop();
            },
            child: Text(i18n.t('save_cta')),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductEditor(
    BuildContext context, {
    required ProductItem? existing,
    required String defaultCategoryKey,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductEditorSheet(
        existing: existing,
        defaultCategoryKey: defaultCategoryKey,
      ),
    );
  }

  Future<void> _openBundleEditor(
    BuildContext context, {
    required BundleOffer? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BundleEditorSheet(existing: existing),
    );
  }
}

class _AdminProductStudioCard extends ConsumerWidget {
  const _AdminProductStudioCard({
    super.key,
    required this.product,
    required this.defaultRestoreCategoryKey,
    required this.onEdit,
    this.isCompactGrid = false,
    this.showCategoryLabel = false,
    this.categoryLabel = '',
    this.rankNumber,
    this.canRank = false,
    this.isDropHighlighted = false,
    this.onMoveRankEarlier,
    this.onMoveRankLater,
  });

  final ProductItem product;
  final String defaultRestoreCategoryKey;
  final VoidCallback onEdit;
  final bool isCompactGrid;
  final bool showCategoryLabel;
  final String categoryLabel;
  final int? rankNumber;
  final bool canRank;
  final bool isDropHighlighted;
  final VoidCallback? onMoveRankEarlier;
  final VoidCallback? onMoveRankLater;

  Future<void> _promptCustomStock(
    BuildContext context,
    WidgetRef ref,
    EvaTranslator i18n,
  ) async {
    final ctrl = TextEditingController(
      text: product.isUnlimited ? '25' : '${product.quantity}',
    );
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t(product.nameKey)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: i18n.isRtl ? 'الكمية المتاحة' : 'Exact Stock Quantity',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel_cta')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(ctrl.text.trim());
              if (parsed != null && parsed >= 0) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: Text(i18n.t('save_cta')),
          ),
        ],
      ),
    );
    if (res != null) {
      ref
          .read(canteenStoreProvider.notifier)
          .quickUpdateProductStockOrCategory(product, quantity: res);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EvaTranslator i18n,
    EvaTokens tokens,
    CanteenStoreNotifier notifier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('delete_cta')),
        content: Text(i18n.t(product.nameKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(i18n.t('cancel_cta')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.statusClosedFg,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(i18n.t('delete_cta')),
          ),
        ],
      ),
    );
    if (ok == true) {
      notifier.deleteProduct(product.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final notifier = ref.read(canteenStoreProvider.notifier);

    final enName = i18n.rawForLang(product.nameKey, 'en');
    final arName = i18n.rawForLang(product.nameKey, 'ar');
    final primaryTitle = i18n.t(product.nameKey);
    final secondaryLangName = i18n.isRtl ? enName : arName;

    final subtitleParts = <String>[
      if (showCategoryLabel && categoryLabel.isNotEmpty) categoryLabel,
      if (secondaryLangName.isNotEmpty && secondaryLangName != primaryTitle)
        secondaryLangName,
    ];
    final subtitleText = subtitleParts.isNotEmpty
        ? subtitleParts.join(' • ')
        : i18n.t(product.descriptionKey);

    final isFiniteStock = !product.isOutOfStock && !product.isUnlimited;

    return EvaSurfaceCard(
      padding: EdgeInsets.all(isCompactGrid ? 9 : 11),
      borderRadius: 18,
      borderWidth: isDropHighlighted ? 2.0 : null,
      borderColor: isDropHighlighted
          ? tokens.brandPrimary
          : (product.isOutOfStock
                ? tokens.statusClosedFg.withValues(alpha: 0.35)
                : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: onEdit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                height: isCompactGrid ? 104 : 118,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.44,
                                      ),
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
                                  bottom: 6,
                                  start: 6,
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
                          const SizedBox(height: 8),
                          Text(
                            primaryTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isCompactGrid ? 13.5 : 14.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: isCompactGrid ? 11.0 : 12.0,
                                  color: tokens.textSecondary,
                                ),
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  i18n.formatPrice(product.price),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: tokens.brandPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: isCompactGrid ? 14.0 : 15.0,
                                        fontFeatures:
                                            EvaThemeBuilder.tabularNums,
                                      ),
                                ),
                              ),
                              if (canRank) ...[
                                const SizedBox(width: 4),
                                Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: tokens.borderSubtle,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _RankStepIconButton(
                                        key: ValueKey(
                                          'rank_earlier_${product.id}',
                                        ),
                                        icon: Icons.chevron_left_rounded,
                                        tooltip: i18n.t('rank_earlier_tooltip'),
                                        onTap: onMoveRankEarlier,
                                        tokens: tokens,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 12,
                                        color: tokens.borderSubtle,
                                      ),
                                      _RankStepIconButton(
                                        key: ValueKey(
                                          'rank_later_${product.id}',
                                        ),
                                        icon: Icons.chevron_right_rounded,
                                        tooltip: i18n.t('rank_later_tooltip'),
                                        onTap: onMoveRankLater,
                                        tokens: tokens,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top-Start Rank Badge (#1, #2, #3... or Archive icon)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: product.isArchived
                            ? tokens.surfaceElevated.withValues(alpha: 0.94)
                            : tokens.brandPrimary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canRank) ...[
                            Icon(
                              Icons.drag_indicator_rounded,
                              size: 12,
                              color: tokens.brandOnPrimary.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            const SizedBox(width: 2),
                          ] else if (product.isArchived) ...[
                            Icon(
                              Icons.archive_outlined,
                              size: 12,
                              color: tokens.textSecondary,
                            ),
                          ],
                          if (rankNumber != null)
                            Text(
                              '#$rankNumber',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: tokens.brandOnPrimary,
                                    fontSize: 10.5,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: EvaThemeBuilder.tabularNums,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top-End Compact Action Capsule (Edit / Archive / Delete)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tokens.borderSubtle, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OverlayCardActionButton(
                          icon: Icons.edit_outlined,
                          tooltip: i18n.t('edit_button'),
                          color: tokens.textPrimary,
                          onTap: onEdit,
                        ),
                        _OverlayCardActionButton(
                          icon: product.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          tooltip: product.isArchived
                              ? i18n.t('restore_button')
                              : i18n.t('move_to_archive'),
                          color: tokens.textSecondary,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.quickUpdateProductStockOrCategory(
                              product,
                              categoryKey: product.isArchived
                                  ? defaultRestoreCategoryKey
                                  : 'archive',
                            );
                          },
                        ),
                        _OverlayCardActionButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: i18n.t('delete_cta'),
                          color: tokens.statusClosedFg,
                          onTap: () =>
                              _confirmDelete(context, i18n, tokens, notifier),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          // 1-Tap Segmented Stock Pill Bar (0 / Qty / ∞) — zero wrapping on 360dp 2-col grids
          Container(
            height: 32,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StockPillSegment(
                    label: i18n.t('stock_out_short'),
                    selected: product.isOutOfStock,
                    activeBg: tokens.statusClosedBg,
                    activeFg: tokens.statusClosedFg,
                    inactiveFg: tokens.textSecondary,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.quickUpdateProductStockOrCategory(
                        product,
                        quantity: 0,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _StockPillSegment(
                    label: isFiniteStock
                        ? '${product.quantity}'
                        : i18n.t('stock_qty_short'),
                    selected: isFiniteStock,
                    activeBg: tokens.brandSoftBg,
                    activeFg: tokens.brandPrimary,
                    inactiveFg: tokens.textSecondary,
                    onTap: () => _promptCustomStock(context, ref, i18n),
                  ),
                ),
                Expanded(
                  child: _StockPillSegment(
                    label: '∞',
                    selected: product.isUnlimited,
                    activeBg: tokens.statusDeliveredBg,
                    activeFg: tokens.statusDeliveredFg,
                    inactiveFg: tokens.textSecondary,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.quickUpdateProductStockOrCategory(
                        product,
                        quantity: 999,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCardActionButton extends StatelessWidget {
  const _OverlayCardActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Center(child: Icon(icon, size: 15, color: color)),
          ),
        ),
      ),
    );
  }
}

class _RankStepIconButton extends StatelessWidget {
  const _RankStepIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final EvaTokens tokens;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: 23,
            height: 22,
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: enabled
                    ? tokens.brandPrimary
                    : tokens.textSecondary.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockPillSegment extends StatelessWidget {
  const _StockPillSegment({
    required this.label,
    required this.selected,
    required this.activeBg,
    required this.activeFg,
    required this.inactiveFg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeBg;
  final Color activeFg;
  final Color inactiveFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeBg : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                strutStyle: const StrutStyle(
                  forceStrutHeight: true,
                  height: 1.0,
                ),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? activeFg : inactiveFg,
                  fontFeatures: EvaThemeBuilder.tabularNums,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductEditorSheet extends ConsumerStatefulWidget {
  const _ProductEditorSheet({
    required this.existing,
    required this.defaultCategoryKey,
  });

  final ProductItem? existing;
  final String defaultCategoryKey;

  @override
  ConsumerState<_ProductEditorSheet> createState() =>
      _ProductEditorSheetState();
}

class _ProductEditorSheetState extends ConsumerState<_ProductEditorSheet> {
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _descEnCtrl;
  late final TextEditingController _descArCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _imgCtrl;

  late String _categoryKey;
  late bool _isUnlimited;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i18n = ref.read(i18nProvider);
    final p = widget.existing;
    _nameEnCtrl = TextEditingController(
      text: p != null ? i18n.rawForLang(p.nameKey, 'en') : '',
    );
    _nameArCtrl = TextEditingController(
      text: p != null ? i18n.rawForLang(p.nameKey, 'ar') : '',
    );
    _descEnCtrl = TextEditingController(
      text: p != null ? i18n.rawForLang(p.descriptionKey, 'en') : '',
    );
    _descArCtrl = TextEditingController(
      text: p != null ? i18n.rawForLang(p.descriptionKey, 'ar') : '',
    );
    _priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(0) : '25',
    );
    _isUnlimited = p == null ? false : p.isUnlimited;
    _qtyCtrl = TextEditingController(
      text: p != null && !p.isUnlimited ? '${p.quantity}' : '30',
    );
    _imgCtrl = TextEditingController(text: p?.image ?? '');
    _categoryKey = p?.categoryKey ?? widget.defaultCategoryKey;
  }

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    _descEnCtrl.dispose();
    _descArCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() {
        _uploading = true;
        _error = null;
      });
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final uploadedUrl = await ref
          .read(canteenStoreProvider.notifier)
          .uploadProductPhoto(bytes: bytes, mimeType: mime);

      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (uploadedUrl != null) {
          _imgCtrl.text = uploadedUrl;
        } else {
          _error = 'Photo upload failed. Check connection or paste URL.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Could not pick image: $e';
      });
    }
  }

  void _save() {
    final en = _nameEnCtrl.text.trim();
    final ar = _nameArCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final qty = _isUnlimited ? 999 : (int.tryParse(_qtyCtrl.text.trim()) ?? 0);

    if ((en.isEmpty && ar.isEmpty) || price == null || price < 0) {
      setState(
        () => _error = 'Please enter at least one product name and valid price.',
      );
      return;
    }

    final resolvedEn = en.isEmpty ? ar : en;
    final resolvedAr = ar.isEmpty ? en : ar;
    final id =
        widget.existing?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final nameKey = widget.existing?.nameKey ?? 'item_name_$id';
    final descKey = widget.existing?.descriptionKey ?? 'item_desc_$id';

    final item = ProductItem(
      id: id,
      nameKey: nameKey,
      descriptionKey: descKey,
      price: price,
      quantity: qty,
      image: _imgCtrl.text.trim(),
      categoryKey: _categoryKey,
    );

    ref.read(canteenStoreProvider.notifier).saveProduct(
      isNew: widget.existing == null,
      product: item,
      nameEn: resolvedEn,
      nameAr: resolvedAr,
      descEn: _descEnCtrl.text.trim().isEmpty
          ? resolvedEn
          : _descEnCtrl.text.trim(),
      descAr: _descArCtrl.text.trim().isEmpty
          ? resolvedAr
          : _descArCtrl.text.trim(),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final categories = ref.watch(canteenStoreProvider.select((s) => s.categories));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? i18n.t('new_product_cta')
                            : i18n.t('edit_product_cta'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Live Image & Upload Row
                Row(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _imgCtrl,
                        builder: (_, val, _) => EvaProductImage(
                          imageUrl: val.text.trim(),
                          borderRadius: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickAndUploadPhoto,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 18,
                                  ),
                            label: Text(i18n.t('upload_photo_cta')),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _imgCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Image URL / Path',
                              hintText: '/uploads/... or https://...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ResponsivePair(
                  first: TextField(
                    controller: _nameEnCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Name (English)',
                    ),
                  ),
                  second: TextField(
                    controller: _nameArCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم (عربي)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsivePair(
                  first: TextField(
                    controller: _descEnCtrl,
                    maxLines: 2,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Description (English)',
                    ),
                  ),
                  second: TextField(
                    controller: _descArCtrl,
                    maxLines: 2,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (عربي)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsivePair(
                  first: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price (${i18n.currencySymbol})',
                    ),
                  ),
                  second: DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c.key == _categoryKey)
                        ? _categoryKey
                        : (categories.firstOrNull?.key ?? 'sandwiches'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: i18n.t('studio_categories_tab'),
                    ),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(
                          value: c.key,
                          child: Text(
                            c.isArchive
                                ? i18n.t('archive_shelf_label')
                                : i18n.t(c.nameKey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _categoryKey = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: _isUnlimited,
                      onChanged: (v) => setState(() => _isUnlimited = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '∞ ${i18n.t('unlimited_stock')}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (!_isUnlimited)
                      SizedBox(
                        width: 128,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Qty',
                          ),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: tokens.statusClosedFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(i18n.t('save_cta')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BundleEditorSheet extends ConsumerStatefulWidget {
  const _BundleEditorSheet({required this.existing});

  final BundleOffer? existing;

  @override
  ConsumerState<_BundleEditorSheet> createState() => _BundleEditorSheetState();
}

class _BundleEditorSheetState extends ConsumerState<_BundleEditorSheet> {
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _descEnCtrl;
  late final TextEditingController _descArCtrl;
  late bool _isSuggestion;
  late double _discountPercent;
  late Set<String> _selectedIds;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i18n = ref.read(i18nProvider);
    final b = widget.existing;
    _nameEnCtrl = TextEditingController(
      text: b != null ? i18n.rawForLang(b.nameKey, 'en') : '',
    );
    _nameArCtrl = TextEditingController(
      text: b != null ? i18n.rawForLang(b.nameKey, 'ar') : '',
    );
    _descEnCtrl = TextEditingController(
      text: b != null ? i18n.rawForLang(b.descriptionKey, 'en') : '',
    );
    _descArCtrl = TextEditingController(
      text: b != null ? i18n.rawForLang(b.descriptionKey, 'ar') : '',
    );
    _isSuggestion = b?.isSuggestion ?? false;
    _discountPercent = (b != null && b.discountPercent > 0)
        ? b.discountPercent
        : 15;
    _selectedIds = Set<String>.from(b?.itemIds ?? const []);
  }

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    _descEnCtrl.dispose();
    _descArCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final en = _nameEnCtrl.text.trim();
    final ar = _nameArCtrl.text.trim();
    if ((en.isEmpty && ar.isEmpty) || _selectedIds.length < 2) {
      setState(
        () => _error = 'Enter a bundle name and select at least 2 products.',
      );
      return;
    }

    final resolvedEn = en.isEmpty ? ar : en;
    final resolvedAr = ar.isEmpty ? en : ar;
    final id =
        widget.existing?.id ??
        'bundle-${DateTime.now().millisecondsSinceEpoch}';
    final nameKey = widget.existing?.nameKey ?? 'bundle_name_$id';
    final descKey = widget.existing?.descriptionKey ?? 'bundle_desc_$id';

    final offer = BundleOffer(
      id: id,
      nameKey: nameKey,
      descriptionKey: descKey,
      itemIds: _selectedIds.toList(growable: false),
      discountPercent: _isSuggestion ? 0 : _discountPercent,
      isSuggestion: _isSuggestion,
      active: widget.existing?.active ?? true,
      displayOrder: widget.existing?.displayOrder ?? 0,
    );

    ref.read(canteenStoreProvider.notifier).saveBundle(
      bundle: offer,
      nameEn: resolvedEn,
      nameAr: resolvedAr,
      descEn: _descEnCtrl.text.trim().isEmpty
          ? resolvedEn
          : _descEnCtrl.text.trim(),
      descAr: _descArCtrl.text.trim().isEmpty
          ? resolvedAr
          : _descArCtrl.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final activeProducts = ref.watch(
      canteenStoreProvider.select(
        (s) => s.orderedProductsForCategory(null, includeArchived: false),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? i18n.t('new_bundle_cta')
                            : i18n.t('edit_button'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.local_offer_rounded, size: 17),
                        label: Text(
                          i18n.isRtl
                              ? 'حزمة خصم (% توفير)'
                              : 'Discount Deal (% OFF)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                        label: Text(
                          i18n.t('meal_ideas_badge'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {_isSuggestion},
                    onSelectionChanged: (s) =>
                        setState(() => _isSuggestion = s.first),
                  ),
                ),
                const SizedBox(height: 14),
                _ResponsivePair(
                  first: TextField(
                    controller: _nameEnCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Title (English)',
                    ),
                  ),
                  second: TextField(
                    controller: _nameArCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'العنوان (عربي)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsivePair(
                  first: TextField(
                    controller: _descEnCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Subtitle (English)',
                    ),
                  ),
                  second: TextField(
                    controller: _descArCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (عربي)',
                    ),
                  ),
                ),
                if (!_isSuggestion) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Discount: ${_discountPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.statusDeliveredFg,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _discountPercent.clamp(5, 50),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: '${_discountPercent.toStringAsFixed(0)}%',
                          onChanged: (v) =>
                              setState(() => _discountPercent = v),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  i18n.isRtl
                      ? 'اختر الأصناف المشمولة في العرض (${_selectedIds.length}):'
                      : 'Select Included Items (${_selectedIds.length}):',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in activeProducts)
                      FilterChip(
                        selected: _selectedIds.contains(p.id),
                        label: Text(
                          '${i18n.t(p.nameKey)} (${i18n.formatPrice(p.price)})',
                        ),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedIds.add(p.id);
                            } else {
                              _selectedIds.remove(p.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: tokens.statusClosedFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(i18n.t('save_cta')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
