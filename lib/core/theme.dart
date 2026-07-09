import 'package:flutter/material.dart';

class BeenutTheme {
  static const shell = Color(0xffeef2f6);
  static const surface = Color(0xfffbfcfe);
  static const raised = Color(0xfff5f7fa);
  static const ink = Color(0xff171717);
  static const muted = Color(0xff555f6d);
  static const line = Color(0xffd9e0ea);
  static const accent = Color(0xfff3c622);
  static const success = Color(0xff0b8043);
  static const warning = Color(0xffb06000);
  static const danger = Color(0xffb3261e);
  static const previewBlack = Color(0xff050505);
  static const fontFamily = 'NotoSansThai';
  static const fontFamilyFallback = ['NotoSans'];
  static const _darkShell = Color(0xff111315);
  static const _darkSurface = Color(0xff111315);
  static const _darkRaised = Color(0xff1e2226);
  static const _darkInk = Color(0xffe8eaed);
  static const _darkMuted = Color(0xffc2c7cf);
  static const _darkLine = Color(0xff454b53);
  static const _darkAccent = Color(0xfff3c622);
  static const radiusSharp = BorderRadius.all(Radius.circular(4));
  static const radiusPanel = BorderRadius.all(Radius.circular(6));
  static const controlShape = RoundedRectangleBorder(borderRadius: radiusSharp);
  static const panelShape = RoundedRectangleBorder(borderRadius: radiusPanel);

  static Color inkColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkInk : ink;

  static Color mutedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkMuted : muted;

  static Color lineColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkLine : line;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkSurface : surface;

  static Color raisedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkRaised : raised;

  static Color shellColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkShell : shell;

  static Color containerLow(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color container(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color containerHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color containerHighest(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color outlineVariant(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color successColor(BuildContext context) =>
      Theme.of(context).colorScheme.tertiary;

  static Color warningColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color dangerColor(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static const _buttonTextStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff1d4ed8),
          brightness: Brightness.light,
          surface: surface,
        ).copyWith(
          primary: const Color(0xff1d4ed8),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xffbfdbfe),
          onPrimaryContainer: const Color(0xff1e40af),
          secondary: accent,
          onSecondary: ink,
          secondaryContainer: const Color(0xfffef08a),
          onSecondaryContainer: const Color(0xff713f12),
          tertiary: const Color(0xff10b981),
          tertiaryContainer: const Color(0xffd1fae5),
          onTertiaryContainer: const Color(0xff065f46),
          error: danger,
          errorContainer: const Color(0xfffee2e2),
          onErrorContainer: const Color(0xff991b1b),
          surface: surface,
          surfaceDim: const Color(0xffdce4ee),
          surfaceBright: surface,
          surfaceContainerLowest: surface,
          surfaceContainerLow: const Color(0xfff3f6fa),
          surfaceContainer: const Color(0xffffffff),
          surfaceContainerHigh: const Color(0xffedf2f7),
          surfaceContainerHighest: const Color(0xffdfe7f0),
          outline: const Color(0xffb9c5d3),
          outlineVariant: const Color(0xffd9e1eb),
          onSurface: ink,
          onSurfaceVariant: muted,
        );
    return _baseTheme(
      scheme: scheme,
      scaffoldBackgroundColor: shell,
      popupColor: surface,
      dialogBackgroundColor: surface,
      menuTextColor: ink,
      dialogTitleColor: ink,
      dialogContentColor: muted,
      selectedSwitchThumb: Colors.white,
      selectedSwitchTrack: scheme.primary,
      unselectedSwitchThumb: Colors.white,
      unselectedSwitchTrack: const Color(0xffd1d5db),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w500, color: ink),
        bodyMedium: TextStyle(color: ink),
        labelLarge: TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff3b82f6),
          brightness: Brightness.dark,
          surface: _darkSurface,
        ).copyWith(
          primary: const Color(0xff60a5fa),
          onPrimary: const Color(0xff0f172a),
          primaryContainer: const Color(0xff1e3a8a),
          onPrimaryContainer: const Color(0xffdbeafe),
          secondary: _darkAccent,
          onSecondary: const Color(0xff1e1b4b),
          secondaryContainer: const Color(0xff453000),
          onSecondaryContainer: const Color(0xffffe082),
          tertiary: const Color(0xff34d399),
          tertiaryContainer: const Color(0xff065f46),
          onTertiaryContainer: const Color(0xffa7f3d0),
          error: const Color(0xfff87171),
          errorContainer: const Color(0xff991b1b),
          onErrorContainer: const Color(0xfffecaca),
          surface: _darkSurface,
          surfaceDim: const Color(0xff111315),
          surfaceBright: const Color(0xff373b40),
          surfaceContainerLowest: const Color(0xff0b0d0f),
          surfaceContainerLow: const Color(0xff191c20),
          surfaceContainer: const Color(0xff1f2328),
          surfaceContainerHigh: const Color(0xff292d33),
          surfaceContainerHighest: _darkRaised,
          outline: _darkLine,
          outlineVariant: const Color(0xff454b53),
          onSurface: _darkInk,
          onSurfaceVariant: _darkMuted,
        );
    return _baseTheme(
      scheme: scheme,
      scaffoldBackgroundColor: _darkShell,
      popupColor: _darkRaised,
      dialogBackgroundColor: _darkSurface,
      menuTextColor: _darkInk,
      dialogTitleColor: _darkInk,
      dialogContentColor: _darkMuted,
      selectedSwitchThumb: _darkShell,
      selectedSwitchTrack: scheme.primary,
      unselectedSwitchThumb: const Color(0xff9ca3af),
      unselectedSwitchTrack: const Color(0xff374151),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: _darkInk),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: _darkInk),
        titleMedium: TextStyle(fontWeight: FontWeight.w500, color: _darkInk),
        bodyMedium: TextStyle(color: _darkInk),
        labelLarge: TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Color scaffoldBackgroundColor,
    required Color popupColor,
    required Color dialogBackgroundColor,
    required Color menuTextColor,
    required Color dialogTitleColor,
    required Color dialogContentColor,
    required Color selectedSwitchThumb,
    required Color selectedSwitchTrack,
    required Color unselectedSwitchThumb,
    required Color unselectedSwitchTrack,
    required TextTheme textTheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_buttonTextStyle),
          shape: WidgetStatePropertyAll(controlShape),
          minimumSize: WidgetStatePropertyAll(Size(64, 40)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
          shape: const WidgetStatePropertyAll(controlShape),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_buttonTextStyle),
          shape: WidgetStatePropertyAll(controlShape),
          minimumSize: WidgetStatePropertyAll(Size(64, 40)),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(controlShape)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: panelShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: popupColor,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: panelShape,
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: menuTextColor,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: dialogTitleColor,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          color: dialogContentColor,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radiusSharp),
        enabledBorder: OutlineInputBorder(borderRadius: radiusSharp),
        focusedBorder: OutlineInputBorder(borderRadius: radiusSharp),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return selectedSwitchThumb;
          return unselectedSwitchThumb;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return selectedSwitchTrack;
          return unselectedSwitchTrack;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
