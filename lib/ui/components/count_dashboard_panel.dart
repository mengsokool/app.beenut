import 'package:flutter/material.dart';
import '../../core/dls_tokens.dart';
import '../../core/i18n.dart';
import 'kiosk_form_controls.dart';

enum CountDashboardStatus { ready, counting, counted, fault }

/// Class breakdown item with color tag.
class ClassBreakdownItem {
  const ClassBreakdownItem({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

/// Stat card for count metrics.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color accentColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? spacing.sm : spacing.md,
        vertical: dense ? spacing.xs : spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: radii.borderSm(),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: DlsTypography.captionSmall(color: colors.inkSecondary)
                .copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: DlsTypography.titleSection(color: accentColor).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: dense ? 16 : 18,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Touchscreen Count Dashboard Panel Component.
/// Displays tabular hero count, stat cards (target count, pass/fail status),
/// class breakdown list with color tags, and progress ring indicator.
class CountDashboardPanel extends StatelessWidget {
  const CountDashboardPanel({
    super.key,
    required this.count,
    this.targetCount,
    this.status = CountDashboardStatus.ready,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.classBreakdowns,
    this.statusColor,
    this.isLoading = false,
    this.isMuted = false,
    this.progressValue,
  });

  final int count;
  final int? targetCount;
  final CountDashboardStatus status;
  final String statusTitle;
  final String statusSubtitle;
  final List<ClassBreakdownItem> classBreakdowns;
  final Color? statusColor;
  final bool isLoading;
  final bool isMuted;
  final double? progressValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;

    final effectiveStatusColor =
        statusColor ??
        switch (status) {
          CountDashboardStatus.ready => colors.accent,
          CountDashboardStatus.counting => colors.info,
          CountDashboardStatus.counted => colors.success,
          CountDashboardStatus.fault => colors.danger,
        };

    return KioskCard(
      padding: EdgeInsets.all(spacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDense = constraints.maxHeight < 200;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A compact instrument header: metric name first, state second.
              Row(
                children: [
                  Text(
                    I18n.t(context, 'total_count'),
                    style: DlsTypography.captionSmall(
                      color: colors.inkSecondary,
                    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
                  ),
                  const Spacer(),
                  _buildStatusPill(context, effectiveStatusColor),
                  if (isLoading || status == CountDashboardStatus.counting)
                    const SizedBox(width: 10),
                  if (isLoading || status == CountDashboardStatus.counting)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value:
                            progressValue ??
                            (targetCount != null && targetCount! > 0
                                ? (count / targetCount!).clamp(0.0, 1.0)
                                : null),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          effectiveStatusColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isDense ? spacing.sm : spacing.lg),

              // Keep the result and its explanation together, aligned to the
              // same edge as the class totals below.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: Text(
                  isMuted ? '—' : '$count',
                  key: ValueKey(isMuted ? 'muted' : count),
                  style:
                      DlsTypography.displayHero(
                        color: isMuted ? colors.inkDisabled : colors.inkPrimary,
                      ).copyWith(
                        fontSize: isDense ? 36 : 54,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                ),
              ),
              if (statusSubtitle.isNotEmpty)
                Text(
                  statusSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DlsTypography.captionSmall(
                    color: colors.inkSecondary,
                  ).copyWith(fontSize: 12, letterSpacing: 0),
                ),

              // Stat Cards (Target Count, Pass/Fail Status)
              if (targetCount != null) ...[
                SizedBox(height: spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Target',
                        value: '$targetCount',
                        accentColor: colors.inkPrimary,
                        dense: isDense,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Status',
                        value: count >= targetCount! ? 'PASS' : 'REMAINING',
                        accentColor: count >= targetCount!
                            ? colors.success
                            : colors.warning,
                        dense: isDense,
                      ),
                    ),
                  ],
                ),
              ],

              // Class totals read as a compact inspection list.
              if (classBreakdowns.isNotEmpty && !isDense) ...[
                SizedBox(height: spacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    I18n.t(context, 'breakdown_by_class'),
                    style:
                        DlsTypography.captionSmall(
                          color: colors.inkSecondary,
                        ).copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.borderSubtle)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < classBreakdowns.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: colors.borderSubtle.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.md,
                                vertical: spacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: classBreakdowns[i].color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: spacing.sm + 2),
                                  Expanded(
                                    child: Text(
                                      classBreakdowns[i].label,
                                      style:
                                          DlsTypography.bodyStandard(
                                            color: colors.inkPrimary,
                                          ).copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    isMuted ? '—' : '${classBreakdowns[i].count}',
                                    style:
                                        DlsTypography.captionSmall(
                                          color: colors.inkPrimary,
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, Color color) {
    final colors = context.dlsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          statusTitle,
          style: DlsTypography.captionSmall(
            color: colors.inkSecondary,
          ).copyWith(fontWeight: FontWeight.w500, letterSpacing: 0),
        ),
      ],
    );
  }
}
