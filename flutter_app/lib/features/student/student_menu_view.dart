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

class _StudentMenuViewState extends ConsumerState<StudentMenuView>
    with TickerProviderStateMixin {
  static const int _waveSlots = 6;
  static const Cubic _expoOut = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Cubic _combosExpoOut = Cubic(0.22, 1.0, 0.36, 1.0);

  final _searchCtrl = TextEditingController();
  final _categoryScrollCtrl = ScrollController();
  final Map<String, GlobalKey> _chipKeys = {};
  String _searchQuery = '';
  String? _selectedCategoryKey;
  double _categorySlideDir = 1.0;

  late final AnimationController _gridTransitionCtrl;
  late final CurvedAnimation _gridOpacityCurve;
  late final Animation<double> _gridOpacity;
  late final List<CurvedAnimation> _slotCurves;
  late final List<Animation<Offset>> _slotSlidesRight;
  late final List<Animation<Offset>> _slotSlidesLeft;

  late final AnimationController _combosCtrl;
  late final CurvedAnimation _combosSizeCurve;
  late final CurvedAnimation _combosFadeCurve;
  late final Animation<Offset> _combosSlide;
  bool _combosInitialized = false;
  bool _lastShowCombos = false;

  @override
  void initState() {
    super.initState();
    _gridTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 290),
      value: 1.0,
    );
    _gridOpacityCurve = CurvedAnimation(
      parent: _gridTransitionCtrl,
      curve: const Interval(0.0, 0.56, curve: Curves.easeOutCubic),
    );
    _gridOpacity = Tween<double>(
      begin: 0.18,
      end: 1.0,
    ).animate(_gridOpacityCurve);

    _slotCurves = List<CurvedAnimation>.generate(_waveSlots, (slot) {
      final start = (slot * 0.044).clamp(0.0, 0.22);
      final end = (0.72 + slot * 0.056).clamp(0.72, 1.0);
      return CurvedAnimation(
        parent: _gridTransitionCtrl,
        curve: Interval(start, end, curve: _expoOut),
      );
    }, growable: false);

    _slotSlidesRight = List<Animation<Offset>>.generate(_waveSlots, (slot) {
      return Tween<Offset>(
        begin: const Offset(0.14, 0.045),
        end: Offset.zero,
      ).animate(_slotCurves[slot]);
    }, growable: false);

    _slotSlidesLeft = List<Animation<Offset>>.generate(_waveSlots, (slot) {
      return Tween<Offset>(
        begin: const Offset(-0.14, 0.045),
        end: Offset.zero,
      ).animate(_slotCurves[slot]);
    }, growable: false);

    _combosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _combosSizeCurve = CurvedAnimation(
      parent: _combosCtrl,
      curve: _combosExpoOut,
    );
    _combosFadeCurve = CurvedAnimation(
      parent: _combosCtrl,
      curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
    );
    _combosSlide = Tween<Offset>(
      begin: const Offset(0.0, -0.06),
      end: Offset.zero,
    ).animate(_combosSizeCurve);
    _combosCtrl.addStatusListener(_handleCombosStatus);
  }

  void _handleCombosStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  void _syncCombosVisibility(bool showCombos, bool disableMotion) {
    if (!_combosInitialized) {
      _combosInitialized = true;
      _lastShowCombos = showCombos;
      _combosCtrl.value = showCombos ? 1.0 : 0.0;
      return;
    }
    if (showCombos == _lastShowCombos) return;
    _lastShowCombos = showCombos;
    if (disableMotion) {
      _combosCtrl.value = showCombos ? 1.0 : 0.0;
    } else if (showCombos) {
      _combosCtrl.forward();
    } else {
      _combosCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _combosCtrl.removeStatusListener(_handleCombosStatus);
    _combosFadeCurve.dispose();
    _combosSizeCurve.dispose();
    _combosCtrl.dispose();
    for (final c in _slotCurves) {
      c.dispose();
    }
    _gridOpacityCurve.dispose();
    _gridTransitionCtrl.dispose();
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  GlobalKey _chipKeyFor(String? categoryKey) =>
      _chipKeys.putIfAbsent(categoryKey ?? '__all__', GlobalKey.new);

  void _selectCategory(String? nextKey, List<CategoryItem> categories) {
    if (_selectedCategoryKey == nextKey) return;
    final orderedKeys = <String?>[null, ...categories.map((c) => c.key)];
    final oldIdx = orderedKeys.indexOf(_selectedCategoryKey);
    final newIdx = orderedKeys.indexOf(nextKey);
    final logicalDir = newIdx >= oldIdx ? 1.0 : -1.0;
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    setState(() {
      _selectedCategoryKey = nextKey;
      _categorySlideDir = logicalDir;
    });

    if (disableMotion) {
      _gridTransitionCtrl.value = 1.0;
    } else {
      _gridTransitionCtrl.forward(from: 0.0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryScrollCtrl.hasClients) return;
      final position = _categoryScrollCtrl.position;
      if (position.maxScrollExtent <= 0) return;
      final chipCtx = _chipKeyFor(nextKey).currentContext;
      final listBox =
          position.context.storageContext.findRenderObject() as RenderBox?;
      final chipBox = chipCtx?.findRenderObject() as RenderBox?;
      if (chipBox == null || listBox == null || !chipBox.attached) return;

      final chipLeftInViewport = chipBox
          .localToGlobal(Offset.zero, ancestor: listBox)
          .dx;
      final chipRightInViewport = chipLeftInViewport + chipBox.size.width;
      const edgeComfortMargin = 8.0;
      if (chipLeftInViewport >= edgeComfortMargin &&
          chipRightInViewport <= listBox.size.width - edgeComfortMargin) {
        return;
      }
      final desiredDelta =
          (chipLeftInViewport + chipBox.size.width / 2) -
          (listBox.size.width / 2);
      final targetOffset = (position.pixels + desiredDelta).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if ((targetOffset - position.pixels).abs() > 12.0) {
        _categoryScrollCtrl.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final (
      user,
      visibleCategories,
      rawProducts,
      bundles,
      activeOrder,
      walletEnabled,
      isCanteenOpen,
    ) = ref.watch(
      canteenStoreProvider.select(
        (s) => (
          s.currentUser,
          s.studentCategories,
          s.orderedProductsForCategory(_selectedCategoryKey),
          s.bundles,
          s.activeStudentOrder,
          s.paymentMethods.wallet,
          s.isCanteenOpen,
        ),
      ),
    );
    final cartSummary = ref.watch(cartPricingProvider);

    final filteredProducts = _searchQuery.trim().isEmpty
        ? rawProducts
        : rawProducts
              .where(
                (p) =>
                    i18n.matchesBilingualQuery(p.nameKey, _searchQuery) ||
                    i18n.matchesBilingualQuery(p.descriptionKey, _searchQuery),
              )
              .toList(growable: false);

    final activeBundles = bundles
        .where((b) => b.active)
        .toList(growable: false);
    final showCombos =
        _searchQuery.trim().isEmpty &&
        _selectedCategoryKey == null &&
        activeBundles.isNotEmpty;
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncCombosVisibility(
      showCombos,
      disableMotion || activeBundles.isEmpty,
    );
    final renderCombos =
        activeBundles.isNotEmpty && (showCombos || !_combosCtrl.isDismissed);

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final visualDir = isRtl ? -_categorySlideDir : _categorySlideDir;
    final activeSlotSlides =
        visualDir >= 0 ? _slotSlidesRight : _slotSlidesLeft;

    final isGuest = user == null || user.role == UserRole.guest;
    final showWalletInHeader =
        !isGuest &&
        user.role == UserRole.student &&
        walletEnabled;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return EvaFloatingHeaderScaffold(
      initialHeaderHeight: 72.0,
      headerBuilder: (context, isScrolled) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1204),
          child: EvaGlassBar(
            isScrolled: isScrolled,
            borderRadius: 22,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: EdgeInsets.symmetric(
              horizontal: 13,
              vertical: isScrolled ? 8 : 11,
            ),
            child: Row(
              children: [
                AnimatedScale(
                  scale: isScrolled ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: const EvaBrandLogo(size: 44),
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
                              children: [...previousChildren, ?currentChild],
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
                              child: EvaAnimatedCounterText(
                                text: i18n.formatPrice(user.balance),
                                numericValue: user.balance,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: tokens.brandPrimary,
                                      fontWeight: FontWeight.w700,
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
                  label: isCanteenOpen
                      ? i18n.t('canteen_open_badge')
                      : i18n.t('canteen_closed_badge'),
                  background: isCanteenOpen
                      ? tokens.statusDeliveredBg
                      : tokens.statusClosedBg,
                  foreground: isCanteenOpen
                      ? tokens.statusDeliveredFg
                      : tokens.statusClosedFg,
                  pulsing: isCanteenOpen,
                ),
              ],
            ),
          ),
        ),
      ),
      bodyBuilder: (context, topClearance, _) => Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, viewportConstraints) {
              final totalW = viewportConstraints.maxWidth;
              final sidePad = totalW < 420
                  ? 12.0
                  : math.max(16.0, (totalW - 1180) / 2);
              final gridW = math.max(220.0, totalW - sidePad * 2);

              final int cols = gridW < 260
                  ? 1
                  : (gridW < 620 ? 2 : (gridW < 920 ? 3 : 4));
              final double spacing = cols <= 2 ? 10 : 14;
              final double cardHeight = cols <= 2 ? 262 : 280;
              final navClearance = EvaFloatingNavBar.bottomClearance(context);

              return CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, topClearance + 4, 12, 6),
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
                                          ?.copyWith(color: tokens.textPrimary),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => context.go('/welcome'),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
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

                          if (!isCanteenOpen) ...[
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
                                      i18n.t('canteen_closed_browse_banner'),
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

                  // Smoothly collapsing/expanding Featured Combos & Deals Carousel
                  SliverToBoxAdapter(
                    child: !renderCombos
                        ? const SizedBox.shrink()
                        : IgnorePointer(
                            ignoring: !showCombos,
                            child: FadeTransition(
                              opacity: _combosFadeCurve,
                              child: SizeTransition(
                                sizeFactor: _combosSizeCurve,
                                alignment: Alignment.topCenter,
                                child: SlideTransition(
                                  position: _combosSlide,
                                  child: RepaintBoundary(
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1180,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    12,
                                                    8,
                                                    12,
                                                    8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .local_fire_department_rounded,
                                                    size: 20,
                                                    color:
                                                        tokens.accentAppetite,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      i18n.t(
                                                        'smart_combos_title',
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                scrollDirection:
                                                    Axis.horizontal,
                                                addRepaintBoundaries: false,
                                                itemCount: activeBundles.length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(width: 12),
                                                itemBuilder: (context, idx) =>
                                                    _SmartBundleCard(
                                                      key: ValueKey<String>(
                                                        activeBundles[idx].id,
                                                      ),
                                                      bundle:
                                                          activeBundles[idx],
                                                    ),
                                              ),
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

                  // Category Filter Chips with Auto-Centering & Animated Active State
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: SizedBox(
                            height: 54,
                            child: ListView(
                              controller: _categoryScrollCtrl,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              scrollDirection: Axis.horizontal,
                              children: [
                                _CategoryFilterChip(
                                  key: _chipKeyFor(null),
                                  label: i18n.t('all_categories'),
                                  selected: _selectedCategoryKey == null,
                                  onTap: () =>
                                      _selectCategory(null, visibleCategories),
                                ),
                                for (final cat in visibleCategories) ...[
                                  const SizedBox(width: 8),
                                  _CategoryFilterChip(
                                    key: _chipKeyFor(cat.key),
                                    label: i18n.t(cat.nameKey),
                                    selected: _selectedCategoryKey == cat.key,
                                    onTap: () => _selectCategory(
                                      cat.key,
                                      visibleCategories,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Multi-Column Product Grid with Single-Layer GPU Wave Cascade
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      sidePad,
                      8,
                      sidePad,
                      (cartSummary.isEmpty ? 24.0 : 96.0) + navClearance,
                    ),
                    sliver: SliverFadeTransition(
                      opacity: _gridOpacity,
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          mainAxisExtent: cardHeight,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = filteredProducts[index];
                            final waveSlot = index < _waveSlots
                                ? index
                                : _waveSlots - 1;
                            return SlideTransition(
                              key: ValueKey<String>(product.id),
                              position: activeSlotSlides[waveSlot],
                              child: _MenuProductCard(
                                product: product,
                                isCompactGrid: cols <= 2,
                                onOpenDetails: () =>
                                    _showItemDetailSheet(context, product),
                              ),
                            );
                          },
                          childCount: filteredProducts.length,
                          addRepaintBoundaries: false,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Animated Floating Checkout Dock (lifts cleanly above EvaFloatingNavBar on mobile)
          Positioned(
            left: 16,
            right: 16,
            bottom:
                MediaQuery.sizeOf(context).width <
                    EvaFloatingNavBar.shellWideBreakpoint
                ? 84 + bottomSafe
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
                            shadowColor: Colors.black.withValues(alpha: 0.25),
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
                                        color: tokens.brandOnPrimary.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: EvaAnimatedCounterText(
                                        text: '${cartSummary.totalItemCount}',
                                        numericValue:
                                            cartSummary.totalItemCount,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: tokens.brandOnPrimary,
                                              fontWeight: FontWeight.w800,
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
                                                  color: tokens.brandOnPrimary,
                                                ),
                                          ),
                                          if (cartSummary.totalDiscount > 0)
                                            EvaAnimatedCounterText(
                                              text:
                                                  '-${i18n.formatPrice(cartSummary.totalDiscount)} ${i18n.t('bundle_savings_label')}',
                                              numericValue:
                                                  cartSummary.totalDiscount,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: tokens.brandOnPrimary
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    EvaAnimatedCounterText(
                                      text: i18n.formatPrice(
                                        cartSummary.finalTotal,
                                      ),
                                      numericValue: cartSummary.finalTotal,
                                      textAlign: TextAlign.end,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: tokens.brandOnPrimary,
                                            fontWeight: FontWeight.w800,
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
    );
  }

  void _showItemDetailSheet(BuildContext context, ProductItem product) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (_) => _ItemDetailBottomSheet(productId: product.id),
    );
  }
}

class _SmartBundleCard extends ConsumerWidget {
  const _SmartBundleCard({super.key, required this.bundle});

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

    return RepaintBoundary(
      child: SizedBox(
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
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Cubic _chipCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final labelStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14))
            .copyWith(
              color: selected ? tokens.brandOnPrimary : tokens.textPrimary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            );

    return EvaPressable(
      pressedScale: 0.96,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: _chipCurve,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 15,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected ? tokens.brandPrimary : tokens.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tokens.brandPrimary : tokens.borderSubtle,
              width: tokens.borderWidth,
            ),
            boxShadow: selected && !tokens.isNight
                ? [
                    BoxShadow(
                      color: tokens.brandPrimary.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, dot) => Transform.scale(
                      scale: scale,
                      child: dot,
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tokens.brandOnPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: labelStyle,
                child: Text(label),
              ),
            ],
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

    return RepaintBoundary(
      child: EvaSurfaceCard(
        padding: EdgeInsets.all(isCompactGrid ? 9 : 11),
        borderRadius: 18,
        borderColor: qtyInCart > 0
            ? tokens.brandPrimary.withValues(alpha: 0.72)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: onOpenDetails,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: tokens.brandOnPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures:
                                              EvaThemeBuilder.tabularNums,
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
                      const Spacer(),
                      Text(
                        i18n.formatPrice(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: tokens.brandPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: isCompactGrid ? 14.5 : 15.5,
                              fontFeatures: EvaThemeBuilder.tabularNums,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            EvaQuantityStepper(
              quantity: qtyInCart,
              addLabel: i18n.t('add_button'),
              compact: true,
              fullWidth: true,
              disabled: product.isOutOfStock,
              maxReached:
                  !product.isUnlimited && qtyInCart >= product.quantity,
              onIncrement: () => cartNotifier.increment(product),
              onDecrement: () => cartNotifier.decrement(product.id),
            ),
          ],
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

    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomSafe),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
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
              ),
              const SizedBox(width: 12),
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const ValueKey('item_detail_cta_button'),
              onPressed: product.isOutOfStock
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      if (qtyInCart == 0) {
                        cartNotifier.increment(product);
                      }
                      Navigator.of(context).pop();
                    },
              child: Text(
                qtyInCart > 0
                    ? '${i18n.t('done_cta')} • ${i18n.formatPrice(product.price * qtyInCart)}'
                    : '${i18n.t('add_button')} • ${i18n.formatPrice(product.price)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
