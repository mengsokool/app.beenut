import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;
import 'package:flutter/material.dart';

/// DLS Colors Theme Extension & Palette Definitions.
@immutable
class DlsColors extends ThemeExtension<DlsColors> {
  const DlsColors({
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkDisabled,
    required this.border,
    required this.borderSubtle,
    required this.accent,
    required this.accentHover,
    required this.accentActive,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.streamViewport,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkDisabled;
  final Color border;
  final Color borderSubtle;
  final Color accent;
  final Color accentHover;
  final Color accentActive;
  final Color accentSoft;
  final Color onAccent;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color streamViewport;

  // Backward compatibility & semantic aliases
  Color get raised => surfaceRaised;
  Color get ink => inkPrimary;
  Color get muted => inkSecondary;
  Color get disabled => inkDisabled;
  Color get line => border;
  Color get lineSubtle => borderSubtle;
  Color get primaryAction => accent;
  Color get primaryActionHover => accentHover;
  Color get primaryActionActive => accentActive;
  Color get primaryActionSoft => accentSoft;
  Color get onPrimaryAction => onAccent;

  /// Neutral desktop palette with color reserved for actions and status.
  static const light = DlsColors(
    canvas: Color(0xFFF4F4F4),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF4F4F4),
    surfaceRaised: Color(0xFFE0E0E0),
    inkPrimary: Color(0xFF161616),
    inkSecondary: Color(0xFF525252),
    inkDisabled: Color(0xFF6F6F6F),
    border: Color(0xFF8D8D8D),
    borderSubtle: Color(0xFFE0E0E0),
    accent: Color(0xFF0F62FE),
    accentHover: Color(0xFF0353E9),
    accentActive: Color(0xFF002D9C),
    accentSoft: Color(0xFFEDF5FF),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2D6A4F),
    successSoft: Color(0xFFD8F3DC),
    warning: Color(0xFFC85A17),
    warningSoft: Color(0xFFFFEDD5),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEE2E2),
    info: Color(0xFF2563EB),
    infoSoft: Color(0xFFDBEAFE),
    streamViewport: Color(0xFF0C0A09),
  );

  /// Palette 2: Dark Obsidian (#121110)
  static const dark = DlsColors(
    canvas: Color(0xFF161616),
    surface: Color(0xFF262626),
    surfaceSubtle: Color(0xFF393939),
    surfaceRaised: Color(0xFF525252),
    inkPrimary: Color(0xFFF4F4F4),
    inkSecondary: Color(0xFFC6C6C6),
    inkDisabled: Color(0xFFA8A8A8),
    border: Color(0xFF6F6F6F),
    borderSubtle: Color(0xFF525252),
    accent: Color(0xFF78A9FF),
    accentHover: Color(0xFFA6C8FF),
    accentActive: Color(0xFF4589FF),
    accentSoft: Color(0xFF002D9C),
    onAccent: Color(0xFF161616),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF0A3824),
    warning: Color(0xFFFB923C),
    warningSoft: Color(0xFF3D1B0A),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF451A1A),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF122645),
    streamViewport: Color(0xFF050505),
  );

  /// Palette 3: Kiosk High-Contrast (WCAG AAA #000000 / #FFFFFF / #FFD600)
  static const kioskHighContrast = DlsColors(
    canvas: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceSubtle: Color(0xFF1E1E1E),
    surfaceRaised: Color(0xFF2C2C2C),
    inkPrimary: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFE0E0E0),
    inkDisabled: Color(0xFF808080),
    border: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFA0A0A0),
    accent: Color(0xFFFFD600),
    accentHover: Color(0xFFFFEE58),
    accentActive: Color(0xFFFFC400),
    accentSoft: Color(0xFF332B00),
    onAccent: Color(0xFF000000),
    success: Color(0xFF00E676),
    successSoft: Color(0xFF003319),
    warning: Color(0xFFFF9100),
    warningSoft: Color(0xFF331D00),
    danger: Color(0xFFFF1744),
    dangerSoft: Color(0xFF33050E),
    info: Color(0xFF00B0FF),
    infoSoft: Color(0xFF002233),
    streamViewport: Color(0xFF000000),
  );

  @override
  DlsColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkDisabled,
    Color? border,
    Color? borderSubtle,
    Color? accent,
    Color? accentHover,
    Color? accentActive,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? streamViewport,
  }) {
    return DlsColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentActive: accentActive ?? this.accentActive,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      streamViewport: streamViewport ?? this.streamViewport,
    );
  }

  @override
  DlsColors lerp(ThemeExtension<DlsColors>? other, double t) {
    if (other is! DlsColors) return this;
    return DlsColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkDisabled: Color.lerp(inkDisabled, other.inkDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentActive: Color.lerp(accentActive, other.accentActive, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      streamViewport: Color.lerp(streamViewport, other.streamViewport, t)!,
    );
  }
}

