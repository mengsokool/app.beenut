import 'package:flutter/material.dart';

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
  static const fontFamily = 'NotoSansThai';
  static const fontFamilyFallback = ['NotoSans'];

  static const radiusSharp = BorderRadius.all(
    Radius.circular(WorkbenchRadius.control),
  );
  static const radiusPanel = BorderRadius.all(
    Radius.circular(WorkbenchRadius.panel),
  );
  static const controlShape = RoundedRectangleBorder(borderRadius: radiusSharp);
  static const panelShape = RoundedRectangleBorder(borderRadius: radiusPanel);

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

  static ThemeData get light =>
      _buildTheme(WorkbenchColors.light, brightness: Brightness.light);

  static ThemeData get dark =>
      _buildTheme(WorkbenchColors.dark, brightness: Brightness.dark);

  static ThemeData _buildTheme(
    WorkbenchColors tokens, {
    required Brightness brightness,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.action,
          brightness: brightness,
          surface: tokens.surface,
        ).copyWith(
          primary: tokens.action,
          onPrimary: tokens.onAction,
          primaryContainer: tokens.actionSoft,
          onPrimaryContainer: tokens.actionText,
          secondary: tokens.action,
          onSecondary: tokens.onAction,
          secondaryContainer: tokens.actionSoft,
          onSecondaryContainer: tokens.actionText,
          tertiary: tokens.success,
          onTertiary: brightness == Brightness.light
              ? tokens.surface
              : const Color(0xff052e16),
          tertiaryContainer: tokens.successSoft,
          onTertiaryContainer: tokens.success,
          error: tokens.danger,
          onError: tokens.surface,
          errorContainer: tokens.dangerSoft,
          onErrorContainer: tokens.danger,
          surface: tokens.surface,
          surfaceDim: tokens.canvas,
          surfaceBright: tokens.surface,
          surfaceContainerLowest: tokens.surface,
          surfaceContainerLow: tokens.raised,
          surfaceContainer: tokens.surface,
          surfaceContainerHigh: tokens.raised,
          surfaceContainerHighest: tokens.lineSubtle,
          outline: tokens.line,
          outlineVariant: tokens.lineSubtle,
          onSurface: tokens.ink,
          onSurfaceVariant: tokens.muted,
        );
    final textTheme = _textTheme(tokens);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      disabledColor: tokens.disabled,
      focusColor: tokens.actionSoft,
      hoverColor: tokens.raised,
      splashColor: tokens.actionSoft,
      highlightColor: Colors.transparent,
      textTheme: textTheme,
      extensions: [tokens],
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return tokens.lineSubtle;
            }
            if (states.contains(WidgetState.pressed)) {
              return tokens.actionActive;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.actionHover;
            }
            return tokens.action;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return tokens.disabled;
            return tokens.onAction;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(controlShape),
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
              return tokens.raised;
            }
            return tokens.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return tokens.disabled;
            return tokens.ink;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(controlShape),
          minimumSize: const WidgetStatePropertyAll(
            Size(64, WorkbenchMetric.technicianControlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: tokens.actionFocus, width: 2);
            }
            return BorderSide(color: tokens.line);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return tokens.disabled;
            return tokens.actionText;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return tokens.actionSoft;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(controlShape),
          minimumSize: const WidgetStatePropertyAll(
            Size(40, WorkbenchMetric.technicianControlHeight),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(tokens.muted),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return tokens.raised;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(controlShape),
          minimumSize: const WidgetStatePropertyAll(
            Size.square(WorkbenchMetric.technicianHitTarget),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusPanel,
          side: BorderSide(color: tokens.line),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.lineSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tokens.raised,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.raised,
        selectedIconTheme: IconThemeData(color: tokens.actionText, size: 20),
        unselectedIconTheme: IconThemeData(color: tokens.muted, size: 20),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: tokens.actionText,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: tokens.muted,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: tokens.actionSoft,
        indicatorShape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: brightness == Brightness.light
            ? const Color(0x24171717)
            : const Color(0x5c000000),
        shape: RoundedRectangleBorder(
          borderRadius: radiusPanel,
          side: BorderSide(color: tokens.line),
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: tokens.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: brightness == Brightness.light
            ? const Color(0x33171717)
            : const Color(0x7a000000),
        shape: panelShape,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WorkbenchSpace.x3,
          vertical: WorkbenchSpace.x2,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted),
        labelStyle: textTheme.labelLarge?.copyWith(color: tokens.muted),
        border: OutlineInputBorder(
          borderRadius: radiusSharp,
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusSharp,
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusSharp,
          borderSide: BorderSide(color: tokens.actionFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusSharp,
          borderSide: BorderSide(color: tokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusSharp,
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.disabled;
          if (states.contains(WidgetState.selected)) return tokens.onAction;
          return tokens.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.lineSubtle;
          if (states.contains(WidgetState.selected)) return tokens.action;
          return tokens.line;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.raised,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: radiusSharp,
          side: BorderSide(color: tokens.line),
        ),
        elevation: 4,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: tokens.ink, borderRadius: radiusSharp),
        textStyle: textTheme.bodySmall?.copyWith(color: tokens.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.action,
        linearTrackColor: tokens.lineSubtle,
        circularTrackColor: tokens.lineSubtle,
      ),
    );
  }

  static TextTheme _textTheme(WorkbenchColors tokens) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      Color? color,
      double? letterSpacing,
      List<FontFeature>? features,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? tokens.ink,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );

    return TextTheme(
      displayLarge: style(
        size: 96,
        weight: FontWeight.w700,
        height: 1,
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
        color: tokens.muted,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w400,
        height: 1.35,
        color: tokens.muted,
      ),
    );
  }
}
