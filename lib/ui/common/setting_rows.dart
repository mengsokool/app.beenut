import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/i18n.dart';
import 'setting_primitives.dart';

class IconInfoRow extends StatelessWidget {
  const IconInfoRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.description = '',
    this.tone = RowTone.neutral,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final String value;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    return SettingRowShell(
      leading: SettingIcon(icon: icon, color: iconColor),
      label: label,
      description: description,
      trailing: StatusPill(value: value, tone: tone),
    );
  }
}

class SelectSettingRow extends StatefulWidget {
  const SelectSettingRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final String description;
  final String value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  State<SelectSettingRow> createState() => _SelectSettingRowState();
}

class _SelectSettingRowState extends State<SelectSettingRow> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingRowShell(
      label: widget.label,
      description: widget.description,
      trailing: MenuAnchor(
        controller: _menuController,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(150, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(150, double.infinity)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
        ),
        menuChildren: [
          for (final option in widget.options)
            MenuItemButton(
              onPressed: () {
                widget.onSelected(option);
                _menuController.close();
              },
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(150, 48)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
                alignment: Alignment.centerLeft,
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
        child: GestureDetector(
          onTap: widget.enabled
              ? () {
                  if (_menuController.isOpen) {
                    _menuController.close();
                  } else {
                    _menuController.open();
                  }
                }
              : null,
          child: SelectorValue(value: widget.value),
        ),
      ),
    );
  }
}

class StepperSettingRow extends StatelessWidget {
  const StepperSettingRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.step = 1,
    this.unit = '',
  });

  final String label;
  final String description;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    void update(int delta) {
      final next = (value + delta).clamp(min, max);
      onChanged(next);
    }

    return SettingRowShell(
      label: label,
      description: description,
      trailing: StepperControl(
        value: unit.isEmpty ? '$value' : '$value $unit',
        enabled: enabled,
        onDecrement: () => update(-step),
        onIncrement: () => update(step),
      ),
    );
  }
}

class DecimalStepperSettingRow extends StatelessWidget {
  const DecimalStepperSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    void update(double delta) {
      final next = (value + delta).clamp(min, max);
      onChanged(double.parse(next.toStringAsFixed(2)));
    }

    return SettingRowShell(
      label: label,
      trailing: StepperControl(
        value: value.toStringAsFixed(2),
        enabled: enabled,
        onDecrement: () => update(-step),
        onIncrement: () => update(step),
      ),
    );
  }
}

class SwitchSettingRow extends StatelessWidget {
  const SwitchSettingRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingRowShell(
      label: label,
      description: description,
      trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
    );
  }
}

class PathSettingRow extends StatelessWidget {
  const PathSettingRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.buttonLabel,
    required this.enabled,
    this.onBrowse,
  });

  final String label;
  final String description;
  final String value;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return SettingRowShell(
      label: label,
      description:
          '$description\n${value.isEmpty ? I18n.t(context, 'no_file_selected') : value}',
      trailing: OutlinedButton.icon(
        onPressed: enabled ? onBrowse : null,
        icon: Icon(Icons.folder_open_outlined, size: 14),
        label: Text(buttonLabel),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: TextStyle(
            fontFamily: BeenutTheme.fontFamily,
            fontFamilyFallback: BeenutTheme.fontFamilyFallback,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}
