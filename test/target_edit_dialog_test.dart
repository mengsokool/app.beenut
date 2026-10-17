import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/settings/widgets/target_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const part = PartType(
  id: 'nut',
  name: 'Nut',
  image: '',
  keywords: ['nut'],
  enabled: true,
);

void main() {
  setUp(() => I18n.updateFromConfig(MachineConfig.empty));

  testWidgets('short screen edits and saves all target fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 432));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PartType? saved;
    await openEditor(tester, onSave: (value) => saved = value);
    expect(
      tester.getSize(find.byKey(const ValueKey('target-edit-form'))).width,
      lessThanOrEqualTo(400),
    );
    expect(find.text('Default icon'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Washer');
    await tester.ensureVisible(find.byKey(const ValueKey('add-class')));
    await tester.tap(find.byKey(const ValueKey('add-class')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-class-washer')));
    await tester.tap(find.byKey(const ValueKey('classes-done')));
    await tester.pump();
    final alias = find.byKey(const ValueKey('class-name-washer'));
    await tester.ensureVisible(alias);
    await tester.enterText(alias, 'แหวนรอง');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Washer');
    expect(saved?.keywords, ['nut', 'washer']);
    expect(saved?.enabled, isFalse);
    expect(saved?.id, 'nut');
    expect(saved?.classNames, {'washer': 'แหวนรอง'});
    expect(
      PartType.fromJson(
        saved!.copyWith(enabled: true).toJson(),
      ).displayNameForClass('washer'),
      'แหวนรอง',
    );
    expect(find.byType(TargetEditDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank name disables save and cancel discards edits', (
    tester,
  ) async {
    var saved = false;
    await openEditor(tester, onSave: (_) => saved = true);
    await tester.enterText(find.byType(TextField).first, ' ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.byType(TargetEditDialog), findsNothing);
  });

  testWidgets('large model uses search separately from naming selected items', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 432));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PartType? saved;
    await openEditor(
      tester,
      onSave: (value) => saved = value,
      labels: ['nut', for (var i = 0; i < 80; i++) 'class_$i'],
    );
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('class_79'), findsNothing);
    expect(find.byKey(const ValueKey('class-name-nut')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('add-class')));
    await tester.tap(find.byKey(const ValueKey('add-class')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('class-search')),
      'class_79',
    );
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-class-class_79')));
    expect(saved, isNull);
    await tester.tap(find.byKey(const ValueKey('classes-done')));
    await tester.pumpAndSettle();
    final alias = find.byKey(const ValueKey('class-name-class_79'));
    await tester.ensureVisible(alias);
    await tester.enterText(alias, 'ชิ้นงานใหม่');
    await tester.tap(find.byKey(const ValueKey('remove-class-nut')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('target-save')));
    await tester.pumpAndSettle();
    expect(saved?.keywords, ['class_79']);
    expect(saved?.classNames['class_79'], 'ชิ้นงานใหม่');
    expect(tester.takeException(), isNull);
  });
}

Future<void> openEditor(
  WidgetTester tester, {
  required ValueChanged<PartType> onSave,
  List<String> labels = const ['nut', 'washer'],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: BeenutTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TargetEditDialog(
                part: part,
                modelLabels: labels,
                onSave: onSave,
                onDelete: () {},
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
