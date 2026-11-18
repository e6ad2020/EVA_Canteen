import 'dart:ui' show FontFeature, lerpDouble;
import 'package:material_ui/material_ui.dart';

enum EvaSurfaceMode { daylight, nightShift }

enum EvaNavBarBehavior {
  adaptive('navbar_adaptive'),
  expanded('navbar_expanded'),
  compact('navbar_compact');

  const EvaNavBarBehavior(this.i18nKey);
  final String i18nKey;

  static EvaNavBarBehavior fromStorageName(String? raw) {
    return EvaNavBarBehavior.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => EvaNavBarBehavior.adaptive,
    );
  }
}

enum EvaAccentPreset {
  lightBlue(
    i18nKey: 'theme_light_blue',
    fallbackLabel: 'Light Blue',
    daylightColor: Color(0xFF0D47A1),
    nightColor: Color(0xFF64B5F6),
    swatchStart: Color(0xFFFFFFFF),
    swatchEnd: Color(0xFF90CAF9),
    wallpaperFolder: 'assets/images/wallpapers/light_blue',
  ),
  lightRed(
    i18nKey: 'theme_light_red',
    fallbackLabel: 'Light Red',
    daylightColor: Color(0xFFB71C1C),
    nightColor: Color(0xFFEF5350),
    swatchStart: Color(0xFFFFFFFF),
    swatchEnd: Color(0xFFEF9A9A),
    wallpaperFolder: 'assets/images/wallpapers/light_red',
  ),
  cobalt(
    i18nKey: 'theme_cobalt',
    fallbackLabel: 'Cobalt',
    daylightColor: Color(0xFF1652D0),
    nightColor: Color(0xFF5B95FF),
  ),
  emerald(
    i18nKey: 'theme_emerald',
    fallbackLabel: 'Emerald',
    daylightColor: Color(0xFF0B7A53),
    nightColor: Color(0xFF34D399),
  ),
  violet(
    i18nKey: 'theme_violet',
    fallbackLabel: 'Violet',
    daylightColor: Color(0xFF7E22CE),
    nightColor: Color(0xFFC084FC),
  ),
  amber(
    i18nKey: 'theme_amber',
    fallbackLabel: 'Amber',
    daylightColor: Color(0xFFB45309),
    nightColor: Color(0xFFFBBF24),
  ),
  monochrome(
    i18nKey: 'theme_monochrome',
    fallbackLabel: 'Monochrome',
    daylightColor: Color(0xFF141417),
    nightColor: Color(0xFFF4F4F5),
    swatchStart: Color(0xFFFFFFFF),
    swatchEnd: Color(0xFF141417),
  );

  const EvaAccentPreset({
    required this.i18nKey,
    required this.fallbackLabel,
    required this.daylightColor,
    required this.nightColor,
    this.swatchStart,
    this.swatchEnd,
    this.wallpaperFolder,
  });

  final String i18nKey;
  final String fallbackLabel;
  final Color daylightColor;
  final Color nightColor;
  final Color? swatchStart;
  final Color? swatchEnd;
  final String? wallpaperFolder;

  bool get isWallpaperLightTheme => wallpaperFolder != null;

  static EvaAccentPreset fromStorageName(String? raw) {
    if (raw == null || raw.isEmpty) return EvaAccentPreset.lightBlue;
    if (raw == 'light-blue') return EvaAccentPreset.lightBlue;
    if (raw == 'light-red' || raw == 'terracotta') {
      return EvaAccentPreset.lightRed;
    }
    if (raw == 'plum') return EvaAccentPreset.violet;
    for (final preset in EvaAccentPreset.values) {
      if (preset.name == raw) return preset;
    }
    return EvaAccentPreset.lightBlue;
  }
}

