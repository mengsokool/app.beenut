import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';

class SettingsGroup extends StatefulWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.summary,
    this.icon,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String title;
  final List<Widget> children;
  final String? description;
  final String? summary;
  final IconData? icon;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  State<SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<SettingsGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(SettingsGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final panelShape = RoundedRectangleBorder(
      borderRadius: BeenutTheme.radiusPanel,
      side: BorderSide(color: tokens.line),
    );
    final header = _SettingsGroupHeader(
      title: widget.title,
      description: widget.description,
      summary: widget.summary,
      icon: widget.icon,
      collapsible: widget.collapsible,
      expanded: _expanded,
      animationDuration: animationDuration,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: WorkbenchSpace.x4),
      child: Material(
        color: tokens.surface,
        shape: panelShape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (widget.collapsible)
              Semantics(
                button: true,
                expanded: _expanded,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: header,
                ),
              )
            else
              header,
            if (!widget.collapsible || _expanded) ...[
              Divider(height: 1, color: tokens.lineSubtle),
              _SettingsGroupChildren(children: widget.children),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupHeader extends StatelessWidget {
  const _SettingsGroupHeader({
    required this.title,
    required this.description,
    required this.summary,
    required this.icon,
    required this.collapsible,
    required this.expanded,
    required this.animationDuration,
  });

  final String title;
  final String? description;
  final String? summary;
  final IconData? icon;
  final bool collapsible;
  final bool expanded;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final textTheme = Theme.of(context).textTheme;
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
            final stackSummary = constraints.maxWidth < 520;
            return Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: tokens.muted),
                  const SizedBox(width: WorkbenchSpace.x2),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      if (description case final value?) ...[
                        const SizedBox(height: WorkbenchSpace.x1),
                        Text(value, style: textTheme.bodySmall),
                      ],
                      if (stackSummary && summary != null) ...[
                        const SizedBox(height: WorkbenchSpace.x1),
                        Text(
                          summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!stackSummary && summary != null) ...[
                  const SizedBox(width: WorkbenchSpace.x4),
                  Flexible(
                    child: Text(
                      summary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
                if (collapsible) ...[
                  const SizedBox(width: WorkbenchSpace.x3),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsGroupChildren extends StatelessWidget {
  const _SettingsGroupChildren({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = context.workbenchColors.lineSubtle;
    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) Divider(height: 1, color: line),
        ],
      ],
    );
  }
}
