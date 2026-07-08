import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CountPanel extends StatelessWidget {
  const CountPanel({
    super.key,
    required this.count,
    required this.color,
    this.isLoading = false,
    this.isMuted = false,
  });

  final int count;
  final Color color;
  final bool isLoading;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final countSize = (constraints.maxHeight * 0.85).clamp(68.0, 148.0);
        // Base on M3 displayLarge, override size + family for the large counter.
        final baseStyle = Theme.of(context).textTheme.displayLarge ?? const TextStyle();
        final countStyle = baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: countSize,
          height: 0.92,
          fontWeight: FontWeight.w600,
          letterSpacing: 4.0,
        );
        return Center(
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
                  : (isLoading
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : Text(
                          count.toString().padLeft(3, '0'),
                          key: ValueKey(count),
                          style: countStyle.copyWith(
                            color: BeenutTheme.inkColor(context),
                          ),
                        )),
            ),
          ),
        );
      },
    );
  }
}
