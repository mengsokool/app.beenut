import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';

class CountPanel extends StatelessWidget {
  const CountPanel({
    super.key,
    required this.count,
    required this.color,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.isMuted = false,
  });

  final int count;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 180;
        final countSize = (constraints.maxHeight * (dense ? 0.50 : 0.56)).clamp(
          52.0,
          128.0,
        );
        final countStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontFamily: BeenutTheme.fontFamily,
          fontFamilyFallback: BeenutTheme.fontFamilyFallback,
          fontSize: countSize,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: isMuted ? tokens.disabled : tokens.ink,
        );

        return Material(
          color: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BeenutTheme.radiusPanel,
            side: BorderSide(color: tokens.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? WorkbenchSpace.x3 : WorkbenchSpace.x5,
              vertical: dense ? WorkbenchSpace.x2 : WorkbenchSpace.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CountStatus(title: title, color: color),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: isLoading
                          ? _CountingProgress(
                              key: const ValueKey('counting'),
                              style: countStyle,
                            )
                          : Text(
                              isMuted ? '—' : '$count',
                              key: ValueKey(isMuted ? 'muted' : count),
                              style: countStyle,
                            ),
                    ),
                  ),
                ),
                if (constraints.maxHeight >= 128 && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: tokens.muted),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountStatus extends StatelessWidget {
  const _CountStatus({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: WorkbenchSpace.x2),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountingProgress extends StatelessWidget {
  const _CountingProgress({super.key, required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('—', style: style?.copyWith(color: tokens.muted)),
        const SizedBox(height: WorkbenchSpace.x2),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            minHeight: 3,
            color: tokens.action,
            backgroundColor: tokens.lineSubtle,
            borderRadius: BeenutTheme.radiusSharp,
          ),
        ),
      ],
    );
  }
}
