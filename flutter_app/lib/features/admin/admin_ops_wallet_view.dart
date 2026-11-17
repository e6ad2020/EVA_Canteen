import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';

import '../../core/localization/eva_i18n.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class AdminOpsWalletView extends ConsumerStatefulWidget {
  const AdminOpsWalletView({super.key});

  @override
  ConsumerState<AdminOpsWalletView> createState() => _AdminOpsWalletViewState();
}

class _AdminOpsWalletViewState extends ConsumerState<AdminOpsWalletView> {
  String _walletQuery = '';
  final _walletSearchCtrl = TextEditingController();
  late final TextEditingController _currEnCtrl;
  late final TextEditingController _currArCtrl;

  @override
  void initState() {
    super.initState();
    final i18n = ref.read(i18nProvider);
    _currEnCtrl = TextEditingController(
      text: i18n.rawForLang('currency_symbol', 'en').isNotEmpty
          ? i18n.rawForLang('currency_symbol', 'en')
          : 'L.E',
    );
    _currArCtrl = TextEditingController(
      text: i18n.rawForLang('currency_symbol', 'ar').isNotEmpty
          ? i18n.rawForLang('currency_symbol', 'ar')
          : 'ج.م',
    );

    Future.microtask(() {
      if (mounted) {
        ref.read(canteenStoreProvider.notifier).requestWallets();
      }
    });
  }

  @override
  void dispose() {
    _walletSearchCtrl.dispose();
    _currEnCtrl.dispose();
    _currArCtrl.dispose();
    super.dispose();
  }

