import 'package:flutter/material.dart';

class UiScaleController {
  UiScaleController._();

  static final ValueNotifier<double> scale = ValueNotifier<double>(1.0);

  static void update(double value) {
    final next = value.clamp(0.5, 2.0).toDouble();
    if ((scale.value - next).abs() < 0.001) return;
    scale.value = next;
  }
}

class UiScaleScope extends StatelessWidget {
  const UiScaleScope({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clampedScale = scale.clamp(0.5, 2.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }

        final scaledWidth = constraints.maxWidth / clampedScale;
        final scaledHeight = constraints.maxHeight / clampedScale;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: scaledWidth,
            maxWidth: scaledWidth,
            minHeight: scaledHeight,
            maxHeight: scaledHeight,
            child: Transform.scale(
              scale: clampedScale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
