import 'package:beenut/core/theme.dart';
import 'package:beenut/core/workbench_tokens.dart';
import 'package:beenut/ui/common/setting_choice_cards.dart';
import 'package:beenut/ui/common/setting_controls.dart';
import 'package:beenut/ui/common/setting_group.dart';
import 'package:beenut/ui/common/setting_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('runtime choices render as divided workbench rows', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: SettingsGroup(
              title: 'Model runtime',
              children: [
                ChoiceCardsRow(
                  value: 'onnx',
                  enabled: true,
                  onSelected: (value) => selected = value,
                  options: const [
                    ChoiceOption(
                      value: 'onnx',
                      title: 'ONNX',
                      detail: 'General devices',
                      icon: Icons.memory_outlined,
                    ),
                    ChoiceOption(
                      value: 'hailo',
                      title: 'Hailo',
                      detail: 'Production accelerator',
                      icon: Icons.developer_board_outlined,
                    ),
                    ChoiceOption(
                      value: 'mock',
                      title: 'Mock',
                      detail: 'UI development',
                      icon: Icons.science_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text('ONNX'), findsOneWidget);
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any(
            (material) => material.color == WorkbenchColors.light.actionSoft,
          ),
      isTrue,
    );

    await tester.tap(find.text('Hailo'));
    expect(selected, 'hailo');
  });

  testWidgets('settings rows stack controls without compact overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsGroup(
            title: 'Model source',
            children: [
              PathSettingRow(
                label: 'ONNX model path',
                description: '',
                value:
                    '/opt/beenut/models/production/very-long-model-file-name.onnx',
                buttonLabel: 'Select model',
                enabled: true,
                onBrowse: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ONNX model path'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workbench switch exposes and changes binary state', (
    tester,
  ) async {
    bool? nextValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: WorkbenchSwitch(
            value: false,
            onChanged: (value) => nextValue = value,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(WorkbenchSwitch));
    expect(semantics.flagsCollection.isToggled.toBoolOrNull(), isFalse);

    await tester.tap(find.byType(WorkbenchSwitch));
    expect(nextValue, isTrue);
  });
}
