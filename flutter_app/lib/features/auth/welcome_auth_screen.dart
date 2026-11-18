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

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            isWide ? 32 : 28,
                            horizontalPad,
                            isWide ? 24 : 18,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                viewport.maxHeight - (isWide ? 56 : 46),
                              ),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Hero Brand Logo (already includes EVA Canteen lettering)
                                    EvaReveal(
                                      index: 1,
                                      child: _SimpleBrandHeader(isWide: isWide),
                                    ),
                                    SizedBox(height: isWide ? 14 : 10),

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
                        ),

                        // Top-left live Open/Closed status badge
                        Positioned(
                          key: const ValueKey('welcome_status_top_left'),
                          top: 8,
                          left: 16,
                          child: EvaReveal(
                            index: 0,
                            offsetY: 6,
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
                        ),
                      ],
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

  Widget _buildAnimatedHeaderContent(
    BuildContext context,
    EvaTokens tokens,
    String Function(String, [Map<String, String>?]) t,
  ) {
    if (_isAdminMode) {
      return Column(
        key: const ValueKey('auth_header_admin'),
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(height: 10),
          Text(
            t('admin_portal_title'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 3),
          Text(
            t('admin_signin_subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return Column(
      key: ValueKey('auth_header_student_$_isRegister'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _isRegister ? t('auth_create_title') : t('auth_welcome_back'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          _isRegister ? t('auth_register_sub') : t('auth_signin_sub'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildAuthColumn(
    BuildContext context,
    EvaTokens tokens,
    String Function(String, [Map<String, String>?]) t,
    bool busy, {
    required bool isWide,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final headerSwitchDuration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 230);
    final sectionAnimDuration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final showRegisterFields = !_isAdminMode && _isRegister;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvaSurfaceCard(
          borderRadius: 24,
          backgroundColor: tokens.surfaceElevated,
          padding: EdgeInsets.all(isWide ? 28 : 20),
          child: AutofillGroup(
            child: AnimatedSize(
              duration: sectionAnimDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: headerSwitchDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.center,
                      children: [...previousChildren, ?currentChild],
                    ),
                    transitionBuilder: (child, anim) {
                      final isIncomingAdmin =
                          child.key == const ValueKey('auth_header_admin');
                      final isIncomingRegister =
                          child.key == const ValueKey('auth_header_student_true');
                      final forward = _isAdminMode
                          ? isIncomingAdmin
                          : (_isRegister ? isIncomingRegister : !isIncomingRegister);
                      final dir = (forward ? 1.0 : -1.0) * (isRtl ? -1.0 : 1.0);
                      final isIncoming = anim.status != AnimationStatus.reverse;
                      final offsetTween = Tween<Offset>(
                        begin: Offset(isIncoming ? 0.08 * dir : -0.08 * dir, 0),
                        end: Offset.zero,
                      );
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: offsetTween.animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: _buildAnimatedHeaderContent(context, tokens, t),
                  ),

                  if (!_isAdminMode) ...[
                    const SizedBox(height: 16),
                    _AuthModeSegmentedBar(
                      signInLabel: t('sign_in_tab'),
                      registerLabel: t('register_tab'),
                      isRegister: _isRegister,
                      onSelect: (register) {
                        if (_isRegister == register) return;
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isRegister = register;
                          _errorText = null;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 18),

                  AnimatedSize(
                    duration: sectionAnimDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: showRegisterFields
                        ? Column(
                            key: const ValueKey('register_avatar_section'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t('choose_avatar_label'),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: tokens.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (int i = 0; i < 3; i++) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: _AvatarChoiceTile(
                                        picKey: 'pic${i + 1}',
                                        selected:
                                            _selectedPic == 'pic${i + 1}',
                                        tokens: tokens,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(
                                            () => _selectedPic = 'pic${i + 1}',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

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
                    textInputAction: showRegisterFields
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

                  AnimatedSize(
                    duration: sectionAnimDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: showRegisterFields
                        ? Column(
                            key: const ValueKey('register_confirm_section'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                          )
                        : const SizedBox.shrink(),
                  ),

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
                            : AnimatedSwitcher(
                                duration: headerSwitchDuration,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: Row(
                                  key: ValueKey(
                                    'cta_${_isAdminMode}_$_isRegister',
                                  ),
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
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isAdminMode = !_isAdminMode;
                  _errorText = null;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textPrimary,
                backgroundColor: tokens.surfaceElevated.withValues(
                  alpha: tokens.isNight ? 0.72 : 0.88,
                ),
                side: BorderSide(
                  color: tokens.borderSubtle,
                  width: math.max(tokens.borderWidth, 1.0),
                ),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: Icon(
                _isAdminMode
                    ? Icons.person_outline_rounded
                    : Icons.storefront_outlined,
                size: 16,
              ),
              label: Text(
                _isAdminMode
                    ? t('customer_portal_button')
                    : t('staff_portal_button'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(appPreferencesProvider.notifier).toggleLanguage();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textPrimary,
                backgroundColor: tokens.surfaceElevated.withValues(
                  alpha: tokens.isNight ? 0.72 : 0.88,
                ),
                side: BorderSide(
                  color: tokens.borderSubtle,
                  width: math.max(tokens.borderWidth, 1.0),
                ),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.translate_rounded, size: 15),
              label: Text(
                ref.watch(appPreferencesProvider).locale.languageCode == 'ar'
                    ? 'English'
                    : 'عربي',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Clean, minimal brand lockup: just the centered hero emblem (which already
/// includes the "EVA Canteen" lettering).
class _SimpleBrandHeader extends StatelessWidget {
  const _SimpleBrandHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EvaBrandLogo(size: isWide ? 236 : 210, hero: true),
    );
  }
}

/// Sliding pill segmented tab switcher between "Sign in" and "Create account".
class _AuthModeSegmentedBar extends StatelessWidget {
  const _AuthModeSegmentedBar({
    required this.signInLabel,
    required this.registerLabel,
    required this.isRegister,
    required this.onSelect,
  });

  final String signInLabel;
  final String registerLabel;
  final bool isRegister;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.7),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: isRegister
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.borderSubtle),
                  boxShadow: tokens.isNight
                      ? null
                      : [
                          BoxShadow(
                            color: tokens.brandPrimary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ModeTabButton(
                  label: signInLabel,
                  selected: !isRegister,
                  onTap: () => onSelect(false),
                ),
              ),
              Expanded(
                child: _ModeTabButton(
                  label: registerLabel,
                  selected: isRegister,
                  onTap: () => onSelect(true),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final baseStyle = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: baseStyle.copyWith(
              color: selected ? tokens.textPrimary : tokens.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
