import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';
import 'setting_types.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.value, required this.tone});

  final String value;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final colors = switch (tone) {
      RowTone.success => (
        bg: tokens.successSoft,
        fg: tokens.success,
        border: tokens.successSoft,
      ),
      RowTone.warning => (
        bg: tokens.warningSoft,
        fg: tokens.warning,
        border: tokens.warningSoft,
      ),
      RowTone.danger => (
        bg: tokens.dangerSoft,
        fg: tokens.danger,
        border: tokens.dangerSoft,
      ),
      RowTone.neutral => (
        bg: tokens.raised,
        fg: tokens.muted,
        border: tokens.line,
      ),
    };
    final showLoading =
        value.toLowerCase().contains('loading') ||
        value.toLowerCase().contains('scanning') ||
        value.contains('กำลังโหลด') ||
        value.toLowerCase().contains('loading');

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchSpace.x2,
        vertical: WorkbenchSpace.x1,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLoading) ...[
            SizedBox(
              width: 18,
              height: 5,
              child: LinearProgressIndicator(
                minHeight: 5,
                color: colors.fg,
                backgroundColor: colors.border,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.fg,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: BeenutTheme.mutedColor(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
