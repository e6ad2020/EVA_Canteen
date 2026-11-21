import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications/notification_providers.dart';
import '../../design_system/eva_theme.dart';

/// Pure visual, zero-text kinetic splash overlay that choreographs EVA Canteen's
/// 3-layer emblem (`logo_swoosh.png`, `logo_fill.png`, `logo_outline.png`) over
/// a theme-matched backdrop before seamlessly unmounting to reveal [child].
class EvaSplashOverlay extends ConsumerStatefulWidget {
  const EvaSplashOverlay({
    super.key,
    required this.child,
    this.forceShowInTests = false,
  });

  final Widget child;

  /// Allows widget tests to explicitly opt in to rendering the splash sequence.
  final bool forceShowInTests;

  static const Duration totalDuration = Duration(milliseconds: 1250);
  static const Duration skipDuration = Duration(milliseconds: 200);
  static const Duration precacheTimeout = Duration(milliseconds: 150);

  @override
  ConsumerState<EvaSplashOverlay> createState() => _EvaSplashOverlayState();
}

class _EvaSplashOverlayState extends ConsumerState<EvaSplashOverlay>
    with SingleTickerProviderStateMixin {
  static const ColorFilter _kMonochromeFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  static const List<String> _kLayerAssets = [
    'assets/images/logo_swoosh.png',
    'assets/images/logo_fill.png',
    'assets/images/logo_outline.png',
  ];

  // Phase 1 (0.00 -> 0.45): Orbital swoosh sweep & rotation (-22deg -> +3deg -> 0deg)
  late final Animatable<double> _swooshRotation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: -22.0 * math.pi / 180.0,
        end: 3.0 * math.pi / 180.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 68,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 3.0 * math.pi / 180.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 32,
    ),
  ]);

  late final Animatable<double> _swooshScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.56,
        end: 1.045,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.045,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 30,
    ),
  ]);

  AnimationController? _ctrl;
  Timer? _precacheFallbackTimer;
  bool _initialized = false;
  bool _dismissed = false;
  bool _isSkipping = false;
  int _cachePx = 512;

  bool get _isWidgetTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pendingLink = ref.read(pendingDeepLinkProvider);
    final hasPendingDeepLink = pendingLink != null && pendingLink.isNotEmpty;
    final skipForTest = _isWidgetTestBinding && !widget.forceShowInTests;

    if (disableMotion || hasPendingDeepLink || skipForTest) {
      _dismissed = true;
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logoSize = (size.shortestSide * 0.56).clamp(176.0, 260.0);
    _cachePx = (logoSize * dpr).round().clamp(256, 944);

    final ctrl = AnimationController(
      vsync: this,
      duration: EvaSplashOverlay.totalDuration,
    );
    ctrl.addStatusListener(_onAnimationStatus);
    _ctrl = ctrl;

    unawaited(_precacheAndStart(ctrl));
  }

  void _startAnimation(AnimationController ctrl) {
    _precacheFallbackTimer?.cancel();
    _precacheFallbackTimer = null;
    if (!mounted || _dismissed || _isSkipping || _ctrl != ctrl) return;
    if (!ctrl.isAnimating && ctrl.value == 0.0) {
      unawaited(ctrl.forward());
    }
  }

  Future<void> _precacheAndStart(AnimationController ctrl) async {
    _precacheFallbackTimer = Timer(
      EvaSplashOverlay.precacheTimeout,
      () => _startAnimation(ctrl),
    );
    try {
      await Future.wait<void>([
        for (final asset in _kLayerAssets)
          precacheImage(
            ResizeImage(AssetImage(asset), width: _cachePx),
            context,
          ).catchError((_) {}),
      ]);
    } catch (_) {
      // Proceed cleanly even if asset precaching is interrupted.
    }
    _startAnimation(ctrl);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_dismissed) {
      _precacheFallbackTimer?.cancel();
      _precacheFallbackTimer = null;
      final ctrl = _ctrl;
      _ctrl = null;
      ctrl?.removeStatusListener(_onAnimationStatus);
      ctrl?.dispose();
      setState(() => _dismissed = true);
    }
  }

  void _handleSkipTap() {
    final ctrl = _ctrl;
    if (_dismissed || _isSkipping || ctrl == null) return;
    _isSkipping = true;
    _precacheFallbackTimer?.cancel();
    _precacheFallbackTimer = null;
    // Jump into the final exit window (80% -> 100%) and finish briskly.
    final start = math.max(ctrl.value, 0.80);
    ctrl.value = start;
    unawaited(
      ctrl.animateTo(
        1.0,
        duration: EvaSplashOverlay.skipDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _precacheFallbackTimer?.cancel();
    _precacheFallbackTimer = null;
    final ctrl = _ctrl;
    _ctrl = null;
    ctrl?.removeStatusListener(_onAnimationStatus);
    ctrl?.dispose();
    super.dispose();
  }

  double _interval(double t, double start, double end, [Curve curve = Curves.linear]) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _ctrl == null) {
      return widget.child;
    }

    final tokens = EvaTokens.of(context);
    final ctrl = _ctrl!;
    final viewport = MediaQuery.sizeOf(context);
    final logoSize = (viewport.shortestSide * 0.56).clamp(176.0, 260.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: ctrl,
          builder: (context, _) {
            final t = ctrl.value;
            final isExiting = _isSkipping || t >= 0.80;

            // Phase 4 (0.80 -> 1.00): Seamless forward zoom & fade-out handoff
            final exitT = _interval(t, 0.80, 1.0, Curves.easeInOutCubic);
            final overlayOpacity = (1.0 - exitT).clamp(0.0, 1.0);
            final exitScale = 1.0 + 0.07 * Curves.easeInCubic.transform(exitT);

            // Phase 1 (0.00 -> 0.45): Orbital swoosh + halo ripple
            final p1 = _interval(t, 0.0, 0.45);
            final swooshOpacity = _interval(t, 0.0, 0.16, Curves.easeOut);
            final swooshAngle = _swooshRotation.transform(p1);
            final swooshScale = _swooshScale.transform(p1);
            final haloProgress = _interval(t, 0.04, 0.56, Curves.easeOutCubic);

            // Phase 2 (0.18 -> 0.58): Theme-tinted lettering pop with spring overshoot
            final fillSpring = _interval(t, 0.18, 0.58, Curves.easeOutBack);
            final fillOpacity = _interval(t, 0.18, 0.34, Curves.easeOut);
            final fillScale = 0.70 + 0.30 * fillSpring;
            final fillLiftY =
                16.0 * (1.0 - _interval(t, 0.18, 0.52, Curves.easeOutCubic));

            // Phase 3 (0.35 -> 0.78): Crisp outline lock + starburst + diagonal sheen
            final outlineOpacity = _interval(t, 0.35, 0.54, Curves.easeOut);
            final outlineScale =
                0.90 + 0.10 * _interval(t, 0.35, 0.56, Curves.easeOutBack);
            final starsProgress = _interval(t, 0.36, 0.82);
            final sheenProgress = _interval(t, 0.46, 0.78, Curves.easeInOutSine);

            // Backdrop entrance & breathing glow
            final stripeSlide = _interval(t, 0.0, 0.52, Curves.easeOutCubic);
            final glowBreath = 0.90 + 0.14 * math.sin(t * math.pi);

            Widget swooshImage = Image.asset(
              'assets/images/logo_swoosh.png',
              fit: BoxFit.contain,
              cacheWidth: _cachePx,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              color: tokens.logoSwooshTint == const Color(0xFFFFFFFF)
                  ? null
                  : tokens.logoSwooshTint,
              colorBlendMode: tokens.logoSwooshTint == const Color(0xFFFFFFFF)
                  ? null
                  : BlendMode.modulate,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
            if (tokens.isMonochromeLogo) {
              swooshImage = ColorFiltered(
                colorFilter: _kMonochromeFilter,
                child: swooshImage,
              );
            }

            final assembledEmblem = SizedBox(
              width: logoSize,
              height: logoSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1: Orbital planetary swoosh
                  Opacity(
                    opacity: swooshOpacity,
                    child: Transform.rotate(
                      angle: swooshAngle,
                      child: Transform.scale(
                        scale: swooshScale,
                        child: swooshImage,
                      ),
                    ),
                  ),
                  // Layer 2: Theme-tinted EVA Canteen fill lettering
                  Opacity(
                    opacity: fillOpacity,
                    child: Transform.translate(
                      offset: Offset(0, fillLiftY),
                      child: Transform.scale(
                        scale: fillScale,
                        child: Image.asset(
                          'assets/images/logo_fill.png',
                          fit: BoxFit.contain,
                          cacheWidth: _cachePx,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          color: tokens.logoFill,
                          colorBlendMode: BlendMode.modulate,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  // Layer 3: Crisp outline & accent stars
                  Opacity(
                    opacity: outlineOpacity,
                    child: Transform.scale(
                      scale: outlineScale,
                      child: Image.asset(
                        'assets/images/logo_outline.png',
                        fit: BoxFit.contain,
                        cacheWidth: _cachePx,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        color: tokens.logoOutline,
                        colorBlendMode: BlendMode.modulate,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            );

            // Apply a single crisp diagonal specular sheen across the assembled logo
            final Widget heroEmblem = sheenProgress > 0.0 && sheenProgress < 1.0
                ? ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (bounds) {
                      final sweep = -0.55 + sheenProgress * 2.10;
                      return LinearGradient(
                        begin: Alignment(-1.0 + sweep, -0.8),
                        end: Alignment(-0.2 + sweep, 0.8),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.42),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    child: assembledEmblem,
                  )
                : assembledEmblem;

            return IgnorePointer(
              ignoring: isExiting,
              child: GestureDetector(
                key: const ValueKey('eva_splash_overlay'),
                behavior: HitTestBehavior.opaque,
                onTap: _handleSkipTap,
                child: Opacity(
                  opacity: overlayOpacity,
                  child: RepaintBoundary(
                    child: ColoredBox(
                      color: tokens.canvasBackground,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Theme-matched radial aurora + subtle diagonal icon stripes (or lunar starfield for Moon)
                          CustomPaint(
                            painter: _EvaSplashBackdropPainter(
                              brandPrimary: tokens.brandPrimary,
                              logoFill: tokens.logoFill,
                              isNight: tokens.isNight,
                              isMoon: tokens.isMoon,
                              isMonochrome: tokens.isMonochromeLogo,
                              stripeSlide: stripeSlide,
                              glowBreath: glowBreath,
                            ),
                          ),
                          // Centered kinetic emblem + halo ripple + twinkling starburst
                          Center(
                            child: Transform.scale(
                              scale: exitScale,
                              child: SizedBox(
                                width: logoSize * 1.45,
                                height: logoSize * 1.45,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: Size.square(logoSize * 1.45),
                                      painter: _EvaSplashEffectsPainter(
                                        brandPrimary: tokens.brandPrimary,
                                        logoFill: tokens.isMoon
                                            ? const Color(0xFFF7DC88)
                                            : tokens.logoFill,
                                        logoOutline: tokens.logoOutline,
                                        isNight: tokens.isNight,
                                        isMonochrome: tokens.isMonochromeLogo,
                                        haloProgress: haloProgress,
                                        starsProgress: starsProgress,
                                      ),
                                    ),
                                    heroEmblem,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EvaSplashBackdropPainter extends CustomPainter {
  const _EvaSplashBackdropPainter({
    required this.brandPrimary,
    required this.logoFill,
    required this.isNight,
    required this.isMoon,
    required this.isMonochrome,
    required this.stripeSlide,
    required this.glowBreath,
  });

  final Color brandPrimary;
  final Color logoFill;
  final bool isNight;
  final bool isMoon;
  final bool isMonochrome;
  final double stripeSlide;
  final double glowBreath;

  static const List<Color> _kIconRibbonColors = [
    Color(0xFFFF9800),
    Color(0xFFFFCA28),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFF29B6F6),
  ];

  static final List<({double x, double y, double r, double a, bool gold})>
  _splashMoonStars = _buildSplashMoonStars();

  static List<({double x, double y, double r, double a, bool gold})>
  _buildSplashMoonStars() {
    final rng = math.Random(20260721);
    return List.unmodifiable(
      List.generate(42, (i) {
        final hero = i >= 30;
        return (
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          r: hero ? (1.3 + rng.nextDouble() * 0.9) : (0.7 + rng.nextDouble() * 0.6),
          a: hero ? (0.42 + rng.nextDouble() * 0.42) : (0.18 + rng.nextDouble() * 0.30),
          gold: hero && i % 3 == 0,
        );
      }),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final shortest = size.shortestSide;

    if (isMoon) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45, 1.0],
            colors: isNight
                ? const [
                    Color(0xFF040711),
                    Color(0xFF091227),
                    Color(0xFF152546),
                  ]
                : const [
                    Color(0xFFE7EFFD),
                    Color(0xFFF0F4FC),
                    Color(0xFFE3EBF8),
                  ],
          ).createShader(rect),
      );

      // Soft silver-moonlight radial aura behind the pearl-and-gold EVA emblem
      final glowRadius = shortest * 0.58 * glowBreath;
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (isNight ? const Color(0xFFDCE8FF) : const Color(0xFF6B85C4))
                  .withValues(alpha: isNight ? 0.22 : 0.14),
              const Color(0xFFF7DC88).withValues(alpha: isNight ? 0.08 : 0.05),
              const Color(0x00070B16),
            ],
            stops: const [0.0, 0.46, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
      );

      // Subtle seeded lunar starfield fading in smoothly with the splash
      final starAlphaFactor = (0.35 + 0.65 * stripeSlide).clamp(0.0, 1.0);
      for (final s in _splashMoonStars) {
        final pos = Offset(s.x * size.width, s.y * size.height);
        if ((pos - center).distance < shortest * 0.16) continue;
        final c = isNight
            ? (s.gold ? const Color(0xFFF7DC88) : const Color(0xFFE6F0FF))
            : const Color(0xFF47629E);
        final alpha = (isNight ? s.a : s.a * 0.25) * starAlphaFactor;
        canvas.drawCircle(pos, s.r, Paint()..color = c.withValues(alpha: alpha));
      }
      return;
    }

    // 1. Soft breathing radial glow behind the emblem
    final glowRadius = shortest * 0.56 * glowBreath;
    final glowColor = isNight ? logoFill : brandPrimary;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: isNight ? 0.22 : 0.14),
          logoFill.withValues(alpha: isNight ? 0.08 : 0.07),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Subtle translucent diagonal corner ribbons echoing EVA's app icon
    final ribbonWidth = (shortest * 0.075).clamp(24.0, 44.0);
    final gap = ribbonWidth * 1.18;
    final baseAlpha = isNight ? 0.085 : 0.095;
    final slideOffset = (1.0 - stripeSlide) * 44.0;

    void drawCornerCluster(Offset origin, double directionSign) {
      canvas.save();
      canvas.translate(
        origin.dx + slideOffset * directionSign,
        origin.dy - slideOffset * directionSign,
      );
      canvas.rotate(-0.46); // ~ -26 deg diagonal echoing ic_launcher stripes

      for (int i = 0; i < _kIconRibbonColors.length; i++) {
        final c = isMonochrome
            ? brandPrimary
            : _kIconRibbonColors[i];
        final paint = Paint()
          ..color = c.withValues(alpha: baseAlpha * stripeSlide)
          ..style = PaintingStyle.fill;
        final x = (i - 2) * gap;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 0),
            width: ribbonWidth,
            height: shortest * 0.85,
          ),
          Radius.circular(ribbonWidth * 0.5),
        );
        canvas.drawRRect(rect, paint);
      }
      canvas.restore();
    }

    drawCornerCluster(Offset(size.width * 0.06, size.height * 0.08), -1.0);
    drawCornerCluster(Offset(size.width * 0.94, size.height * 0.92), 1.0);
  }

  @override
  bool shouldRepaint(covariant _EvaSplashBackdropPainter oldDelegate) {
    return oldDelegate.stripeSlide != stripeSlide ||
        oldDelegate.glowBreath != glowBreath ||
        oldDelegate.brandPrimary != brandPrimary ||
        oldDelegate.logoFill != logoFill ||
        oldDelegate.isNight != isNight ||
        oldDelegate.isMoon != isMoon ||
        oldDelegate.isMonochrome != isMonochrome;
  }
}

class _EvaSplashEffectsPainter extends CustomPainter {
  const _EvaSplashEffectsPainter({
    required this.brandPrimary,
    required this.logoFill,
    required this.logoOutline,
    required this.isNight,
    required this.isMonochrome,
    required this.haloProgress,
    required this.starsProgress,
  });

  final Color brandPrimary;
  final Color logoFill;
  final Color logoOutline;
  final bool isNight;
  final bool isMonochrome;
  final double haloProgress;
  final double starsProgress;

  // Normalized polar offsets around center (angleRad, radiusFactor, sizePx, phaseDelay)
  static const List<(double, double, double, double)> _kStars = [
    (-2.38, 0.43, 13.0, 0.00),
    (-0.74, 0.45, 11.5, 0.08),
    (0.46, 0.44, 14.0, 0.14),
    (2.58, 0.42, 10.5, 0.18),
    (-1.55, 0.40, 8.5, 0.24),
    (1.48, 0.41, 9.5, 0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxR = size.shortestSide * 0.5;

    // 1. Expanding circular orbital halo ripple (Phase 1)
    if (haloProgress > 0.0 && haloProgress < 1.0) {
      final rippleRadius = maxR * (0.34 + 0.64 * haloProgress);
      final rippleOpacity = (1.0 - haloProgress) * (isNight ? 0.55 : 0.44);
      final strokeW = 2.8 * (1.0 - 0.55 * haloProgress);

      final haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..shader = SweepGradient(
          colors: [
            brandPrimary.withValues(alpha: rippleOpacity),
            logoFill.withValues(alpha: rippleOpacity * 0.9),
            (isMonochrome ? brandPrimary : const Color(0xFFFF6B9D))
                .withValues(alpha: rippleOpacity * 0.85),
            brandPrimary.withValues(alpha: rippleOpacity),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: rippleRadius));
      canvas.drawCircle(center, rippleRadius, haloPaint);
    }

    // 2. Procedural 4-point twinkling starburst around the emblem (Phase 3)
    if (starsProgress > 0.0) {
      final accentPalette = isMonochrome
          ? [brandPrimary, logoOutline, logoFill]
          : [
              logoOutline,
              const Color(0xFFFFB300),
              const Color(0xFFFF4D8D),
              logoFill,
            ];

      for (int i = 0; i < _kStars.length; i++) {
        final (angle, rFactor, starSize, delay) = _kStars[i];
        final local = ((starsProgress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        if (local <= 0.0) continue;

        final bloom = Curves.easeOutBack.transform(local.clamp(0.0, 0.65) / 0.65);
        final twinkle = 0.72 + 0.28 * math.sin(local * math.pi * 2.0);
        final fadeTail = local > 0.82 ? (1.0 - (local - 0.82) / 0.18) : 1.0;
        final alpha = (twinkle * fadeTail * (isNight ? 0.95 : 0.88)).clamp(
          0.0,
          1.0,
        );
        if (alpha <= 0.01) continue;

        final driftAngle = angle + (i.isEven ? 0.08 : -0.08) * local;
        final starCenter = Offset(
          center.dx + math.cos(driftAngle) * maxR * 2.0 * rFactor,
          center.dy + math.sin(driftAngle) * maxR * 2.0 * rFactor,
        );

        final starColor = accentPalette[i % accentPalette.length].withValues(
          alpha: alpha,
        );
        _drawFourPointStar(
          canvas,
          starCenter,
          starSize * bloom,
          (i.isEven ? 1.0 : -1.0) * local * 0.55,
          starColor,
        );
      }
    }
  }

  void _drawFourPointStar(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Color color,
  ) {
    if (radius <= 0.5) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final inner = radius * 0.26;
    final path = Path()
      ..moveTo(0, -radius)
      ..quadraticBezierTo(inner * 0.5, -inner * 0.5, radius, 0)
      ..quadraticBezierTo(inner * 0.5, inner * 0.5, 0, radius)
      ..quadraticBezierTo(-inner * 0.5, inner * 0.5, -radius, 0)
      ..quadraticBezierTo(-inner * 0.5, -inner * 0.5, 0, -radius)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EvaSplashEffectsPainter oldDelegate) {
    return oldDelegate.haloProgress != haloProgress ||
        oldDelegate.starsProgress != starsProgress ||
        oldDelegate.brandPrimary != brandPrimary ||
        oldDelegate.logoFill != logoFill ||
        oldDelegate.logoOutline != logoOutline ||
        oldDelegate.isNight != isNight ||
        oldDelegate.isMonochrome != isMonochrome;
  }
}
