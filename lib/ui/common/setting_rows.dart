import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/i18n.dart';
import '../../core/workbench_tokens.dart';
import 'setting_primitives.dart';
import 'settings_experience.dart';
import 'number_editor.dart';
import 'inline_number_control.dart';
import 'inline_text_control.dart';
import 'text_editor.dart';

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
    this.disabledOptions = const {},
  });

  final Set<String> disabledOptions;
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
    final tokens = context.workbenchColors;
    return SettingRowShell(
      label: widget.label,
      description: widget.description,
      trailing: widget.options.length >= 2 && widget.options.length <= 3
          ? SizedBox(
              width: 288,
              child: RadioGroup<String>(
                groupValue: widget.value,
                onChanged: (value) {
                  if (widget.enabled &&
                      value != null &&
                      !widget.disabledOptions.contains(value)) {
                    widget.onSelected(value);
                  }
                },
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final option in widget.options)
                      InkWell(
                        onTap:
                            widget.enabled &&
                                !widget.disabledOptions.contains(option)
                            ? () => widget.onSelected(option)
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 288),
                          child: SizedBox(
                            height: SettingsExperience.controlHeight(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: option,
                                  enabled:
                                      widget.enabled &&
                                      !widget.disabledOptions.contains(option),
                                ),
                                Flexible(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color:
                                          widget.enabled &&
                                              !widget.disabledOptions.contains(
                                                option,
                                              )
                                          ? tokens.ink
                                          : tokens.disabled,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : widget.options.length <= 1
          ? SizedBox(
              width: 168,
              child: Text(widget.value, style: TextStyle(color: tokens.ink)),
            )
          : MenuAnchor(
              controller: _menuController,
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(tokens.raised),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                elevation: const WidgetStatePropertyAll(2),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BeenutTheme.radiusPanel,
                    side: BorderSide(color: tokens.line),
                  ),
                ),
                minimumSize: const WidgetStatePropertyAll(Size(240, 0)),
                maximumSize: const WidgetStatePropertyAll(
                  Size(320, double.infinity),
                ),
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
                      minimumSize: WidgetStatePropertyAll(
                        Size(240, SettingsExperience.controlHeight(context)),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12),
                      ),
                      alignment: Alignment.centerLeft,
                      shape: const WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tokens.ink,
                      ),
                    ),
                  ),
              ],
              child: SelectorValue(
                value: widget.value,
                onPressed: widget.enabled
                    ? () {
                        if (_menuController.isOpen) {
                          _menuController.close();
                        } else {
                          _menuController.open();
                        }
                      }
                    : null,
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
      trailing: SettingsExperience.isDeveloper(context)
          ? InlineNumberControl(
              label: label,
              value: value,
              min: min,
              max: max,
              step: step,
              unit: unit,
              enabled: enabled,
              onChanged: (number) => onChanged(number.toInt()),
            )
          : StepperControl(
              value: unit.isEmpty ? '$value' : '$value $unit',
              enabled: enabled,
              onEdit: () async {
                final result = await editSettingNumber(
                  context,
                  label: label,
                  value: value,
                  min: min,
                  max: max,
                );
                if (result != null) onChanged(result.toInt());
              },
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
      trailing: SettingsExperience.isDeveloper(context)
          ? InlineNumberControl(
              label: label,
              value: value,
              min: min,
              max: max,
              step: step,
              decimal: true,
              enabled: enabled,
              onChanged: (number) => onChanged(number.toDouble()),
            )
          : StepperControl(
              value: value.toStringAsFixed(2),
              enabled: enabled,
              onEdit: () async {
                final result = await editSettingNumber(
                  context,
                  label: label,
                  value: value,
                  min: min,
                  max: max,
                  decimal: true,
                );
                if (result != null) onChanged(result.toDouble());
              },
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
      trailing: WorkbenchSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
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
    this.onEdited,
  });

  final String label;
  final String description;
  final String value;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback? onBrowse;
  final ValueChanged<String>? onEdited;

  @override
  Widget build(BuildContext context) {
    if (SettingsExperience.isDeveloper(context) && onEdited != null) {
      return SettingRowShell(
        label: label,
        description: description,
        supporting: InlineTextControl(
          label: label,
          value: value,
          enabled: enabled,
          onChanged: onEdited!,
        ),
        trailing: OutlinedButton.icon(
          onPressed: enabled ? onBrowse : null,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(buttonLabel),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      );
    }

    return SettingRowShell(
      label: label,
      description: description,
      supporting: SelectableText(
        value.isEmpty ? I18n.t(context, 'no_file_selected') : value,
        maxLines: 2,
        style: BeenutTheme.dataTextStyle(context).copyWith(
          color: value.isEmpty
              ? context.workbenchColors.muted
              : context.workbenchColors.ink,
        ),
      ),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (onEdited != null)
            OutlinedButton.icon(
              onPressed: enabled
                  ? () async {
                      final result = await editSettingText(
                        context,
                        label: label,
                        value: value,
                      );
                      if (result != null) onEdited!(result);
                    }
                  : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(I18n.t(context, 'edit')),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, SettingsExperience.controlHeight(context)),
              ),
            ),
          OutlinedButton.icon(
            onPressed: enabled ? onBrowse : null,
            icon: Icon(Icons.folder_open_outlined, size: 14),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, SettingsExperience.controlHeight(context)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: TextStyle(
                fontFamily: BeenutTheme.fontFamily,
                fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
        ],
      ),
    );
  }
}
