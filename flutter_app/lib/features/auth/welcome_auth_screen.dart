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

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final i18n = ref.watch(i18nProvider);
    final isOpen = ref.watch(canteenStoreProvider.select((s) => s.isCanteenOpen));
    final busy = ref.watch(canteenStoreProvider.select((s) => s.authBusy));

    return Scaffold(
      body: EvaScaffoldBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ConnectionStatusBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    const EvaBrandLogo(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        i18n.t('canteen_name'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    EvaStatusBadge(
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
                    const SizedBox(width: 10),
                    const LanguageQuickToggle(),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 760;
                          final formCard = _buildAuthCard(
                            context,
                            tokens,
                            i18n.t,
                            busy,
                          );
                          if (!isWide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeroPitch(context, tokens, i18n.t),
                                const SizedBox(height: 20),
                                formCard,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 11,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 36,
                                  ),
                                  child: _buildHeroPitch(
                                    context,
                                    tokens,
                                    i18n.t,
                                  ),
                                ),
                              ),
                              Expanded(flex: 10, child: formCard),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPitch(
    BuildContext context,
    EvaTokens tokens,
    String Function(String, [Map<String, String>?]) t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.brandSoftBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 16,
                color: tokens.brandPrimary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'EVA International Applied Technology School',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t('welcome_headline'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t('welcome_subtitle'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(
    BuildContext context,
    EvaTokens tokens,
    String Function(String, [Map<String, String>?]) t,
    bool busy,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isAdminMode) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: tokens.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('admin_portal_title'),
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeTabButton(
                        label: t('sign_in_tab'),
                        selected: !_isRegister,
                        onTap: () => setState(() {
                          _isRegister = false;
                          _errorText = null;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _ModeTabButton(
                        label: t('register_tab'),
                        selected: _isRegister,
                        onTap: () => setState(() {
                          _isRegister = true;
                          _errorText = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!_isAdminMode && _isRegister) ...[
              Text(
                t('choose_avatar_label'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final pic in const ['pic1', 'pic2', 'pic3'])
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPic = pic);
                      },
                      child: EvaAvatar(
                        profilePic: pic,
                        radius: 28,
                        isSelected: _selectedPic == pic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            Text(
              t('email_label'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: _isAdminMode ? 'admin@canteen.app' : t('email_hint'),
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
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
              onSubmitted: (_) {
                if (!_isRegister || _isAdminMode) _submit();
              },
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
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
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.verified_user_outlined, size: 19),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.statusClosedBg,
                  borderRadius: BorderRadius.circular(10),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isAdminMode
                          ? t('sign_in_tab')
                          : (_isRegister ? t('register_cta') : t('login_cta')),
                    ),
            ),
            const SizedBox(height: 12),
            if (!_isAdminMode)
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(canteenStoreProvider.notifier).enterBrowseGuestMode();
                  context.go('/menu');
                },
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: Text(t('browse_menu_guest')),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _isAdminMode = !_isAdminMode;
                _errorText = null;
              }),
              icon: Icon(
                _isAdminMode
                    ? Icons.school_outlined
                    : Icons.admin_panel_settings_outlined,
                size: 18,
              ),
              label: Text(
                _isAdminMode
                    ? t('sign_in_tab')
                    : t('staff_portal_button'),
              ),
            ),
          ],
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? tokens.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: selected ? Border.all(color: tokens.borderSubtle) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? tokens.textPrimary : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
