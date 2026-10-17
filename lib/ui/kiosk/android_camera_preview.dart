import 'package:flutter/material.dart';

import '../../core/android_camera_controller.dart';

/// Render-only view for the app-owned Android camera texture.
///
/// This widget never starts, stops, releases, or recreates Camera2 resources.
/// It can be disposed during responsive layout and route transitions without
/// affecting the camera session.
class AndroidCameraPreview extends StatelessWidget {
  const AndroidCameraPreview({super.key, required this.controller});

  final AndroidCameraController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final textureId = controller.textureId;
        final error = controller.error;
        if (error != null && textureId == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Camera unavailable\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        if (textureId == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }

        // Camera sensors on Android phones deliver portrait stream geometry (height > width).
        // Counter-rotate the texture when the device is rotated so the preview pane stays 1:1 fixed
        // and the camera image remains completely upright without rotating clockwise.
        final rawW = controller.previewWidth.toDouble();
        final rawH = controller.previewHeight.toDouble();

        final streamW = rawW < rawH ? rawW : rawH;
        final streamH = rawW > rawH ? rawW : rawH;

        final quarterTurns = (360 - controller.displayRotation) ~/ 90 % 4;
        final isQuarterTurn = quarterTurns.isOdd;
        final displayW = isQuarterTurn ? streamH : streamW;
        final displayH = isQuarterTurn ? streamW : streamH;

        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: displayW,
                height: displayH,
                child: RotatedBox(
                  quarterTurns: quarterTurns,
                  child: SizedBox(
                    width: streamW,
                    height: streamH,
                    child: Texture(
                      textureId: textureId,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
