import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/eva_i18n.dart';
import '../../core/media/eva_image_cache.dart';
import '../../core/models/domain_models.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class SharedSettingsView extends ConsumerStatefulWidget {
  const SharedSettingsView({super.key});

  @override
  ConsumerState<SharedSettingsView> createState() => _SharedSettingsViewState();
}

class _SharedSettingsViewState extends ConsumerState<SharedSettingsView> {
  static const String _kProjectTeamImageUrl =
      'https://i.postimg.cc/jdTC3Sq2/Whats-App-Image-2024-12-10-at-13-31-40-da111f53.jpg';
  static const double _kProjectTeamImageWidth = 280.0;
  static const double _kProjectTeamImageBorder = 1.8;
  static const double _kProjectTeamImageInnerWidth =
      _kProjectTeamImageWidth - (_kProjectTeamImageBorder * 2);

  bool _didPrecacheProjectImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheProjectImage) {
      _didPrecacheProjectImage = true;
      unawaited(
        EvaImageCache.precacheUrl(
          context,
          url: _kProjectTeamImageUrl,
          logicalWidth: _kProjectTeamImageInnerWidth,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final prefsNotifier = ref.read(appPreferencesProvider.notifier);
    final user = ref.watch(canteenStoreProvider.select((s) => s.currentUser));
    final socket = ref.watch(socketClientProvider);
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);

    return EvaFloatingHeaderScaffold(
      initialHeaderHeight: 66.0,
      headerBuilder: (context, isScrolled) => EvaGlassBar(
        isScrolled: isScrolled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                i18n.t('nav_settings'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
      bodyBuilder: (context, topClearance, _) => ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topClearance + 8,
          16,
          32 + EvaFloatingNavBar.bottomClearance(context),
        ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (user != null) ...[
                        EvaReveal(
                          index: 0,
                          child: EvaSurfaceCard(
                            padding: const EdgeInsets.all(18),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 380;
                                final signOutBtn = OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(canteenStoreProvider.notifier)
                                        .logout();
                                    context.go('/welcome');
                                  },
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    user.role == UserRole.guest
                                        ? i18n.t('sign_in_tab')
                                        : i18n.t('sign_out_cta'),
                                  ),
                                );

                                final userMeta = Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.role == UserRole.guest
                                            ? i18n.t('guest_mode_short')
                                            : user.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        switch (user.role) {
                                          UserRole.admin => i18n.t(
                                            'admin_portal_title',
                                          ),
                                          UserRole.student =>
                                            '${i18n.t('wallet_balance_label')}: ${i18n.formatPrice(user.balance)}',
                                          UserRole.guest => i18n.t(
                                            'browse_menu_guest',
                                          ),
                                        },
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                );

                                if (compact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          EvaAvatar(
                                            profilePic: user.profilePic,
                                            radius: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          userMeta,
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      signOutBtn,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    EvaAvatar(
                                      profilePic: user.profilePic,
                                      radius: 24,
                                    ),
                                    const SizedBox(width: 14),
                                    userMeta,
                                    const SizedBox(width: 10),
                                    signOutBtn,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      EvaReveal(
                        index: 1,
                        child: EvaSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.t('appearance_title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SurfaceModeTile(
                                      icon: Icons.wb_sunny_outlined,
                                      label: i18n.t('mode_daylight'),
                                      selected:
                                          prefs.surfaceMode ==
                                          EvaSurfaceMode.daylight,
                                      onTap: () => prefsNotifier.setSurfaceMode(
                                        EvaSurfaceMode.daylight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SurfaceModeTile(
                                      icon: Icons.dark_mode_outlined,
                                      label: i18n.t('mode_night'),
                                      selected:
                                          prefs.surfaceMode ==
                                          EvaSurfaceMode.nightShift,
                                      onTap: () => prefsNotifier.setSurfaceMode(
                                        EvaSurfaceMode.nightShift,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final preset in EvaAccentPreset.values)
                                    _AccentSwatchChip(
                                      preset: preset,
                                      label: i18n.t(preset.i18nKey),
                                      isNight: tokens.isNight,
                                      selected: prefs.accentPreset == preset,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        prefsNotifier.setAccentPreset(preset);
                                      },
                                    ),
                                ],
                              ),
                              if (!tokens.isLiquidGlass) ...[
                                const SizedBox(height: 14),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: prefs.showDoodlePattern,
                                  onChanged: prefsNotifier.setShowDoodlePattern,
                                  title: Text(i18n.t('doodle_pattern_toggle')),
                                ),
                              ],
                              const Divider(height: 28),
                              Text(
                                i18n.t('navbar_behavior_title'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                i18n.t('navbar_behavior_sub'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final behavior
                                      in EvaNavBarBehavior.values)
                                    ChoiceChip(
                                      selected:
                                          prefs.navBarBehavior == behavior,
                                      label: Text(i18n.t(behavior.i18nKey)),
                                      onSelected: (_) {
                                        HapticFeedback.selectionClick();
                                        prefsNotifier.setNavBarBehavior(
                                          behavior,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      EvaReveal(
                        index: 2,
                        child: EvaSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.t('language_label'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          prefsNotifier.setLanguage('en'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            prefs.locale.languageCode == 'en'
                                            ? tokens.brandSoftBg
                                            : null,
                                        side: BorderSide(
                                          color:
                                              prefs.locale.languageCode == 'en'
                                              ? tokens.brandPrimary
                                              : tokens.borderSubtle,
                                          width:
                                              prefs.locale.languageCode == 'en'
                                              ? 1.8
                                              : tokens.borderWidth,
                                        ),
                                      ),
                                      child: const Text('English'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          prefsNotifier.setLanguage('ar'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            prefs.locale.languageCode == 'ar'
                                            ? tokens.brandSoftBg
                                            : null,
                                        side: BorderSide(
                                          color:
                                              prefs.locale.languageCode == 'ar'
                                              ? tokens.brandPrimary
                                              : tokens.borderSubtle,
                                          width:
                                              prefs.locale.languageCode == 'ar'
                                              ? 1.8
                                              : tokens.borderWidth,
                                        ),
                                      ),
                                      child: const Text('العربية'),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 28),
                              Row(
                                children: [
                                  Icon(
                                    Icons.dns_outlined,
                                    color: tokens.brandPrimary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i18n.t('server_connection_label'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          socket.httpBaseUrl,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: () => _showServerDialog(
                                      context,
                                      ref,
                                      prefs.customServerOrigin ?? '',
                                    ),
                                    child: Text(i18n.t('edit_button')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (user == null || user.isStudent) ...[
                        const EvaReveal(
                          index: 3,
                          child: _OrderReadyAlertsCard(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      EvaReveal(
                        index: 4,
                        child: EvaSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const EvaBrandLogo(size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      i18n.t('canteen_name'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('about_project_button'),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showAboutProjectDialog(
                                      context,
                                      i18n,
                                      tokens,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: tokens.brandSoftBg,
                                    foregroundColor: tokens.textPrimary,
                                    side: BorderSide(
                                      color: tokens.borderSubtle,
                                      width: tokens.borderWidth,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.info_outline_rounded,
                                    size: 19,
                                    color: tokens.brandPrimary,
                                  ),
                                  label: Text(
                                    i18n.t('about_project_button'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Widget _buildPopupTransition(
    BuildContext ctx,
    Animation<double> animation,
    Animation<double> _,
    Widget child,
  ) {
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final scale = curved.drive(Tween<double>(begin: 0.94, end: 1.0));
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: scale, child: child),
          ),
        ),
      ),
    );
  }

  void _showAboutProjectDialog(
    BuildContext context,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: i18n.t('about_project_title'),
      barrierColor: Colors.black.withValues(alpha: 0.56),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: _buildPopupTransition,
      pageBuilder: (dialogCtx, _, _) {
        final theme = Theme.of(dialogCtx);
        return RepaintBoundary(
          key: const ValueKey('about_project_dialog_boundary'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: tokens.surfaceElevated,
              surfaceTintColor: Colors.transparent,
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: tokens.borderSubtle,
                  width: tokens.borderWidth,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      i18n.t('about_project_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: _kProjectTeamImageWidth,
                        height: 176,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tokens.borderSubtle,
                              width: _kProjectTeamImageBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: tokens.isNight ? 0.35 : 0.12,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              _kProjectTeamImageBorder,
                            ),
                            child: ClipRRect(
                              key: const ValueKey('about_project_photo_clip'),
                              borderRadius: BorderRadius.circular(
                                14 - _kProjectTeamImageBorder,
                              ),
                              child: EvaCachedImage(
                                url: _kProjectTeamImageUrl,
                                fit: BoxFit.cover,
                                placeholderBuilder: (_) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        tokens.brandSoftBg,
                                        tokens.surfaceSubtle,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.groups_rounded,
                                      size: 40,
                                      color: tokens.brandPrimary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                ),
                                errorBuilder: (_) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        tokens.brandSoftBg,
                                        tokens.surfaceSubtle,
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const EvaBrandLogo(size: 60),
                                        const SizedBox(height: 10),
                                        Text(
                                          i18n.t('about_project_school_badge'),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: tokens.textSecondary,
                                                fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 18),
                    Text(
                      i18n.t('about_project_description'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textPrimary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 52),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 120),
                              child: FilledButton(
                                key: const ValueKey(
                                  'about_project_close_button',
                                ),
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text(i18n.t('ok_button')),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Tooltip(
                              message: i18n.t('copyright_title'),
                              child: InkWell(
                                key: const ValueKey('copyright_info_button'),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(dialogCtx);
                                  _showCopyrightDialog(context, i18n, tokens);
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceSubtle,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tokens.borderSubtle,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.copyright_rounded,
                                    size: 19,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
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
        );
      },
    );
  }

  void _showCopyrightDialog(
    BuildContext context,
    EvaTranslator i18n,
    EvaTokens tokens,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: i18n.t('copyright_title'),
      barrierColor: Colors.black.withValues(alpha: 0.56),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: _buildPopupTransition,
      pageBuilder: (dialogCtx, _, _) {
        final theme = Theme.of(dialogCtx);
        return RepaintBoundary(
          key: const ValueKey('copyright_dialog_boundary'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: tokens.surfaceElevated,
              surfaceTintColor: Colors.transparent,
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: tokens.borderSubtle,
                  width: tokens.borderWidth,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      i18n.t('copyright_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CopyrightSectionHeading(
                              title: i18n.t('copyright_info_title'),
                              tokens: tokens,
                            ),
                            Text(
                              i18n.t('copyright_info_text'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _CopyrightSectionHeading(
                              title: i18n.t('license_info_title'),
                              tokens: tokens,
                            ),
                            Text(
                              i18n.t('license_info_text'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _CopyrightSectionHeading(
                              title: i18n.t('gpl_license_title'),
                              tokens: tokens,
                            ),
                            Text(
                              i18n.t('gpl_license_text_1'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              i18n.t('gpl_license_text_2'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              i18n.t('gpl_license_text_3'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 120),
                        child: FilledButton(
                          key: const ValueKey('copyright_close_button'),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(i18n.t('ok_button')),
                        ),
                      ),
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

  void _showServerDialog(
    BuildContext context,
    WidgetRef ref,
    String initialValue,
  ) {
    final ctrl = TextEditingController(text: initialValue);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Endpoint'),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'https://eva-canteen-backend.onrender.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(appPreferencesProvider.notifier)
                  .setCustomServerOrigin(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _CopyrightSectionHeading extends StatelessWidget {
  const _CopyrightSectionHeading({
    required this.title,
    required this.tokens,
  });

  final String title;
  final EvaTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _SurfaceModeTile extends StatelessWidget {
  const _SurfaceModeTile({
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.8 : tokens.borderWidth,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? tokens.brandPrimary : tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? tokens.brandPrimary : tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatchChip extends StatelessWidget {
  const _AccentSwatchChip({
    required this.preset,
    required this.label,
    required this.isNight,
    required this.selected,
    required this.onTap,
  });

  final EvaAccentPreset preset;
  final String label;
  final bool isNight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.8 : tokens.borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EvaThemeSwatch(preset: preset, isNight: isNight, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? tokens.brandPrimary : tokens.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderReadyAlertsCard extends ConsumerWidget {
  const _OrderReadyAlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);
    final notifState = ref.watch(notificationControllerProvider);
    final perm = notifState.permissionState;

    final (statusLabel, badgeBg, badgeFg, icon) = switch (perm) {
      PushPermissionState.authorized => (
        i18n.t('notifications_status_enabled'),
        tokens.statusDeliveredBg,
        tokens.statusDeliveredFg,
        Icons.notifications_active_rounded,
      ),
      PushPermissionState.permanentlyDenied => (
        i18n.t('notifications_status_denied'),
        tokens.statusClosedBg,
        tokens.statusClosedFg,
        Icons.notifications_off_outlined,
      ),
      PushPermissionState.unsupported => (
        i18n.t('notifications_status_unavailable'),
        tokens.surfaceSubtle,
        tokens.textSecondary,
        Icons.bolt_rounded,
      ),
      PushPermissionState.denied || PushPermissionState.unknown => (
        i18n.t('notifications_status_disabled'),
        tokens.brandSoftBg,
        tokens.brandPrimary,
        Icons.notifications_none_rounded,
      ),
    };

    final canRequest =
        perm == PushPermissionState.denied ||
        perm == PushPermissionState.unknown;

    return EvaSurfaceCard(
      key: const ValueKey('order_ready_alerts_card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeFg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t('order_ready_alerts_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i18n.t('order_ready_alerts_sub'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                key: const ValueKey('order_ready_alerts_status_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canRequest)
                FilledButton.tonalIcon(
                  key: const ValueKey('enable_order_alerts_button'),
                  onPressed: notifState.syncBusy
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(notificationControllerProvider.notifier)
                              .requestPermissionAndSync();
                        },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text(i18n.t('notifications_enable_cta')),
                ),
            ],
          ),
          if (perm == PushPermissionState.permanentlyDenied) ...[
            const SizedBox(height: 12),
            Text(
              i18n.t('notifications_denied_hint'),
              key: const ValueKey('order_ready_alerts_denied_hint'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

