import 'package:beenut/core/dls_tokens.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/core/workbench_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R1 Design System Tokens & Palettes Test Suite', () {
    test('DlsColors neutral light palette values and aliases', () {
      const colors = DlsColors.light;
      expect(colors.canvas, equals(const Color(0xFFF4F4F4)));
      expect(colors.surface, equals(const Color(0xFFFFFFFF)));
      expect(colors.surfaceSubtle, equals(const Color(0xFFF4F4F4)));
      expect(colors.surfaceRaised, equals(const Color(0xFFE0E0E0)));
      expect(colors.inkPrimary, equals(const Color(0xFF161616)));
      expect(colors.inkSecondary, equals(const Color(0xFF525252)));
      expect(colors.inkDisabled, equals(const Color(0xFF6F6F6F)));
      expect(colors.border, equals(const Color(0xFF8D8D8D)));
      expect(colors.borderSubtle, equals(const Color(0xFFE0E0E0)));
      expect(colors.accent, equals(const Color(0xFF0F62FE)));
      expect(colors.accentHover, equals(const Color(0xFF0353E9)));
      expect(colors.accentActive, equals(const Color(0xFF002D9C)));
      expect(colors.accentSoft, equals(const Color(0xFFEDF5FF)));
      expect(colors.onAccent, equals(const Color(0xFFFFFFFF)));
      expect(colors.success, equals(const Color(0xFF2D6A4F)));
      expect(colors.successSoft, equals(const Color(0xFFD8F3DC)));
      expect(colors.warning, equals(const Color(0xFFC85A17)));
      expect(colors.warningSoft, equals(const Color(0xFFFFEDD5)));
      expect(colors.danger, equals(const Color(0xFFB91C1C)));
      expect(colors.dangerSoft, equals(const Color(0xFFFEE2E2)));
      expect(colors.info, equals(const Color(0xFF2563EB)));
      expect(colors.infoSoft, equals(const Color(0xFFDBEAFE)));
      expect(colors.streamViewport, equals(const Color(0xFF0C0A09)));

      // Test aliases
      expect(colors.raised, equals(colors.surfaceRaised));
      expect(colors.ink, equals(colors.inkPrimary));
      expect(colors.muted, equals(colors.inkSecondary));
      expect(colors.disabled, equals(colors.inkDisabled));
      expect(colors.line, equals(colors.border));
      expect(colors.lineSubtle, equals(colors.borderSubtle));
      expect(colors.primaryAction, equals(colors.accent));
      expect(colors.onPrimaryAction, equals(colors.onAccent));
    });

    test('DlsColors neutral dark palette values', () {
      const colors = DlsColors.dark;
      expect(colors.canvas, equals(const Color(0xFF161616)));
      expect(colors.surface, equals(const Color(0xFF262626)));
      expect(colors.surfaceSubtle, equals(const Color(0xFF393939)));
      expect(colors.surfaceRaised, equals(const Color(0xFF525252)));
      expect(colors.inkPrimary, equals(const Color(0xFFF4F4F4)));
      expect(colors.accent, equals(const Color(0xFF78A9FF)));
      expect(colors.onAccent, equals(const Color(0xFF161616)));
      expect(colors.success, equals(const Color(0xFF34D399)));
      expect(colors.warning, equals(const Color(0xFFFB923C)));
      expect(colors.danger, equals(const Color(0xFFF87171)));
      expect(colors.info, equals(const Color(0xFF60A5FA)));
    });

    test('DlsColors Kiosk High-Contrast Palette values (WCAG AAA)', () {
      const colors = DlsColors.kioskHighContrast;
      expect(colors.canvas, equals(const Color(0xFF000000)));
      expect(colors.surface, equals(const Color(0xFF121212)));
      expect(colors.inkPrimary, equals(const Color(0xFFFFFFFF)));
      expect(colors.border, equals(const Color(0xFFFFFFFF)));
      expect(colors.accent, equals(const Color(0xFFFFD600)));
      expect(colors.onAccent, equals(const Color(0xFF000000)));
      expect(colors.success, equals(const Color(0xFF00E676)));
      expect(colors.warning, equals(const Color(0xFFFF9100)));
      expect(colors.danger, equals(const Color(0xFFFF1744)));
      expect(colors.info, equals(const Color(0xFF00B0FF)));
    });

    test('DlsColors copyWith and lerp operations', () {
      const c1 = DlsColors.light;
      const c2 = DlsColors.dark;
      final modified = c1.copyWith(canvas: const Color(0xFF000000));
      expect(modified.canvas, equals(const Color(0xFF000000)));
      expect(modified.surface, equals(c1.surface));

      final lerped = c1.lerp(c2, 0.5);
      expect(lerped.canvas, equals(Color.lerp(c1.canvas, c2.canvas, 0.5)));
      expect(c1.lerp(null, 0.5), equals(c1));
    });

    test('DlsRadii token definitions and border radius helpers', () {
      const radii = DlsRadii.standard;
      expect(radii.xs, equals(0.0));
      expect(radii.sm, equals(0.0));
      expect(radii.md, equals(0.0));
      expect(radii.lg, equals(0.0));
      expect(radii.xl, equals(0.0));
      expect(radii.pill, equals(0.0));

      expect(radii.borderXs(), equals(BorderRadius.zero));
      expect(radii.borderSm(), equals(BorderRadius.zero));
      expect(radii.borderMd(), equals(BorderRadius.zero));
      expect(radii.borderLg(), equals(BorderRadius.zero));
      expect(radii.borderXl(), equals(BorderRadius.zero));
      expect(radii.borderPill(), equals(BorderRadius.zero));

      final copy = radii.copyWith(xs: 10.0);
      expect(copy.xs, equals(10.0));
      expect(copy.sm, equals(0.0));

      final lerped = radii.lerp(const DlsRadii(xs: 16, sm: 24, md: 32, lg: 48, xl: 64, pill: 1000), 0.5);
      expect(lerped.xs, equals(8.0));
      expect(radii.lerp(null, 0.5), equals(radii));
    });

    test('DlsSpacing grid & touchscreen ergonomics tokens', () {
      const spacing = DlsSpacing.standard;
      expect(spacing.xs, equals(4.0));
      expect(spacing.sm, equals(8.0));
      expect(spacing.md, equals(12.0));
      expect(spacing.lg, equals(16.0));
      expect(spacing.xl, equals(24.0));
      expect(spacing.xxl, equals(32.0));
      expect(spacing.hero, equals(48.0));

      expect(spacing.touchTargetMin, equals(48.0));
      expect(spacing.touchTargetStandard, equals(56.0));
      expect(spacing.touchTargetHero, equals(64.0));

      final copy = spacing.copyWith(xs: 6.0);
      expect(copy.xs, equals(6.0));

      final lerped = spacing.lerp(const DlsSpacing(xs: 8, sm: 16, md: 24, lg: 32, xl: 48, xxl: 64, hero: 96), 0.5);
      expect(lerped.xs, equals(6.0));
      expect(spacing.lerp(null, 0.5), equals(spacing));
    });

    test('DlsShadows diffuse ambient shadows and aliases', () {
      final lightShadows = DlsShadows.light;
      expect(lightShadows.softSm, isNotEmpty);
      expect(lightShadows.softMd, isNotEmpty);
      expect(lightShadows.softLg, isNotEmpty);
      expect(lightShadows.low, equals(lightShadows.softSm));
      expect(lightShadows.medium, equals(lightShadows.softMd));
      expect(lightShadows.high, equals(lightShadows.softLg));
      expect(lightShadows.glowPrimary, isEmpty);
      expect(lightShadows.glowSuccess, isEmpty);

      final darkShadows = DlsShadows.dark;
      expect(darkShadows.softSm, isNotEmpty);

      const highContrastShadows = DlsShadows.kioskHighContrast;
      expect(highContrastShadows.softSm, isEmpty);

      final copy = lightShadows.copyWith(softSm: []);
      expect(copy.softSm, isEmpty);
      expect(lightShadows.lerp(darkShadows, 0.5), isNotNull);
      expect(lightShadows.lerp(null, 0.5), equals(lightShadows));
    });

    test('DlsAnimations micro-interaction tokens', () {
      const animations = DlsAnimations.standard;
      expect(animations.organicSpring, equals(const Cubic(0.34, 1.56, 0.64, 1.0)));
      expect(animations.organicEaseOut, equals(Curves.easeOutCubic));
      expect(animations.fastFeedback, equals(const Duration(milliseconds: 150)));
      expect(animations.normal, equals(const Duration(milliseconds: 250)));
      expect(animations.slow, equals(const Duration(milliseconds: 400)));

      final copy = animations.copyWith(fastFeedback: const Duration(milliseconds: 100));
      expect(copy.fastFeedback.inMilliseconds, equals(100));
      expect(animations.lerp(null, 0.5), equals(animations));
      expect(animations.lerp(copy, 0.2).fastFeedback, equals(animations.fastFeedback));
      expect(animations.lerp(copy, 0.8).fastFeedback, equals(copy.fastFeedback));
    });

    test('DlsTypography scale & 88pt displayHero figure', () {
      final heroStyle = DlsTypography.displayHero();
      expect(heroStyle.fontSize, equals(88.0));
      expect(heroStyle.fontWeight, equals(FontWeight.w700));
      expect(heroStyle.fontFeatures, contains(const FontFeature.tabularFigures()));

      final largeStyle = DlsTypography.displayLarge();
      expect(largeStyle.fontSize, equals(56.0));
      expect(largeStyle.fontFeatures, contains(const FontFeature.tabularFigures()));

      final mediumStyle = DlsTypography.displayMedium();
      expect(mediumStyle.fontSize, equals(36.0));

      final sectionStyle = DlsTypography.titleSection();
      expect(sectionStyle.fontSize, equals(24.0));

      final cardStyle = DlsTypography.titleCard();
      expect(cardStyle.fontSize, equals(18.0));

      final subcardStyle = DlsTypography.titleSubcard();
      expect(subcardStyle.fontSize, equals(16.0));

      final bodyKioskStyle = DlsTypography.bodyKiosk();
      expect(bodyKioskStyle.fontSize, equals(16.0));

      final bodyStandardStyle = DlsTypography.bodyStandard();
      expect(bodyStandardStyle.fontSize, equals(14.0));

      final captionKioskStyle = DlsTypography.captionKiosk();
      expect(captionKioskStyle.fontSize, equals(13.0));

      final captionSmallStyle = DlsTypography.captionSmall();
      expect(captionSmallStyle.fontSize, equals(11.0));
      expect(captionSmallStyle.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('DlsThemeExtension holds all strongly-typed sub-tokens', () {
      final lightExt = DlsThemeExtension.light;
      expect(lightExt.colors, equals(DlsColors.light));
      expect(lightExt.radii, equals(DlsRadii.standard));
      expect(lightExt.spacing, equals(DlsSpacing.standard));
      expect(lightExt.shadows, equals(DlsShadows.light));
      expect(lightExt.animations, equals(DlsAnimations.standard));

      final darkExt = DlsThemeExtension.dark;
      expect(darkExt.colors, equals(DlsColors.dark));
      expect(darkExt.shadows, equals(DlsShadows.dark));

      final kioskExt = DlsThemeExtension.kioskHighContrast;
      expect(kioskExt.colors, equals(DlsColors.kioskHighContrast));
      expect(kioskExt.shadows, equals(DlsShadows.kioskHighContrast));

      final copy = lightExt.copyWith(colors: DlsColors.dark);
      expect(copy.colors, equals(DlsColors.dark));

      final lerped = lightExt.lerp(darkExt, 0.5);
      expect(lerped.colors.canvas, equals(Color.lerp(DlsColors.light.canvas, DlsColors.dark.canvas, 0.5)));
      expect(lightExt.lerp(null, 0.5), equals(lightExt));
    });
  });

  group('BeenutTheme ThemeData Registration & Backward Compatibility', () {
    test('BeenutTheme caches static ThemeData instances across multiple accesses', () {
      expect(identical(BeenutTheme.light, BeenutTheme.light), isTrue);
      expect(identical(BeenutTheme.dark, BeenutTheme.dark), isTrue);
      expect(identical(BeenutTheme.kioskHighContrast, BeenutTheme.kioskHighContrast), isTrue);
    });

    test('BeenutTheme.light registers DlsThemeExtension and WorkbenchColors', () {

      final theme = BeenutTheme.light;
      expect(theme.brightness, equals(Brightness.light));

      final dlsExt = theme.extension<DlsThemeExtension>();
      expect(dlsExt, isNotNull);
      expect(dlsExt!.colors, equals(DlsColors.light));

      final colorsExt = theme.extension<DlsColors>();
      expect(colorsExt, isNotNull);
      expect(colorsExt!.canvas, equals(const Color(0xFFF4F4F4)));

      final radiiExt = theme.extension<DlsRadii>();
      expect(radiiExt, isNotNull);
      expect(radiiExt!.lg, equals(0.0));

      final spacingExt = theme.extension<DlsSpacing>();
      expect(spacingExt, isNotNull);
      expect(spacingExt!.hero, equals(48.0));

      final shadowsExt = theme.extension<DlsShadows>();
      expect(shadowsExt, isNotNull);

      final animExt = theme.extension<DlsAnimations>();
      expect(animExt, isNotNull);

      final workbenchExt = theme.extension<WorkbenchColors>();
      expect(workbenchExt, isNotNull);
    });

    test('BeenutTheme.dark registers DlsThemeExtension dark tokens', () {
      final theme = BeenutTheme.dark;
      expect(theme.brightness, equals(Brightness.dark));

      final dlsExt = theme.extension<DlsThemeExtension>();
      expect(dlsExt, isNotNull);
      expect(dlsExt!.colors.canvas, equals(const Color(0xFF161616)));

      final workbenchExt = theme.extension<WorkbenchColors>();
      expect(workbenchExt, isNotNull);
    });

    test('BeenutTheme.kioskHighContrast registers DlsThemeExtension high-contrast tokens', () {
      final theme = BeenutTheme.kioskHighContrast;
      expect(theme.brightness, equals(Brightness.dark));

      final dlsExt = theme.extension<DlsThemeExtension>();
      expect(dlsExt, isNotNull);
      expect(dlsExt!.colors.canvas, equals(const Color(0xFF000000)));
      expect(dlsExt.colors.accent, equals(const Color(0xFFFFD600)));

      final workbenchExt = theme.extension<WorkbenchColors>();
      expect(workbenchExt, isNotNull);
      expect(workbenchExt!.action, equals(const Color(0xFFFFD600)));
    });
  });

  group('ThemeController & AppThemeMode State Notifier Tests', () {
    setUp(() {
      ThemeController.setThemeMode(AppThemeMode.light);
    });

    test('Initial theme mode is light', () {
      expect(ThemeController.mode, equals(AppThemeMode.light));
      expect(ThemeController.currentMode.value, equals(AppThemeMode.light));
      expect(ThemeController.currentThemeData.brightness, equals(Brightness.light));
      expect(
        ThemeController.currentThemeData.extension<DlsThemeExtension>()?.colors,
        equals(DlsColors.light),
      );
    });

    test('setThemeMode updates currentMode and legacy themeMode', () {
      AppThemeMode? notifiedMode;
      void listener() {
        notifiedMode = ThemeController.currentMode.value;
      }

      ThemeController.currentMode.addListener(listener);

      ThemeController.setThemeMode(AppThemeMode.dark);
      expect(notifiedMode, equals(AppThemeMode.dark));
      expect(ThemeController.mode, equals(AppThemeMode.dark));
      expect(ThemeController.themeMode.value, equals(ThemeMode.dark));

      ThemeController.setThemeMode(AppThemeMode.kioskHighContrast);
      expect(notifiedMode, equals(AppThemeMode.kioskHighContrast));
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.currentMode.removeListener(listener);
    });

    test('update string parser handles light, dark, highcontrast, kioskhighcontrast', () {
      ThemeController.update('dark');
      expect(ThemeController.mode, equals(AppThemeMode.dark));

      ThemeController.update('highcontrast');
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.update('kioskhighcontrast');
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.update('kiosk');
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.update('light');
      expect(ThemeController.mode, equals(AppThemeMode.light));
    });

    test('update string parser handles edge cases: mixed case, whitespace, unknown values, system, and toMapString output', () {
      // Mixed case & whitespace
      ThemeController.update('  DARK  ');
      expect(ThemeController.mode, equals(AppThemeMode.dark));

      ThemeController.update('  HIGH_CONTRAST  ');
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.update('  LIGHT  ');
      expect(ThemeController.mode, equals(AppThemeMode.light));

      // toMapString round-trip
      ThemeController.update(AppThemeMode.kioskHighContrast.toMapString());
      expect(ThemeController.mode, equals(AppThemeMode.kioskHighContrast));

      ThemeController.update(AppThemeMode.dark.toMapString());
      expect(ThemeController.mode, equals(AppThemeMode.dark));

      ThemeController.update(AppThemeMode.light.toMapString());
      expect(ThemeController.mode, equals(AppThemeMode.light));

      // System mode
      ThemeController.update('system');
      expect(ThemeController.themeMode.value, equals(ThemeMode.system));
      expect(ThemeController.mode, equals(AppThemeMode.light));

      // Unknown / legacy / invalid fallback values -> defaults to light mode
      ThemeController.update('invalid_value');
      expect(ThemeController.mode, equals(AppThemeMode.light));

      ThemeController.update('');
      expect(ThemeController.mode, equals(AppThemeMode.light));

      ThemeController.update('   ');
      expect(ThemeController.mode, equals(AppThemeMode.light));

      ThemeController.update('12345');
      expect(ThemeController.mode, equals(AppThemeMode.light));
    });

    testWidgets('BuildContext extension getters and BeenutTheme helpers work seamlessly across all theme modes with WorkbenchColors', (WidgetTester tester) async {
      for (final themeData in [BeenutTheme.light, BeenutTheme.dark, BeenutTheme.kioskHighContrast]) {
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(capturedContext.dlsTheme, isNotNull);
        expect(capturedContext.workbenchColors, isNotNull);
        expect(BeenutTheme.colors(capturedContext), equals(capturedContext.workbenchColors));
        expect(BeenutTheme.inkColor(capturedContext), isA<Color>());
        expect(BeenutTheme.mutedColor(capturedContext), isA<Color>());
        expect(BeenutTheme.lineColor(capturedContext), isA<Color>());
        expect(BeenutTheme.surfaceColor(capturedContext), isA<Color>());
        expect(BeenutTheme.raisedColor(capturedContext), isA<Color>());
        expect(BeenutTheme.shellColor(capturedContext), isA<Color>());
        expect(BeenutTheme.outlineVariant(capturedContext), isA<Color>());
        expect(BeenutTheme.primaryColor(capturedContext), isA<Color>());
        expect(BeenutTheme.successColor(capturedContext), isA<Color>());
        expect(BeenutTheme.warningColor(capturedContext), isA<Color>());
        expect(BeenutTheme.dangerColor(capturedContext), isA<Color>());
        expect(BeenutTheme.dataTextStyle(capturedContext), isNotNull);
      }
    });

    testWidgets('BuildContext extension getters work inside widget tree', (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedContext.dlsTheme, isNotNull);
      expect(capturedContext.dlsColors.canvas, equals(const Color(0xFFF4F4F4)));
      expect(capturedContext.dlsRadii.lg, equals(0.0));
      expect(capturedContext.dlsSpacing.hero, equals(48.0));
      expect(capturedContext.dlsShadows.softSm, isNotEmpty);
      expect(capturedContext.dlsAnimations.organicSpring, isNotNull);
      expect(capturedContext.workbenchColors, isNotNull);
    });
  });
}
