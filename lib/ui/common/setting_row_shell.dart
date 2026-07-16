import 'package:flutter/material.dart';

import '../../core/workbench_tokens.dart';

class SettingRowShell extends StatelessWidget {
  const SettingRowShell({
    super.key,
    required this.label,
    required this.trailing,
    this.description = '',
    this.supporting,
    this.leading,
  });

  final Widget? leading;
  final String label;
  final String description;
  final Widget? supporting;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: WorkbenchMetric.technicianRowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchSpace.x3,
          vertical: WorkbenchSpace.x2,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackControl = constraints.maxWidth < 520;
            final information = _SettingRowInformation(
              leading: leading,
              label: label,
              description: description,
              supporting: supporting,
            );
            if (stackControl) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  information,
                  const SizedBox(height: WorkbenchSpace.x2),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: information),
                const SizedBox(width: WorkbenchSpace.x4),
                trailing,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingRowInformation extends StatelessWidget {
  const _SettingRowInformation({
    required this.leading,
    required this.label,
    required this.description,
    required this.supporting,
  });

  final Widget? leading;
  final String label;
  final String description;
  final Widget? supporting;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.workbenchColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: WorkbenchSpace.x1),
            child: leading!,
          ),
          const SizedBox(width: WorkbenchSpace.x3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: WorkbenchSpace.x1),
                Text(description, style: textTheme.bodySmall),
              ],
              if (supporting != null) ...[
                const SizedBox(height: WorkbenchSpace.x1),
                supporting!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
