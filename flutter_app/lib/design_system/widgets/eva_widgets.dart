import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
    final wallpaperFolder = tokens.wallpaperFolder;
    final iconBrightness = tokens.isNight ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: tokens.isNight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
      child: ColoredBox(
        color: tokens.canvasBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: wallpaperFolder != null
                    ? LayoutBuilder(
                        key: ValueKey('wallpaper_$wallpaperFolder'),
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 768;
                          final assetPath =
                              '$wallpaperFolder/${isDesktop ? "desktop.png" : "phone.png"}';
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, _, _) =>
                                    ColoredBox(color: tokens.canvasBackground),
                              ),
                              // Subtle veil keeps illustrated line art crisp without competing with UI text
                              const ColoredBox(color: Color(0x26FFFFFF)),
                            ],
                          );
                        },
                      )
                    : tokens.showDoodlePattern
                    ? CustomPaint(
                        key: ValueKey('grid_${tokens.isNight}'),
                        painter: _SubtleArchitecturalPatternPainter(
                          dotColor: tokens.brandPrimary.withValues(
                            alpha: tokens.isNight ? 0.07 : 0.055,
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SubtleArchitecturalPatternPainter extends CustomPainter {
  const _SubtleArchitecturalPatternPainter({required this.dotColor});

  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    for (double y = 14; y < size.height; y += spacing) {
      for (double x = 14; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleArchitecturalPatternPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

/// High-performance architectural surface card (zero BackdropFilter GPU blur,
/// zero offscreen saveLayer passes during scrolling).
class EvaSurfaceCard extends StatelessWidget {
  const EvaSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final radius = borderRadius ?? tokens.cardRadius;
    final resolvedBg = backgroundColor ?? tokens.surfaceCard;
    final resolvedBorder = borderColor ?? tokens.borderSubtle;
    final resolvedBorderWidth = borderWidth ?? tokens.borderWidth;

    Widget inner = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (onTap != null) {
      inner = InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: inner,
      );
    }

    inner = Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: onTap != null ? Clip.hardEdge : Clip.none,
      child: inner,
    );

    Widget surface = Container(
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolvedBorder, width: resolvedBorderWidth),
        boxShadow: tokens.isNight
            ? null
            : [
                BoxShadow(
                  color: tokens.isLiquidGlass
                      ? tokens.brandPrimary.withValues(alpha: 0.06)
                      : const Color(0x080F172A),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: inner,
    );

    if (clipBehavior != Clip.none) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clipBehavior,
        child: surface,
      );
    }

    if (onTap != null) {
      return EvaPressable(child: surface);
    }
    return surface;
  }
}

/// Rounded, animated floating top/header bar without GPU blur lag or flicker.
class EvaGlassBar extends StatefulWidget {
  const EvaGlassBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 4),
    this.borderRadius = 22,
    this.isScrolled = false,
    this.bottomBorder = true,
    this.topBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool isScrolled;
  final bool bottomBorder;
  final bool topBorder;

  @override
  State<EvaGlassBar> createState() => _EvaGlassBarState();
}

class _EvaGlassBarState extends State<EvaGlassBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curved;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.985, end: 1.0).animate(_curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _curved.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = BorderRadius.circular(widget.borderRadius);

    final borderColor = widget.isScrolled
        ? Color.lerp(tokens.borderSubtle, tokens.brandPrimary, 0.42)!
        : tokens.borderSubtle;

    final bar = Padding(
      padding: widget.margin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: widget.isScrolled
                ? math.max(tokens.borderWidth, 1.35)
                : tokens.borderWidth,
          ),
          boxShadow: tokens.isNight
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isScrolled ? 0.34 : 0.20,
                    ),
                    blurRadius: widget.isScrolled ? 16 : 10,
                    offset: Offset(0, widget.isScrolled ? 5 : 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: tokens.brandPrimary.withValues(
                      alpha: widget.isScrolled
                          ? 0.11
                          : (tokens.isLiquidGlass ? 0.07 : 0.05),
                    ),
                    blurRadius: widget.isScrolled ? 18 : 12,
                    offset: Offset(0, widget.isScrolled ? 6 : 3),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: widget.child,
        ),
      ),
    );

    if (disableMotion) return bar;

    return FadeTransition(
      opacity: _curved,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _curved,
          child: bar,
          builder: (context, child) {
            final dy = (1.0 - _curved.value) * -10.0;
            return Transform.translate(
              offset: Offset(0.0, dy),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Full-bleed floating-island header scaffold that eliminates sharp horizontal
/// viewport clipping beneath [EvaGlassBar].
///
/// The scrollable [bodyBuilder] spans `0 .. screenHeight` edge-to-edge so cards
/// glide smoothly behind the rounded floating [EvaGlassBar], while an ultra-light
/// atmospheric top feather scrim (ending behind the upper half of the opaque
/// header pill) keeps status-bar icons crisp with zero `BackdropFilter` blur.
class EvaFloatingHeaderScaffold extends StatefulWidget {
  const EvaFloatingHeaderScaffold({
    super.key,
    required this.headerBuilder,
    required this.bodyBuilder,
    this.initialHeaderHeight = 68.0,
    this.scrollThreshold = 8.0,
  });

  final Widget Function(BuildContext context, bool isScrolled) headerBuilder;
  final Widget Function(
    BuildContext context,
    double topClearance,
    bool isScrolled,
  ) bodyBuilder;
  final double initialHeaderHeight;
  final double scrollThreshold;

  @override
  State<EvaFloatingHeaderScaffold> createState() =>
      _EvaFloatingHeaderScaffoldState();
}

class _EvaFloatingHeaderScaffoldState extends State<EvaFloatingHeaderScaffold> {
  late final ValueNotifier<double> _headerHeightNotifier =
      ValueNotifier<double>(widget.initialHeaderHeight);
  late final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  void dispose() {
    _headerHeightNotifier.dispose();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  void _onHeaderHeightMeasured(double measuredHeight) {
    if (!mounted) return;
    if ((measuredHeight - _headerHeightNotifier.value).abs() > 0.5) {
      _headerHeightNotifier.value = measuredHeight;
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final nextScrolled = notification.metrics.pixels > widget.scrollThreshold;
    if (nextScrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = nextScrolled;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ValueListenableBuilder<double>(
            valueListenable: _headerHeightNotifier,
            builder: (context, headerHeight, _) {
              final topClearance = topInset + headerHeight + 4.0;
              return widget.bodyBuilder(
                context,
                topClearance,
                _isScrolledNotifier.value,
              );
            },
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _headerHeightNotifier,
          builder: (context, headerHeight, _) {
            // Ends behind the opaque body of EvaGlassBar so there is never a visible seam
            final scrimHeight = topInset + math.min(headerHeight * 0.56, 40.0);
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: scrimHeight,
              child: IgnorePointer(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isScrolledNotifier,
                  builder: (context, isScrolled, child) => AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    opacity: isScrolled ? 1.0 : (topInset > 0 ? 0.45 : 0.0),
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.56, 1.0],
                        colors: [
                          tokens.canvasBackground.withValues(
                            alpha: tokens.isNight ? 0.95 : 0.92,
                          ),
                          tokens.canvasBackground.withValues(
                            alpha: tokens.isNight ? 0.68 : 0.62,
                          ),
                          tokens.canvasBackground.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: _HeaderSizeObserver(
              onHeightChanged: _onHeaderHeightMeasured,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isScrolledNotifier,
                builder: (context, isScrolled, _) =>
                    widget.headerBuilder(context, isScrolled),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderSizeObserver extends SingleChildRenderObjectWidget {
  const _HeaderSizeObserver({
    required this.onHeightChanged,
    required super.child,
  });

  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHeaderSizeObserver(onHeightChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHeaderSizeObserver renderObject,
  ) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class _RenderHeaderSizeObserver extends RenderProxyBox {
  _RenderHeaderSizeObserver(this.onHeightChanged);

  ValueChanged<double> onHeightChanged;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final newHeight = size.height;
    if (newHeight > 0 &&
        (_lastHeight == null || (newHeight - _lastHeight!).abs() > 0.5)) {
      _lastHeight = newHeight;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        onHeightChanged(newHeight);
      });
    }
  }
}

class EvaFloatingNavItem {
  const EvaFloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showDotBadge = false,
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showDotBadge;
  final int? badgeCount;
}

/// Tracks vertical scroll direction across any child scrollable view and drives
/// [EvaFloatingNavBar] label visibility according to [EvaNavBarBehavior].
class EvaNavScrollTracker extends StatefulWidget {
  const EvaNavScrollTracker({
    super.key,
    required this.currentIndex,
    required this.behavior,
    required this.builder,
  });

  final int currentIndex;
  final EvaNavBarBehavior behavior;
  final Widget Function(BuildContext context, bool showLabels) builder;

  @override
  State<EvaNavScrollTracker> createState() => _EvaNavScrollTrackerState();
}

class _EvaNavScrollTrackerState extends State<EvaNavScrollTracker> {
  static const double _collapseThreshold = 34.0;
  static const double _expandThreshold = 22.0;

  bool _collapsedByScroll = false;
  double _accumulatedDelta = 0.0;

  @override
  void didUpdateWidget(covariant EvaNavScrollTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.behavior != widget.behavior) {
      _collapsedByScroll = false;
      _accumulatedDelta = 0.0;
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (widget.behavior != EvaNavBarBehavior.adaptive) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    final pixels = notification.metrics.pixels;
    final maxExtent = notification.metrics.maxScrollExtent;

    if (pixels <= 14.0) {
      _accumulatedDelta = 0.0;
      if (_collapsedByScroll) {
        setState(() => _collapsedByScroll = false);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      if (delta == 0.0) return false;
      // Ignore iOS/Android overscroll bounce beyond bounds
      if (pixels < 0.0 || (maxExtent > 0.0 && pixels > maxExtent)) {
        return false;
      }

      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = delta;
      } else {
        _accumulatedDelta += delta;
      }

      if (_accumulatedDelta > _collapseThreshold &&
          pixels > 28.0 &&
          !_collapsedByScroll) {
        _accumulatedDelta = 0.0;
        setState(() => _collapsedByScroll = true);
      } else if (_accumulatedDelta < -_expandThreshold && _collapsedByScroll) {
        _accumulatedDelta = 0.0;
        setState(() => _collapsedByScroll = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool showLabels = switch (widget.behavior) {
      EvaNavBarBehavior.expanded => true,
      EvaNavBarBehavior.compact => false,
      EvaNavBarBehavior.adaptive => !_collapsedByScroll,
    };

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: widget.builder(context, showLabels),
    );
  }
}

/// Analytical critically-damped / underdamped spring ported from NuvioMobile's
/// `JellySpring.kt` for liquid, alive hold & drag navbar physics.
class _JellySpring {
  _JellySpring(this.value, this.stiffness, this.dampingRatio);

  double value;
  final double stiffness;
  final double dampingRatio;
  double velocity = 0.0;

  bool isAtRest(double target) =>
      (value - target).abs() < 0.0005 && velocity.abs() < 0.002;

  void snapTo(double target) {
    value = target;
    velocity = 0.0;
  }

  void advance(double target, double seconds) {
    if (isAtRest(target)) {
      snapTo(target);
      return;
    }
    final displacement = value - target;
    final frequency = math.sqrt(stiffness);
    if (dampingRatio >= 0.9999) {
      final decay = math.exp(-frequency * seconds);
      final coeff = velocity + frequency * displacement;
      value = target + (displacement + coeff * seconds) * decay;
      velocity = (velocity - frequency * coeff * seconds) * decay;
    } else {
      final damping = dampingRatio * frequency;
      final damped = frequency * math.sqrt(1.0 - dampingRatio * dampingRatio);
      final decay = math.exp(-damping * seconds);
      final cosine = math.cos(damped * seconds);
      final sine = math.sin(damped * seconds);
      final posCoeff = (velocity + damping * displacement) / damped;
      final velCoeff = (damping * velocity + stiffness * displacement) / damped;
      value = target + decay * (displacement * cosine + posCoeff * sine);
      velocity = decay * (velocity * cosine - velCoeff * sine);
    }
  }
}

double _jellyRubberBand(double distance, double dimension) {
  if (distance == 0.0 || dimension <= 0.0) return 0.0;
  final damped =
      (1.0 - 1.0 / (distance.abs() * 0.14 / dimension + 1.0)) * dimension;
  return distance < 0 ? -damped : damped;
}

double _jellyPanelOffset(double rawOffset, double width) {
  if (width <= 0.0 || rawOffset == 0.0) return 0.0;
  final fraction = (rawOffset / width).clamp(-1.0, 1.0);
  final x = fraction.abs();
  var low = 0.0;
  var high = 1.0;
  var param = x;
  for (int i = 0; i < 10; i++) {
    final bezierX = param * param * (3.0 * (1.0 - param) * 0.58 + param);
    if (bezierX < x) {
      low = param;
    } else {
      high = param;
    }
    param = (low + high) / 2.0;
  }
  final eased = param * param * (3.0 * (1.0 - param) + param);
  return (fraction < 0 ? -4.0 : 4.0) * eased;
}

class _JellyFrame {
  const _JellyFrame({
    required this.position,
    this.pillScaleX = 1.0,
    this.pillScaleY = 1.0,
    this.contentScale = 1.0,
    this.panelOffset = 0.0,
    this.trackScale = 1.0,
    this.trackScaleX = 1.0,
    this.trackOffsetY = 0.0,
    this.originX = 0.0,
    this.glowY = 30.0,
    this.glowOpacity = 0.0,
  });

  final double position;
  final double pillScaleX;
  final double pillScaleY;
  final double contentScale;
  final double panelOffset;
  final double trackScale;
  final double trackScaleX;
  final double trackOffsetY;
  final double originX;
  final double glowY;
  final double glowOpacity;
}

class _JellyMotion extends ChangeNotifier {
  _JellyMotion(int initialVisualIndex, int count)
    : _tabCount = count,
      _position = _JellySpring(
        math.max(0, initialVisualIndex).toDouble(),
        1000.0,
        1.0,
      ),
      _velocity = _JellySpring(0.0, 300.0, 0.5),
      _press = _JellySpring(0.0, 1000.0, 1.0),
      _scaleX = _JellySpring(1.0, 250.0, 0.6),
      _scaleY = _JellySpring(1.0, 250.0, 0.7),
      _panel = _JellySpring(0.0, 300.0, 1.0),
      _trackY = _JellySpring(
        0.0,
        240.0 / 0.9,
        18.0 / (2.0 * math.sqrt(240.0 * 0.9)),
      ),
      _trackX = _JellySpring(
        1.0,
        240.0 / 0.9,
        18.0 / (2.0 * math.sqrt(240.0 * 0.9)),
      ),
      _trackPress = _JellySpring(
        1.0,
        240.0 / 0.9,
        18.0 / (2.0 * math.sqrt(240.0 * 0.9)),
      ),
      _glow = _JellySpring(
        0.0,
        240.0 / 0.9,
        18.0 / (2.0 * math.sqrt(240.0 * 0.9)),
      ) {
    _target = _position.value;
    frame = _JellyFrame(position: _position.value);
  }

  static const double inset = 4.0;

  final _JellySpring _position;
  final _JellySpring _velocity;
  final _JellySpring _press;
  final _JellySpring _scaleX;
  final _JellySpring _scaleY;
  final _JellySpring _panel;
  final _JellySpring _trackY;
  final _JellySpring _trackX;
  final _JellySpring _trackPress;
  final _JellySpring _glow;

  double _target = 0.0;
  double _pressTarget = 0.0;
  double _shapeTarget = 1.0;
  bool _releasePending = false;
  double _downX = 0.0;
  double _downY = 30.0;
  double _dragStartTarget = 0.0;
  double _dragStartPanel = 0.0;
  double _dragStartY = 0.0;
  double _movedDistance = 0.0;
  double _originX = 0.0;
  double _glowY = 30.0;
  double _width = 320.0;
  double _height = 62.0;
  int _tabCount;

  bool dragging = false;
  bool running = false;
  late _JellyFrame frame;

  int get _maxIndex => math.max(0, _tabCount - 1);
  double get _tabWidth =>
      math.max(1.0, (_width - inset * 2) / math.max(1, _tabCount));

  int indexAt(double x) =>
      ((x - inset) / _tabWidth).floor().clamp(0, _maxIndex);

  void resize(double width, double height, int count) {
    if ((_width - width).abs() < 0.05 &&
        (_height - height).abs() < 0.05 &&
        _tabCount == count) {
      return;
    }
    _width = width;
    _height = height;
    _tabCount = count;
    _target = _target.clamp(0.0, _maxIndex.toDouble());
    if (!dragging) {
      _originX = _width / 2.0;
      _glowY = _height / 2.0;
    }
    _publish(notify: false);
  }

  void snapToRest(int visualIndex) {
    final clamped = visualIndex.clamp(0, _maxIndex).toDouble();
    dragging = false;
    _releasePending = false;
    _target = clamped;
    _pressTarget = 0.0;
    _shapeTarget = 1.0;
    _position.snapTo(clamped);
    _velocity.snapTo(0.0);
    _press.snapTo(0.0);
    _scaleX.snapTo(1.0);
    _scaleY.snapTo(1.0);
    _panel.snapTo(0.0);
    _trackY.snapTo(0.0);
    _trackX.snapTo(1.0);
    _trackPress.snapTo(1.0);
    _glow.snapTo(0.0);
    _originX = _width / 2.0;
    _glowY = _height / 2.0;
    running = false;
    _publish();
  }

  void select(int visualIndex) {
    dragging = false;
    final clamped = visualIndex >= 0
        ? visualIndex.clamp(0, _maxIndex).toDouble()
        : _target;
    if (_releasePending && (_target - clamped).abs() < 0.001) {
      // finish() already targeted this index; keep _pressTarget & _shapeTarget
      // intact so the NuvioMobile tap-release jelly flight curve isn't cut short.
      running = true;
      return;
    }
    _target = clamped;
    _releasePending = true;
    _pressTarget = 0.0;
    _shapeTarget = 1.0;
    running = true;
    notifyListeners();
  }

  void begin(double x, double y) {
    _downX = x;
    _downY = y.clamp(0.0, _height);
    _originX = _downX.clamp(0.0, _width);
    _glowY = _downY;
    _dragStartY = _trackY.value;
    _movedDistance = 0.0;
    _target = indexAt(_downX).toDouble();
    _dragStartTarget = _target;
    _dragStartPanel = _panel.value;
    dragging = true;
    _releasePending = false;
    _pressTarget = 1.0;
    _shapeTarget = 1.26;
    _panel.velocity = 0.0;
    running = true;
    notifyListeners();
  }

  int drag(double dx, double dy) {
    if (!dragging) return indexAt(_downX);
    _target = (_dragStartTarget + dx / _tabWidth).clamp(
      0.0,
      _maxIndex.toDouble(),
    );
    _panel.snapTo(_dragStartPanel + dx);
    _trackY.snapTo(_dragStartY + _jellyRubberBand(dy, _height) * 0.25);
    _trackX.snapTo(1.0 - (dy.abs() / 700.0).clamp(0.0, 1.0) * 0.08);
    _originX = (_downX + dx).clamp(0.0, _width);
    _glowY = (_downY + dy * 0.35).clamp(0.0, _height);
    _movedDistance = math.max(_movedDistance, math.max(dx.abs(), dy.abs()));
    _publish();
    return (_target + 0.5).floor().clamp(0, _maxIndex);
  }

  int finish() {
    final index = _movedDistance < 6.0
        ? indexAt(_downX)
        : (_target + 0.5).floor().clamp(0, _maxIndex);
    dragging = false;
    _panel.velocity = 0.0;
    _target = index.toDouble();
    _releasePending = true;
    running = true;
    notifyListeners();
    return index;
  }

  void cancel(int selectedVisualIndex) {
    dragging = false;
    _panel.velocity = 0.0;
    _releasePending = false;
    select(selectedVisualIndex);
  }

  void advance(double seconds) {
    final dt = seconds.clamp(0.0, 0.064);
    _target = _target.clamp(0.0, _maxIndex.toDouble());
    _position.advance(_target, dt);
    _velocity.advance(
      dragging && _maxIndex > 0 ? _position.velocity / _maxIndex : 0.0,
      dt,
    );
    if (!dragging) _panel.advance(0.0, dt);
    if (_releasePending &&
        (_position.value - _target).abs() < math.max(1, _maxIndex) * 0.025) {
      _releasePending = false;
      _pressTarget = 0.0;
      _shapeTarget = 1.0;
    }
    _press.advance(_pressTarget, dt);
    _scaleX.advance(_shapeTarget, dt);
    _scaleY.advance(_shapeTarget, dt);
    _trackPress.advance(dragging ? 1.026 : 1.0, dt);
    _glow.advance(dragging ? 1.0 : 0.0, dt);
    if (!dragging) {
      _trackY.advance(0.0, dt);
      _trackX.advance(1.0, dt);
      if (_trackX.isAtRest(1.0)) _originX = _width / 2.0;
    }
    running =
        dragging ||
        _releasePending ||
        !_position.isAtRest(_target) ||
        !_velocity.isAtRest(0.0) ||
        !_press.isAtRest(0.0) ||
        !_scaleX.isAtRest(1.0) ||
        !_scaleY.isAtRest(1.0) ||
        !_panel.isAtRest(0.0) ||
        !_trackY.isAtRest(0.0) ||
        !_trackX.isAtRest(1.0) ||
        !_trackPress.isAtRest(1.0) ||
        !_glow.isAtRest(0.0);
    _publish();
  }

  void _publish({bool notify = true}) {
    final speed = _velocity.value / 10.0;
    frame = _JellyFrame(
      position: _position.value,
      pillScaleX: _scaleX.value / (1.0 - (speed * 0.75).clamp(-0.22, 0.22)),
      pillScaleY: _scaleY.value * (1.0 - (speed * 0.25).clamp(-0.22, 0.22)),
      contentScale: 1.0 + 0.18 * _press.value,
      panelOffset: _jellyPanelOffset(_panel.value, _width),
      trackScale: _trackPress.value,
      trackScaleX: _trackX.value,
      trackOffsetY: _trackY.value,
      originX: _originX,
      glowY: _glowY,
      glowOpacity: _glow.value.clamp(0.0, 1.0),
    );
    if (notify) {
      notifyListeners();
    }
  }
}

/// Floating stadium-pill bottom navigation bar modeled on NuvioMobile's
/// `FloatingNavigationBar` & `JellyTabs` — featuring real-time hold inflation,
/// velocity-driven jelly stretch, 2D rubber-band capsule response, scroll-hiding
/// tab labels, full RTL mirroring, and zero `BackdropFilter`.
class EvaFloatingNavBar extends StatefulWidget {
  const EvaFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.showLabels = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<EvaFloatingNavItem> items;
  final bool showLabels;

  static const double shellWideBreakpoint = 840.0;

  /// Bottom scroll clearance so scrollable content passes behind the floating
  /// capsule's margins while resting completely above it at the bottom.
  static double bottomClearance(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= shellWideBreakpoint) return 0.0;
    return 86.0 + MediaQuery.paddingOf(context).bottom;
  }

  @override
  State<EvaFloatingNavBar> createState() => _EvaFloatingNavBarState();
}

class _EvaFloatingNavBarState extends State<EvaFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late final _JellyMotion _motion;
  late final Ticker _ticker;
  Duration? _lastTickElapsed;
  int? _activePointerId;
  Offset _pointerDownLocal = Offset.zero;
  int? _lastHapticVisualIdx;
  bool? _lastIsRtl;

  int _visualIndex(int logicalIndex, int count, bool isRtl) {
    if (count <= 0) return 0;
    final clamped = logicalIndex.clamp(0, count - 1);
    return isRtl ? (count - 1 - clamped) : clamped;
  }

  int _logicalIndex(int visualIndex, int count, bool isRtl) {
    if (count <= 0) return 0;
    final clamped = visualIndex.clamp(0, count - 1);
    return isRtl ? (count - 1 - clamped) : clamped;
  }

  @override
  void initState() {
    super.initState();
    _motion = _JellyMotion(widget.selectedIndex, widget.items.length);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final count = widget.items.length;
    if (_lastIsRtl != isRtl) {
      _lastIsRtl = isRtl;
      if (_activePointerId == null) {
        _motion.snapToRest(_visualIndex(widget.selectedIndex, count, isRtl));
      }
    }
  }

  @override
  void didUpdateWidget(covariant EvaFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isRtl = _lastIsRtl ?? false;
    final count = widget.items.length;
    final visualTarget = _visualIndex(widget.selectedIndex, count, isRtl);

    if (oldWidget.items.length != count && _activePointerId == null) {
      _motion.snapToRest(visualTarget);
      _stopTicker();
      return;
    }

    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _activePointerId == null) {
      final disableMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableMotion) {
        _motion.snapToRest(visualTarget);
        _stopTicker();
      } else {
        _motion.select(visualTarget);
        _ensureTickerRunning();
      }
    }
  }

  void _onTick(Duration elapsed) {
    final prev = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    final dt = prev == null
        ? (1.0 / 60.0)
        : (elapsed - prev).inMicroseconds / 1000000.0;

    _motion.advance(dt);

    if (!_motion.running && _activePointerId == null) {
      _stopTicker();
    }
  }

  void _ensureTickerRunning() {
    if (!_ticker.isActive) {
      _lastTickElapsed = null;
      _ticker.start();
    }
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastTickElapsed = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    final tokens = EvaTokens.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isDense = count >= 5;
    final screenW = MediaQuery.sizeOf(context).width;
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final capsuleBg = tokens.isNight
        ? Color.alphaBlend(
            tokens.brandPrimary.withValues(alpha: 0.07),
            const Color(0xF2151922),
          )
        : tokens.surfaceElevated;
    final capsuleBorder = Color.lerp(
      tokens.borderSubtle,
      tokens.brandPrimary,
      tokens.isNight ? 0.30 : (tokens.isLiquidGlass ? 0.26 : 0.16),
    )!;
    final activeFg = tokens.isNight
        ? Color.lerp(tokens.brandPrimary, Colors.white, 0.18)!
        : tokens.brandPrimary;
    final inactiveFg = tokens.textSecondary;
    final baseLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: isDense ? 10.5 : 11.5,
      height: 1.15,
      letterSpacing: isDense ? -0.15 : 0.0,
    );

    final clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.12);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.showLabels ? 1.0 : 0.0),
        duration: disableMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, labelFraction, _) {
          // NuvioMobile dynamic width & height: capsule sleekly compacts as labels hide
          final double baseMargin = isDense
              ? (screenW < 390 ? 10.0 : 16.0)
              : (screenW < 390 ? 20.0 : 28.0);
          final double collapsedExtraMargin = isDense ? 14.0 : 26.0;
          final double horizontalMargin =
              baseMargin + collapsedExtraMargin * (1.0 - labelFraction);
          final double maxCapsuleWidth = isDense ? 492.0 : 400.0;
          final double trackHeight =
              48.0 + (isDense ? 12.0 : 14.0) * labelFraction;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              6,
              horizontalMargin,
              12 + bottomSafe,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCapsuleWidth),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final trackWidth = constraints.maxWidth;
                    _motion.resize(trackWidth, trackHeight, count);

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (_activePointerId != null) return;
                        _activePointerId = event.pointer;
                        _pointerDownLocal = event.localPosition;
                        _motion.begin(
                          event.localPosition.dx,
                          event.localPosition.dy,
                        );
                        _lastHapticVisualIdx = _motion.indexAt(
                          event.localPosition.dx,
                        );
                        HapticFeedback.selectionClick();
                        if (!disableMotion) {
                          _ensureTickerRunning();
                        }
                      },
                      onPointerMove: (event) {
                        if (event.pointer != _activePointerId) return;
                        final delta = event.localPosition - _pointerDownLocal;
                        final nearestVisual = _motion.drag(delta.dx, delta.dy);
                        if (_lastHapticVisualIdx != null &&
                            _lastHapticVisualIdx != nearestVisual) {
                          HapticFeedback.selectionClick();
                        }
                        _lastHapticVisualIdx = nearestVisual;
                        if (!disableMotion) {
                          _ensureTickerRunning();
                        }
                      },
                      onPointerUp: (event) {
                        if (event.pointer != _activePointerId) return;
                        _activePointerId = null;
                        _lastHapticVisualIdx = null;
                        final visualIdx = _motion.finish();
                        final logicalIdx = _logicalIndex(
                          visualIdx,
                          count,
                          isRtl,
                        );
                        if (disableMotion) {
                          _motion.snapToRest(visualIdx);
                          _stopTicker();
                        } else {
                          _ensureTickerRunning();
                        }
                        if (logicalIdx != widget.selectedIndex) {
                          widget.onDestinationSelected(logicalIdx);
                        }
                      },
                      onPointerCancel: (event) {
                        if (event.pointer != _activePointerId) return;
                        _activePointerId = null;
                        _lastHapticVisualIdx = null;
                        final selectedVisual = _visualIndex(
                          widget.selectedIndex,
                          count,
                          isRtl,
                        );
                        if (disableMotion) {
                          _motion.snapToRest(selectedVisual);
                          _stopTicker();
                        } else {
                          _motion.cancel(selectedVisual);
                          _ensureTickerRunning();
                        }
                      },
                      child: ListenableBuilder(
                        listenable: _motion,
                        builder: (context, _) {
                          final frame = _motion.frame;
                          final originAlignX = trackWidth > 0
                              ? ((frame.originX / trackWidth) * 2.0 - 1.0)
                                    .clamp(-1.0, 1.0)
                              : 0.0;
                          // Quantize glow alpha to 16 steps & keep blurRadius constant
                          // so Impeller and CanvasKit cache the stadium RRect shadow mask
                          // across 60/120 Hz frames instead of regenerating Gaussian kernels.
                          final quantizedGlow =
                              (frame.glowOpacity * 16.0).round() / 16.0;

                          return Transform.translate(
                            offset: Offset(
                              frame.panelOffset,
                              frame.trackOffsetY,
                            ),
                            child: Transform(
                              alignment: Alignment(originAlignX, 0.0),
                              transform: Matrix4.diagonal3Values(
                                frame.trackScale * frame.trackScaleX,
                                frame.trackScale,
                                1.0,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: capsuleBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: capsuleBorder,
                                    width: math.max(tokens.borderWidth, 1.25),
                                  ),
                                  boxShadow: tokens.isNight
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.44,
                                            ),
                                            blurRadius: 22,
                                            spreadRadius: -2,
                                            offset: const Offset(0, 9),
                                          ),
                                          BoxShadow(
                                            color: tokens.brandPrimary
                                                .withValues(
                                                  alpha:
                                                      0.12 +
                                                      0.14 * quantizedGlow,
                                                ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: tokens.brandPrimary
                                                .withValues(
                                                  alpha:
                                                      (tokens.isLiquidGlass
                                                          ? 0.14
                                                          : 0.09) +
                                                      0.12 * quantizedGlow,
                                                ),
                                            blurRadius: 26,
                                            spreadRadius: -2,
                                            offset: const Offset(0, 10),
                                          ),
                                          const BoxShadow(
                                            color: Color(0x120F172A),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                ),
                                child: SizedBox(
                                  height: trackHeight,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        willChange: _motion.running,
                                        painter: _NuvioJellyPillPainter(
                                          motion: _motion,
                                          count: count,
                                          inset: _JellyMotion.inset,
                                          accentColor: tokens.brandPrimary,
                                          isNight: tokens.isNight,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(
                                          _JellyMotion.inset,
                                        ),
                                        child: Row(
                                          children: [
                                            for (int i = 0; i < count; i++)
                                              Expanded(
                                                child: _buildTabItem(
                                                  tokens: tokens,
                                                  item: widget.items[i],
                                                  index: i,
                                                  visualIndex: _visualIndex(
                                                    i,
                                                    count,
                                                    isRtl,
                                                  ),
                                                  frame: frame,
                                                  labelFraction: labelFraction,
                                                  isDense: isDense,
                                                  textScaler: clampedScaler,
                                                  activeFg: activeFg,
                                                  inactiveFg: inactiveFg,
                                                  baseLabelStyle:
                                                      baseLabelStyle,
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
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabItem({
    required EvaTokens tokens,
    required EvaFloatingNavItem item,
    required int index,
    required int visualIndex,
    required _JellyFrame frame,
    required double labelFraction,
    required bool isDense,
    required TextScaler textScaler,
    required Color activeFg,
    required Color inactiveFg,
    required TextStyle? baseLabelStyle,
  }) {
    final rawCoverage = (1.0 - (frame.position - visualIndex).abs()).clamp(
      0.0,
      1.0,
    );
    final coverage = rawCoverage < 0.001 ? 0.0 : rawCoverage;
    final effectiveContentScale = coverage == 0.0 ? 1.0 : frame.contentScale;

    return _EvaNavTabItem(
      item: item,
      isSelectedSemantics: index == widget.selectedIndex,
      coverage: coverage,
      contentScale: effectiveContentScale,
      labelFraction: labelFraction,
      isDense: isDense,
      textScaler: textScaler,
      activeFg: activeFg,
      inactiveFg: inactiveFg,
      dotBadgeColor: tokens.accentAppetite,
      baseLabelStyle: baseLabelStyle,
    );
  }
}

class _EvaNavTabItem extends StatelessWidget {
  const _EvaNavTabItem({
    required this.item,
    required this.isSelectedSemantics,
    required this.coverage,
    required this.contentScale,
    required this.labelFraction,
    required this.isDense,
    required this.textScaler,
    required this.activeFg,
    required this.inactiveFg,
    required this.dotBadgeColor,
    required this.baseLabelStyle,
  });

  final EvaFloatingNavItem item;
  final bool isSelectedSemantics;
  final double coverage;
  final double contentScale;
  final double labelFraction;
  final bool isDense;
  final TextScaler textScaler;
  final Color activeFg;
  final Color inactiveFg;
  final Color dotBadgeColor;
  final TextStyle? baseLabelStyle;

  @override
  Widget build(BuildContext context) {
    final isSelected = coverage >= 0.5;
    final fgColor = coverage <= 0.0
        ? inactiveFg
        : (coverage >= 1.0
              ? activeFg
              : Color.lerp(inactiveFg, activeFg, coverage)!);
    final iconSize = isDense ? 20.0 : 22.0;

    // NuvioMobile contentScale: active item blooms up to ~1.18x while holding the pill
    final itemScale = 1.0 + (0.06 + (contentScale - 1.0)) * coverage;

    Widget iconWidget = Icon(
      isSelected ? item.selectedIcon : item.icon,
      size: iconSize,
      color: fgColor,
    );

    if (item.badgeCount != null && item.badgeCount! > 0) {
      iconWidget = Badge(
        label: Text(
          '${item.badgeCount}',
          textScaler: textScaler,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
        child: iconWidget,
      );
    } else if (item.showDotBadge) {
      iconWidget = Badge(
        smallSize: 7.5,
        backgroundColor: dotBadgeColor,
        child: iconWidget,
      );
    }

    final clampedLabelFraction = labelFraction.clamp(0.0, 1.0);
    Widget? labelSection;
    if (clampedLabelFraction > 0.001) {
      final labelText = Text(
        item.label,
        textScaler: textScaler,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: baseLabelStyle?.copyWith(
          color: fgColor,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      labelSection = Align(
        alignment: Alignment.topCenter,
        heightFactor: clampedLabelFraction,
        child: clampedLabelFraction >= 0.999
            ? labelText
            : Opacity(opacity: clampedLabelFraction, child: labelText),
      );
    }

    final iconLiftY = -1.0 * coverage * labelFraction;
    final Widget liftedIcon = iconLiftY.abs() < 0.01
        ? iconWidget
        : Transform.translate(offset: Offset(0, iconLiftY), child: iconWidget);

    Widget column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        liftedIcon,
        if (labelSection != null) ...[
          SizedBox(height: (isDense ? 2.5 : 3.0) * labelFraction),
          labelSection,
        ],
      ],
    );

    if ((itemScale - 1.0).abs() >= 0.001) {
      column = Transform.scale(scale: itemScale, child: column);
    }

    return Semantics(
      selected: isSelectedSemantics,
      button: true,
      label: item.label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDense ? 2.0 : 4.0),
        child: column,
      ),
    );
  }
}

class _NuvioJellyPillPainter extends CustomPainter {
  _NuvioJellyPillPainter({
    required this.motion,
    required this.count,
    required this.inset,
    required this.accentColor,
    required this.isNight,
  }) : frame = motion.frame,
       super(repaint: motion);

  final _JellyMotion motion;
  final _JellyFrame frame;
  final int count;
  final double inset;
  final Color accentColor;
  final bool isNight;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0 || size.width <= inset * 2 || size.height <= inset * 2) {
      return;
    }

    final f = motion.frame;
    final tabWidth = (size.width - inset * 2) / count;
    final itemHeight = size.height - inset * 2;
    final centerX = inset + (f.position + 0.5) * tabWidth;
    final centerY = size.height / 2;
    final capsuleRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    canvas.save();
    canvas.clipRRect(capsuleRRect);

    // 1. Ambient pill glow + dynamic finger-hold spotlight glow (NuvioMobile drawJellyGlow)
    final holdBoost = f.glowOpacity;
    final glowRadius = math.max(tabWidth * (1.45 + 0.55 * holdBoost), 96.0);
    final glowCenter = Offset(
      centerX + (f.originX - centerX) * 0.35 * holdBoost,
      centerY + (f.glowY - centerY) * 0.35 * holdBoost,
    );
    final baseGlowAlpha =
        (isNight ? 0.20 : 0.11) + (isNight ? 0.14 : 0.10) * holdBoost;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: baseGlowAlpha),
          accentColor.withValues(alpha: baseGlowAlpha * 0.42),
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius));
    canvas.drawRRect(capsuleRRect, glowPaint);

    // 2. Volume-preserving & hold-inflating jelly stadium pill (NuvioMobile jellyPillPath)
    final halfW = (tabWidth * f.pillScaleX) / 2;
    final halfH = (itemHeight * f.pillScaleY) / 2;
    final baseRadius = math.min(tabWidth, itemHeight) / 2;

    final pillRect = Rect.fromLTRB(
      centerX - halfW,
      centerY - halfH,
      centerX + halfW,
      centerY + halfH,
    );
    final pillRRect = RRect.fromRectAndCorners(
      pillRect,
      topLeft: Radius.elliptical(
        baseRadius * f.pillScaleX,
        baseRadius * f.pillScaleY,
      ),
      topRight: Radius.elliptical(
        baseRadius * f.pillScaleX,
        baseRadius * f.pillScaleY,
      ),
      bottomLeft: Radius.elliptical(
        baseRadius * f.pillScaleX,
        baseRadius * f.pillScaleY,
      ),
      bottomRight: Radius.elliptical(
        baseRadius * f.pillScaleX,
        baseRadius * f.pillScaleY,
      ),
    );

    final topAlpha =
        (isNight ? 0.28 : 0.16) + (isNight ? 0.09 : 0.06) * holdBoost;
    final bottomAlpha =
        (isNight ? 0.16 : 0.09) + (isNight ? 0.06 : 0.04) * holdBoost;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: topAlpha),
          accentColor.withValues(alpha: bottomAlpha),
        ],
      ).createShader(pillRect);
    canvas.drawRRect(pillRRect, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15 + 0.35 * holdBoost
      ..color = accentColor.withValues(
        alpha: (isNight ? 0.44 : 0.25) + 0.14 * holdBoost,
      );
    canvas.drawRRect(pillRRect, borderPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NuvioJellyPillPainter oldDelegate) {
    final a = oldDelegate.frame;
    final b = frame;
    return a.position != b.position ||
        a.pillScaleX != b.pillScaleX ||
        a.pillScaleY != b.pillScaleY ||
        a.glowOpacity != b.glowOpacity ||
        a.originX != b.originX ||
        oldDelegate.count != count ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isNight != isNight;
  }
}

/// Tactile press scale micro-interaction that never blocks child gestures.
class EvaPressable extends StatefulWidget {
  const EvaPressable({
    super.key,
    required this.child,
    this.pressedScale = 0.975,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<EvaPressable> createState() => _EvaPressableState();
}

class _EvaPressableState extends State<EvaPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableMotion) return widget.child;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Staggered fade + upward entrance animation with constant widget topology
/// (FadeTransition over RepaintBoundary — zero RenderObject reparenting and
/// zero saveLayer at rest once alpha == 255).
class EvaReveal extends StatefulWidget {
  const EvaReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 10,
  });

  final Widget child;
  final int index;
  final double offsetY;

  @override
  State<EvaReveal> createState() => _EvaRevealState();
}

class _EvaRevealState extends State<EvaReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    final clamped = math.min(widget.index, 7);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 190 + clamped * 28),
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _curved.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableMotion) return widget.child;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _curved,
        child: AnimatedBuilder(
          animation: _curved,
          child: widget.child,
          builder: (context, inner) {
            final dy = (1.0 - _curved.value) * widget.offsetY;
            return Transform.translate(
              offset: Offset(0.0, dy),
              child: inner,
            );
          },
        ),
      ),
    );
  }
}

