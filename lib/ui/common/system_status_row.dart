import 'package:flutter/material.dart';

import '../../core/dls_tokens.dart';
import '../../core/theme.dart';
import 'setting_types.dart';

@immutable
class SystemStatusMetric {
  const SystemStatusMetric({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;
}

@immutable
class SystemStatusDetail {
  const SystemStatusDetail({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;
}

class SystemStatusRow extends StatefulWidget {
  const SystemStatusRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.status,
    required this.tone,
    this.metrics = const [],
    this.details = const [],
    this.showDetailsLabel = 'Show details',
    this.hideDetailsLabel = 'Hide details',
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String status;
  final RowTone tone;
  final List<SystemStatusMetric> metrics;
  final List<SystemStatusDetail> details;
  final String showDetailsLabel;
  final String hideDetailsLabel;

  @override
  State<SystemStatusRow> createState() => _SystemStatusRowState();
}

class _SystemStatusRowState extends State<SystemStatusRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64.0),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 680) {
                  return _buildWideRow(context);
                }
                return _buildCompactRow(context);
              },
            ),
          ),
        ),
        if (widget.details.isNotEmpty) ...[
          Divider(height: 1, color: colors.borderSubtle),
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 48.0,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.sm,
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: colors.accent,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Text(
                        _expanded
                            ? widget.hideDetailsLabel
                            : widget.showDetailsLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.accent,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _StatusDetailsRegion(details: widget.details)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _buildWideRow(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.inkPrimary,
          fontWeight: FontWeight.w500,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          child: Icon(widget.icon, size: 18, color: widget.iconColor),
        ),
        SizedBox(width: spacing.sm),
        SizedBox(
          width: 130,
          child: Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        SizedBox(width: spacing.md),
        SizedBox(
          width: 108,
          child: _SystemStatusIndicator(
            status: widget.status,
            tone: widget.tone,
          ),
        ),
        if (widget.metrics.isNotEmpty) ...[
          SizedBox(width: spacing.md),
          Expanded(child: _WideMetricGrid(metrics: widget.metrics)),
        ] else
          const Spacer(),
      ],
    );
  }

  Widget _buildCompactRow(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Icon(widget.icon, size: 18, color: widget.iconColor),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.inkPrimary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            SizedBox(width: spacing.md),
            Flexible(
              child: _SystemStatusIndicator(
                status: widget.status,
                tone: widget.tone,
              ),
            ),
          ],
        ),
        if (widget.metrics.isNotEmpty) ...[
          SizedBox(height: spacing.md),
          Wrap(
            spacing: spacing.lg,
            runSpacing: spacing.md,
            children: [
              for (final metric in widget.metrics)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 104,
                    maxWidth: 220,
                  ),
                  child: _StatusMetricBlock(metric: metric),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SystemStatusIndicator extends StatelessWidget {
  const _SystemStatusIndicator({required this.status, required this.tone});

  final String status;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    final color = switch (tone) {
      RowTone.success => colors.success,
      RowTone.warning => colors.warning,
      RowTone.danger => colors.danger,
      RowTone.neutral => colors.inkSecondary,
    };
    return Semantics(
      label: status,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: spacing.sm),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideMetricGrid extends StatelessWidget {
  const _WideMetricGrid({required this.metrics});

  final List<SystemStatusMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int index = 0; index < metrics.length; index++) ...[
          if (index > 0) ...[
            SizedBox(width: spacing.md),
            Container(width: 1, height: 36, color: colors.borderSubtle),
            SizedBox(width: spacing.md),
          ],
          Expanded(child: _StatusMetricBlock(metric: metrics[index])),
        ],
      ],
    );
  }
}

class _StatusMetricBlock extends StatelessWidget {
  const _StatusMetricBlock({required this.metric});

  final SystemStatusMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: spacing.xs),
        Text(
          metric.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: metric.monospace
              ? BeenutTheme.dataTextStyle(context).copyWith(color: colors.inkPrimary)
              : Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.inkPrimary),
        ),
      ],
    );
  }
}

class _StatusDetailsRegion extends StatelessWidget {
  const _StatusDetailsRegion({required this.details});

  final List<SystemStatusDetail> details;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            return Column(
              children: [
                for (int index = 0; index < details.length; index++) ...[
                  _StatusDetailRow(detail: details[index], compact: compact),
                  if (index < details.length - 1)
                    SizedBox(height: spacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusDetailRow extends StatelessWidget {
  const _StatusDetailRow({required this.detail, required this.compact});

  final SystemStatusDetail detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = context.dlsSpacing;
    final label = Text(
      detail.label,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final value = SelectableText(
      detail.value,
      style: detail.monospace
          ? BeenutTheme.dataTextStyle(context)
          : Theme.of(context).textTheme.bodyMedium,
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          SizedBox(height: spacing.xs),
          value,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: label),
        SizedBox(width: spacing.md),
        Expanded(child: value),
      ],
    );
  }
}
