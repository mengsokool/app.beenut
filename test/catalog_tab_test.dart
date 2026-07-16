import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/settings/tabs/catalog_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('target list hides internal ids and shows mapped classes', (
    tester,
  ) async {
    const internalId = 'target_mrbe34pj';
    final config = MachineConfig.empty.copyWithPartCatalog(
      partTypes: const [
        PartType(
          id: internalId,
          name: 'Capsules',
          image: '',
          keywords: ['capsules'],
          enabled: true,
        ),
        PartType(
          id: 'target_without_classes',
          name: 'Unmapped target',
          image: '',
          keywords: [],
          enabled: true,
        ),
      ],
      selectedPartType: internalId,
    );
    I18n.updateFromConfig(config);

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: PartCatalogEditor(
            config: config,
            modelLabels: const ['capsules'],
            enabled: true,
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Capsules'), findsOneWidget);
    expect(find.text('Model classes: capsules'), findsOneWidget);
    expect(find.text('No model classes mapped'), findsOneWidget);
    expect(find.text(internalId), findsNothing);
    expect(find.text('target_without_classes'), findsNothing);
    expect(
      tester
          .widget<Text>(find.text('Model classes: capsules'))
          .style
          ?.fontFamily,
      BeenutTheme.fontFamily,
    );
  });
}
