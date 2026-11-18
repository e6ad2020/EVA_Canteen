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
    final wallpaperFolder = tokens.wallpaperFolder;

    return ColoredBox(
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
  late final Animation<double> _curved;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_settled) {
        setState(() => _settled = true);
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
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

    if (_settled || disableMotion) return bar;

    return AnimatedBuilder(
      animation: _curved,
      child: bar,
      builder: (context, child) {
        final t = _curved.value;
        if (t >= 0.999) return child!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -10),
            child: Transform.scale(
              scale: 0.985 + (0.015 * t),
              child: child,
            ),
          ),
        );
      },
    );
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

/// Floating stadium-pill bottom navigation bar inspired by NuvioMobile's
/// `FloatingNavigationBar` & `JellyTabs` — featuring a volume-preserving
/// jelly-stretch sliding indicator, radial accent glow, tap + horizontal
/// thumb-scrubbing gestures, full RTL mirroring, and zero `BackdropFilter`.
class EvaFloatingNavBar extends StatefulWidget {
  const EvaFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<EvaFloatingNavItem> items;

  static const double shellWideBreakpoint = 840.0;

  /// Bottom scroll clearance so scrollable content passes behind the floating
  /// capsule's margins while resting completely above it at the bottom.
  static double bottomClearance(BuildContext context) {
    return MediaQuery.sizeOf(context).width < shellWideBreakpoint ? 86.0 : 0.0;
  }

  @override
  State<EvaFloatingNavBar> createState() => _EvaFloatingNavBarState();
}

