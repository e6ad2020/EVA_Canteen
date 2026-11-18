import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/eva_i18n.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class AdminAnalyticsView extends ConsumerStatefulWidget {
  const AdminAnalyticsView({super.key});

  @override
  ConsumerState<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends ConsumerState<AdminAnalyticsView> {
  bool _showRevenueChart = false;
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = ref.read(canteenStoreProvider).analytics;
    _selectedMonth = existing?.selectedMonth ?? now.month;
    _selectedYear = existing?.selectedYear ?? now.year;

    Future.microtask(() {
      if (mounted) {
        ref
            .read(canteenStoreProvider.notifier)
            .requestAnalytics(month: _selectedMonth, year: _selectedYear);
      }
    });
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final snap = store.analytics;

    final years = <int>{
      DateTime.now().year,
      _selectedYear,
      ...?snap?.availableYears,
    }.toList()..sort((a, b) => b.compareTo(a));

    final lowStockLive = store.products
        .where((p) => !p.isArchived && (p.isOutOfStock || p.isLowStock))
        .toList(growable: false);

    return EvaFloatingHeaderScaffold(
      initialHeaderHeight: 118.0,
      headerBuilder: (context, isScrolled) => EvaGlassBar(
        isScrolled: isScrolled,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;

            final monthDropdown = DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              isExpanded: true,
              items: [
                for (int m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      DateFormat(
                        'MMMM',
                        i18n.langCode,
                      ).format(DateTime(2026, m, 1)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (m) {
                if (m == null) return;
                setState(() => _selectedMonth = m);
                ref
                    .read(canteenStoreProvider.notifier)
                    .requestAnalytics(month: m, year: _selectedYear);
              },
            );

            final yearDropdown = DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              isExpanded: true,
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (y) {
                if (y == null) return;
                setState(() => _selectedYear = y);
                ref
                    .read(canteenStoreProvider.notifier)
                    .requestAnalytics(month: _selectedMonth, year: y);
              },
            );

            final refreshBtn = IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref
                    .read(canteenStoreProvider.notifier)
                    .requestAnalytics(
                      month: _selectedMonth,
                      year: _selectedYear,
                    );
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i18n.t('admin_analytics_tab'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      refreshBtn,
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 3, child: monthDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: yearDropdown),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.t('admin_analytics_tab'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                SizedBox(width: 152, child: monthDropdown),
                const SizedBox(width: 10),
                SizedBox(width: 108, child: yearDropdown),
                const SizedBox(width: 10),
                refreshBtn,
              ],
            );
          },
        ),
      ),
      bodyBuilder: (context, topClearance, _) => snap == null
          ? Padding(
              padding: EdgeInsets.only(top: topClearance),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: tokens.brandPrimary),
                    const SizedBox(height: 12),
                    Text(
                      i18n.isRtl
                          ? 'جاري تحميل التحليلات...'
                          : 'Loading analytics...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                topClearance + 8,
                16,
                28 + EvaFloatingNavBar.bottomClearance(context),
              ),
              children: [
                    // 1. KPI Summary Strip
                    EvaReveal(
                      index: 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 820;
                          final isVeryNarrow = constraints.maxWidth < 380;
                          final cards = [
                            _KpiCard(
                              title: i18n.t('kpi_revenue'),
                              value: i18n.formatPrice(snap.totalRevenue),
                              icon: Icons.payments_rounded,
                              accent: tokens.statusDeliveredFg,
                              softBg: tokens.statusDeliveredBg,
                            ),
                            _KpiCard(
                              title: i18n.t('kpi_orders'),
                              value: '${snap.totalOrders}',
                              icon: Icons.receipt_long_rounded,
                              accent: tokens.brandPrimary,
                              softBg: tokens.brandSoftBg,
                            ),
                            _KpiCard(
                              title: i18n.t('kpi_aov'),
                              value: i18n.formatPrice(snap.avgOrderValue),
                              icon: Icons.trending_up_rounded,
                              accent: tokens.accentAppetite,
                              softBg: tokens.statusPendingBg,
                            ),
                          ];

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[1]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[2]),
                              ],
                            );
                          }
                          if (isVeryNarrow) {
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 10),
                                cards[1],
                                const SizedBox(height: 10),
                                cards[2],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: cards[1]),
                                  const SizedBox(width: 10),
                                  Expanded(child: cards[2]),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Payment Mix & Fulfillment Summary Bar
                    EvaReveal(
                      index: 1,
                      child: EvaSurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            EvaStatusBadge(
                              label:
                                  '${i18n.t('status_delivered')}: ${snap.ordersByStatus['delivered'] ?? 0}',
                              background: tokens.statusDeliveredBg,
                              foreground: tokens.statusDeliveredFg,
                              icon: Icons.check_circle_rounded,
                            ),
                            EvaStatusBadge(
                              label:
                                  '${i18n.t('status_preparing')}: ${snap.ordersByStatus['preparing'] ?? 0}',
                              background: tokens.statusPreparingBg,
                              foreground: tokens.statusPreparingFg,
                              icon: Icons.soup_kitchen_rounded,
                            ),
                            EvaStatusBadge(
                              label:
                                  '${i18n.t('status_pending')}: ${snap.ordersByStatus['pending'] ?? 0}',
                              background: tokens.statusPendingBg,
                              foreground: tokens.statusPendingFg,
                              icon: Icons.schedule_rounded,
                            ),
                            for (final entry
                                in snap.revenueByPaymentMethod.entries)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  entry.key == 'wallet'
                                      ? Icons.account_balance_wallet_rounded
                                      : (entry.key == 'card'
                                            ? Icons.credit_card_rounded
                                            : Icons.payments_outlined),
                                  size: 15,
                                  color: tokens.brandPrimary,
                                ),
                                label: Text(
                                  '${entry.key.toUpperCase()}: ${i18n.formatPrice(entry.value)}',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        fontFeatures:
                                            EvaThemeBuilder.tabularNums,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Interactive Daily Bar Chart (fl_chart)
                    EvaReveal(
                      index: 2,
                      child: EvaSurfaceCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _showRevenueChart
                                      ? i18n.t('chart_revenue_mode')
                                      : i18n.t('chart_orders_mode'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                SegmentedButton<bool>(
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment(
                                      value: false,
                                      label: Text(i18n.t('chart_orders_mode')),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text(i18n.t('chart_revenue_mode')),
                                    ),
                                  ],
                                  selected: {_showRevenueChart},
                                  onSelectionChanged: (s) => setState(
                                    () => _showRevenueChart = s.first,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 240,
                              child: _buildDailyBarChart(
                                context,
                                snap,
                                i18n,
                                tokens,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Sales Ranking & Low-Stock Watchlist
                    EvaReveal(
                      index: 3,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final twoCols = constraints.maxWidth >= 900;
                          final rankingCard = _buildSalesRankingCard(
                            context,
                            snap,
                            i18n,
                            tokens,
                          );
                          final lowStockCard = _buildLowStockCard(
                            context,
                            lowStockLive,
                            i18n,
                            tokens,
                          );

                          if (twoCols) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: rankingCard),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: lowStockCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              rankingCard,
                              const SizedBox(height: 14),
                              lowStockCard,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDailyBarChart(
    BuildContext context,
    AnalyticsSnapshot snap,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    final days = _daysInMonth(snap.selectedYear, snap.selectedMonth);
    double maxVal = 0;
    for (int d = 1; d <= days; d++) {
      final v = _showRevenueChart
          ? (snap.dailyRevenue[d] ?? 0)
          : (snap.dailyOrders[d] ?? 0).toDouble();
      if (v > maxVal) maxVal = v;
    }
    final ceiling = maxVal <= 0 ? 5.0 : (maxVal * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: ceiling,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: tokens.borderSubtle, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipColor: (_) => tokens.isNight
                ? const Color(0xFF283242)
                : const Color(0xFF121826),
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              final day = group.x;
              final formatted = _showRevenueChart
                  ? i18n.formatPrice(rod.toY)
                  : '${rod.toY.toInt()} orders';
              return BarTooltipItem(
                'Day $day\n$formatted',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day != 1 && day % 5 != 0 && day != days) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '$day',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int d = 1; d <= days; d++)
            BarChartGroupData(
              x: d,
              barRods: [
                BarChartRodData(
                  toY: _showRevenueChart
                      ? (snap.dailyRevenue[d] ?? 0)
                      : (snap.dailyOrders[d] ?? 0).toDouble(),
                  width: days > 28 ? 6.0 : 7.5,
                  color: _showRevenueChart
                      ? tokens.statusDeliveredFg
                      : tokens.brandPrimary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildSalesRankingCard(
    BuildContext context,
    AnalyticsSnapshot snap,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    final items = snap.itemSalesRanking;
    final topCount = items.isEmpty
        ? 1
        : math.max(1, items.map((e) => e.count).reduce(math.max));

    return EvaSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('top_products_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              i18n.t('no_orders_yet'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _RankingRow(
                rank: i + 1,
                item: items[i],
                ratio: items[i].count / topCount,
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildLowStockCard(
    BuildContext context,
    List<ProductItem> lowStock,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    return EvaSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: tokens.statusPendingFg,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.t('low_stock_watchlist'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (lowStock.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: tokens.statusDeliveredFg,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i18n.isRtl
                        ? 'جميع الأصناف متوفرة بكميات جيدة.'
                        : 'All active menu items are well stocked.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.statusDeliveredFg,
                    ),
                  ),
                ),
              ],
            )
          else
            for (final prod in lowStock)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: EvaProductImage(
                          imageUrl: prod.image,
                          borderRadius: 8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.t(prod.nameKey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              prod.isOutOfStock
                                  ? i18n.t('out_of_stock')
                                  : i18n.t('low_stock_left', {
                                      'count': '${prod.quantity}',
                                    }),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: prod.isOutOfStock
                                    ? tokens.statusClosedFg
                                    : tokens.statusPendingFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(canteenStoreProvider.notifier)
                              .quickUpdateProductStockOrCategory(
                                prod,
                                quantity: prod.quantity + 20,
                              );
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('+20'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.softBg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Color softBg;

  @override
  Widget build(BuildContext context) {
    return EvaSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: softBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFeatures: EvaThemeBuilder.tabularNums,
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

class _RankingRow extends ConsumerWidget {
  const _RankingRow({
    required this.rank,
    required this.item,
    required this.ratio,
  });

  final int rank;
  final SalesRankItem item;
  final double ratio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank <= 3 ? tokens.brandSoftBg : tokens.surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: rank <= 3 ? tokens.brandPrimary : tokens.textSecondary,
              fontWeight: FontWeight.w700,
              fontFeatures: EvaThemeBuilder.tabularNums,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          height: 40,
          child: EvaProductImage(imageUrl: item.image, borderRadius: 8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.t(item.nameKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${item.count} • ${i18n.formatPrice(item.revenue)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: tokens.surfaceSubtle,
                  color: tokens.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