@immutable
class EvaTokens extends ThemeExtension<EvaTokens> {
  const EvaTokens({
    required this.isNight,
    required this.isLiquidGlass,
    required this.wallpaperFolder,
    required this.canvasBackground,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.borderSubtle,
    required this.borderWidth,
    required this.textPrimary,
    required this.textSecondary,
    required this.brandPrimary,
    required this.brandOnPrimary,
    required this.brandSoftBg,
    required this.accentAppetite,
    required this.statusPendingBg,
    required this.statusPendingFg,
    required this.statusPreparingBg,
    required this.statusPreparingFg,
    required this.statusDeliveredBg,
    required this.statusDeliveredFg,
    required this.statusClosedBg,
    required this.statusClosedFg,
    required this.showDoodlePattern,
    this.logoFill = const Color(0xFF5CE1E6),
    this.logoOutline = const Color(0xFF3B01D9),
    this.logoSwooshTint = const Color(0xFFFFFFFF),
    this.isMonochromeLogo = false,
    this.cardRadius = 16,
    this.controlRadius = 12,
  });

  final bool isNight;
  final bool isLiquidGlass;
  final String? wallpaperFolder;
  final Color canvasBackground;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color borderSubtle;
  final double borderWidth;
  final Color textPrimary;
  final Color textSecondary;
  final Color brandPrimary;
  final Color brandOnPrimary;
  final Color brandSoftBg;
  final Color accentAppetite;
  final Color statusPendingBg;
  final Color statusPendingFg;
  final Color statusPreparingBg;
  final Color statusPreparingFg;
  final Color statusDeliveredBg;
  final Color statusDeliveredFg;
  final Color statusClosedBg;
  final Color statusClosedFg;
  final bool showDoodlePattern;
  final Color logoFill;
  final Color logoOutline;
  final Color logoSwooshTint;
  final bool isMonochromeLogo;
  final double cardRadius;
  final double controlRadius;

  static (Color fill, Color outline, Color swooshTint, bool mono)
  _resolveLogoPalette(EvaAccentPreset accent, {required bool isNight}) {
    return switch (accent) {
      EvaAccentPreset.lightBlue => (
        const Color(0xFF5CE1E6),
        const Color(0xFF3B01D9),
        const Color(0xFFFFFFFF),
        false,
      ),
      EvaAccentPreset.lightRed => (
        isNight ? const Color(0xFFFF8A80) : const Color(0xFFFF9E9E),
        isNight ? const Color(0xFF7F0019) : const Color(0xFF8E001C),
        const Color(0xFFFFD584),
        false,
      ),
      EvaAccentPreset.cobalt => (
        const Color(0xFF67E8F9),
        isNight ? const Color(0xFF2563EB) : const Color(0xFF1E3A8A),
        const Color(0xFFFFFFFF),
        false,
      ),
      EvaAccentPreset.emerald => (
        const Color(0xFF6EE7B7),
        isNight ? const Color(0xFF047857) : const Color(0xFF064E3B),
        const Color(0xFFD9F99D),
        false,
      ),
      EvaAccentPreset.violet => (
        const Color(0xFFE9D5FF),
        isNight ? const Color(0xFF6D28D9) : const Color(0xFF4C1D95),
        const Color(0xFFF5D0FE),
        false,
      ),
      EvaAccentPreset.amber => (
        const Color(0xFFFDE047),
        isNight ? const Color(0xFF92400E) : const Color(0xFF78350F),
        const Color(0xFFFDBA74),
        false,
      ),
      EvaAccentPreset.monochrome => (
        const Color(0xFFF4F4F5),
        isNight ? const Color(0xFF27272A) : const Color(0xFF18181B),
        const Color(0xFFD4D4D8),
        true,
      ),
    };
  }