/// DLS Radii Theme Extension & Token Definitions.
@immutable
class DlsRadii extends ThemeExtension<DlsRadii> {
  const DlsRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  static const standard = DlsRadii(
    xs: 0.0,
    sm: 0.0,
    md: 0.0,
    lg: 0.0,
    xl: 0.0,
    pill: 0.0,
  );

  BorderRadius borderXs() => BorderRadius.circular(xs);
  BorderRadius borderSm() => BorderRadius.circular(sm);
  BorderRadius borderMd() => BorderRadius.circular(md);
  BorderRadius borderLg() => BorderRadius.circular(lg);
  BorderRadius borderXl() => BorderRadius.circular(xl);
  BorderRadius borderPill() => BorderRadius.circular(pill);

  @override
  DlsRadii copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? pill,
  }) {
    return DlsRadii(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  @override
  DlsRadii lerp(ThemeExtension<DlsRadii>? other, double t) {
    if (other is! DlsRadii) return this;
    return DlsRadii(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      pill: lerpDouble(pill, other.pill, t)!,
    );
  }
}

/// DLS Spacing Theme Extension & Touchscreen Ergonomics.
@immutable
class DlsSpacing extends ThemeExtension<DlsSpacing> {
  const DlsSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.hero,
    this.touchTargetMin = 48.0,
    this.touchTargetStandard = 56.0,
    this.touchTargetHero = 64.0,
  });

  final double xs; // 4.0
  final double sm; // 8.0
  final double md; // 12.0
  final double lg; // 16.0
  final double xl; // 24.0
  final double xxl; // 32.0
  final double hero; // 48.0

  final double touchTargetMin; // 48.0
  final double touchTargetStandard; // 56.0
  final double touchTargetHero; // 64.0

  static const standard = DlsSpacing(
    xs: 4.0,
    sm: 8.0,
    md: 12.0,
    lg: 16.0,
    xl: 24.0,
    xxl: 32.0,
    hero: 48.0,
  );

  @override
  DlsSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? hero,
    double? touchTargetMin,
    double? touchTargetStandard,
    double? touchTargetHero,
  }) {
    return DlsSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      hero: hero ?? this.hero,
      touchTargetMin: touchTargetMin ?? this.touchTargetMin,
      touchTargetStandard: touchTargetStandard ?? this.touchTargetStandard,
      touchTargetHero: touchTargetHero ?? this.touchTargetHero,
    );
  }

  @override
  DlsSpacing lerp(ThemeExtension<DlsSpacing>? other, double t) {
    if (other is! DlsSpacing) return this;
    return DlsSpacing(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
      hero: lerpDouble(hero, other.hero, t)!,
      touchTargetMin: lerpDouble(touchTargetMin, other.touchTargetMin, t)!,
      touchTargetStandard: lerpDouble(
        touchTargetStandard,
        other.touchTargetStandard,
        t,
      )!,
      touchTargetHero: lerpDouble(touchTargetHero, other.touchTargetHero, t)!,
    );
  }
}

/// DLS Shadows Theme Extension & Diffuse Ambient Shadows.
@immutable
class DlsShadows extends ThemeExtension<DlsShadows> {
  const DlsShadows({
    required this.softSm,
    required this.softMd,
    required this.softLg,
    this.glowPrimary = const [],
    this.glowSuccess = const [],
  });

  final List<BoxShadow> softSm;
  final List<BoxShadow> softMd;
  final List<BoxShadow> softLg;
  final List<BoxShadow> glowPrimary;
  final List<BoxShadow> glowSuccess;

  // Convenience aliases
  List<BoxShadow> get low => softSm;
  List<BoxShadow> get medium => softMd;
  List<BoxShadow> get high => softLg;