class _EvaFloatingNavBarState extends State<EvaFloatingNavBar>
    with SingleTickerProviderStateMixin {
  static const double _pillInset = 4.5;

  late final AnimationController _ctrl;
  late double _fromLogicalPos;
  late double _toLogicalPos;
  double? _dragLogicalPos;
  int? _lastDragHapticIndex;

  @override
  void initState() {
    super.initState();
    final initial = widget.selectedIndex
        .clamp(0, math.max(0, widget.items.length - 1))
        .toDouble();
    _fromLogicalPos = initial;
    _toLogicalPos = initial;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant EvaFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxIdx = math.max(0, widget.items.length - 1).toDouble();
    _fromLogicalPos = _fromLogicalPos.clamp(0.0, maxIdx);
    _toLogicalPos = _toLogicalPos.clamp(0.0, maxIdx);

    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _dragLogicalPos == null) {
      final current = _currentLogicalPosition;
      _fromLogicalPos = current;
      _toLogicalPos = widget.selectedIndex.toDouble().clamp(0.0, maxIdx);
      final disableMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableMotion) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _currentLogicalPosition {
    if (_dragLogicalPos != null) return _dragLogicalPos!;
    final t = Curves.easeOutCubic.transform(_ctrl.value);
    return _fromLogicalPos + (_toLogicalPos - _fromLogicalPos) * t;
  }

  double _dxToLogicalPos({
    required double dx,
    required double trackWidth,
    required int count,
    required bool isRtl,
  }) {
    final usableW = math.max(1.0, trackWidth - _pillInset * 2);
    final tabW = usableW / count;
    final visualPos = ((dx - _pillInset) / tabW - 0.5).clamp(
      0.0,
      (count - 1).toDouble(),
    );
    return isRtl ? (count - 1) - visualPos : visualPos;
  }

  void _updateDrag({
    required double dx,
    required double trackWidth,
    required int count,
    required bool isRtl,
  }) {
    final nextLogical = _dxToLogicalPos(
      dx: dx,
      trackWidth: trackWidth,
      count: count,
      isRtl: isRtl,
    );
    final nearest = nextLogical.round().clamp(0, count - 1);
    if (_lastDragHapticIndex != null && _lastDragHapticIndex != nearest) {
      HapticFeedback.selectionClick();
    }
    _lastDragHapticIndex = nearest;
    setState(() {
      _dragLogicalPos = nextLogical;
    });
  }

  void _finishDrag(int count) {
    final dragged = _dragLogicalPos;
    if (dragged == null) return;
    final targetIdx = dragged.round().clamp(0, count - 1);
    setState(() {
      _fromLogicalPos = dragged;
      _toLogicalPos = targetIdx.toDouble();
      _dragLogicalPos = null;
      _lastDragHapticIndex = null;
    });
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableMotion) {
      _ctrl.value = 1.0;
    } else {
      _ctrl.forward(from: 0.0);
    }
    if (targetIdx != widget.selectedIndex) {
      widget.onDestinationSelected(targetIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    final tokens = EvaTokens.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isDense = count >= 5;
    final screenW = MediaQuery.sizeOf(context).width;

    final double horizontalMargin = isDense
        ? (screenW < 390 ? 10.0 : 16.0)
        : (screenW < 390 ? 20.0 : 28.0);
    final double maxCapsuleWidth = isDense ? 492.0 : 400.0;
    final double trackHeight = isDense ? 60.0 : 62.0;

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

    final clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.12);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalMargin, 6, horizontalMargin, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCapsuleWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _lastDragHapticIndex = widget.selectedIndex;
                    _updateDrag(
                      dx: details.localPosition.dx,
                      trackWidth: trackWidth,
                      count: count,
                      isRtl: isRtl,
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateDrag(
                      dx: details.localPosition.dx,
                      trackWidth: trackWidth,
                      count: count,
                      isRtl: isRtl,
                    );
                  },
                  onHorizontalDragEnd: (_) => _finishDrag(count),
                  onHorizontalDragCancel: () {
                    setState(() {
                      _dragLogicalPos = null;
                      _lastDragHapticIndex = null;
                      _fromLogicalPos = widget.selectedIndex.toDouble();
                      _toLogicalPos = widget.selectedIndex.toDouble();
                      _ctrl.value = 1.0;
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final rawT = _ctrl.value;
                      final logicalPos = _currentLogicalPosition;
                      final visualPos = isRtl
                          ? (count - 1) - logicalPos
                          : logicalPos;

                      final flightWave = _dragLogicalPos != null
                          ? 0.35
                          : math.sin(rawT * math.pi);
                      final hopDistance = (_toLogicalPos - _fromLogicalPos)
                          .abs()
                          .clamp(0.0, 2.2);
                      final pillScaleX =
                          1.0 + 0.13 * flightWave * (0.65 + 0.35 * hopDistance);
                      final pillScaleY = 1.0 - 0.055 * flightWave;
                      final trackScale = _dragLogicalPos != null
                          ? 1.014
                          : (1.0 + 0.008 * flightWave);

                      return Transform.scale(
                        scale: trackScale,
                        child: Container(
                          height: trackHeight,
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
                                      color: tokens.brandPrimary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: tokens.brandPrimary.withValues(
                                        alpha: tokens.isLiquidGlass
                                            ? 0.14
                                            : 0.09,
                                      ),
                                      blurRadius: 24,
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
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _NuvioJellyPillPainter(
                                  visualPosition: visualPos,
                                  count: count,
                                  inset: _pillInset,
                                  pillScaleX: pillScaleX,
                                  pillScaleY: pillScaleY,
                                  accentColor: tokens.brandPrimary,
                                  isNight: tokens.isNight,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(_pillInset),
                                child: Row(
                                  children: [
                                    for (int i = 0; i < count; i++)
                                      Expanded(
                                        child: _buildTabItem(
                                          context: context,
                                          tokens: tokens,
                                          item: widget.items[i],
                                          index: i,
                                          selectionProgress:
                                              (1.0 - (logicalPos - i).abs())
                                                  .clamp(0.0, 1.0),
                                          isDense: isDense,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required EvaTokens tokens,
    required EvaFloatingNavItem item,
    required int index,
    required double selectionProgress,
    required bool isDense,
  }) {
    final isSelected = selectionProgress >= 0.5;
    final activeFg = tokens.isNight
        ? Color.lerp(tokens.brandPrimary, Colors.white, 0.18)!
        : tokens.brandPrimary;
    final inactiveFg = tokens.textSecondary;
    final fgColor = Color.lerp(inactiveFg, activeFg, selectionProgress)!;
    final iconSize = isDense ? 20.0 : 22.0;

    Widget iconWidget = Icon(
      isSelected ? item.selectedIcon : item.icon,
      size: iconSize,
      color: fgColor,
    );

    if (item.badgeCount != null && item.badgeCount! > 0) {
      iconWidget = Badge(
        label: Text(
          '${item.badgeCount}',
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
        child: iconWidget,
      );
    } else if (item.showDotBadge) {
      iconWidget = Badge(
        smallSize: 7.5,
        backgroundColor: tokens.accentAppetite,
        child: iconWidget,
      );
    }

    return Semantics(
      selected: index == widget.selectedIndex,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index != widget.selectedIndex) {
            widget.onDestinationSelected(index);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDense ? 2.0 : 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -1.0 * selectionProgress),
                child: Transform.scale(
                  scale: 1.0 + 0.08 * selectionProgress,
                  child: iconWidget,
                ),
              ),
              SizedBox(height: isDense ? 2.5 : 3.0),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: isDense ? 10.5 : 11.5,
                  height: 1.15,
                  letterSpacing: isDense ? -0.15 : 0.0,
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NuvioJellyPillPainter extends CustomPainter {
  const _NuvioJellyPillPainter({
    required this.visualPosition,
    required this.count,
    required this.inset,
    required this.pillScaleX,
    required this.pillScaleY,
    required this.accentColor,
    required this.isNight,
  });

  final double visualPosition;
  final int count;
  final double inset;
  final double pillScaleX;
  final double pillScaleY;
  final Color accentColor;
  final bool isNight;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0 || size.width <= inset * 2 || size.height <= inset * 2) {
      return;
    }

    final tabWidth = (size.width - inset * 2) / count;
    final itemHeight = size.height - inset * 2;
    final centerX = inset + (visualPosition + 0.5) * tabWidth;
    final centerY = size.height / 2;

    // 1. Subtle radial ambient glow behind active pill (modeled on NuvioMobile's drawJellyGlow)
    final glowRadius = math.max(tabWidth * 1.45, 92.0);
    final glowCenter = Offset(centerX, centerY);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: isNight ? 0.20 : 0.11),
          accentColor.withValues(alpha: isNight ? 0.07 : 0.04),
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius));
    canvas.drawRect(Offset.zero & size, glowPaint);

    // 2. Volume-preserving jelly stadium pill
    final rawLeft = centerX - (tabWidth * pillScaleX) / 2;
    final rawRight = centerX + (tabWidth * pillScaleX) / 2;
    final clampedLeft = rawLeft.clamp(inset, size.width - inset);
    final clampedRight = rawRight.clamp(inset, size.width - inset);
    final halfH = (itemHeight * pillScaleY) / 2;

    final pillRect = Rect.fromLTRB(
      clampedLeft,
      centerY - halfH,
      clampedRight,
      centerY + halfH,
    );
    final pillRRect = RRect.fromRectAndRadius(
      pillRect,
      Radius.circular(pillRect.height / 2),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: isNight ? 0.28 : 0.16),
          accentColor.withValues(alpha: isNight ? 0.16 : 0.09),
        ],
      ).createShader(pillRect);
    canvas.drawRRect(pillRRect, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = accentColor.withValues(alpha: isNight ? 0.44 : 0.24);
    canvas.drawRRect(pillRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NuvioJellyPillPainter oldDelegate) {
    return oldDelegate.visualPosition != visualPosition ||
        oldDelegate.count != count ||
        oldDelegate.pillScaleX != pillScaleX ||
        oldDelegate.pillScaleY != pillScaleY ||
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

/// Staggered fade + upward entrance animation that detaches its Opacity &
/// Transform layers once complete so scrolling stays 100% flicker-free.
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
  late final Animation<double> _curved;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final clamped = math.min(widget.index, 7);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 190 + clamped * 28),
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_done) {
        setState(() => _done = true);
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_done || disableMotion) return widget.child;

    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, inner) {
        final t = _curved.value;
        if (t >= 0.999) return inner!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offsetY),
            child: inner,
          ),
        );
      },
    );
  }
}

