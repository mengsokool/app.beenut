import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';

BoxDecoration panelDecoration(BuildContext context) {
  final tokens = context.workbenchColors;
  return BoxDecoration(
    color: tokens.surface,
    borderRadius: BeenutTheme.radiusPanel,
    border: Border.all(color: tokens.line),
  );
}
