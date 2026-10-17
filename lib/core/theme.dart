import 'package:flutter/material.dart';

import 'dls_tokens.dart';
import 'workbench_tokens.dart';

class BeenutTheme {
  static const shell = Color(0xfff3f4f6);
  static const surface = Color(0xffffffff);
  static const raised = Color(0xfff9fafb);
  static const ink = Color(0xff171717);
  static const muted = Color(0xff52525b);
  static const line = Color(0xffd4d4d8);
  static const accent = Color(0xfff4a900);
  static const success = Color(0xff166534);
  static const warning = Color(0xff9a3412);
  static const danger = Color(0xffb91c1c);
  static const previewBlack = Color(0xff09090b);
  static const fontFamily = 'IBMPlexSansThaiLooped';
  static const fontFamilyFallback = ['IBMPlexSans'];

  static const radiusSharp = BorderRadius.all(
    Radius.circular(WorkbenchRadius.control),
  );
  static const radiusPanel = BorderRadius.all(
    Radius.circular(WorkbenchRadius.panel),
  );
  static const controlShape = RoundedRectangleBorder(borderRadius: radiusSharp);
  static const panelShape = RoundedRectangleBorder(borderRadius: radiusPanel);

  static Color getLabelColor(String label, List<String> keywords) {
    if (keywords.length <= 1) {
      return const Color(0xff06b6d4); // Cyan (default single class color)
    }
    const colors = [
      Color(0xffef4444), // Red
      Color(0xff22c55e), // Green
      Color(0xff3b82f6), // Blue
      Color(0xffeab308), // Yellow
      Color(0xffa855f7), // Purple
      Color(0xfff97316), // Orange
      Color(0xffec4899), // Pink
      Color(0xff06b6d4), // Cyan
    ];
    final normalizedLabel = label.toLowerCase().trim();
    for (int i = 0; i < keywords.length; i++) {
      final kw = keywords[i].toLowerCase().trim();
      if (kw == normalizedLabel || normalizedLabel.contains(kw) || kw.contains(normalizedLabel)) {
        return colors[i % colors.length];
      }
    }
    return const Color(0xff06b6d4);
  }

  static WorkbenchColors colors(BuildContext context) =>
      context.workbenchColors;

  static Color inkColor(BuildContext context) => colors(context).ink;

  static Color mutedColor(BuildContext context) => colors(context).muted;

  static Color lineColor(BuildContext context) => colors(context).line;

  static Color surfaceColor(BuildContext context) => colors(context).surface;

  static Color raisedColor(BuildContext context) => colors(context).raised;

  static Color shellColor(BuildContext context) => colors(context).canvas;

