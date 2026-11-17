import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/domain_models.dart';
import '../../core/network/eva_socket_client.dart';
import '../../core/state/canteen_providers.dart';
import '../eva_theme.dart';

class EvaScaffoldBackground extends StatelessWidget {
  const EvaScaffoldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    if (!tokens.showDoodlePattern) {
      return ColoredBox(color: tokens.canvasBackground, child: child);
    }

    return ColoredBox(
      color: tokens.canvasBackground,
      child: CustomPaint(
        painter: _SubtleBistroDoodlePainter(
          strokeColor: tokens.brandPrimary.withValues(
            alpha: tokens.isNight ? 0.045 : 0.038,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SubtleBistroDoodlePainter extends CustomPainter {
  const _SubtleBistroDoodlePainter({required this.strokeColor});

  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const tile = 132.0;
    for (double y = 24; y < size.height + tile; y += tile) {
      for (double x = 24; x < size.width + tile; x += tile) {
        final rowIdx = (y / tile).floor();
        final dx = x + (rowIdx.isEven ? 0 : tile * 0.5);
        // Minimal coffee cup & croissant geometric accents
        canvas.drawArc(
          Rect.fromCenter(center: Offset(dx, y), width: 20, height: 16),
          0,
          math.pi,
          false,
          paint,
        );
        canvas.drawLine(Offset(dx - 11, y), Offset(dx + 11, y), paint);

        final sliceCenter = Offset(dx + 58, y + 54);
        final path = Path()
          ..moveTo(sliceCenter.dx, sliceCenter.dy - 10)
          ..lineTo(sliceCenter.dx + 10, sliceCenter.dy + 9)
          ..lineTo(sliceCenter.dx - 10, sliceCenter.dy + 9)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleBistroDoodlePainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}

class EvaBrandLogo extends StatelessWidget {
  const EvaBrandLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.08),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.restaurant_menu_rounded,
          color: tokens.brandPrimary,
          size: size * 0.56,
        ),
      ),
    );
  }
}

class EvaAvatar extends StatelessWidget {
  const EvaAvatar({
    super.key,
    required this.profilePic,
    this.radius = 20,
    this.isSelected = false,
  });

  final String profilePic;
  final double radius;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final asset = UserProfile.avatarAssetForPic(profilePic);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.surfaceSubtle,
        border: Border.all(
          color: isSelected ? tokens.brandPrimary : tokens.borderSubtle,
          width: isSelected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.person_rounded,
            color: tokens.brandPrimary,
            size: radius,
          ),
        ),
      ),
    );
  }
}

class EvaProductImage extends ConsumerWidget {
  const EvaProductImage({
    super.key,
    required this.imageUrl,
    this.borderRadius = 12,
    this.aspectRatio,
  });

  final String imageUrl;
  final double borderRadius;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final socket = ref.watch(socketClientProvider);
    final resolved = socket.resolveMediaUrl(imageUrl);

    Widget content;
    if (resolved.isEmpty) {
      content = _fallbackPlaceholder(tokens);
    } else {
      content = Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackPlaceholder(tokens),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: tokens.surfaceSubtle,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.brandPrimary,
                ),
              ),
            ),
          );
        },
      );
    }

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(color: tokens.surfaceSubtle, child: content),
    );

    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: clipped);
    }
    return clipped;
  }

  Widget _fallbackPlaceholder(EvaTokens tokens) {
    return ColoredBox(
      color: tokens.surfaceSubtle,
      child: Center(
        child: Icon(
          Icons.lunch_dining_rounded,
          color: tokens.textSecondary.withValues(alpha: 0.55),
          size: 30,
        ),
      ),
    );
  }
}

class EvaStatusBadge extends StatelessWidget {
  const EvaStatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.pulsing = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool pulsing;

