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
    return Column(
      children: [
        // Studio Header
        EvaGlassBar(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  segments: [
                    ButtonSegment(
                      value: _StudioSection.products,
                      icon: const Icon(Icons.lunch_dining_rounded, size: 16),
                      label: Text(
                        i18n.t('studio_products_tab'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ButtonSegment(
                      value: _StudioSection.categories,
                      icon: const Icon(Icons.category_rounded, size: 16),
                      label: Text(
                        i18n.t('studio_categories_tab'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ButtonSegment(
                      value: _StudioSection.bundles,
                      icon: const Icon(Icons.local_offer_rounded, size: 16),
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

        // Active Sub-View
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey(_section),
              child: switch (_section) {
                _StudioSection.products => _buildProductsSection(
                  context,
                  store,
                  i18n,
                  tokens,
                ),
                _StudioSection.categories => _buildCategoriesSection(
                  context,
                  store,
                  i18n,
                  tokens,
                ),
                _StudioSection.bundles => _buildBundlesSection(
                  context,
                  store,
                  i18n,
                  tokens,
                ),
              },
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. PRODUCTS STUDIO
  // ===========================================================================
  Widget _buildProductsSection(
    BuildContext context,
    CanteenStoreState store,
    EvaTranslator i18n,
    EvaTokens tokens,
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

    final canReorderIntraCategory =
        _selectedCategoryKey != null &&
        _selectedCategoryKey != 'archive' &&
        _searchQuery.trim().isEmpty &&
        filtered.length > 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: i18n.t('search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
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
                        onSelected: (_) =>
                            setState(() => _selectedCategoryKey = cat.key),
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
                      onSelected: (_) =>
                          setState(() => _selectedCategoryKey = 'archive'),
                    ),
                  ],
                ),
              ),
              if (canReorderIntraCategory)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: tokens.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          i18n.isRtl
                              ? 'اسحب مقبض الترتيب لتغيير ظهور الأصناف داخل هذه الفئة.'
                              : 'Drag the handle on any row to reorder items inside this category.',
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
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    i18n.isRtl
                        ? 'لا توجد أصناف في هذا القسم.'
                        : 'No items in this section.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                )
              : canReorderIntraCategory
              ? ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + EvaFloatingNavBar.bottomClearance(context),
                  ),
                  buildDefaultDragHandles: false,
                  itemCount: filtered.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reorderedIds = filtered.map((e) => e.id).toList();
                    final moved = reorderedIds.removeAt(oldIndex);
                    reorderedIds.insert(newIndex, moved);

                    final updatedCategories = [
                      for (final cat in store.categories)
                        if (cat.key == _selectedCategoryKey)
                          cat.copyWith(productIds: reorderedIds)
                        else
                          cat,
                    ];
                    HapticFeedback.selectionClick();
                    ref
                        .read(canteenStoreProvider.notifier)
                        .reorderCategories(updatedCategories);
                  },
                  itemBuilder: (context, idx) {
                    final prod = filtered[idx];
                    return Padding(
                      key: ValueKey('reorder_prod_${prod.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminProductStudioCard(
                        product: prod,
                        dragIndex: idx,
                        defaultRestoreCategoryKey:
                            store.studentCategories.firstOrNull?.key ??
                            'sandwiches',
                        onEdit: () => _openProductEditor(
                          context,
                          existing: prod,
                          defaultCategoryKey: prod.categoryKey,
                        ),
                      ),
                    );
                  },
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final navClearance = EvaFloatingNavBar.bottomClearance(
                      context,
                    );
                    final cols = constraints.maxWidth >= 1100
                        ? 3
                        : (constraints.maxWidth >= 700 ? 2 : 1);
                    if (cols == 1) {
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24 + navClearance,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final prod = filtered[idx];
                          return EvaReveal(
                            index: idx,
                            child: _AdminProductStudioCard(
                              product: prod,
                              defaultRestoreCategoryKey:
                                  store.studentCategories.firstOrNull?.key ??
                                  'sandwiches',
                              onEdit: () => _openProductEditor(
                                context,
                                existing: prod,
                                defaultCategoryKey: prod.categoryKey,
                              ),
                            ),
                          );
                        },
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        24 + navClearance,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 204,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final prod = filtered[idx];
                        return EvaReveal(
                          index: idx,
                          child: _AdminProductStudioCard(
                            product: prod,
                            defaultRestoreCategoryKey:
                                store.studentCategories.firstOrNull?.key ??
                                'sandwiches',
                            onEdit: () => _openProductEditor(
                              context,
                              existing: prod,
                              defaultCategoryKey: prod.categoryKey,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
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
  ) {
    final activeCats = store.studentCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            i18n.isRtl
                ? 'اسحب الفئات لإعادة ترتيب أقسام القائمة. يجب إفراغ الفئة من الأصناف قبل حذفها.'
                : 'Drag categories to reorder menu sections. Empty a category before deleting it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + EvaFloatingNavBar.bottomClearance(context),
            ),
            buildDefaultDragHandles: false,
            itemCount: activeCats.length,
            onReorderItem: (oldIndex, newIndex) {
              final list = List<CategoryItem>.from(activeCats);
              final moved = list.removeAt(oldIndex);
              list.insert(newIndex, moved);
              final archives = store.categories
                  .where((c) => c.isArchive)
                  .toList();
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
          ),
        ),
      ],
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
  ) {
    final allBundles = store.adminBundles.isNotEmpty
        ? store.adminBundles
        : store.bundles;
    final productsMap = store.productsById;

    if (allBundles.isEmpty) {
      return Center(
        child: Text(
          i18n.isRtl ? 'لا توجد عروض مسجلة بعد.' : 'No bundles configured yet.',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: tokens.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
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
                        Flexible(
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
                        const Spacer(),
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BundleEditorSheet(existing: existing),
    );
  }
}

class _AdminProductStudioCard extends ConsumerWidget {
  const _AdminProductStudioCard({
    required this.product,
    required this.defaultRestoreCategoryKey,
    required this.onEdit,
    this.dragIndex,
  });

  final ProductItem product;
  final String defaultRestoreCategoryKey;
  final VoidCallback onEdit;
  final int? dragIndex;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final notifier = ref.read(canteenStoreProvider.notifier);

    final enName = i18n.rawForLang(product.nameKey, 'en');
    final arName = i18n.rawForLang(product.nameKey, 'ar');

    return EvaSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: 8,
                      top: 18,
                    ),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              SizedBox(
                width: 66,
                height: 66,
                child: EvaProductImage(
                  imageUrl: product.image,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enName.isNotEmpty && arName.isNotEmpty
                          ? '$enName • $arName'
                          : i18n.t(product.nameKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i18n.formatPrice(product.price),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.brandPrimary,
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.isArchived
                          ? i18n.t('archive_shelf_label')
                          : i18n.t('category_${product.categoryKey}') !=
                                'category_${product.categoryKey}'
                          ? i18n.t('category_${product.categoryKey}')
                          : product.categoryKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: i18n.t('edit_button'),
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                tooltip: product.isArchived
                    ? i18n.t('restore_button')
                    : i18n.t('move_to_archive'),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  notifier.quickUpdateProductStockOrCategory(
                    product,
                    categoryKey: product.isArchived
                        ? defaultRestoreCategoryKey
                        : 'archive',
                  );
                },
                icon: Icon(
                  product.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 19,
                ),
              ),
              IconButton(
                tooltip: i18n.t('delete_cta'),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
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
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: tokens.statusClosedFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 1-Tap Quick Stock Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                selected: product.isOutOfStock,
                selectedColor: tokens.statusClosedBg,
                label: Text(
                  i18n.t('out_of_stock'),
                  style: TextStyle(
                    color: product.isOutOfStock
                        ? tokens.statusClosedFg
                        : tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.quickUpdateProductStockOrCategory(
                    product,
                    quantity: 0,
                  );
                },
              ),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                selected: !product.isOutOfStock && !product.isUnlimited,
                selectedColor: tokens.brandSoftBg,
                label: Text(
                  !product.isOutOfStock && !product.isUnlimited
                      ? 'Qty: ${product.quantity}'
                      : (i18n.isRtl ? 'كمية محددة' : 'Set Qty'),
                ),
                onSelected: (_) => _promptCustomStock(context, ref, i18n),
              ),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                selected: product.isUnlimited,
                selectedColor: tokens.statusDeliveredBg,
                label: Text(
                  '∞ ${i18n.t('unlimited_stock')}',
                  style: TextStyle(
                    color: product.isUnlimited
                        ? tokens.statusDeliveredFg
                        : tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.quickUpdateProductStockOrCategory(
                    product,
                    quantity: 999,
                  );
                },
              ),
            ],
          ),
        ],
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
