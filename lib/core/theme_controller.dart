import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static void update(String themeStr) {
    final next = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (themeMode.value == next) return;
    themeMode.value = next;
  }
}