  factory EvaTokens.resolve({
    required EvaSurfaceMode mode,
    required EvaAccentPreset accent,
    required bool showDoodlePattern,
  }) {
    final isNight = mode == EvaSurfaceMode.nightShift;
    final primary = isNight ? accent.nightColor : accent.daylightColor;
    final onPrimary = primary.computeLuminance() > 0.45
        ? const Color(0xFF11141A)
        : const Color(0xFFFFFFFF);
    final (logoFill, logoOutline, logoSwooshTint, isMonoLogo) =
        _resolveLogoPalette(accent, isNight: isNight);

    if (isNight) {
      return EvaTokens(
        isNight: true,
        isLiquidGlass: false,
        wallpaperFolder: null,
        canvasBackground: const Color(0xFF0D1117),
        surfaceCard: const Color(0xFF161B23),
        surfaceElevated: const Color(0xFF1C232E),
        surfaceSubtle: const Color(0xFF212936),
        borderSubtle: const Color(0xFF2B3545),
        borderWidth: 1,
        textPrimary: const Color(0xFFF3F6FA),
        textSecondary: const Color(0xFF98A5B8),
        brandPrimary: primary,
        brandOnPrimary: onPrimary,
        brandSoftBg: primary.withValues(alpha: 0.16),
        accentAppetite: const Color(0xFFF97316),
        statusPendingBg: const Color(0xFF3A290B),
        statusPendingFg: const Color(0xFFFBBF24),
        statusPreparingBg: const Color(0xFF12284B),
        statusPreparingFg: const Color(0xFF60A5FA),
        statusDeliveredBg: const Color(0xFF0A3224),
        statusDeliveredFg: const Color(0xFF34D399),
        statusClosedBg: const Color(0xFF3A1418),
        statusClosedFg: const Color(0xFFF87171),
        showDoodlePattern: showDoodlePattern,
        logoFill: logoFill,
        logoOutline: logoOutline,
        logoSwooshTint: logoSwooshTint,
        isMonochromeLogo: isMonoLogo,
      );
    }

    // Authentic 'Light Blue' theme from the EVA Canteen web project:
    // White & Sapphire palette (#0D47A1), #E3F2FD accents, #90A4AE borders,
    // illustrated food wallpaper + crisp zero-blur porcelain surfaces.
    if (accent == EvaAccentPreset.lightBlue) {
      return EvaTokens(
        isNight: false,
        isLiquidGlass: true,
        wallpaperFolder: accent.wallpaperFolder,
        canvasBackground: const Color(0xFFF8FBFF),
        surfaceCard: const Color(0xF2FFFFFF),
        surfaceElevated: const Color(0xFAFFFFFF),
        surfaceSubtle: const Color(0xFFE6F2FE),
        borderSubtle: const Color(0xFF90A4AE),
        borderWidth: 1.5,
        textPrimary: const Color(0xFF0D47A1),
        textSecondary: const Color(0xFF355C8C),
        brandPrimary: const Color(0xFF0D47A1),
        brandOnPrimary: const Color(0xFFFFFFFF),
        brandSoftBg: const Color(0xFFE3F2FD),
        accentAppetite: const Color(0xFFEF6C00),
        statusPendingBg: const Color(0xFFFFF3E0),
        statusPendingFg: const Color(0xFFE65100),
        statusPreparingBg: const Color(0xFFE3F2FD),
        statusPreparingFg: const Color(0xFF0D47A1),
        statusDeliveredBg: const Color(0xFFE8F5E9),
        statusDeliveredFg: const Color(0xFF2E7D32),
        statusClosedBg: const Color(0xFFFFEBEE),
        statusClosedFg: const Color(0xFFC62828),
        showDoodlePattern: false,
        logoFill: logoFill,
        logoOutline: logoOutline,
        logoSwooshTint: logoSwooshTint,
        isMonochromeLogo: isMonoLogo,
      );
    }

    // Authentic 'Light Red' theme from the EVA Canteen web project:
    // White & Crimson palette (#B71C1C), #FFEBEE accents, #EF9A9A borders,
    // illustrated food wallpaper + crisp zero-blur porcelain surfaces.
    if (accent == EvaAccentPreset.lightRed) {
      return EvaTokens(
        isNight: false,
        isLiquidGlass: true,
        wallpaperFolder: accent.wallpaperFolder,
        canvasBackground: const Color(0xFFFFF9FA),
        surfaceCard: const Color(0xF2FFFFFF),
        surfaceElevated: const Color(0xFAFFFFFF),
        surfaceSubtle: const Color(0xFFFFECEF),
        borderSubtle: const Color(0xFFEF9A9A),
        borderWidth: 1.5,
        textPrimary: const Color(0xFFB71C1C),
        textSecondary: const Color(0xFF883232),
        brandPrimary: const Color(0xFFB71C1C),
        brandOnPrimary: const Color(0xFFFFFFFF),
        brandSoftBg: const Color(0xFFFFEBEE),
        accentAppetite: const Color(0xFFD84315),
        statusPendingBg: const Color(0xFFFFF3E0),
        statusPendingFg: const Color(0xFFE65100),
        statusPreparingBg: const Color(0xFFFFF8E1),
        statusPreparingFg: const Color(0xFFF57F17),
        statusDeliveredBg: const Color(0xFFE8F5E9),
        statusDeliveredFg: const Color(0xFF2E7D32),
        statusClosedBg: const Color(0xFFFFEBEE),
        statusClosedFg: const Color(0xFFB71C1C),
        showDoodlePattern: false,
        logoFill: logoFill,
        logoOutline: logoOutline,
        logoSwooshTint: logoSwooshTint,
        isMonochromeLogo: isMonoLogo,
      );
    }

    return EvaTokens(
      isNight: false,
      isLiquidGlass: false,
      wallpaperFolder: null,
      canvasBackground: const Color(0xFFF5F7FA),
      surfaceCard: const Color(0xFFFFFFFF),
      surfaceElevated: const Color(0xFFFFFFFF),
      surfaceSubtle: const Color(0xFFEEF1F6),
      borderSubtle: accent == EvaAccentPreset.monochrome
          ? const Color(0xFFD4D4D8)
          : const Color(0xFFE0E6F0),
      borderWidth: 1,
      textPrimary: const Color(0xFF111827),
      textSecondary: const Color(0xFF526075),
      brandPrimary: primary,
      brandOnPrimary: onPrimary,
      brandSoftBg: primary.withValues(alpha: 0.10),
      accentAppetite: const Color(0xFFEA580C),
      statusPendingBg: const Color(0xFFFEF3C7),
      statusPendingFg: const Color(0xFFB45309),
      statusPreparingBg: const Color(0xFFDBEAFE),
      statusPreparingFg: const Color(0xFF1D4ED8),
      statusDeliveredBg: const Color(0xFFD1FAE5),
      statusDeliveredFg: const Color(0xFF047857),
      statusClosedBg: const Color(0xFFFEE2E2),
      statusClosedFg: const Color(0xFFB91C1C),
      showDoodlePattern: showDoodlePattern,
      logoFill: logoFill,
      logoOutline: logoOutline,
      logoSwooshTint: logoSwooshTint,
      isMonochromeLogo: isMonoLogo,
    );
  }

