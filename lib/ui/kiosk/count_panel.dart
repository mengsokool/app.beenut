import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 170;
        final countSize = (constraints.maxHeight * (compact ? 0.72 : 0.55))
            .clamp(68.0, 158.0);
        final baseStyle =
            Theme.of(context).textTheme.displayLarge ?? const TextStyle();
        final countStyle = baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: countSize,
          height: 0.9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BeenutTheme.radiusPanel,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 22,
              vertical: compact ? 8 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact) _StatusHeader(title: title, color: color),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isMuted
                            ? Text(
                                '---',
                                key: const ValueKey('muted'),
                                style: countStyle.copyWith(
                                  color: BeenutTheme.mutedColor(context),
                                ),
                              )
                            : isLoading
                            ? SizedBox(
                                width: 112,
                                height: 10,
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  color: scheme.primary,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                  borderRadius: BeenutTheme.radiusSharp,
                                ),
                              )
                            : Text(
                                count.toString().padLeft(3, '0'),
                                key: ValueKey(count),
                                style: countStyle.copyWith(
                                  color: BeenutTheme.inkColor(context),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (!compact)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BeenutTheme.radiusSharp,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
