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
    final store = ref.watch(canteenStoreProvider);
    final socket = ref.watch(socketClientProvider);
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);
    final user = store.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          EvaAvatar(profilePic: user.profilePic, radius: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.titleMedium,
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
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(canteenStoreProvider.notifier).logout();
                              context.go('/welcome');
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(
                              user.role == UserRole.guest
                                  ? i18n.t('sign_in_tab')
                                  : i18n.t('sign_out_cta'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.t('appearance_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SurfaceModeTile(
                                icon: Icons.wb_sunny_outlined,
                                label: i18n.t('mode_daylight'),
                                selected:
                                    prefs.surfaceMode == EvaSurfaceMode.daylight,
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
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final preset in EvaAccentPreset.values)
                              _AccentSwatchChip(
                                preset: preset,
                                isNight: tokens.isNight,
                                selected: prefs.accentPreset == preset,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  prefsNotifier.setAccentPreset(preset);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: prefs.showDoodlePattern,
                          onChanged: prefsNotifier.setShowDoodlePattern,
                          title: Text(i18n.t('doodle_pattern_toggle')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
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
                                    color: prefs.locale.languageCode == 'en'
                                        ? tokens.brandPrimary
                                        : tokens.borderSubtle,
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
                                    color: prefs.locale.languageCode == 'ar'
                                        ? tokens.brandPrimary
                                        : tokens.borderSubtle,
                                  ),
                                ),
                                child: const Text('العربية'),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.dns_outlined,
                            color: tokens.brandPrimary,
                          ),
                          title: Text(i18n.t('server_connection_label')),
                          subtitle: Text(socket.httpBaseUrl),
                          trailing: OutlinedButton(
                            onPressed: () => _showServerDialog(
                              context,
                              ref,
                              prefs.customServerOrigin ?? '',
                            ),
                            child: Text(i18n.t('edit_button')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const EvaBrandLogo(size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                i18n.t('about_project_title'),
                                style: Theme.of(context).textTheme.titleLarge,
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
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:8080 (leave blank for auto)',
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.8 : 1,
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
    required this.isNight,
    required this.selected,
    required this.onTap,
  });

  final EvaAccentPreset preset;
  final bool isNight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final swatch = isNight ? preset.nightColor : preset.daylightColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(preset.label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