/// Smooth tab-switch transition wrapper for StatefulNavigationShell that
/// preserves child state with constant widget topology (zero RenderObject
/// reparenting at start/end and zero offscreen saveLayer at rest).
class EvaShellTransition extends StatefulWidget {
  const EvaShellTransition({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<EvaShellTransition> createState() => _EvaShellTransitionState();
}

class _EvaShellTransitionState extends State<EvaShellTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1.0,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.4,
    end: 1.0,
  ).animate(_curved);
  double _slideDir = 1.0;

  @override
  void didUpdateWidget(covariant EvaShellTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final disableMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!disableMotion) {
        _slideDir = widget.currentIndex > oldWidget.currentIndex ? 1.0 : -1.0;
        _ctrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: AnimatedBuilder(
          animation: _curved,
          child: widget.child,
          builder: (context, child) {
            final dx = (1.0 - _curved.value) * 8.0 * _slideDir;
            return Transform.translate(
              offset: Offset(dx, 0.0),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Diagonal 135° split swatch for Light Blue / Light Red / Monochrome themes,
/// or solid circle for single-hue themes.
class EvaThemeSwatch extends StatelessWidget {
  const EvaThemeSwatch({
    super.key,
    required this.preset,
    required this.isNight,
    this.size = 18,
  });

  final EvaAccentPreset preset;
  final bool isNight;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final hasDiagonal =
        !isNight && preset.swatchStart != null && preset.swatchEnd != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.borderSubtle,
          width: 1.2,
        ),
        color: hasDiagonal
            ? null
            : (isNight ? preset.nightColor : preset.daylightColor),
        gradient: hasDiagonal
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.49, 0.51, 1.0],
                colors: [
                  preset.swatchStart!,
                  preset.swatchStart!,
                  preset.swatchEnd!,
                  preset.swatchEnd!,
                ],
              )
            : null,
      ),
    );
  }
}