  static EvaTokens of(BuildContext context) {
    return Theme.of(context).extension<EvaTokens>() ??
        EvaTokens.resolve(
          mode: EvaSurfaceMode.daylight,
          accent: EvaAccentPreset.lightBlue,
          showDoodlePattern: true,
        );
  }

  @override
  EvaTokens copyWith({
    bool? isNight,
    bool? isLiquidGlass,
    String? wallpaperFolder,
    Color? canvasBackground,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? borderSubtle,
    double? borderWidth,
    Color? textPrimary,
    Color? textSecondary,
    Color? brandPrimary,
    Color? brandOnPrimary,
    Color? brandSoftBg,
    Color? accentAppetite,
    Color? statusPendingBg,
    Color? statusPendingFg,
    Color? statusPreparingBg,
    Color? statusPreparingFg,
    Color? statusDeliveredBg,
    Color? statusDeliveredFg,
    Color? statusClosedBg,
    Color? statusClosedFg,
    bool? showDoodlePattern,
    Color? logoFill,
    Color? logoOutline,
    Color? logoSwooshTint,
    bool? isMonochromeLogo,
    double? cardRadius,
    double? controlRadius,
  }) {
    return EvaTokens(
      isNight: isNight ?? this.isNight,
      isLiquidGlass: isLiquidGlass ?? this.isLiquidGlass,
      wallpaperFolder: wallpaperFolder ?? this.wallpaperFolder,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderWidth: borderWidth ?? this.borderWidth,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
      brandSoftBg: brandSoftBg ?? this.brandSoftBg,
      accentAppetite: accentAppetite ?? this.accentAppetite,
      statusPendingBg: statusPendingBg ?? this.statusPendingBg,
      statusPendingFg: statusPendingFg ?? this.statusPendingFg,
      statusPreparingBg: statusPreparingBg ?? this.statusPreparingBg,
      statusPreparingFg: statusPreparingFg ?? this.statusPreparingFg,
      statusDeliveredBg: statusDeliveredBg ?? this.statusDeliveredBg,
      statusDeliveredFg: statusDeliveredFg ?? this.statusDeliveredFg,
      statusClosedBg: statusClosedBg ?? this.statusClosedBg,
      statusClosedFg: statusClosedFg ?? this.statusClosedFg,
      showDoodlePattern: showDoodlePattern ?? this.showDoodlePattern,
      logoFill: logoFill ?? this.logoFill,
      logoOutline: logoOutline ?? this.logoOutline,
      logoSwooshTint: logoSwooshTint ?? this.logoSwooshTint,
      isMonochromeLogo: isMonochromeLogo ?? this.isMonochromeLogo,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
    );
  }

