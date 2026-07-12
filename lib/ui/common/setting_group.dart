import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'panel_decoration.dart';

class SettingsGroup extends StatefulWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.icon,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String title;
  final List<Widget> children;
  final String? description;
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
    final scheme = Theme.of(context).colorScheme;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final content = DecoratedBox(
      decoration: panelDecoration(context),
      child: _SettingsGroupChildren(children: widget.children),
    );

    if (widget.collapsible) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Material(
          color: _expanded
              ? scheme.surfaceContainer
              : scheme.surfaceContainerLow,
          shape: BeenutTheme.panelShape,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Semantics(
                button: true,
                expanded: _expanded,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BeenutTheme.radiusPanel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 19,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (widget.description
                                  case final description?) ...[
                                const SizedBox(height: 3),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: animationDuration,
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 21,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(height: 1, color: scheme.outlineVariant),
                _SettingsGroupChildren(children: widget.children),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (widget.description case final description?) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _SettingsGroupChildren extends StatelessWidget {
  const _SettingsGroupChildren({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            Divider(height: 1, color: BeenutTheme.outlineVariant(context)),
        ],
      ],
    );
  }
}
