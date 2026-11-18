import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/canteen_providers.dart';
import '../../design_system/eva_theme.dart';
import '../../design_system/widgets/eva_widgets.dart';

class WelcomeAuthScreen extends ConsumerStatefulWidget {
  const WelcomeAuthScreen({super.key, this.initialAdminMode = false});

  final bool initialAdminMode;

  @override
  ConsumerState<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends ConsumerState<WelcomeAuthScreen> {
  late bool _isAdminMode = widget.initialAdminMode;
  bool _isRegister = false;
  bool _obscurePassword = true;
  String _selectedPic = 'pic2';
  String? _errorText;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorText = null);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      setState(() => _errorText = 'Please enter a valid email and password.');
      return;
    }

    final notifier = ref.read(canteenStoreProvider.notifier);
    String? err;

    if (_isAdminMode) {
      err = await notifier.loginAdmin(email: email, password: password);
      if (!mounted) return;
      if (err == null) {
        context.go('/admin/kds');
        return;
      }
    } else if (_isRegister) {
      if (password != _confirmCtrl.text) {
        setState(() => _errorText = 'Passwords do not match.');
        return;
      }
      if (password.length < 4) {
        setState(
          () => _errorText = 'Password should be at least 4 characters.',
        );
        return;
      }
      err = await notifier.registerStudent(
        email: email,
        password: password,
        profilePic: _selectedPic,
      );
      if (!mounted) return;
      if (err == null) {
        context.go('/menu');
        return;
      }
    } else {
      err = await notifier.loginStudent(email: email, password: password);
      if (!mounted) return;
      if (err == null) {
        context.go('/menu');
        return;
      }
    }

    setState(() => _errorText = err);
  }

  void _enterGuestMenu() {
    HapticFeedback.selectionClick();
    ref.read(canteenStoreProvider.notifier).enterBrowseGuestMode();
    context.go('/menu');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final isOpen = ref.watch(
      canteenStoreProvider.select((s) => s.isCanteenOpen),
    );
    final busy = ref.watch(canteenStoreProvider.select((s) => s.authBusy));

    return Scaffold(
      body: EvaScaffoldBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ConnectionStatusBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final isWide = viewport.maxWidth >= 768;
                    final horizontalPad = viewport.maxWidth < 380 ? 14.0 : 20.0;

                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPad,
                        vertical: isWide ? 28 : 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            viewport.maxHeight - (isWide ? 56 : 32),
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Floating minimal utility pills (NO top bar, NO border, NO blur)
                                EvaReveal(
                                  index: 0,
                                  offsetY: 6,
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: EvaStatusBadge(
                                          label: isOpen
                                              ? i18n.t('canteen_open_badge')
                                              : i18n.t('canteen_closed_badge'),
                                          background: isOpen
                                              ? tokens.statusDeliveredBg
                                              : tokens.statusClosedBg,
                                          foreground: isOpen
                                              ? tokens.statusDeliveredFg
                                              : tokens.statusClosedFg,
                                          pulsing: isOpen,
                                        ),
                                      ),
                                      const Spacer(),
                                      const LanguageQuickToggle(),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isWide ? 24 : 18),

                                // Simple centered Brand Logo + Name underneath
                                EvaReveal(
                                  index: 1,
                                  child: _SimpleBrandHeader(
                                    canteenName: i18n.t('canteen_name'),
                                    tokens: tokens,
                                    isWide: isWide,
                                  ),
                                ),
                                SizedBox(height: isWide ? 24 : 20),

                                // Centered Auth Card
                                EvaReveal(
                                  index: 2,
                                  child: _buildAuthColumn(
                                    context,
                                    tokens,
                                    i18n.t,
                                    busy,
                                    isWide: isWide,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthColumn(
    BuildContext context,
    EvaTokens tokens,
    String Function(String, [Map<String, String>?]) t,
    bool busy, {
    required bool isWide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvaSurfaceCard(
          borderRadius: 24,
          backgroundColor: tokens.surfaceElevated,
          padding: EdgeInsets.all(isWide ? 28 : 20),
          child: AutofillGroup(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isAdminMode) ...[
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.brandSoftBg,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: tokens.brandPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('admin_portal_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t('admin_signin_subtitle'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      _isRegister
                          ? t('auth_create_title')
                          : t('auth_welcome_back'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegister
                          ? t('auth_register_sub')
                          : t('auth_signin_sub'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tokens.borderSubtle.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeTabButton(
                              label: t('sign_in_tab'),
                              selected: !_isRegister,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isRegister = false;
                                  _errorText = null;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _ModeTabButton(
                              label: t('register_tab'),
                              selected: _isRegister,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isRegister = true;
                                  _errorText = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  if (!_isAdminMode && _isRegister) ...[
                    Text(
                      t('choose_avatar_label'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _AvatarChoiceTile(
                              picKey: 'pic${i + 1}',
                              selected: _selectedPic == 'pic${i + 1}',
                              tokens: tokens,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedPic = 'pic${i + 1}');
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    t('email_label'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: _isAdminMode
                          ? 'admin@canteen.app'
                          : t('email_hint'),
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('password_label'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    autofillHints: [
                      _isRegister
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: !_isAdminMode && _isRegister
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isRegister || _isAdminMode) _submit();
                    },
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 19,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ),

                  if (!_isAdminMode && _isRegister) ...[
                    const SizedBox(height: 14),
                    Text(
                      t('confirm_password_label'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(
                          Icons.verified_user_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ],

                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.statusClosedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tokens.statusClosedFg.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: tokens.statusClosedFg,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: tokens.statusClosedFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  EvaPressable(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: tokens.brandOnPrimary,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isAdminMode
                                          ? t('sign_in_tab')
                                          : (_isRegister
                                                ? t('register_cta')
                                                : t('login_cta')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  if (!_isAdminMode) ...[
                    const SizedBox(height: 10),
                    EvaPressable(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : _enterGuestMenu,
                          icon: const Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18,
                          ),
                          label: Text(
                            t('browse_menu_guest'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isAdminMode = !_isAdminMode;
                _errorText = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: tokens.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: Icon(
              _isAdminMode
                  ? Icons.person_outline_rounded
                  : Icons.storefront_outlined,
              size: 17,
            ),
            label: Text(
              _isAdminMode
                  ? t('customer_portal_button')
                  : t('staff_portal_button'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Clean, minimal brand lockup: just the centered logo with the canteen name
/// directly underneath it.
class _SimpleBrandHeader extends StatelessWidget {
  const _SimpleBrandHeader({
    required this.canteenName,
    required this.tokens,
    required this.isWide,
  });

  final String canteenName;
  final EvaTokens tokens;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EvaBrandLogo(size: isWide ? 84 : 74),
        const SizedBox(height: 12),
        Text(
          canteenName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: tokens.textPrimary,
            fontSize: isWide ? 28 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            shadows: (!tokens.isNight && tokens.isLiquidGlass)
                ? const [
                    Shadow(color: Color(0xE6FFFFFF), blurRadius: 10),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

class _AvatarChoiceTile extends StatelessWidget {
  const _AvatarChoiceTile({
    required this.picKey,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String picKey;
  final bool selected;
  final EvaTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSoftBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tokens.brandPrimary : tokens.borderSubtle,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              EvaAvatar(profilePic: picKey, radius: 22, isSelected: selected),
              if (selected)
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: tokens.brandPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tokens.surfaceElevated,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: tokens.brandOnPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: tokens.borderSubtle) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? tokens.textPrimary : tokens.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