  factory EvaStatusBadge.forOrderStatus({
    required BuildContext context,
    required OrderStatus status,
    required String label,
  }) {
    final tokens = EvaTokens.of(context);
    return switch (status) {
      OrderStatus.pending => EvaStatusBadge(
        label: label,
        background: tokens.statusPendingBg,
        foreground: tokens.statusPendingFg,
        icon: Icons.schedule_rounded,
        pulsing: true,
      ),
      OrderStatus.preparing => EvaStatusBadge(
        label: label,
        background: tokens.statusPreparingBg,
        foreground: tokens.statusPreparingFg,
        icon: Icons.soup_kitchen_rounded,
        pulsing: true,
      ),
      OrderStatus.delivered => EvaStatusBadge(
        label: label,
        background: tokens.statusDeliveredBg,
        foreground: tokens.statusDeliveredFg,
        icon: Icons.check_circle_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ] else if (pulsing) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EvaQuantityStepper extends StatelessWidget {
  const EvaQuantityStepper({
    super.key,
    required this.quantity,
    required this.addLabel,
    required this.onIncrement,
    required this.onDecrement,
    this.disabled = false,
    this.maxReached = false,
    this.compact = false,
  });

  final int quantity;
  final String addLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool disabled;
  final bool maxReached;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final height = compact ? 36.0 : 40.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: quantity <= 0
          ? SizedBox(
              key: const ValueKey('stepper_empty'),
              height: height,
              child: FilledButton.tonalIcon(
                onPressed: disabled
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onIncrement();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: disabled
                      ? tokens.surfaceSubtle
                      : tokens.brandSoftBg,
                  foregroundColor: disabled
                      ? tokens.textSecondary
                      : tokens.brandPrimary,
                  minimumSize: Size(compact ? 72 : 84, height),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  addLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: disabled
                        ? tokens.textSecondary
                        : tokens.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('stepper_active'),
              height: height,
              decoration: BoxDecoration(
                color: tokens.brandPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperIconBtn(
                    icon: quantity == 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    color: tokens.brandOnPrimary,
                    size: height,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDecrement();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '$quantity',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.brandOnPrimary,
                        fontFeatures: EvaThemeBuilder.tabularNums,
                      ),
                    ),
                  ),
                  _StepperIconBtn(
                    icon: Icons.add_rounded,
                    color: maxReached
                        ? tokens.brandOnPrimary.withValues(alpha: 0.38)
                        : tokens.brandOnPrimary,
                    size: height,
                    onTap: maxReached
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onIncrement();
                          },
                  ),
                ],
              ),
            ),
    );
  }
}

class _StepperIconBtn extends StatelessWidget {
  const _StepperIconBtn({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class LanguageQuickToggle extends ConsumerWidget {
  const LanguageQuickToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = EvaTokens.of(context);
    final isAr = ref.watch(
      appPreferencesProvider.select((s) => s.locale.languageCode == 'ar'),
    );

    return OutlinedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(appPreferencesProvider.notifier).toggleLanguage();
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: tokens.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(Icons.translate_rounded, size: 16, color: tokens.brandPrimary),
      label: Text(
        isAr ? 'EN' : 'عربي',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      canteenStoreProvider.select((s) => s.connectionPhase),
    );
    final i18n = ref.watch(i18nProvider);
    final tokens = EvaTokens.of(context);

    if (phase == SocketConnectionPhase.connected) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: tokens.statusPendingBg,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.statusPendingFg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              i18n.t('reconnecting_banner'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.statusPendingFg,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(socketClientProvider).reconnectNow(),
            child: Text(
              'Retry',
              style: TextStyle(
                color: tokens.statusPendingFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Crisp deterministic ticket barcode graphic for the Student Live Pickup Pass.
class EvaPickupBarcodeBar extends StatelessWidget {
  const EvaPickupBarcodeBar({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final codeUnits = orderId.codeUnits;
    return SizedBox(
      height: 40,
      width: 220,
      child: CustomPaint(
        painter: _BarcodePainter(
          seed: codeUnits,
          color: tokens.textPrimary.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.seed, required this.color});

  final List<int> seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    double x = 0;
    int idx = 0;
    while (x < size.width - 3) {
      final unit = seed.isEmpty ? 42 : seed[idx % seed.length];
      final barW = ((unit + idx * 7) % 3 + 1) * 1.6;
      final gapW = ((unit >> 2) % 2 + 1) * 1.8;
      if (x + barW <= size.width) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, barW, size.height),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      x += barW + gapW;
      idx++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
