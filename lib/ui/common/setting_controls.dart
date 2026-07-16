import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';

class SettingIcon extends StatelessWidget {
  const SettingIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.lineSubtle),
        borderRadius: BeenutTheme.radiusSharp,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class SelectorValue extends StatelessWidget {
  const SelectorValue({
    super.key,
    required this.value,
    required this.onPressed,
  });

  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return SizedBox(
      width: 168,
      height: WorkbenchMetric.technicianControlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
          backgroundColor: tokens.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onPressed == null ? tokens.disabled : tokens.ink,
                ),
              ),
            ),
            const SizedBox(width: WorkbenchSpace.x1),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: onPressed == null ? tokens.disabled : tokens.muted,
            ),
          ],
        ),
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
    final tokens = context.workbenchColors;
    return Container(
      height: WorkbenchMetric.technicianControlHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.line),
        borderRadius: BeenutTheme.radiusSharp,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            enabled: enabled,
            icon: Icons.remove,
            onTap: onDecrement,
          ),
          Container(width: 1, height: 20, color: tokens.lineSubtle),
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: WorkbenchSpace.x2),
            child: Text(
              value,
              style: BeenutTheme.dataTextStyle(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: enabled ? tokens.ink : tokens.disabled,
              ),
            ),
          ),
          Container(width: 1, height: 20, color: tokens.lineSubtle),
          _StepperButton(enabled: enabled, icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: WorkbenchMetric.technicianControlHeight,
          height: WorkbenchMetric.technicianControlHeight,
          child: Icon(
            icon,
            size: 14,
            color: enabled ? tokens.ink : tokens.disabled,
          ),
        ),
      ),
    );
  }
}

class WorkbenchSwitch extends StatefulWidget {
  const WorkbenchSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<WorkbenchSwitch> createState() => _WorkbenchSwitchState();
}

class _WorkbenchSwitchState extends State<WorkbenchSwitch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final enabled = widget.onChanged != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 100);
    final track = !enabled
        ? tokens.lineSubtle
        : widget.value
        ? tokens.action
        : tokens.line;
    final thumb = !enabled
        ? tokens.disabled
        : widget.value
        ? tokens.onAction
        : tokens.surface;

    return Semantics(
      button: true,
      toggled: widget.value,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(WorkbenchRadius.panel),
          child: SizedBox(
            width: 44,
            height: WorkbenchMetric.technicianHitTarget,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 32,
                height: 18,
                padding: const EdgeInsets.all(2),
                alignment: widget.value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _focused ? tokens.actionFocus : track,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: AnimatedContainer(
                  duration: duration,
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: thumb,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
