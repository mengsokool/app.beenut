import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../components/count_dashboard_panel.dart';

/// Refactored CountPanel delegating to CountDashboardPanel component.
class CountPanel extends StatelessWidget {
  const CountPanel({
    super.key,
    required this.count,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.detections,
    required this.parts,
    required this.selectedPartTypeId,
    this.isLoading = false,
    this.isMuted = false,
  });

  final int count;
  final Color color;
  final String title;
  final String subtitle;
  final List<Detection> detections;
  final List<PartType> parts;
  final String selectedPartTypeId;
  final bool isLoading;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final selectedPart = parts.firstWhere(
      (part) => part.id == selectedPartTypeId,
      orElse: () => const PartType(id: '', name: '', image: '', keywords: [], enabled: false),
    );

    final keywordCounts = <String, int>{
      for (final kw in selectedPart.keywords) kw: 0,
    };
    for (final d in detections) {
      if (d.label.isEmpty) continue;
      final labelLower = d.label.toLowerCase().trim();
      for (final kw in selectedPart.keywords) {
        final kwLower = kw.toLowerCase().trim();
        if (kwLower == labelLower || labelLower.contains(kwLower)) {
          keywordCounts[kw] = (keywordCounts[kw] ?? 0) + 1;
        }
      }
    }

    final classBreakdowns = [
      for (final kw in selectedPart.keywords)
        ClassBreakdownItem(
          label: kw,
          count: isMuted ? 0 : (keywordCounts[kw] ?? 0),
          color: BeenutTheme.getLabelColor(kw, selectedPart.keywords),
        ),
    ];

    final dashboardStatus = isMuted
        ? CountDashboardStatus.fault
        : (isLoading
            ? CountDashboardStatus.counting
            : (count > 0
                ? CountDashboardStatus.counted
                : CountDashboardStatus.ready));

    return CountDashboardPanel(
      count: count,
      status: dashboardStatus,
      statusTitle: title,
      statusSubtitle: subtitle,
      classBreakdowns: classBreakdowns,
      statusColor: color,
      isLoading: isLoading,
      isMuted: isMuted,
    );
  }
}
