import 'package:beenut/core/dls_tokens.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empirical Verification: Dynamic Theme Switching & State Preservation', () {
    tearDown(() {
      ThemeController.setThemeMode(AppThemeMode.light);
    });

    testWidgets('TS1: Dynamic Theme Switch updates DlsThemeExtension colors across Light, Dark, High Contrast without state loss', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final textController = TextEditingController(text: 'Active Operator Notes');
      bool switchValue = true;
      double sliderValue = 0.75;
      AppThemeMode capturedMode = AppThemeMode.light;

      // Wrap full component layout in a ValueListenableBuilder listening to ThemeController.currentMode
      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: ThemeController.currentMode,
          builder: (context, mode, child) {
            final theme = switch (mode) {
              AppThemeMode.light => BeenutTheme.light,
              AppThemeMode.dark => BeenutTheme.dark,
              AppThemeMode.kioskHighContrast => BeenutTheme.kioskHighContrast,
            };

            return MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1. Header Status Bar
                      KioskHeaderStatusBar(
                        connectionState: DaemonConnectionState.connected,
                        cameraStatusText: 'Camera Ready',
                        activeModelName: 'yolo_model_v1.onnx',
                        currentThemeMode: mode,
                        hardwareTemperature: 45.0,
                        onThemeModeChanged: (newMode) {
                          capturedMode = newMode;
                          ThemeController.setThemeMode(newMode);
                        },
                        onOpenSettings: () {},
                      ),

                      // 2. Live Stream Camera Pane
                      SizedBox(
                        height: 300,
                        child: LiveStreamCameraPane(
                          state: MachineState.empty.copyWith(
                            camera: 'ok',
                            model: 'ok',
                            temperature: 45.0,
                            previewTransport: 'shm_nv12',
                            previewUrl: '/tmp/test_shm',
                            previewPaused: false,
                            detections: const [
                              Detection(
                                label: 'bolt',
                                confidence: 0.95,
                                x: 0.1,
                                y: 0.1,
                                w: 0.2,
                                h: 0.2,
                              ),
                            ],
                          ),
                          connected: true,
                          keywords: const ['bolt'],
                        ),
                      ),

                      // 3. Part Selector Card
                      PartSelectorCard(
                        selectedPart: const PartType(
                          id: 'p1',
                          name: 'Hex Bolt M10',
                          image: '',
                          keywords: ['bolt'],
                          enabled: true,
                        ),
                        availablePartsCount: 5,
                        onTapOpenCatalog: () {},
                      ),

                      // 4. Count Dashboard Panel
                      const SizedBox(
                        height: 350,
                        child: CountDashboardPanel(
                          count: 142,
                          targetCount: 200,
                          status: CountDashboardStatus.counting,
                          statusTitle: 'COUNTING',
                          statusSubtitle: 'Batch processing',
                          classBreakdowns: [
                            ClassBreakdownItem(
                              label: 'Hex Bolt M10',
                              count: 142,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ),

                      // 5. Kiosk Form Controls
                      StatefulBuilder(
                        builder: (context, setState) {
                          return Column(
                            children: [
                              KioskTextField(
                                controller: textController,
                                label: 'Notes',
                              ),
                              KioskSwitch(
                                label: 'Auto Pause',
                                value: switchValue,
                                onChanged: (v) => setState(() => switchValue = v),
                              ),
                              KioskSlider(
                                label: 'Threshold',
                                value: sliderValue,
                                onChanged: (v) => setState(() => sliderValue = v),
                              ),
                              KioskButton(
                                label: 'Execute',
                                onPressed: () {},
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // --- PHASE 1: LIGHT MODE VERIFICATION ---
      expect(ThemeController.mode, AppThemeMode.light);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Active Operator Notes'), findsOneWidget);

      // Verify Light mode theme colors via BuildContext
      final lightContext = tester.element(find.byType(KioskHeaderStatusBar));
      expect(lightContext.dlsColors.canvas, const Color(0xFFFBF9F5));
      expect(lightContext.dlsColors.surface, const Color(0xFFFFFFFF));
      expect(lightContext.dlsColors.accent, const Color(0xFFD97706));

      // --- PHASE 2: SWITCH TO DARK OBSIDIAN MODE ---
      ThemeController.setThemeMode(AppThemeMode.dark);
      await tester.pumpAndSettle();

      expect(ThemeController.mode, AppThemeMode.dark);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Active Operator Notes'), findsOneWidget);

      final darkContext = tester.element(find.byType(KioskHeaderStatusBar));
      expect(darkContext.dlsColors.canvas, const Color(0xFF121110));
      expect(darkContext.dlsColors.surface, const Color(0xFF1C1B18));
      expect(darkContext.dlsColors.accent, const Color(0xFFF59E0B));

      // --- PHASE 3: SWITCH TO KIOSK HIGH CONTRAST MODE ---
      ThemeController.setThemeMode(AppThemeMode.kioskHighContrast);
      await tester.pumpAndSettle();

      expect(ThemeController.mode, AppThemeMode.kioskHighContrast);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Active Operator Notes'), findsOneWidget);

      final hcContext = tester.element(find.byType(KioskHeaderStatusBar));
      expect(hcContext.dlsColors.canvas, const Color(0xFF000000));
      expect(hcContext.dlsColors.surface, const Color(0xFF121212));
      expect(hcContext.dlsColors.accent, const Color(0xFFFFD600));

      // --- PHASE 4: SWITCH BACK TO LIGHT MODE VIA HEADER TOGGLE ---
      await tester.tap(find.byTooltip('Switch Theme Mode'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light Warm Mode'));
      await tester.pumpAndSettle();

      expect(capturedMode, AppThemeMode.light);
      expect(ThemeController.mode, AppThemeMode.light);
      expect(find.text('Active Operator Notes'), findsOneWidget);
      expect(switchValue, isTrue);
      expect(sliderValue, 0.75);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TS2: Dialog & Catalog State Persists across Dynamic Theme Switch', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: ThemeController.currentMode,
          builder: (context, mode, child) {
            final theme = switch (mode) {
              AppThemeMode.light => BeenutTheme.light,
              AppThemeMode.dark => BeenutTheme.dark,
              AppThemeMode.kioskHighContrast => BeenutTheme.kioskHighContrast,
            };

            return MaterialApp(
              theme: theme,
              home: Scaffold(
                body: PartCatalogSelector(
                  parts: const [
                    PartType(
                      id: 'p1',
                      name: 'M10 Hex Bolt',
                      image: '',
                      keywords: ['bolt', 'm10'],
                      enabled: true,
                    ),
                    PartType(
                      id: 'p2',
                      name: 'M8 Flange Nut',
                      image: '',
                      keywords: ['nut'],
                      enabled: true,
                    ),
                  ],
                  selectedId: 'p1',
                  onSelectPart: (_) {},
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query in PartCatalogSelector
      await tester.enterText(find.byType(TextField), 'Nut');
      await tester.pumpAndSettle();

      expect(find.text('M8 Flange Nut'), findsOneWidget);
      expect(find.text('M10 Hex Bolt'), findsNothing);

      // Switch theme to Dark Mode dynamically while search query is present
      ThemeController.setThemeMode(AppThemeMode.dark);
      await tester.pumpAndSettle();

      // Verify state (search query & filtered items) persisted
      expect(find.text('M8 Flange Nut'), findsOneWidget);
      expect(find.text('M10 Hex Bolt'), findsNothing);

      // Switch theme to High Contrast Mode dynamically
      ThemeController.setThemeMode(AppThemeMode.kioskHighContrast);
      await tester.pumpAndSettle();

      expect(find.text('M8 Flange Nut'), findsOneWidget);
      expect(find.text('M10 Hex Bolt'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