  @override
  EvaTokens lerp(ThemeExtension<EvaTokens>? other, double t) {
    if (other is! EvaTokens) return this;
    return EvaTokens(
      isNight: t < 0.5 ? isNight : other.isNight,
      isLiquidGlass: t < 0.5 ? isLiquidGlass : other.isLiquidGlass,
      wallpaperFolder: t < 0.5 ? wallpaperFolder : other.wallpaperFolder,
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t) ?? 1,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      brandSoftBg: Color.lerp(brandSoftBg, other.brandSoftBg, t)!,
      accentAppetite: Color.lerp(accentAppetite, other.accentAppetite, t)!,
      statusPendingBg: Color.lerp(statusPendingBg, other.statusPendingBg, t)!,
      statusPendingFg: Color.lerp(statusPendingFg, other.statusPendingFg, t)!,
      statusPreparingBg: Color.lerp(
        statusPreparingBg,
        other.statusPreparingBg,
        t,
      )!,
      statusPreparingFg: Color.lerp(
        statusPreparingFg,
        other.statusPreparingFg,
        t,
      )!,
      statusDeliveredBg: Color.lerp(
        statusDeliveredBg,
        other.statusDeliveredBg,
        t,
      )!,
      statusDeliveredFg: Color.lerp(
        statusDeliveredFg,
        other.statusDeliveredFg,
        t,
      )!,
      statusClosedBg: Color.lerp(statusClosedBg, other.statusClosedBg, t)!,
      statusClosedFg: Color.lerp(statusClosedFg, other.statusClosedFg, t)!,
      showDoodlePattern: t < 0.5 ? showDoodlePattern : other.showDoodlePattern,
      logoFill: Color.lerp(logoFill, other.logoFill, t)!,
      logoOutline: Color.lerp(logoOutline, other.logoOutline, t)!,
      logoSwooshTint: Color.lerp(logoSwooshTint, other.logoSwooshTint, t)!,
      isMonochromeLogo: t < 0.5 ? isMonochromeLogo : other.isMonochromeLogo,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? 16,
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t) ?? 12,
    );
  }
}

class EvaThemeBuilder {
  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  static ThemeData build({
    required Locale locale,
    required EvaSurfaceMode mode,
    required EvaAccentPreset accent,
    required bool showDoodlePattern,
  }) {
    final tokens = EvaTokens.resolve(
      mode: mode,
      accent: accent,
      showDoodlePattern: showDoodlePattern,
    );
    final isAr = locale.languageCode == 'ar';
    final fontFamily = isAr ? 'Cairo' : 'Nunito';
    final fallbackFonts = isAr ? const ['Nunito'] : const ['Cairo'];
    final brightness = tokens.isNight ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.brandPrimary,
      onPrimary: tokens.brandOnPrimary,
      secondary: tokens.accentAppetite,
      onSecondary: Colors.white,
      error: tokens.statusClosedFg,
      onError: Colors.white,
      surface: tokens.surfaceElevated,
      onSurface: tokens.textPrimary,
      outline: tokens.borderSubtle,
      outlineVariant: tokens.borderSubtle,
      surfaceContainerHighest: tokens.surfaceSubtle,
    );

