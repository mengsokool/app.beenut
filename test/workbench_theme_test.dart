import 'package:beenut/core/theme.dart';
import 'package:beenut/core/workbench_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'workbench light theme exposes the approved palette and type budget',
    () {
      final theme = BeenutTheme.light;
      final tokens = theme.extension<WorkbenchColors>()!;

      expect(tokens.action, const Color(0xfff4a900));
      expect(tokens.actionSoft, const Color(0xfffff2cc));
      expect(tokens.actionText, const Color(0xff8a4b00));
      expect(tokens.canvas, const Color(0xfff3f4f6));
      expect(tokens.ink, const Color(0xff171717));
      expect(tokens.success, const Color(0xff166534));
      expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w500);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.displayLarge?.fontWeight, FontWeight.w700);

      final filledStyle = theme.filledButtonTheme.style!;
      expect(filledStyle.textStyle?.resolve({})?.fontWeight, FontWeight.w500);
      expect(
        filledStyle.backgroundColor?.resolve({WidgetState.hovered}),
        tokens.actionHover,
      );
    },
  );

  test('workbench dark theme uses tonal depth and amber interaction', () {
    final theme = BeenutTheme.dark;
    final tokens = theme.extension<WorkbenchColors>()!;

    expect(tokens.canvas, const Color(0xff0f0f0f));
    expect(tokens.surface, const Color(0xff18181b));
    expect(tokens.raised, const Color(0xff27272a));
    expect(tokens.action, const Color(0xffffc23d));
    expect(theme.scaffoldBackgroundColor, tokens.canvas);
    expect(theme.cardTheme.elevation, 0);
  });

  test('approved text and status pairs meet normal-text contrast', () {
    const light = WorkbenchColors.light;
    const dark = WorkbenchColors.dark;

    expect(_contrast(light.ink, light.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(light.muted, light.surface), greaterThanOrEqualTo(4.5));
    expect(
      _contrast(light.actionText, light.actionSoft),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(light.onAction, light.action), greaterThanOrEqualTo(4.5));
    expect(_contrast(dark.ink, dark.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(dark.muted, dark.surface), greaterThanOrEqualTo(4.5));
    expect(
      _contrast(dark.actionText, dark.actionSoft),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
