import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SettingIcon extends StatelessWidget {
  const SettingIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}

class SelectorValue extends StatelessWidget {
  const SelectorValue({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 150,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: BeenutTheme.inkColor(context),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: BeenutTheme.mutedColor(context),
          ),
        ],
      ),
    );
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.enabled,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String value;
  final bool enabled;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            enabled: enabled,
            icon: Icons.remove,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(7),
              bottomLeft: Radius.circular(7),
            ),
            onTap: onDecrement,
          ),
          Container(
            width: 1,
            height: 16,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BeenutTheme.inkColor(context),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _StepperButton(
            enabled: enabled,
            icon: Icons.add,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(7),
              bottomRight: Radius.circular(7),
            ),
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.enabled,
    required this.icon,
    required this.borderRadius,
    required this.onTap,
  });

  final bool enabled;
  final IconData icon;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: borderRadius,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 13,
            color: enabled
                ? BeenutTheme.inkColor(context)
                : BeenutTheme.mutedColor(context),
          ),
        ),
      ),
    );
  }
}
