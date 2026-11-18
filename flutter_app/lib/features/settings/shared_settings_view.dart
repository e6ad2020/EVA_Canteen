import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class SharedSettingsView extends ConsumerWidget {
  const SharedSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                      EvaReveal(
                        index: 3,
                        child: EvaSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const EvaBrandLogo(size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      i18n.t('about_project_title'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                i18n.t('about_project_credits'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: tokens.textSecondary),
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
            hintText: 'https://your-tunnel.trycloudflare.com',
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