  static Color containerLow(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color container(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color containerHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color containerHighest(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color outlineVariant(BuildContext context) =>
      colors(context).lineSubtle;

  static Color primaryColor(BuildContext context) => colors(context).action;

  static Color successColor(BuildContext context) => colors(context).success;

  static Color warningColor(BuildContext context) => colors(context).warning;

  static Color dangerColor(BuildContext context) => colors(context).danger;

  static TextStyle dataTextStyle(BuildContext context) => TextStyle(
    fontFamily: 'monospace',
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: colors(context).ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static const kioskHighContrastWorkbench = WorkbenchColors(
    action: Color(0xffffd600),
    actionHover: Color(0xffffee58),
    actionActive: Color(0xffffc400),
    actionSoft: Color(0xff332b00),
    actionText: Color(0xffffd600),
    actionFocus: Color(0xffffd600),
    onAction: Color(0xff000000),
    canvas: Color(0xff000000),
    surface: Color(0xff121212),
    raised: Color(0xff2c2c2c),
    ink: Color(0xffffffff),
    muted: Color(0xffe0e0e0),
    disabled: Color(0xff808080),
    line: Color(0xffffffff),
    lineSubtle: Color(0xffa0a0a0),
    success: Color(0xff00e676),
    successSoft: Color(0xff003319),
    warning: Color(0xffff9100),
    warningSoft: Color(0xff331d00),
    danger: Color(0xffff1744),
    dangerSoft: Color(0xff33050e),
    info: Color(0xff00b0ff),
    infoSoft: Color(0xff002233),
    previewBlack: Color(0xff000000),
  );

  static final ThemeData light = _buildTheme(
    DlsThemeExtension.light,
    workbenchColors: WorkbenchColors.light,
    brightness: Brightness.light,
  );

  static final ThemeData dark = _buildTheme(
    DlsThemeExtension.dark,
    workbenchColors: WorkbenchColors.dark,
    brightness: Brightness.dark,
  );

  static final ThemeData kioskHighContrast = _buildTheme(
    DlsThemeExtension.kioskHighContrast,
    workbenchColors: kioskHighContrastWorkbench,
    brightness: Brightness.dark,
  );


  static ThemeData _buildTheme(
    DlsThemeExtension dlsTokens, {
    required WorkbenchColors workbenchColors,
    required Brightness brightness,
  }) {
    final colors = dlsTokens.colors;
    final radii = dlsTokens.radii;

    final scheme = ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      surface: workbenchColors.surface,
    ).copyWith(
      primary: workbenchColors.action,
      onPrimary: workbenchColors.onAction,
      primaryContainer: workbenchColors.actionSoft,
      onPrimaryContainer: workbenchColors.actionText,
      secondary: workbenchColors.action,
      onSecondary: workbenchColors.onAction,
      secondaryContainer: workbenchColors.actionSoft,
      onSecondaryContainer: workbenchColors.actionText,
      tertiary: workbenchColors.success,
      onTertiary: brightness == Brightness.light
          ? workbenchColors.surface
          : const Color(0xff052e16),
      tertiaryContainer: workbenchColors.successSoft,
      onTertiaryContainer: workbenchColors.success,
      error: workbenchColors.danger,
      onError: workbenchColors.surface,
      errorContainer: workbenchColors.dangerSoft,
      onErrorContainer: workbenchColors.danger,
      surface: workbenchColors.surface,
      surfaceDim: workbenchColors.canvas,
      surfaceBright: workbenchColors.surface,
      surfaceContainerLowest: workbenchColors.surface,
      surfaceContainerLow: workbenchColors.raised,
      surfaceContainer: workbenchColors.surface,
      surfaceContainerHigh: workbenchColors.raised,
      surfaceContainerHighest: workbenchColors.lineSubtle,
      outline: workbenchColors.line,
      outlineVariant: workbenchColors.lineSubtle,
      onSurface: workbenchColors.ink,
      onSurfaceVariant: workbenchColors.muted,
    );
    final textTheme = _textTheme(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor: workbenchColors.canvas,
      canvasColor: workbenchColors.canvas,
      disabledColor: workbenchColors.disabled,
      focusColor: workbenchColors.actionSoft,
      hoverColor: workbenchColors.raised,
      splashColor: workbenchColors.actionSoft,
      highlightColor: Colors.transparent,
      textTheme: textTheme,
      extensions: [
        dlsTokens,
        dlsTokens.colors,
        dlsTokens.radii,
        dlsTokens.spacing,
        dlsTokens.shadows,
        dlsTokens.animations,
        workbenchColors,
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return workbenchColors.lineSubtle;
            }
            if (states.contains(WidgetState.pressed)) {
              return workbenchColors.actionActive;
            }
            if (states.contains(WidgetState.hovered)) {
              return workbenchColors.actionHover;
            }
            return workbenchColors.action;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return workbenchColors.disabled;
            }
            return workbenchColors.onAction;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radii.borderSm()),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(64, WorkbenchMetric.technicianControlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return workbenchColors.raised;
            }
            return workbenchColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return workbenchColors.disabled;
            }
            return workbenchColors.ink;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radii.borderSm()),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(64, WorkbenchMetric.technicianControlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: workbenchColors.actionFocus, width: 2);
            }
            return BorderSide(color: workbenchColors.line);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return workbenchColors.disabled;
            }
            return workbenchColors.actionText;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return workbenchColors.actionSoft;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radii.borderSm()),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(40, WorkbenchMetric.technicianControlHeight),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(workbenchColors.muted),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return workbenchColors.raised;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radii.borderSm()),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size.square(WorkbenchMetric.technicianHitTarget),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: workbenchColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radii.borderMd(),
          side: BorderSide(color: workbenchColors.line),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: workbenchColors.lineSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: workbenchColors.raised,
        foregroundColor: workbenchColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: workbenchColors.raised,
        selectedIconTheme: IconThemeData(color: workbenchColors.actionText, size: 20),
        unselectedIconTheme: IconThemeData(color: workbenchColors.muted, size: 20),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: workbenchColors.actionText,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: workbenchColors.muted,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: workbenchColors.actionSoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: radii.borderSm()),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: workbenchColors.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: brightness == Brightness.light
            ? const Color(0x24171717)
            : const Color(0x5c000000),
        shape: RoundedRectangleBorder(
          borderRadius: radii.borderMd(),
          side: BorderSide(color: workbenchColors.line),
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: workbenchColors.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: workbenchColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: brightness == Brightness.light
            ? const Color(0x33171717)
            : const Color(0x7a000000),
        shape: RoundedRectangleBorder(
          borderRadius: radii.borderLg(),
          side: BorderSide(color: workbenchColors.line),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: workbenchColors.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: workbenchColors.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WorkbenchSpace.x3,
          vertical: WorkbenchSpace.x2,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: workbenchColors.muted),
        labelStyle: textTheme.labelLarge?.copyWith(color: workbenchColors.muted),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: workbenchColors.line),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: workbenchColors.line),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: workbenchColors.actionFocus, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: workbenchColors.danger),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: workbenchColors.danger, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return workbenchColors.disabled;
          if (states.contains(WidgetState.selected)) return workbenchColors.onAction;
          return workbenchColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return workbenchColors.lineSubtle;
          if (states.contains(WidgetState.selected)) return workbenchColors.action;
          return workbenchColors.line;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: workbenchColors.raised,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: radii.borderSm(),
          side: BorderSide(color: workbenchColors.line),
        ),
        elevation: 4,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: workbenchColors.ink,
          borderRadius: radii.borderXs(),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: workbenchColors.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: workbenchColors.action,
        linearTrackColor: workbenchColors.lineSubtle,
        circularTrackColor: workbenchColors.lineSubtle,
      ),
    );
  }

  static TextTheme _textTheme(DlsColors colors) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      Color? color,
      double? letterSpacing,
      List<FontFeature>? features,
    }) =>
        TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? colors.inkPrimary,
          letterSpacing: letterSpacing,
          fontFeatures: features,
        );

    return TextTheme(
      displayLarge: style(
        size: 56,
        weight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.5,
        features: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: style(size: 20, weight: FontWeight.w600, height: 1.3),
      titleLarge: style(size: 16, weight: FontWeight.w600, height: 1.4),
      titleMedium: style(size: 14, weight: FontWeight.w500, height: 1.4),
      bodyMedium: style(size: 13, weight: FontWeight.w400, height: 1.45),
      labelLarge: style(size: 12, weight: FontWeight.w500, height: 1.3),
      bodySmall: style(
        size: 11,
        weight: FontWeight.w400,
        height: 1.35,
        color: colors.inkSecondary,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w400,
        height: 1.35,
        color: colors.inkSecondary,
      ),
    );
  }
}
