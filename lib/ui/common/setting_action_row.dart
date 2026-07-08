import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'setting_controls.dart';
import 'setting_row_shell.dart';

class RowAction {
  const RowAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
}

class ActionSettingRow extends StatelessWidget {
  const ActionSettingRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    return SettingRowShell(
      leading: SettingIcon(icon: icon, color: iconColor),
      label: label,
      description: description,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in actions)
            action.primary
                ? FilledButton(
                    onPressed: action.onPressed,
                    style: _filledActionStyle(),
                    child: Text(action.label),
                  )
                : OutlinedButton(
                    onPressed: action.onPressed,
                    style: _outlinedActionStyle(),
                    child: Text(action.label),
                  ),
        ],
      ),
    );
  }

  ButtonStyle _filledActionStyle() => FilledButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: const TextStyle(
      fontFamily: BeenutTheme.fontFamily,
      fontFamilyFallback: BeenutTheme.fontFamilyFallback,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  ButtonStyle _outlinedActionStyle() => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: const TextStyle(
      fontFamily: BeenutTheme.fontFamily,
      fontFamilyFallback: BeenutTheme.fontFamilyFallback,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