class EvaBrandLogo extends StatelessWidget {
  const EvaBrandLogo({super.key, this.size = 40, this.hero = false});

  static const ColorFilter _kMonochromeFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  final double size;
  final bool hero;

  Widget _buildLayeredEmblem(
    EvaTokens tokens,
    double fallbackIconSize,
    int cachePx,
  ) {
    Widget swooshLayer = Image.asset(
      'assets/images/logo_swoosh.png',
      fit: BoxFit.contain,
      cacheWidth: cachePx,
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
      swooshLayer = ColorFiltered(
        colorFilter: _kMonochromeFilter,
        child: swooshLayer,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        swooshLayer,
        Image.asset(
          'assets/images/logo_fill.png',
          fit: BoxFit.contain,
          cacheWidth: cachePx,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          color: tokens.logoFill,
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        Image.asset(
          'assets/images/logo_outline.png',
          fit: BoxFit.contain,
          cacheWidth: cachePx,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          color: tokens.logoOutline,
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, _, _) => Icon(
            Icons.restaurant_menu_rounded,
            color: tokens.brandPrimary,
            size: fallbackIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(64, 944);
    if (hero) {
      return RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size * 0.72,
          child: ClipRect(
            child: Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size * 0.72,
              fit: BoxFit.fitWidth,
              alignment: Alignment.center,
              cacheWidth: cachePx,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Icon(
                Icons.restaurant_menu_rounded,
                color: tokens.brandPrimary,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(
            color: tokens.borderSubtle,
            width: tokens.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(size * 0.025),
        child: _buildLayeredEmblem(tokens, size * 0.58, cachePx),
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (radius * 2 * dpr).round().clamp(64, 800);
    return AnimatedScale(
      scale: isSelected ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.surfaceSubtle,
          border: Border.all(
            color: isSelected ? tokens.brandPrimary : tokens.borderSubtle,
            width: isSelected ? 2.5 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipOval(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            cacheWidth: cachePx,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              Icons.person_rounded,
              color: tokens.brandPrimary,
              size: radius,
            ),
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
    final trimmed = imageUrl.trim();
    final String resolved;
    if (trimmed.isEmpty) {
      resolved = '';
    } else if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      resolved = trimmed;
    } else {
      resolved = ref.watch(socketClientProvider).resolveMediaUrl(trimmed);
    }

    Widget content;
    if (resolved.isEmpty) {
      content = _fallbackPlaceholder(tokens);
    } else {
      content = Image.network(
        resolved,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.5, color: foreground),
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
            const SizedBox(width: 5),
          ],
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                label,
                key: ValueKey<String>(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Directional rolling counter/price text for cart totals, line subtotals, and badges.
class EvaAnimatedCounterText extends StatefulWidget {
  const EvaAnimatedCounterText({
    super.key,
    required this.text,
    required this.numericValue,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final num numericValue;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;

  @override
  State<EvaAnimatedCounterText> createState() => _EvaAnimatedCounterTextState();
}

class _EvaAnimatedCounterTextState extends State<EvaAnimatedCounterText> {
  double _dir = 1.0;

  @override
  void didUpdateWidget(covariant EvaAnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.numericValue != oldWidget.numericValue) {
      _dir = widget.numericValue > oldWidget.numericValue ? 1.0 : -1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final resolvedStyle = (widget.style ?? DefaultTextStyle.of(context).style)
        .copyWith(fontFeatures: EvaThemeBuilder.tabularNums);

    if (disableMotion) {
      return Text(
        widget.text,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        style: resolvedStyle,
      );
    }

    final currentKey = ValueKey<String>(widget.text);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 210),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: switch (widget.textAlign) {
            TextAlign.center => Alignment.center,
            TextAlign.right || TextAlign.end => AlignmentDirectional.centerEnd,
            _ => AlignmentDirectional.centerStart,
          },
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, anim) {
          final isIncoming = child.key == currentKey;
          final offsetTween = Tween<Offset>(
            begin: Offset(0, isIncoming ? 0.52 * _dir : -0.52 * _dir),
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
        child: Text(
          widget.text,
          key: currentKey,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          style: resolvedStyle,
        ),
      ),
    );
  }
}

class EvaQuantityStepper extends StatefulWidget {
  const EvaQuantityStepper({
    super.key,
    required this.quantity,
    required this.addLabel,
    required this.onIncrement,
    required this.onDecrement,
    this.disabled = false,
    this.maxReached = false,
    this.compact = false,
    this.fullWidth = false,
    this.highlightRemoveAtOne = false,
  });

  final int quantity;
  final String addLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool disabled;
  final bool maxReached;
  final bool compact;
  final bool fullWidth;
  final bool highlightRemoveAtOne;

  @override
  State<EvaQuantityStepper> createState() => _EvaQuantityStepperState();
}

class _EvaQuantityStepperState extends State<EvaQuantityStepper>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _kStepperFadeTween = CurveTween(
    curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
  );
  static final Animatable<double> _kStepperScaleTween = CurveTween(
    curve: Curves.easeOutBack,
  );

  double _dir = 1.0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.065,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.065,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 58,
      ),
    ]).animate(_pulseCtrl);
  }

  @override
  void didUpdateWidget(covariant EvaQuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity != oldWidget.quantity) {
      _dir = widget.quantity > oldWidget.quantity ? 1.0 : -1.0;
      final disableMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!disableMotion && oldWidget.quantity > 0 && widget.quantity > 0) {
        _pulseCtrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final height = widget.compact ? 36.0 : 40.0;
    final emptyFg = widget.disabled ? tokens.textSecondary : tokens.brandPrimary;
    final quantity = widget.quantity;
    final currentQtyKey = ValueKey<int>(quantity);
    final isRemoveAtOne = quantity == 1;

    return ScaleTransition(
      scale: _pulseScale,
      child: AnimatedSwitcher(
        duration: disableMotion
            ? Duration.zero
            : const Duration(milliseconds: 190),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: widget.fullWidth
              ? Alignment.center
              : AlignmentDirectional.centerEnd,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: _kStepperFadeTween.animate(anim),
          child: ScaleTransition(
            scale: _kStepperScaleTween.animate(anim),
            child: child,
          ),
        ),
        child: quantity <= 0
            ? SizedBox(
                key: const ValueKey('stepper_empty'),
                width: widget.fullWidth ? double.infinity : null,
                height: height,
                child: Material(
                  color: widget.disabled
                      ? tokens.surfaceSubtle
                      : tokens.brandSoftBg,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: widget.disabled
                          ? tokens.borderSubtle
                          : tokens.brandPrimary.withValues(alpha: 0.28),
                      width: 1.15,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: widget.disabled
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            widget.onIncrement();
                          },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: widget.fullWidth
                            ? double.infinity
                            : (widget.compact ? 82.0 : 104.0),
                        minHeight: height,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.compact ? 12 : 16,
                        ),
                        child: Row(
                          mainAxisSize: widget.fullWidth
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: widget.compact ? 17 : 18,
                              color: emptyFg,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.addLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                strutStyle: const StrutStyle(
                                  forceStrutHeight: true,
                                  height: 1.0,
                                  leading: 0,
                                ),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: emptyFg,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : SizedBox(
                key: const ValueKey('stepper_active'),
                width: widget.fullWidth ? double.infinity : null,
                height: height,
                child: Material(
                  color: tokens.brandPrimary,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: widget.fullWidth
                          ? double.infinity
                          : (widget.compact ? 98.0 : 114.0),
                    ),
                    child: Row(
                      mainAxisSize: widget.fullWidth
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _StepperIconBtn(
                          icon: isRemoveAtOne
                              ? Icons.delete_outline_rounded
                              : Icons.remove_rounded,
                          color: tokens.brandOnPrimary,
                          highlightBg: widget.highlightRemoveAtOne &&
                                  isRemoveAtOne
                              ? Colors.black.withValues(alpha: 0.16)
                              : null,
                          size: height,
                          onTap: () {
                            if (isRemoveAtOne) {
                              HapticFeedback.lightImpact();
                            } else {
                              HapticFeedback.selectionClick();
                            }
                            widget.onDecrement();
                          },
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 26),
                          child: ClipRect(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: disableMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) {
                                  final isIncoming = child.key == currentQtyKey;
                                  final slideTween = Tween<Offset>(
                                    begin: Offset(
                                      0,
                                      isIncoming ? 0.65 * _dir : -0.65 * _dir,
                                    ),
                                    end: Offset.zero,
                                  );
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: slideTween.animate(anim),
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.84,
                                          end: 1.0,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  '$quantity',
                                  key: currentQtyKey,
                                  textAlign: TextAlign.center,
                                  strutStyle: const StrutStyle(
                                    forceStrutHeight: true,
                                    height: 1.0,
                                    leading: 0,
                                  ),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: tokens.brandOnPrimary,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        fontFeatures:
                                            EvaThemeBuilder.tabularNums,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _StepperIconBtn(
                          icon: Icons.add_rounded,
                          color: widget.maxReached
                              ? tokens.brandOnPrimary.withValues(alpha: 0.38)
                              : tokens.brandOnPrimary,
                          size: height,
                          onTap: widget.maxReached
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.onIncrement();
                                },
                        ),
                      ],
                    ),
                  ),
                ),
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
    this.highlightBg,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? highlightBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlightBg ?? Colors.transparent,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: disableMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              icon,
              key: ValueKey<int>(icon.codePoint),
              size: 17.5,
              color: color,
            ),
          ),
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
    final topInset = MediaQuery.paddingOf(context).top;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: phase == SocketConnectionPhase.connected
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 8 + topInset, 16, 8),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: tokens.statusPendingFg,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(socketClientProvider).reconnectNow(),
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
            ),
    );
  }
}

/// Crisp deterministic ticket barcode graphic for the Live Pickup Pass.
class EvaPickupBarcodeBar extends StatelessWidget {
  const EvaPickupBarcodeBar({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return RepaintBoundary(
      child: SizedBox(
        height: 40,
        width: 220,
        child: CustomPaint(
          painter: _BarcodePainter(
            orderId: orderId,
            color: tokens.textPrimary.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.orderId, required this.color});

  final String orderId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final seed = orderId.codeUnits;
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
      oldDelegate.color != color || oldDelegate.orderId != orderId;
}
