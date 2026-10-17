import 'package:flutter/material.dart';

/// Input behavior and density for the task or machine workspace.
/// This scope is not a user role or an access-control boundary.
class SettingsExperience extends InheritedWidget {
  const SettingsExperience({
    super.key,
    required this.developer,
    required super.child,
  });

  final bool developer;

  static bool isDeveloper(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsExperience>()
          ?.developer ??
      true;

  static double controlHeight(BuildContext context) =>
      isDeveloper(context) ? 48 : 56;

  @override
  bool updateShouldNotify(SettingsExperience oldWidget) =>
      developer != oldWidget.developer;
}
