import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options) ...[
              Expanded(
                child: Material(
                  color: option.value == value
                      ? scheme.primaryContainer.withValues(alpha: 0.25)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled && option.available
                        ? () => onSelected(option.value)
                        : null,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        border: Border.all(
                          color: option.value == value
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: option.value == value ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            option.icon,
                            size: 22,
                            color: option.value == value
                                ? scheme.primary
                                : (option.available
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurfaceVariant.withValues(
                                          alpha: 0.5,
                                        )),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            option.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: option.value == value
                                  ? scheme.onSurface
                                  : (option.available
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.detail,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: BeenutTheme.mutedColor(context),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (option != options.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}
