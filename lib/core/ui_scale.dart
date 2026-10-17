import 'package:flutter/material.dart';

class UiScaleController {
  UiScaleController._();

  static final ValueNotifier<double> scale = ValueNotifier<double>(1.0);
  static double _savedScale = 1.0;
  static double? _previewScale;

  static void update(double value) {
    _savedScale = value.clamp(0.5, 2.0).toDouble();
    _publish();
  }

  static void preview(double value) {
    _previewScale = value.clamp(0.5, 2.0).toDouble();
    _publish();
  }

  static void clearPreview() {
    _previewScale = null;
    _publish();
  }

  static void _publish() {
    final next = _previewScale ?? _savedScale;
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
    // Root-level scaling changes the constraints seen by every responsive
    // layout. On a phone this can turn an 853dp landscape screen into a
    // 426dp compact layout. Mobile already honours the system text scale, so
    // retain the real viewport for orientation-aware layouts.
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (mobile && MediaQuery.sizeOf(context).shortestSide < 600) {
      return child;
    }
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
