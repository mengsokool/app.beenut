import 'dart:math';
import 'package:beenut/core/dls_tokens.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empirical Stress Testing: DLS Tokens & Palette Architecture (M1)', () {

    group('1. ThemeController State Transitions Stress Test', () {
      setUp(() {
        ThemeController.setThemeMode(AppThemeMode.light);
      });

      test('Rapid state transitions (1,000 iterations) across light <-> dark <-> kioskHighContrast', () {
        final modes = [
          AppThemeMode.light,
          AppThemeMode.dark,
          AppThemeMode.kioskHighContrast,
        ];

        int listenerCallCount = 0;
        void listener() {
          listenerCallCount++;
        }

        ThemeController.currentMode.addListener(listener);

        final random = Random(42);
        AppThemeMode previousMode = AppThemeMode.light;
        int expectedNotifications = 0;

        for (int i = 0; i < 1000; i++) {
          final nextMode = modes[random.nextInt(modes.length)];
          if (nextMode != previousMode) {
            expectedNotifications++;
          }

          ThemeController.setThemeMode(nextMode);

          // Verify internal state consistency after transition
          expect(ThemeController.mode, equals(nextMode));
          expect(ThemeController.currentMode.value, equals(nextMode));

          final expectedBrightness = switch (nextMode) {
            AppThemeMode.light => Brightness.light,
            AppThemeMode.dark => Brightness.dark,
            AppThemeMode.kioskHighContrast => Brightness.dark,
          };
          expect(ThemeController.currentThemeData.brightness, equals(expectedBrightness));

          final dlsExt = ThemeController.currentThemeData.extension<DlsThemeExtension>();
          expect(dlsExt, isNotNull);

          final expectedCanvasColor = switch (nextMode) {
            AppThemeMode.light => DlsColors.light.canvas,
            AppThemeMode.dark => DlsColors.dark.canvas,
            AppThemeMode.kioskHighContrast => DlsColors.kioskHighContrast.canvas,
          };
          expect(dlsExt!.colors.canvas, equals(expectedCanvasColor));

          previousMode = nextMode;
        }

        expect(listenerCallCount, equals(expectedNotifications));
        ThemeController.currentMode.removeListener(listener);
      });

      test('ThemeController.setThemeMode idempotency (setting same mode does not notify)', () {
        ThemeController.setThemeMode(AppThemeMode.dark);

        int listenerCalls = 0;
        void listener() {
          listenerCalls++;
        }

        ThemeController.currentMode.addListener(listener);
        ThemeController.setThemeMode(AppThemeMode.dark);
        ThemeController.setThemeMode(AppThemeMode.dark);
        ThemeController.setThemeMode(AppThemeMode.dark);

        expect(listenerCalls, equals(0));
        ThemeController.currentMode.removeListener(listener);
      });

      test('ThemeController.update string parser robustness with edge cases', () {
        final testCases = [
          ('light', AppThemeMode.light),
          ('LIGHT', AppThemeMode.light),
          ('  light  ', AppThemeMode.light),
          ('dark', AppThemeMode.dark),
          ('DARK', AppThemeMode.dark),
          ('highcontrast', AppThemeMode.kioskHighContrast),
          ('HIGHCONTRAST', AppThemeMode.kioskHighContrast),
          ('high_contrast', AppThemeMode.kioskHighContrast),
          ('kioskhighcontrast', AppThemeMode.kioskHighContrast),
          ('kiosk', AppThemeMode.kioskHighContrast),
          ('system', AppThemeMode.light), // 'system' resets currentMode to light
          ('unknown_string', AppThemeMode.light),
          ('', AppThemeMode.light),
        ];

        for (final (input, expected) in testCases) {
          ThemeController.update(input);
          expect(
            ThemeController.mode,
            equals(expected),
            reason: 'Failed string input: "$input"',
          );
        }
      });

      test('AppThemeMode toMapString completeness', () {
        for (final mode in AppThemeMode.values) {
          final str = mode.toMapString();
          expect(str, isNotEmpty);
          expect(str, isA<String>());
        }
      });
    });

    group('2. ThemeExtension Lerp Interpolation Stress Test', () {
      final themes = [
        ('light', DlsThemeExtension.light),
        ('dark', DlsThemeExtension.dark),
        ('kioskHighContrast', DlsThemeExtension.kioskHighContrast),
      ];

      test('Standard bounded lerp between all theme modes across t values (0.0 to 1.0)', () {
        final boundedTValues = [0.0, 0.001, 0.25, 0.5, 0.75, 0.999, 1.0];
        for (final (nameA, themeA) in themes) {
          for (final (nameB, themeB) in themes) {
            for (final t in boundedTValues) {
              final lerped = themeA.lerp(themeB, t);

              expect(lerped, isNotNull, reason: 'Lerp ($nameA -> $nameB) at t=$t returned null');
              expect(lerped.colors.canvas, isA<Color>());
              expect(lerped.radii.xs, isA<double>());
              expect(lerped.spacing.xs, isA<double>());
              expect(lerped.shadows.softSm, isA<List<BoxShadow>>());
            }
          }
        }
      });

      test('Overshoot/Extrapolation lerp (t < 0.0 or t > 1.0) safely clamps blurRadius >= 0.0 when interpolating with empty shadow lists', () {
        // DlsShadows.kioskHighContrast has empty shadow lists [].
        // Interpolating from DlsShadows.light (non-empty) to kioskHighContrast (empty) with t > 1.0 or t < 0.0
        // must sanitize blurRadius >= 0.0 to prevent assertion failures during organic spring animations.

        final lerpedOver = DlsShadows.light.lerp(DlsShadows.kioskHighContrast, 1.5);
        expect(lerpedOver, isNotNull);
        for (final shadow in lerpedOver.softSm) {
          expect(shadow.blurRadius, greaterThanOrEqualTo(0.0));
        }

        final lerpedUnder = DlsShadows.kioskHighContrast.lerp(DlsShadows.light, -0.5);
        expect(lerpedUnder, isNotNull);
        for (final shadow in lerpedUnder.softSm) {
          expect(shadow.blurRadius, greaterThanOrEqualTo(0.0));
        }
      });


      test('Boundary conditions: t=0.0 returns exact start state, t=1.0 returns exact end state', () {
        for (final (nameA, themeA) in themes) {
          for (final (nameB, themeB) in themes) {
            final lerpZero = themeA.lerp(themeB, 0.0);
            final lerpOne = themeA.lerp(themeB, 1.0);

            expect(lerpZero.colors.canvas, equals(themeA.colors.canvas), reason: '$nameA lerp $nameB at t=0');
            expect(lerpOne.colors.canvas, equals(themeB.colors.canvas), reason: '$nameA lerp $nameB at t=1');
          }
        }
      });

      test('Null target handling: theme.lerp(null, t) gracefully returns current instance', () {
        final tValues = [0.0, 0.5, 1.0];
        for (final (name, theme) in themes) {
          for (final t in tValues) {
            final lerped = theme.lerp(null, t);
            expect(lerped, equals(theme), reason: 'lerp(null, $t) failed for $name');
            expect(theme.colors.lerp(null, t), equals(theme.colors));
            expect(theme.radii.lerp(null, t), equals(theme.radii));
            expect(theme.spacing.lerp(null, t), equals(theme.spacing));
            expect(theme.shadows.lerp(null, t), equals(theme.shadows));
            expect(theme.animations.lerp(null, t), equals(theme.animations));
          }
        }
      });

      test('Incompatible type handling: lerp with non-matching ThemeExtension returns self', () {
        final dummyColors = _DummyColorsExtension();
        for (final (name, theme) in themes) {
          final lerpedColors = theme.colors.lerp(dummyColors, 0.5);
          expect(lerpedColors, equals(theme.colors), reason: 'lerp with dummy failed for $name colors');
        }
      });
    });

  });
}

class _DummyColorsExtension extends ThemeExtension<DlsColors> {
  @override
  _DummyColorsExtension copyWith() => this;

  @override
  _DummyColorsExtension lerp(ThemeExtension<DlsColors>? other, double t) => this;
}
