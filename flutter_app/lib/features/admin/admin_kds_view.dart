import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/eva_i18n.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class AdminKdsView extends ConsumerStatefulWidget {
  const AdminKdsView({super.key});

  @override
  ConsumerState<AdminKdsView> createState() => _AdminKdsViewState();
}

class _AdminKdsViewState extends ConsumerState<AdminKdsView> {
  bool _archiveMode = false;
  OrderStatus _mobileStageTab = OrderStatus.pending;
  OrderStatus? _archiveStatusFilter;
  DateTime? _archiveDateFilter;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_archiveMode) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesQuery(CanteenOrder order) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return order.pickupNumber.toLowerCase().contains(q) ||
        order.id.toLowerCase().contains(q) ||
        order.userEmail.toLowerCase().contains(q);
  }

  Future<void> _pickArchiveDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _archiveDateFilter ?? now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _archiveDateFilter = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final allOrders = store.adminOrders;

    final todayOrders = allOrders
        .where((o) => o.isToday && _matchesQuery(o))
        .toList(growable: false);

    // Oldest pending/preparing first (FIFO kitchen queue), newest delivered first
    final pendingToday = todayOrders
        .where((o) => o.status == OrderStatus.pending)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final preparingToday = todayOrders
        .where((o) => o.status == OrderStatus.preparing)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final deliveredToday = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final archiveOrders = allOrders.where((o) {
      if (!_matchesQuery(o)) return false;
      if (_archiveStatusFilter != null && o.status != _archiveStatusFilter) {
        return false;
      }
      if (_archiveDateFilter != null &&
          !o.isPlacedOnDate(_archiveDateFilter!)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isKanbanWide = constraints.maxWidth >= 960;
        final isCompactHeader = constraints.maxWidth < 680;

        final modeToggle = SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text(
                i18n.t('kds_today_toggle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.history_rounded, size: 16),
              label: Text(
                i18n.t('kds_archive_toggle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {_archiveMode},
          onSelectionChanged: (sel) {
            setState(() => _archiveMode = sel.first);
          },
        );

        final searchField = TextField(
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: i18n.t('kds_search_hint'),
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
        );

        return EvaFloatingHeaderScaffold(
          initialHeaderHeight: isKanbanWide ? 118.0 : 186.0,
          headerBuilder: (context, isScrolled) => EvaGlassBar(
            isScrolled: isScrolled,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('admin_kds_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(canteenStoreProvider.notifier)
                            .setCanteenOpen(!store.isCanteenOpen);
                      },
                      child: EvaStatusBadge(
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
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isCompactHeader) ...[
                  SizedBox(width: double.infinity, child: modeToggle),
                  const SizedBox(height: 10),
                  searchField,
                ] else
                  Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      modeToggle,
                    ],
                  ),
                if (_archiveMode) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickArchiveDate,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                          ),
                          label: Text(
                            _archiveDateFilter == null
                                ? (i18n.isRtl ? 'كل التواريخ' : 'All Dates')
                                : DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_archiveDateFilter!),
                          ),
                        ),
                        if (_archiveDateFilter != null)
                          IconButton(
                            tooltip: i18n.isRtl ? 'مسح التاريخ' : 'Clear date',
                            onPressed: () =>
                                setState(() => _archiveDateFilter = null),
                            icon: const Icon(Icons.filter_alt_off_rounded),
                          ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _archiveStatusFilter == null,
                          label: Text(i18n.t('all_categories')),
                          onSelected: (_) =>
                              setState(() => _archiveStatusFilter = null),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: _archiveStatusFilter == OrderStatus.pending,
                          label: Text(i18n.t('status_pending')),
                          onSelected: (_) => setState(
                            () => _archiveStatusFilter = OrderStatus.pending,
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected:
                              _archiveStatusFilter == OrderStatus.preparing,
                          label: Text(i18n.t('status_preparing')),
                          onSelected: (_) => setState(
                            () => _archiveStatusFilter = OrderStatus.preparing,
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected:
                              _archiveStatusFilter == OrderStatus.delivered,
                          label: Text(i18n.t('status_delivered')),
                          onSelected: (_) => setState(
                            () => _archiveStatusFilter = OrderStatus.delivered,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_archiveMode && !isKanbanWide) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<OrderStatus>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: OrderStatus.pending,
                          label: Text(
                            '${i18n.t('status_pending')} (${pendingToday.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButtonSegment(
                          value: OrderStatus.preparing,
                          label: Text(
                            '${i18n.t('status_preparing')} (${preparingToday.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButtonSegment(
                          value: OrderStatus.delivered,
                          label: Text(
                            '${i18n.t('status_delivered')} (${deliveredToday.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selected: {_mobileStageTab},
                      onSelectionChanged: (sel) {
                        setState(() => _mobileStageTab = sel.first);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          bodyBuilder: (context, topClearance, _) => _archiveMode
              ? _buildArchiveList(
                  context,
                  archiveOrders,
                  i18n,
                  tokens,
                  topClearance,
                )
              : isKanbanWide
              ? Padding(
                  padding: EdgeInsets.fromLTRB(16, topClearance + 8, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _KdsStageColumn(
                          title: i18n.t('status_pending'),
                          count: pendingToday.length,
                          headerBg: tokens.statusPendingBg,
                          headerFg: tokens.statusPendingFg,
                          icon: Icons.schedule_rounded,
                          orders: pendingToday,
                          now: _now,
                          emptyLabel: i18n.t('kds_empty_column'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _KdsStageColumn(
                          title: i18n.t('status_preparing'),
                          count: preparingToday.length,
                          headerBg: tokens.statusPreparingBg,
                          headerFg: tokens.statusPreparingFg,
                          icon: Icons.soup_kitchen_rounded,
                          orders: preparingToday,
                          now: _now,
                          emptyLabel: i18n.t('kds_empty_column'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _KdsStageColumn(
                          title: i18n.t('status_delivered'),
                          count: deliveredToday.length,
                          headerBg: tokens.statusDeliveredBg,
                          headerFg: tokens.statusDeliveredFg,
                          icon: Icons.check_circle_rounded,
                          orders: deliveredToday,
                          now: _now,
                          emptyLabel: i18n.t('kds_empty_column'),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildMobileStageList(
                  switch (_mobileStageTab) {
                    OrderStatus.pending => pendingToday,
                    OrderStatus.preparing => preparingToday,
                    OrderStatus.delivered => deliveredToday,
                  },
                  i18n,
                  tokens,
                  topClearance,
                ),
        );
      },
    );
  }

  Widget _buildMobileStageList(
    List<CanteenOrder> orders,
    EvaTranslator i18n,
    EvaTokens tokens,
    double topClearance,
  ) {
    final navClearance = EvaFloatingNavBar.bottomClearance(context);
    if (orders.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topClearance, bottom: navClearance),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 48,
                color: tokens.textSecondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 10),
              Text(
                i18n.t('kds_empty_column'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        topClearance + 8,
        16,
        20 + navClearance,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) =>
          _KdsTicketCard(order: orders[idx], now: _now, showFullDate: false),
    );
  }

  Widget _buildArchiveList(
    BuildContext context,
    List<CanteenOrder> orders,
    EvaTranslator i18n,
    EvaTokens tokens,
    double topClearance,
  ) {
    final navClearance = EvaFloatingNavBar.bottomClearance(context);
    if (orders.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topClearance, bottom: navClearance),
        child: Center(
          child: Text(
            i18n.t('no_orders_yet'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        20,
        topClearance + 10,
        20,
        24 + navClearance,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: _KdsTicketCard(
            order: orders[idx],
            now: _now,
            showFullDate: true,
          ),
        ),
      ),
    );
  }
}

class _KdsStageColumn extends StatelessWidget {
  const _KdsStageColumn({
    required this.title,
    required this.count,
    required this.headerBg,
    required this.headerFg,
    required this.icon,
    required this.orders,
    required this.now,
    required this.emptyLabel,
  });

  final String title;
  final int count;
  final Color headerBg;
  final Color headerFg;
  final IconData icon;
  final List<CanteenOrder> orders;
  final DateTime now;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: headerFg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: headerFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: headerFg.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: headerFg,
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) => _KdsTicketCard(
                      order: orders[idx],
                      now: now,
                      showFullDate: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KdsTicketCard extends ConsumerWidget {
  const _KdsTicketCard({
    required this.order,
    required this.now,
    required this.showFullDate,
  });

  final CanteenOrder order;
  final DateTime now;
  final bool showFullDate;

  String _formatElapsed(Duration diff) {
    final safe = diff.isNegative ? Duration.zero : diff;
    final mins = safe.inMinutes;
    final secs = safe.inSeconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remMins = mins % 60;
      return '${hrs}h ${remMins.toString().padLeft(2, '0')}m';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _paymentLabel(EvaTranslator i18n, String method) {
    return switch (method) {
      'card' => i18n.t('payment_card'),
      'wallet' => i18n.t('payment_wallet'),
      _ => i18n.t('payment_cash'),
    };
  }

  IconData _paymentIcon(String method) {
    return switch (method) {
      'card' => Icons.credit_card_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      _ => Icons.payments_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final notifier = ref.read(canteenStoreProvider.notifier);

    final elapsed = now.difference(order.timestamp);
    final isOverdue =
        order.status != OrderStatus.delivered && elapsed.inMinutes >= 5;
    final timeFormatted = showFullDate
        ? DateFormat('yyyy-MM-dd • HH:mm').format(order.timestamp.toLocal())
        : DateFormat('HH:mm').format(order.timestamp.toLocal());

    return EvaSurfaceCard(
      borderRadius: 14,
      borderColor: isOverdue ? tokens.accentAppetite : tokens.borderSubtle,
      borderWidth: isOverdue ? 1.8 : tokens.borderWidth,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Ticket Header: #PickupNumber + Time + Live Elapsed Clock + Overflow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.pickupNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: tokens.brandPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    timeFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: EvaThemeBuilder.tabularNums,
                    ),
                  ),
                ),
                if (!showFullDate && order.status != OrderStatus.delivered)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? tokens.statusClosedBg
                          : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: isOverdue
                              ? tokens.statusClosedFg
                              : tokens.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatElapsed(elapsed),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isOverdue
                                    ? tokens.statusClosedFg
                                    : tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontFeatures: EvaThemeBuilder.tabularNums,
                              ),
                        ),
                      ],
                    ),
                  )
                else if (showFullDate)
                  EvaStatusBadge.forOrderStatus(
                    context: context,
                    status: order.status,
                    label: switch (order.status) {
                      OrderStatus.pending => i18n.t('status_pending'),
                      OrderStatus.preparing => i18n.t('status_preparing'),
                      OrderStatus.delivered => i18n.t('status_delivered'),
                    },
                  ),
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Change stage',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                  onSelected: (next) {
                    HapticFeedback.selectionClick();
                    notifier.updateOrderStatus(order.id, next);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: OrderStatus.pending,
                      child: Text(i18n.t('status_pending')),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.preparing,
                      child: Text(i18n.t('status_preparing')),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.delivered,
                      child: Text(i18n.t('status_delivered')),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Customer Identity & Payment Method
            Row(
              children: [
                EvaAvatar(profilePic: order.userProfilePic, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _paymentIcon(order.paymentMethod),
                        size: 13,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _paymentLabel(i18n, order.paymentMethod),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: tokens.borderSubtle),
            ),

            // Inline Ticket Items (No popup needed!)
            for (final line in order.regularItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.brandSoftBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${line.quantity}×',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: tokens.brandPrimary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: EvaThemeBuilder.tabularNums,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i18n.t(line.nameKey),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      i18n.formatPrice(line.price * line.quantity),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),

            for (final disc in order.discountItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 13,
                      color: tokens.statusDeliveredFg,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i18n.t(disc.nameKey),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.statusDeliveredFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      i18n.formatPrice(disc.price),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.statusDeliveredFg,
                        fontWeight: FontWeight.w700,
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Footer: Total & 1-Tap Stage Advance CTA
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t('total_label'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      i18n.formatPrice(order.totalAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: switch (order.status) {
                    OrderStatus.pending => FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.updateOrderStatus(
                          order.id,
                          OrderStatus.preparing,
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 17),
                      label: Text(
                        i18n.t('kds_start_preparing'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OrderStatus.preparing => FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        notifier.updateOrderStatus(
                          order.id,
                          OrderStatus.delivered,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.statusDeliveredFg,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text(
                        i18n.t('kds_mark_delivered'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OrderStatus.delivered => OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        notifier.updateOrderStatus(
                          order.id,
                          OrderStatus.pending,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 15),
                      label: Text(
                        i18n.t('kds_reopen_pending'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  },
                ),
              ],
            ),
          ],
        ),
    );
  }
}