/// Smooth tab-switch transition wrapper for StatefulNavigationShell that
/// preserves child state and detaches Opacity/Transform at rest.
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
  late final Animation<double> _curved = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
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
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        if (t >= 0.999) return child!;
        return Opacity(
          opacity: (0.4 + 0.6 * t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - t) * 8 * _slideDir, 0),
            child: child,
          ),
        );
      },
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
  const EvaBrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: tokens.borderSubtle, width: tokens.borderWidth),
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
    this.fullWidth = false,
  });

  final int quantity;
  final String addLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool disabled;
  final bool maxReached;
  final bool compact;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = EvaTokens.of(context);
    final height = compact ? 34.0 : 40.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: quantity <= 0
          ? SizedBox(
              key: const ValueKey('stepper_empty'),
              width: fullWidth ? double.infinity : null,
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
                  minimumSize: Size(compact ? 64 : 84, height),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: disabled
                          ? tokens.borderSubtle
                          : tokens.brandPrimary.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                icon: Icon(Icons.add_rounded, size: compact ? 16 : 18),
                label: Text(
                  addLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              width: fullWidth ? double.infinity : null,
              height: height,
              decoration: BoxDecoration(
                color: tokens.brandPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: fullWidth
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
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
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      child: Text(
                        '$quantity',
                        key: ValueKey<int>(quantity),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: tokens.brandOnPrimary,
                          fontFeatures: EvaThemeBuilder.tabularNums,
                        ),
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
        child: Icon(icon, size: 17, color: color),
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

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: phase == SocketConnectionPhase.connected
          ? const SizedBox.shrink()
          : Container(
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
