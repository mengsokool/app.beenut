import 'package:flutter/material.dart';

import '../../core/theme.dart';

BoxDecoration panelDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainer,
    borderRadius: BeenutTheme.radiusPanel,
    border: Border.all(color: scheme.outlineVariant),
  );
}
