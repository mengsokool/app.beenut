import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'panel_decoration.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
          DecoratedBox(
            decoration: panelDecoration(context),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      color: BeenutTheme.outlineVariant(context),
                      indent: 0,
                      endIndent: 0,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