    TextStyle style(
      double size,
      FontWeight weight,
      double enHeight,
      double arHeight, {
      Color? color,
      double letterSpacing = 0,
      bool tabular = false,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fallbackFonts,
        fontSize: size,
        fontWeight: weight,
        height: isAr ? arHeight : enHeight,
        color: color ?? tokens.textPrimary,
        letterSpacing: isAr ? 0 : letterSpacing,
        fontFeatures: tabular ? tabularNums : null,
      );
    }

    final textTheme = TextTheme(
      displayMedium: style(
        38,
        FontWeight.w700,
        1.14,
        1.25,
        letterSpacing: -0.6,
        tabular: true,
      ),
      headlineMedium: style(
        24,
        FontWeight.w700,
        1.22,
        1.36,
        letterSpacing: -0.3,
      ),
      headlineSmall: style(
        19,
        FontWeight.w700,
        1.26,
        1.40,
        letterSpacing: -0.2,
      ),
      titleLarge: style(17, FontWeight.w700, 1.28, 1.42),
      titleMedium: style(15, FontWeight.w700, 1.28, 1.42),
      titleSmall: style(13, FontWeight.w600, 1.25, 1.38),
      bodyLarge: style(15, FontWeight.w400, 1.45, 1.60),
      bodyMedium: style(14, FontWeight.w400, 1.45, 1.58),
      bodySmall: style(
        12,
        FontWeight.w500,
        1.38,
        1.52,
        color: tokens.textSecondary,
      ),
      labelLarge: style(14, FontWeight.w700, 1.20, 1.32),
      labelMedium: style(12, FontWeight.w600, 1.20, 1.32),
      labelSmall: style(
        11,
        FontWeight.w600,
        1.20,
        1.30,
        color: tokens.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvasBackground,
      fontFamily: fontFamily,
      textTheme: textTheme,
      extensions: [tokens],
      dividerColor: tokens.borderSubtle,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surfaceElevated,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(
            color: tokens.borderSubtle,
            width: tokens.borderWidth,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.brandSoftBg,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return style(
            11.5,
            selected ? FontWeight.w700 : FontWeight.w600,
            1.15,
            1.25,
            color: selected ? tokens.brandPrimary : tokens.textSecondary,
          ).copyWith(overflow: TextOverflow.ellipsis);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? tokens.brandPrimary : tokens.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surfaceElevated,
        indicatorColor: tokens.brandSoftBg,
        selectedIconTheme: IconThemeData(color: tokens.brandPrimary, size: 22),
        unselectedIconTheme: IconThemeData(
          color: tokens.textSecondary,
          size: 22,
        ),
        selectedLabelTextStyle: style(
          12,
          FontWeight.w700,
          1.2,
          1.3,
          color: tokens.brandPrimary,
        ),
        unselectedLabelTextStyle: style(
          12,
          FontWeight.w600,
          1.2,
          1.3,
          color: tokens.textSecondary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          side: WidgetStatePropertyAll(
            BorderSide(color: tokens.borderSubtle, width: tokens.borderWidth),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.brandPrimary;
            }
            return tokens.surfaceCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.brandOnPrimary;
            }
            return tokens.textPrimary;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.isLiquidGlass
            ? const Color(0xCCFFFFFF)
            : tokens.surfaceSubtle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: style(
          13.5,
          FontWeight.w400,
          1.35,
          1.45,
          color: tokens.textSecondary,
        ),
        labelStyle: style(
          13,
          FontWeight.w600,
          1.3,
          1.4,
          color: tokens.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(
            color: tokens.borderSubtle,
            width: tokens.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(
            color: tokens.borderSubtle,
            width: tokens.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.brandPrimary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brandPrimary,
          foregroundColor: tokens.brandOnPrimary,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          backgroundColor: tokens.isLiquidGlass
              ? const Color(0xB8FFFFFF)
              : null,
          minimumSize: const Size(44, 44),
          side: BorderSide(
            color: tokens.borderSubtle,
            width: tokens.borderWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.isNight
            ? const Color(0xFF283242)
            : const Color(0xFF182234),
        contentTextStyle: style(
          13,
          FontWeight.w600,
          1.35,
          1.5,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
