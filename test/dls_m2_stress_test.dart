import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group('M2 Stress Testing: CountDashboardPanel', () {
    testWidgets('Renders extreme count 0 and 99999 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final countVal in [0, 99999, 1000000]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: BeenutTheme.light,
            home: Scaffold(
              body: CountDashboardPanel(
                count: countVal,
                targetCount: 100000,
                statusTitle: 'Counting',
                statusSubtitle: 'High volume stress test',
                classBreakdowns: const [],
              ),
            ),
          ),
        );

        expect(find.text('$countVal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Renders multi-class breakdowns with long class names without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final longBreakdowns = List.generate(
        15,
        (index) => ClassBreakdownItem(
          label: 'very_long_industrial_component_class_name_designator_spec_part_number_$index',
          count: index * 123,
          color: Colors.blue,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: CountDashboardPanel(
              count: 9999,
              targetCount: 10000,
              statusTitle: 'Active',
              statusSubtitle: 'Multi-class breakdown stress test',
              classBreakdowns: longBreakdowns,
            ),
          ),
        ),
      );

      expect(find.text('CLASS BREAKDOWN'), findsOneWidget);
      expect(find.textContaining('very_long_industrial_component_class_name_designator_spec_part_number_0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders dense container layout (isDense mode)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 180));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.kioskHighContrast,
          home: Scaffold(
            body: CountDashboardPanel(
              count: 50,
              targetCount: 50,
              statusTitle: 'Complete',
              statusSubtitle: 'Hidden in dense mode',
              classBreakdowns: const [],
            ),
          ),
        ),
      );

      expect(find.text('50'), findsNWidgets(2)); // Count & Target
      expect(find.text('PASS'), findsOneWidget);
      // Subtitle should be omitted in dense mode
      expect(find.text('Hidden in dense mode'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders muted state and loading state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: CountDashboardPanel(
              count: 0,
              isMuted: true,
              isLoading: true,
              statusTitle: 'Standby',
              statusSubtitle: 'Sensor muted',
              classBreakdowns: const [],
            ),
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('M2 Stress Testing: LiveStreamCameraPane', () {
    testWidgets('Handles null/loading/error/disconnected camera states gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Disconnected state
      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: LiveStreamCameraPane(
              state: MachineState.empty,
              connected: false,
              keywords: const [],
            ),
          ),
        ),
      );
      expect(find.text('CONNECTION LOST'), findsOneWidget);

      // Camera error state
      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: LiveStreamCameraPane(
              state: MachineState.empty.copyWith(camera: 'error'),
              connected: true,
              keywords: const [],
            ),
          ),
        ),
      );
      expect(find.text('CAMERA OFFLINE'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles dense detection list (100 overlapping detections) without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final denseDetections = List.generate(
        100,
        (index) => Detection(
          label: index % 2 == 0 ? 'bolt' : 'nut',
          confidence: 0.85 + (index % 10) * 0.01,
          x: (index % 10) * 0.09,
          y: (index ~/ 10) * 0.09,
          w: 0.08,
          h: 0.08,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: LiveStreamCameraPane(
              state: MachineState.empty.copyWith(
                camera: 'ready',
                detections: denseDetections,
              ),
              connected: true,
              keywords: const ['bolt', 'nut'],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('LIVE 30 FPS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles pause blur state transition and resume', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool isPaused = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: BeenutTheme.light,
              home: Scaffold(
                body: LiveStreamCameraPane(
                  state: MachineState.empty.copyWith(
                    camera: 'ready',
                    previewPaused: isPaused,
                  ),
                  connected: true,
                  keywords: const ['bolt'],
                  onTogglePause: () => setState(() => isPaused = !isPaused),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('LIVE 30 FPS'), findsOneWidget);
      expect(find.text('PAUSE'), findsOneWidget);

      // Tap pause button
      await tester.tap(find.text('PAUSE'));
      await tester.pump();

      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('VIDEO STREAM PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);

      // Tap resume button
      await tester.tap(find.text('RESUME'));
      await tester.pump();

      expect(find.text('LIVE 30 FPS'), findsOneWidget);
      expect(find.text('PAUSE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('M2 Stress Testing: PartSelectorCard & PartCatalogSelector', () {
    const extremeLongPart = PartType(
      id: 'super_long_part',
      name: 'Super Ultra Mega Long Custom Industrial Part Type Designation Model 9000-X-DELUXE',
      image: '',
      keywords: ['kw1', 'kw2', 'kw3', 'kw4', 'kw5', 'kw6', 'kw7', 'kw8', 'kw9', 'kw10'],
      enabled: true,
    );

    const disabledPart = PartType(
      id: 'disabled_part',
      name: 'Legacy Obsolete Part',
      image: '',
      keywords: ['legacy'],
      enabled: false,
    );

    testWidgets('PartSelectorCard handles extremely long part name and keywords without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PartSelectorCard(
                  selectedPart: extremeLongPart,
                  availablePartsCount: 5,
                  onTapOpenCatalog: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Super Ultra Mega Long Custom'), findsOneWidget);
      expect(find.text('10 classes mapped'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PartSelectorCard handles zero available parts (disabled interactive state)', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PartSelectorCard(
                  selectedPart: null,
                  availablePartsCount: 0,
                  onTapOpenCatalog: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Part Target'), findsOneWidget);
      expect(find.text('0 parts available'), findsOneWidget);

      await tester.tap(find.byType(PartSelectorCard));
      await tester.pump();
      expect(tapped, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PartCatalogSelector handles search with no matches, category filter, and clear search', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: PartCatalogSelector(
              parts: const [extremeLongPart, disabledPart],
              selectedId: 'super_long_part',
              onSelectPart: (_) {},
            ),
          ),
        ),
      );

      // Search non-existent query
      await tester.enterText(find.byType(TextField), 'nonexistent_query_xyz');
      await tester.pump();

      expect(find.text('No matching parts found'), findsOneWidget);

      // Clear search via clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(find.textContaining('Super Ultra Mega Long Custom'), findsOneWidget);

      // Switch category chip to MULTI
      await tester.tap(find.text('Multi-Class'));
      await tester.pump();

      expect(find.textContaining('Super Ultra Mega Long Custom'), findsOneWidget);

      // Switch category chip to SINGLE
      await tester.tap(find.text('Single-Class'));
      await tester.pump();

      expect(find.text('No matching parts found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