  static final light = DlsShadows(
    softSm: const [
      BoxShadow(color: Color(0x09000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    softMd: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
    softLg: const [
      BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 8)),
    ],
    glowPrimary: const [],
    glowSuccess: const [],
  );

  static final dark = DlsShadows(
    softSm: const [
      BoxShadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
    softMd: const [
      BoxShadow(color: Color(0x50000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    softLg: const [
      BoxShadow(
        color: Color(0x70000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
    glowPrimary: const [],
    glowSuccess: const [],
  );

  static const kioskHighContrast = DlsShadows(
    softSm: [],
    softMd: [],
    softLg: [],
    glowPrimary: [],
    glowSuccess: [],
  );

  @override
  DlsShadows copyWith({
    List<BoxShadow>? softSm,
    List<BoxShadow>? softMd,
    List<BoxShadow>? softLg,
    List<BoxShadow>? glowPrimary,
    List<BoxShadow>? glowSuccess,
  }) {
    return DlsShadows(
      softSm: softSm ?? this.softSm,
      softMd: softMd ?? this.softMd,
      softLg: softLg ?? this.softLg,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowSuccess: glowSuccess ?? this.glowSuccess,
    );
  }

  @override
  DlsShadows lerp(ThemeExtension<DlsShadows>? other, double t) {
    if (other is! DlsShadows) return this;
    return DlsShadows(
      softSm: _lerpShadowList(softSm, other.softSm, t) ?? softSm,
      softMd: _lerpShadowList(softMd, other.softMd, t) ?? softMd,
      softLg: _lerpShadowList(softLg, other.softLg, t) ?? softLg,
      glowPrimary:
          _lerpShadowList(glowPrimary, other.glowPrimary, t) ?? glowPrimary,
      glowSuccess:
          _lerpShadowList(glowSuccess, other.glowSuccess, t) ?? glowSuccess,
    );
  }

  static List<BoxShadow>? _lerpShadowList(
    List<BoxShadow>? a,
    List<BoxShadow>? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    final listA = a ?? const <BoxShadow>[];
    final listB = b ?? const <BoxShadow>[];

    final int commonLength = math.min(listA.length, listB.length);
    final List<BoxShadow> result = <BoxShadow>[];

    for (int i = 0; i < commonLength; i++) {
      final lerped = _lerpBoxShadow(listA[i], listB[i], t);
      if (lerped != null) result.add(lerped);
    }
    for (int i = commonLength; i < listA.length; i++) {
      final scaled = _scaleBoxShadow(listA[i], 1.0 - t);
      if (scaled != null) result.add(scaled);
    }
    for (int i = commonLength; i < listB.length; i++) {
      final scaled = _scaleBoxShadow(listB[i], t);
      if (scaled != null) result.add(scaled);
    }
    return result;
  }

  static BoxShadow? _scaleBoxShadow(BoxShadow shadow, double factor) {
    final rawBlur = shadow.blurRadius * factor;
    final clampedBlur = rawBlur < 0.0 ? 0.0 : rawBlur;
    return BoxShadow(
      color: shadow.color,
      offset: shadow.offset * factor,
      blurRadius: clampedBlur,
      spreadRadius: shadow.spreadRadius * factor,
      blurStyle: shadow.blurStyle,
    );
  }

  static BoxShadow? _lerpBoxShadow(BoxShadow? a, BoxShadow? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return _scaleBoxShadow(b!, t);
    if (b == null) return _scaleBoxShadow(a, 1.0 - t);
    final lerpedBlur = lerpDouble(a.blurRadius, b.blurRadius, t) ?? 0.0;
    final clampedBlur = lerpedBlur < 0.0 ? 0.0 : lerpedBlur;
    return BoxShadow(
      color: Color.lerp(a.color, b.color, t)!,
      offset: Offset.lerp(a.offset, b.offset, t)!,
      blurRadius: clampedBlur,
      spreadRadius: lerpDouble(a.spreadRadius, b.spreadRadius, t)!,
      blurStyle: t < 0.5 ? a.blurStyle : b.blurStyle,
    );
  }
}

/// DLS Animations Theme Extension & Micro-interactions.
@immutable
class DlsAnimations extends ThemeExtension<DlsAnimations> {
  const DlsAnimations({
    this.organicSpring = const Cubic(0.34, 1.56, 0.64, 1.0),
    this.organicEaseOut = Curves.easeOutCubic,
    this.fastFeedback = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 250),
    this.slow = const Duration(milliseconds: 400),
  });

  final Curve organicSpring;
  final Curve organicEaseOut;
  final Duration fastFeedback;
  final Duration normal;
  final Duration slow;

  static const standard = DlsAnimations();

  @override
  DlsAnimations copyWith({
    Curve? organicSpring,
    Curve? organicEaseOut,
    Duration? fastFeedback,
    Duration? normal,
    Duration? slow,
  }) {
    return DlsAnimations(
      organicSpring: organicSpring ?? this.organicSpring,
      organicEaseOut: organicEaseOut ?? this.organicEaseOut,
      fastFeedback: fastFeedback ?? this.fastFeedback,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
    );
  }

  @override
  DlsAnimations lerp(ThemeExtension<DlsAnimations>? other, double t) {
    if (other is! DlsAnimations) return this;
    return DlsAnimations(
      organicSpring: t < 0.5 ? organicSpring : other.organicSpring,
      organicEaseOut: t < 0.5 ? organicEaseOut : other.organicEaseOut,
      fastFeedback: t < 0.5 ? fastFeedback : other.fastFeedback,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
    );
  }
}

/// DLS Main Theme Extension Container.
@immutable
class DlsThemeExtension extends ThemeExtension<DlsThemeExtension> {
  const DlsThemeExtension({
    required this.colors,
    required this.radii,
    required this.spacing,
    required this.shadows,
    required this.animations,
  });

  final DlsColors colors;
  final DlsRadii radii;
  final DlsSpacing spacing;
  final DlsShadows shadows;
  final DlsAnimations animations;

  static final light = DlsThemeExtension(
    colors: DlsColors.light,
    radii: DlsRadii.standard,
    spacing: DlsSpacing.standard,
    shadows: DlsShadows.light,
    animations: DlsAnimations.standard,
  );

  static final dark = DlsThemeExtension(
    colors: DlsColors.dark,
    radii: DlsRadii.standard,
    spacing: DlsSpacing.standard,
    shadows: DlsShadows.dark,
    animations: DlsAnimations.standard,
  );

  static final kioskHighContrast = DlsThemeExtension(
    colors: DlsColors.kioskHighContrast,
    radii: DlsRadii.standard,
    spacing: DlsSpacing.standard,
    shadows: DlsShadows.kioskHighContrast,
    animations: DlsAnimations.standard,
  );

  @override
  DlsThemeExtension copyWith({
    DlsColors? colors,
    DlsRadii? radii,
    DlsSpacing? spacing,
    DlsShadows? shadows,
    DlsAnimations? animations,
  }) {
    return DlsThemeExtension(
      colors: colors ?? this.colors,
      radii: radii ?? this.radii,
      spacing: spacing ?? this.spacing,
      shadows: shadows ?? this.shadows,
      animations: animations ?? this.animations,
    );
  }

  @override
  DlsThemeExtension lerp(ThemeExtension<DlsThemeExtension>? other, double t) {
    if (other is! DlsThemeExtension) return this;
    return DlsThemeExtension(
      colors: colors.lerp(other.colors, t),
      radii: radii.lerp(other.radii, t),
      spacing: spacing.lerp(other.spacing, t),
      shadows: shadows.lerp(other.shadows, t),
      animations: animations.lerp(other.animations, t),
    );
  }
}

/// DLS Typography Scale definitions.
abstract final class DlsTypography {
  static const String fontFamily = 'GoogleSans';
  static const List<String> fontFamilyFallback = <String>[];

  static TextStyle displayHero({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 88.0,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -2.0,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle displayLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 56.0,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -1.5,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle displayMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 36.0,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.5,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle titleSection({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: color,
  );

  static TextStyle titleCard({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color,
  );

  static TextStyle titleSubcard({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: color,
  );

  static TextStyle bodyKiosk({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: color,
  );

  static TextStyle bodyStandard({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  static TextStyle captionKiosk({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.2,
    color: color,
  );

  static TextStyle captionSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0.4,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

extension DlsThemeAccess on BuildContext {
  DlsThemeExtension get dlsTheme =>
      Theme.of(this).extension<DlsThemeExtension>() ?? DlsThemeExtension.light;
  DlsColors get dlsColors => dlsTheme.colors;
  DlsRadii get dlsRadii => dlsTheme.radii;
  DlsSpacing get dlsSpacing => dlsTheme.spacing;
  DlsShadows get dlsShadows => dlsTheme.shadows;
  DlsAnimations get dlsAnimations => dlsTheme.animations;
}
