import 'package:flutter/material.dart';

import '../../core/workbench_tokens.dart';

class ChoiceOption {
  const ChoiceOption({
    required this.value,
    required this.title,
    required this.detail,
    required this.icon,
    this.available = true,
  });

  final String value;
  final String title;
  final String detail;
  final IconData icon;
  final bool available;
}

class ChoiceCardsRow extends StatelessWidget {
  const ChoiceCardsRow({
    super.key,
    required this.options,
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  final List<ChoiceOption> options;
  final String value;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final line = context.workbenchColors.lineSubtle;
    return Column(
      children: [
        for (int index = 0; index < options.length; index++) ...[
          _ChoiceOptionRow(
            option: options[index],
            selected: options[index].value == value,
            enabled: enabled && options[index].available,
            onSelected: onSelected,
          ),
          if (index < options.length - 1) Divider(height: 1, color: line),
        ],
      ],
    );
  }
}

class _ChoiceOptionRow extends StatelessWidget {
  const _ChoiceOptionRow({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final ChoiceOption option;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final titleColor = !enabled
        ? tokens.disabled
        : selected
        ? tokens.actionText
        : tokens.ink;
    final iconColor = !enabled
        ? tokens.disabled
        : selected
        ? tokens.actionText
        : tokens.muted;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? tokens.actionSoft : Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onSelected(option.value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkbenchSpace.x3,
                vertical: WorkbenchSpace.x2,
              ),
              child: Row(
                children: [
                  SettingChoiceIcon(icon: option.icon, color: iconColor),
                  const SizedBox(width: WorkbenchSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (option.detail.isNotEmpty) ...[
                          const SizedBox(height: WorkbenchSpace.x1),
                          Text(
                            option.detail,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: enabled
                                      ? tokens.muted
                                      : tokens.disabled,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: WorkbenchSpace.x3),
                  _ChoiceMark(selected: selected, enabled: enabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingChoiceIcon extends StatelessWidget {
  const SettingChoiceIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 24, child: Icon(icon, size: 18, color: color));
  }
}

class _ChoiceMark extends StatelessWidget {
  const _ChoiceMark({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final color = !enabled
        ? tokens.disabled
        : selected
        ? tokens.actionText
        : tokens.line;
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: selected ? 1.5 : 1),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
