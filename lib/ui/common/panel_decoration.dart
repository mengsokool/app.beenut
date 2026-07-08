import 'package:flutter/material.dart';

BoxDecoration panelDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainer,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: scheme.outlineVariant),
  );
}