  void _togglePaymentMethod(
    PaymentMethodsConfig current, {
    bool? cash,
    bool? card,
    bool? wallet,
  }) {
    final next = current.copyWith(cash: cash, card: card, wallet: wallet);
    if (next.enabledKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one payment method must remain enabled.'),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    ref.read(canteenStoreProvider.notifier).updatePaymentMethods(next);
  }

  Future<void> _openWalletAdjustDialog(
    BuildContext context, {
    required WalletUserSummary user,
    required String initialMode,
  }) async {
    final i18n = ref.read(i18nProvider);
    String mode = initialMode;
    final amountCtrl = TextEditingController(text: '50');
    final reasonCtrl = TextEditingController(
      text: initialMode == 'add'
          ? 'Cash top-up at canteen counter'
          : 'Manual balance adjustment',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(user.email),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i18n.t('wallet_balance_label')}: ${i18n.formatPrice(user.balance)}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'add',
                        label: Text(i18n.t('wallet_add')),
                      ),
                      ButtonSegment(
                        value: 'deduct',
                        label: Text(i18n.t('wallet_deduct')),
                      ),
                      ButtonSegment(
                        value: 'set',
                        label: Text(i18n.t('wallet_set')),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) =>
                        setDialogState(() => mode = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in const [20, 50, 100, 200])
                      ActionChip(
                        label: Text('$preset ${i18n.currencySymbol}'),
                        onPressed: () => amountCtrl.text = '$preset',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (${i18n.currencySymbol})',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.isRtl ? 'ملاحظة / السبب' : 'Reason / Note',
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
                final val = double.tryParse(amountCtrl.text.trim());
                if (val == null || val < 0) return;
                HapticFeedback.mediumImpact();
                ref.read(canteenStoreProvider.notifier).adjustStudentWallet(
                  email: user.email,
                  mode: mode,
                  amount: val,
                  reason: reasonCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(i18n.t('save_cta')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final i18n = ref.read(i18nProvider);
    final jsonText = ref
        .read(canteenStoreProvider.notifier)
        .exportCatalogConfigJson();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('catalog_backup_title')),
        content: SizedBox(
          width: 560,
          height: 340,
          child: TextField(
            controller: TextEditingController(text: jsonText),
            readOnly: true,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel_cta')),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonText));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Catalog JSON copied!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final i18n = ref.read(i18nProvider);
    final tokens = EvaTokens.of(context);
    final pasteCtrl = TextEditingController();
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(i18n.t('catalog_backup_title')),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.isRtl
                      ? 'الصق ملف JSON المصدّر سابقاً لاستبدال وتحديث الفئات والمنتجات:'
                      : 'Paste a previously exported catalog JSON payload to replace categories and products:',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 240,
                  child: TextField(
                    controller: pasteCtrl,
                    maxLines: null,
                    expands: true,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '{ "categories": [...], "products": [...] }',
                    ),
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: TextStyle(color: tokens.statusClosedFg)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(i18n.t('cancel_cta')),
            ),
            FilledButton.icon(
              onPressed: () {
                final ok = ref
                    .read(canteenStoreProvider.notifier)
                    .importCatalogConfigJson(pasteCtrl.text);
                if (!ok) {
                  setDialogState(
                    () => err =
                        'Invalid JSON schema (requires categories & products arrays).',
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catalog configuration imported!')),
                );
              },
              icon: const Icon(Icons.upload_file_rounded, size: 17),
              label: const Text('Import & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final store = ref.watch(canteenStoreProvider);
    final wallets = store.walletsSnapshot;

    final filteredUsers = wallets.users.where((u) {
      if (_walletQuery.trim().isEmpty) return true;
      return u.email.toLowerCase().contains(_walletQuery.trim().toLowerCase());
    }).toList(growable: false);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  i18n.t('admin_ops_tab'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh Wallets',
                onPressed: () =>
                    ref.read(canteenStoreProvider.notifier).requestWallets(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Storefront Open/Closed & Payment Methods
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 760;
                          final statusCard = _buildStorefrontCard(
                            context,
                            store,
                            i18n,
                            tokens,
                          );
                          final payCard = _buildPaymentMethodsCard(
                            context,
                            store.paymentMethods,
                            i18n,
                            tokens,
                          );
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: statusCard),
                                const SizedBox(width: 16),
                                Expanded(child: payCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              statusCard,
                              const SizedBox(height: 16),
                              payCard,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      // 2. Student Wallet Balances Desk (الرصيد)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: tokens.brandPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      i18n.t('wallet_desk_title'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  EvaStatusBadge(
                                    label: '${wallets.users.length} students',
                                    background: tokens.brandSoftBg,
                                    foreground: tokens.brandPrimary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _walletSearchCtrl,
                                onChanged: (v) =>
                                    setState(() => _walletQuery = v),
                                decoration: InputDecoration(
                                  hintText: i18n.isRtl
                                      ? 'ابحث بالبريد الإلكتروني للطالب...'
                                      : 'Search student by school email...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (filteredUsers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    i18n.isRtl
                                        ? 'لا يوجد طلاب مطابقون للبحث بعد.'
                                        : 'No registered student accounts match this filter yet.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                )
                              else
                                for (final u in filteredUsers)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: tokens.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 10,
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              EvaAvatar(
                                                profilePic: u.profilePic,
                                                radius: 19,
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    u.email,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                  Text(
                                                    '${u.orderCount} orders • Spent ${i18n.formatPrice(u.totalSpent)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: tokens.surfaceCard,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: tokens.borderSubtle,
                                                  ),
                                                ),
                                                child: Text(
                                                  i18n.formatPrice(u.balance),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: tokens
                                                            .statusDeliveredFg,
                                                        fontFeatures:
                                                            EvaThemeBuilder
                                                                .tabularNums,
                                                      ),
                                                ),
                                              ),
                                              FilledButton.tonal(
                                                onPressed: () =>
                                                    _openWalletAdjustDialog(
                                                      context,
                                                      user: u,
                                                      initialMode: 'add',
                                                    ),
                                                style: FilledButton.styleFrom(
                                                  minimumSize: const Size(
                                                    0,
                                                    38,
                                                  ),
                                                ),
                                                child: Text(
                                                  i18n.t('wallet_add'),
                                                ),
                                              ),
                                              OutlinedButton(
                                                onPressed: () =>
                                                    _openWalletAdjustDialog(
                                                      context,
                                                      user: u,
                                                      initialMode: 'deduct',
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(
                                                    0,
                                                    38,
                                                  ),
                                                ),
                                                child: Text(
                                                  i18n.t('wallet_deduct'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                              if (wallets.recentTransactions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Divider(color: tokens.borderSubtle),
                                const SizedBox(height: 10),
                                Text(
                                  i18n.isRtl
                                      ? 'آخر حركات المحفظة'
                                      : 'Recent Wallet Ledger',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                for (final tx
                                    in wallets.recentTransactions.take(8))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          tx.delta >= 0
                                              ? Icons.south_west_rounded
                                              : Icons.north_east_rounded,
                                          size: 15,
                                          color: tx.delta >= 0
                                              ? tokens.statusDeliveredFg
                                              : tokens.statusClosedFg,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${tx.email} — ${tx.reason}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'MM/dd HH:mm',
                                          ).format(tx.timestamp.toLocal()),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${tx.delta >= 0 ? "+" : ""}${i18n.formatPrice(tx.delta)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: tx.delta >= 0
                                                    ? tokens.statusDeliveredFg
                                                    : tokens.statusClosedFg,
                                                fontFeatures:
                                                    EvaThemeBuilder.tabularNums,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. Bilingual Currency & Catalog Backup
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.t('currency_settings_title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _currEnCtrl,
                                      textDirection: TextDirection.ltr,
                                      decoration: const InputDecoration(
                                        labelText: 'English Symbol (e.g. L.E)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _currArCtrl,
                                      textDirection: TextDirection.rtl,
                                      decoration: const InputDecoration(
                                        labelText: 'الرمز بالعربية (مثال: ج.م)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(canteenStoreProvider.notifier)
                                          .updateCurrency(
                                            enSymbol: _currEnCtrl.text,
                                            arSymbol: _currArCtrl.text,
                                          );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(i18n.t('save_cta')),
                                        ),
                                      );
                                    },
                                    child: Text(i18n.t('save_cta')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Divider(color: tokens.borderSubtle),
                              const SizedBox(height: 14),
                              Text(
                                i18n.t('catalog_backup_title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showExportDialog(context),
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Export Catalog JSON'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showImportDialog(context),
                                    icon: const Icon(
                                      Icons.upload_file_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Import Catalog JSON'),
                                  ),
                                ],
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
      ],
    );
  }

  Widget _buildStorefrontCard(
    BuildContext context,
    CanteenStoreState store,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.t('storefront_status_card'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(
                  value: store.isCanteenOpen,
                  onChanged: (val) {
                    HapticFeedback.mediumImpact();
                    ref.read(canteenStoreProvider.notifier).setCanteenOpen(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            Text(
              i18n.isRtl
                  ? 'عند الإغلاق، يمكن للطلاب تصفح القائمة والأسعار دون إرسال طلبات جديدة.'
                  : 'When closed, students can still browse the menu and prices while checkout stays paused.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard(
    BuildContext context,
    PaymentMethodsConfig methods,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.t('payment_controls_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(
                Icons.payments_outlined,
                color: tokens.brandPrimary,
              ),
              title: Text(i18n.t('payment_cash')),
              value: methods.cash,
              onChanged: (v) => _togglePaymentMethod(methods, cash: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(
                Icons.credit_card_rounded,
                color: tokens.brandPrimary,
              ),
              title: Text(i18n.t('payment_card')),
              value: methods.card,
              onChanged: (v) => _togglePaymentMethod(methods, card: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(
                Icons.account_balance_wallet_rounded,
                color: tokens.brandPrimary,
              ),
              title: Text(i18n.t('payment_wallet')),
              value: methods.wallet,
              onChanged: (v) => _togglePaymentMethod(methods, wallet: v),
            ),
          ],
        ),
      ),
    );
  }
}
