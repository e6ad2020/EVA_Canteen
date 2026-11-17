import 'dart:ui' show FontFeature, lerpDouble;
import 'package:material_ui/material_ui.dart';

enum EvaSurfaceMode { daylight, nightShift }

enum EvaAccentPreset {
  cobalt('Cobalt Blue', Color(0xFF1B5DE0), Color(0xFF4C8DFF)),
  emerald('Campus Emerald', Color(0xFF0D8A5F), Color(0xFF34D399)),
  terracotta('Bistro Terracotta', Color(0xFFC84B31), Color(0xFFFF7A59)),
  amber('Warm Harvest', Color(0xFFB45309), Color(0xFFFBBF24)),
  plum('Royal Berry', Color(0xFF86198F), Color(0xFFE879F9)),
  monochrome('Crisp Mono', Color(0xFF18181B), Color(0xFFF4F4F5));

  const EvaAccentPreset(this.label, this.daylightColor, this.nightColor);

  final String label;
  final Color daylightColor;
  final Color nightColor;
}

@immutable
class EvaTokens extends ThemeExtension<EvaTokens> {
  const EvaTokens({
    required this.isNight,
    required this.canvasBackground,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.borderSubtle,
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
    this.cardRadius = 16,
    this.controlRadius = 12,
  });

  final bool isNight;
  final Color canvasBackground;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color borderSubtle;
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
  final double cardRadius;
  final double controlRadius;

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

    if (isNight) {
      return EvaTokens(
        isNight: true,
        canvasBackground: const Color(0xFF0F1217),
        surfaceCard: const Color(0xFF181D25),
        surfaceElevated: const Color(0xFF1E2530),
        surfaceSubtle: const Color(0xFF232B38),
        borderSubtle: const Color(0xFF2C3646),
        textPrimary: const Color(0xFFF3F5F8),
        textSecondary: const Color(0xFF9BA7B8),
        brandPrimary: primary,
        brandOnPrimary: onPrimary,
        brandSoftBg: primary.withValues(alpha: 0.16),
        accentAppetite: const Color(0xFFFF7A29),
        statusPendingBg: const Color(0xFF3B2A0C),
        statusPendingFg: const Color(0xFFFBBF24),
        statusPreparingBg: const Color(0xFF13284C),
        statusPreparingFg: const Color(0xFF60A5FA),
        statusDeliveredBg: const Color(0xFF0B3326),
        statusDeliveredFg: const Color(0xFF34D399),
        statusClosedBg: const Color(0xFF3B1418),
        statusClosedFg: const Color(0xFFF87171),
        showDoodlePattern: showDoodlePattern,
      );
    }

    return EvaTokens(
      isNight: false,
      canvasBackground: const Color(0xFFF7F8FA),
      surfaceCard: const Color(0xFFFFFFFF),
      surfaceElevated: const Color(0xFFFFFFFF),
      surfaceSubtle: const Color(0xFFEEF1F6),
      borderSubtle: const Color(0xFFE1E6EF),
      textPrimary: const Color(0xFF121826),
      textSecondary: const Color(0xFF526077),
      brandPrimary: primary,
      brandOnPrimary: onPrimary,
      brandSoftBg: primary.withValues(alpha: 0.10),
      accentAppetite: const Color(0xFFE85D04),
      statusPendingBg: const Color(0xFFFEF3C7),
      statusPendingFg: const Color(0xFFB45309),
      statusPreparingBg: const Color(0xFFDBEAFE),
      statusPreparingFg: const Color(0xFF1D4ED8),
      statusDeliveredBg: const Color(0xFFD1FAE5),
      statusDeliveredFg: const Color(0xFF047857),
      statusClosedBg: const Color(0xFFFEE2E2),
      statusClosedFg: const Color(0xFFB91C1C),
      showDoodlePattern: showDoodlePattern,
    );
  }

  static EvaTokens of(BuildContext context) {
    return Theme.of(context).extension<EvaTokens>() ??
        EvaTokens.resolve(
          mode: EvaSurfaceMode.daylight,
          accent: EvaAccentPreset.cobalt,
          showDoodlePattern: true,
        );
  }

  @override
  EvaTokens copyWith({
    bool? isNight,
    Color? canvasBackground,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? borderSubtle,
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
    double? cardRadius,
    double? controlRadius,
  }) {
    return EvaTokens(
      isNight: isNight ?? this.isNight,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderSubtle: borderSubtle ?? this.borderSubtle,
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
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
    );
  }

  @override
  EvaTokens lerp(ThemeExtension<EvaTokens>? other, double t) {
    if (other is! EvaTokens) return this;
    return EvaTokens(
      isNight: t < 0.5 ? isNight : other.isNight,
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      brandSoftBg: Color.lerp(brandSoftBg, other.brandSoftBg, t)!,
      accentAppetite: Color.lerp(accentAppetite, other.accentAppetite, t)!,
      statusPendingBg: Color.lerp(statusPendingBg, other.statusPendingBg, t)!,
      statusPendingFg: Color.lerp(statusPendingFg, other.statusPendingFg, t)!,
      statusPreparingBg: Color.lerp(statusPreparingBg, other.statusPreparingBg, t)!,
      statusPreparingFg: Color.lerp(statusPreparingFg, other.statusPreparingFg, t)!,
      statusDeliveredBg: Color.lerp(statusDeliveredBg, other.statusDeliveredBg, t)!,
      statusDeliveredFg: Color.lerp(statusDeliveredFg, other.statusDeliveredFg, t)!,
      statusClosedBg: Color.lerp(statusClosedBg, other.statusClosedBg, t)!,
      statusClosedFg: Color.lerp(statusClosedFg, other.statusClosedFg, t)!,
      showDoodlePattern: t < 0.5 ? showDoodlePattern : other.showDoodlePattern,
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
      surface: tokens.surfaceCard,
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
      displayMedium: style(38, FontWeight.w700, 1.15, 1.25, letterSpacing: -0.5, tabular: true),
      headlineMedium: style(24, FontWeight.w700, 1.25, 1.40, letterSpacing: -0.2),
      headlineSmall: style(20, FontWeight.w700, 1.28, 1.42),
      titleLarge: style(18, FontWeight.w600, 1.30, 1.45),
      titleMedium: style(15, FontWeight.w700, 1.30, 1.45),
      titleSmall: style(13, FontWeight.w600, 1.25, 1.40),
      bodyLarge: style(15, FontWeight.w400, 1.45, 1.60),
      bodyMedium: style(14, FontWeight.w400, 1.45, 1.60),
      bodySmall: style(12, FontWeight.w400, 1.40, 1.55, color: tokens.textSecondary),
      labelLarge: style(14, FontWeight.w700, 1.20, 1.35),
      labelMedium: style(12, FontWeight.w600, 1.20, 1.35),
      labelSmall: style(11, FontWeight.w600, 1.20, 1.35, color: tokens.textSecondary),
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
        backgroundColor: tokens.surfaceCard,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSubtle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: style(14, FontWeight.w400, 1.4, 1.5, color: tokens.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.borderSubtle),
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
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(48, 46),
          side: BorderSide(color: tokens.borderSubtle),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.isNight
            ? const Color(0xFF283242)
            : const Color(0xFF182234),
        contentTextStyle: style(13, FontWeight.w600, 1.35, 1.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
