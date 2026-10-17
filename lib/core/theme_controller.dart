import 'package:flutter/material.dart';
import 'theme.dart';

enum AppThemeMode {
  light,
  dark,
  kioskHighContrast;

  String toMapString() => switch (this) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.kioskHighContrast => 'kioskHighContrast',
      };
}

class ThemeController {
  ThemeController._();

  /// State notifier for DLS AppThemeMode.
  static final ValueNotifier<AppThemeMode> currentMode =
      ValueNotifier<AppThemeMode>(AppThemeMode.light);

  /// Backward-compatibility state notifier for Flutter ThemeMode.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Current active AppThemeMode.
  static AppThemeMode get mode => currentMode.value;

  /// Active ThemeData corresponding to current AppThemeMode.
  static ThemeData get currentThemeData => switch (currentMode.value) {
        AppThemeMode.light => BeenutTheme.light,
        AppThemeMode.dark => BeenutTheme.dark,
        AppThemeMode.kioskHighContrast => BeenutTheme.kioskHighContrast,
      };

  /// Set active AppThemeMode and update state notifiers.
  static void setThemeMode(AppThemeMode mode) {
    if (currentMode.value != mode) {
      currentMode.value = mode;
    }
    final mappedThemeMode = switch (mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.kioskHighContrast => ThemeMode.dark,
    };
    if (themeMode.value != mappedThemeMode) {
      themeMode.value = mappedThemeMode;
    }
  }

  /// Update theme mode from string representation.
  static void update(String themeStr) {
    final modeStr = themeStr.toLowerCase().trim();
    if (modeStr == 'system') {
      themeMode.value = ThemeMode.system;
      currentMode.value = AppThemeMode.light;
      return;
    }
    final next = switch (modeStr) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'highcontrast' ||
      'high_contrast' ||
      'kioskhighcontrast' ||
      'kiosk' =>
        AppThemeMode.kioskHighContrast,
      _ => AppThemeMode.light,
    };
    setThemeMode(next);
  }
}
