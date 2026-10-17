import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import '../../core/dls_tokens.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/android_camera_controller.dart';
import '../kiosk/preview_pane.dart' show ShmNv12Preview, MjpegPreview;
import '../kiosk/android_camera_preview.dart';
import 'kiosk_form_controls.dart';

/// Touchscreen live stream camera pane widget.
/// Renders native preview stream, inspection frame, animated detection bounding box overlays,
/// paused preview blur filter, and glassmorphic status indicators.
class LiveStreamCameraPane extends StatefulWidget {
  const LiveStreamCameraPane({
    super.key,
    required this.state,
    required this.connected,
    required this.keywords,
    this.client,
    this.cameraController,
    this.aspectRatio = 1.0,
    this.onTogglePause,
    this.cameraTexture,
  });

  /// Factory constructor for MachineSnapshot binding.
  factory LiveStreamCameraPane.fromSnapshot({
    Key? key,
    required MachineSnapshot snapshot,
    required List<String> targetKeywords,
    KioskServiceClient? client,
    AndroidCameraController? cameraController,
    double aspectRatio = 1.0,
    VoidCallback? onTogglePause,
    Widget? cameraTexture,
  }) {
    return LiveStreamCameraPane(
      key: key,
      state: snapshot.state,
      connected: snapshot.connected,
      keywords: targetKeywords,
      client: client,
      cameraController: cameraController,
      aspectRatio: aspectRatio,
      onTogglePause: onTogglePause,
      cameraTexture: cameraTexture,
    );
  }

  final MachineState state;
  final bool connected;
  final List<String> keywords;
  final KioskServiceClient? client;
  final AndroidCameraController? cameraController;
  final double aspectRatio;
  final VoidCallback? onTogglePause;
  final Widget? cameraTexture;

  @override
  State<LiveStreamCameraPane> createState() => _LiveStreamCameraPaneState();
}

class _LiveStreamCameraPaneState extends State<LiveStreamCameraPane> {
  final GlobalKey _boundaryKey = GlobalKey();
  ui.Image? _lastFrameImage;

  @override
  void dispose() {
    _lastFrameImage?.dispose();
    _lastFrameImage = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveStreamCameraPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.previewPaused && oldWidget.state.previewPaused) {
      _lastFrameImage?.dispose();
      _lastFrameImage = null;
    } else if (widget.state.previewPaused &&
        !oldWidget.state.previewPaused &&
        _lastFrameImage == null) {
      _captureLastFrame();
    }
  }

  Future<void> _captureLastFrame() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 0.25);
        if (mounted) {
          setState(() {
            _lastFrameImage?.dispose();
            _lastFrameImage = image;
          });
        } else {
          image.dispose();
        }
      }
    } catch (e) {
      debugPrint('Failed to capture frame: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final shadows = context.dlsShadows;

    final hasCameraFault =
        widget.state.camera == 'error' || widget.state.camera == 'missing';
    final isPaused = widget.state.previewPaused;

    // Direct texture widget or native video stream switcher
    final Widget previewContent = Stack(
      fit: StackFit.expand,
      children: [
        if (widget.cameraTexture != null)
          widget.cameraTexture!
        else if (widget.cameraController != null)
          AndroidCameraPreview(controller: widget.cameraController!)
        else if ((widget.state.previewTransport == 'shm_nv12' ||
                widget.state.previewTransport == 'iosurface_nv12' ||
                widget.state.previewTransport == 'dmabuf_egl') &&
            widget.state.previewUrl.isNotEmpty)
          ShmNv12Preview(path: widget.state.previewUrl)
        else if (widget.state.previewTransport == 'mjpeg-http' &&
            widget.state.previewUrl.isNotEmpty)
          MjpegPreview(url: widget.state.previewUrl),

        // Animated Detections Overlay
        KioskAnimatedDetectionsOverlay(
          detections: isPaused ? const [] : widget.state.detections,
          keywords: widget.keywords,
          enabled: widget.connected && !hasCameraFault && !isPaused,
        ),
      ],
    );

    return Center(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: colors.streamViewport,
            borderRadius: radii.borderLg(),
            border: Border.all(color: colors.border, width: 1.5),
            boxShadow: shadows.softMd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live stream container wrapped in boundary
              RepaintBoundary(
                key: _boundaryKey,
                child: previewContent,
              ),

              // 2. Pause Blur Filter & Image
              if (isPaused && _lastFrameImage != null)
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: RawImage(image: _lastFrameImage, fit: BoxFit.cover),
                ),

              // 3. Error or Suspended Center Card
              if (isPaused)
                IgnorePointer(
                  child: _buildCenterMessage(
                    context,
                    icon: Icons.pause_circle_outline,
                    title: 'VIDEO STREAM PAUSED',
                    subtitle: 'Tap Resume to restart detection feed',
                  ),
                )
              else if (!widget.connected)
                IgnorePointer(
                  child: _buildCenterMessage(
                    context,
                    icon: Icons.wifi_off_rounded,
                    title: 'CONNECTION LOST',
                    subtitle: 'Reconnecting to hardware daemon...',
                  ),
                )
              else if (hasCameraFault)
                IgnorePointer(
                  child: _buildCenterMessage(
                    context,
                    icon: Icons.videocam_off_rounded,
                    title: 'CAMERA OFFLINE',
                    subtitle: 'Check physical camera cable connection',
                  ),
                ),

              // 4. Status Glass Pill Overlay (Top Left)
              Positioned(
                top: spacing.md,
                left: spacing.md,
                child: _buildStatusPill(context, isPaused: isPaused, hasFault: hasCameraFault),
              ),

              // 5. Pause Action Toggle Pill (Bottom Right)
              if (widget.onTogglePause != null)
                Positioned(
                  bottom: spacing.md,
                  right: spacing.md,
                  child: KioskTouchScale(
                    onTap: widget.onTogglePause,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: radii.borderPill(),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: spacing.xs),
                          Text(
                            isPaused ? 'RESUME' : 'PAUSE',
                            style: DlsTypography.captionKiosk(color: Colors.white).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, {required bool isPaused, required bool hasFault}) {
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final colors = context.dlsColors;

    final Color statusColor = isPaused
        ? colors.warning
        : (hasFault ? colors.danger : colors.success);
    final String statusText = isPaused
        ? 'PAUSED'
        : (hasFault ? 'ERROR' : 'LIVE 30 FPS');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: radii.borderPill(),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          SizedBox(width: spacing.xs + 2),
          Text(
            statusText,
            style: DlsTypography.captionKiosk(color: Colors.white).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final spacing = context.dlsSpacing;

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white70),
          SizedBox(height: spacing.md),
          Text(
            title,
            style: DlsTypography.titleCard(color: Colors.white),
          ),
          SizedBox(height: spacing.xs),
          Text(
            subtitle,
            style: DlsTypography.captionKiosk(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Animated Overlay for Detection Bounding Boxes.
class KioskAnimatedDetectionsOverlay extends StatefulWidget {
  const KioskAnimatedDetectionsOverlay({
    super.key,
    required this.detections,
    required this.keywords,
    required this.enabled,
  });

  final List<Detection> detections;
  final List<String> keywords;
  final bool enabled;

  @override
  State<KioskAnimatedDetectionsOverlay> createState() =>
      _KioskAnimatedDetectionsOverlayState();
}

class _KioskAnimatedDetectionsOverlayState
    extends State<KioskAnimatedDetectionsOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_DlsBox> _boxes = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _matchDetections(widget.detections);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KioskAnimatedDetectionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _boxes.clear();
    }
    _matchDetections(widget.detections);
  }

  void _matchDetections(List<Detection> newDetections) {
    for (final box in _boxes) {
      box.matched = false;
    }

    for (final det in newDetections) {
      _DlsBox? bestMatch;
      double minDistance = double.infinity;

      for (final box in _boxes) {
        if (box.matched || box.label != det.label) continue;
        final dx = (box.targetX + box.targetW / 2) - (det.x + det.w / 2);
        final dy = (box.targetY + box.targetH / 2) - (det.y + det.h / 2);
        final dist = dx * dx + dy * dy;
        if (dist < minDistance) {
          minDistance = dist;
          bestMatch = box;
        }
      }

      if (bestMatch != null && minDistance < 0.0625) {
        bestMatch.matched = true;
        bestMatch.targetX = det.x;
        bestMatch.targetY = det.y;
        bestMatch.targetW = det.w;
        bestMatch.targetH = det.h;
        bestMatch.confidence = det.confidence;
        bestMatch.targetOpacity = 1.0;
      } else {
        _boxes.add(
          _DlsBox(
            label: det.label,
            currentX: det.x,
            currentY: det.y,
            currentW: det.w,
            currentH: det.h,
            targetX: det.x,
            targetY: det.y,
            targetW: det.w,
            targetH: det.h,
            confidence: det.confidence,
            currentOpacity: 0.0,
            targetOpacity: 1.0,
          )..matched = true,
        );
      }
    }

    for (final box in _boxes) {
      if (!box.matched) box.targetOpacity = 0.0;
    }
    _syncTicker();
  }

  void _syncTicker() {
    final bool hasAnimatingBoxes = _boxes.any((b) =>
        (b.targetX - b.currentX).abs() > 0.001 ||
        (b.targetY - b.currentY).abs() > 0.001 ||
        (b.targetW - b.currentW).abs() > 0.001 ||
        (b.targetH - b.currentH).abs() > 0.001 ||
        (b.targetOpacity - b.currentOpacity).abs() > 0.001);

    final active = widget.enabled && hasAnimatingBoxes;
    if (active && !_ticker.isActive) {
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    bool hasChanges = false;
    const double lerp = 0.25;
    const double threshold = 0.001;

    for (int i = _boxes.length - 1; i >= 0; i--) {
      final box = _boxes[i];

      final dx = box.targetX - box.currentX;
      final dy = box.targetY - box.currentY;
      final dw = box.targetW - box.currentW;
      final dh = box.targetH - box.currentH;
      final dop = box.targetOpacity - box.currentOpacity;

      if (dx.abs() > threshold ||
          dy.abs() > threshold ||
          dw.abs() > threshold ||
          dh.abs() > threshold ||
          dop.abs() > threshold) {
        hasChanges = true;
        box.currentX += dx * lerp;
        box.currentY += dy * lerp;
        box.currentW += dw * lerp;
        box.currentH += dh * lerp;
        box.currentOpacity += dop * lerp;
      } else {
        box.currentX = box.targetX;
        box.currentY = box.targetY;
        box.currentW = box.targetW;
        box.currentH = box.targetH;
        box.currentOpacity = box.targetOpacity;
      }

      if (box.targetOpacity == 0.0 && box.currentOpacity < 0.02) {
        _boxes.removeAt(i);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      setState(() {});
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final colors = context.dlsColors;

    return CustomPaint(
      painter: _DlsDetectionsPainter(
        _boxes,
        keywords: widget.keywords,
        colors: colors,
      ),
    );
  }
}

class _DlsBox {
  _DlsBox({
    required this.label,
    required this.currentX,
    required this.currentY,
    required this.currentW,
    required this.currentH,
    required this.targetX,
    required this.targetY,
    required this.targetW,
    required this.targetH,
    required this.confidence,
    required this.currentOpacity,
    required this.targetOpacity,
  });

  final String label;
  double currentX, currentY, currentW, currentH;
  double targetX, targetY, targetW, targetH;
  double confidence;
  double currentOpacity, targetOpacity;
  bool matched = false;
}

class _DlsDetectionsPainter extends CustomPainter {
  _DlsDetectionsPainter(
    this.boxes, {
    required this.keywords,
    required this.colors,
  });

  final List<_DlsBox> boxes;
  final List<String> keywords;
  final DlsColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      if (box.currentOpacity <= 0.01) continue;

      final rect = Rect.fromLTWH(
        box.currentX * size.width,
        box.currentY * size.height,
        box.currentW * size.width,
        box.currentH * size.height,
      );

      final color = _getLabelColor(box.label, keywords, colors);
      final paint = Paint()
        ..color = color.withValues(alpha: box.currentOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final RRect rrect = RRect.fromRectAndRadius(rect, Radius.zero);
      canvas.drawRRect(rrect, paint);

      // Label Tag Pill
      final textSpan = TextSpan(
        text: '${box.label.toUpperCase()} ${(box.confidence * 100).toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 18 < 0 ? rect.top : rect.top - 18,
        textPainter.width + 10,
        18,
      );
      final labelBg = Paint()
        ..color = color.withValues(alpha: box.currentOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, Radius.zero),
        labelBg,
      );
      textPainter.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 2));
    }
  }

  Color _getLabelColor(String label, List<String> keywords, DlsColors colors) {
    if (keywords.length <= 1) return colors.success;
    final palette = [
      colors.success,
      colors.warning,
      colors.info,
      colors.accent,
      colors.danger,
    ];
    final norm = label.toLowerCase().trim();
    for (int i = 0; i < keywords.length; i++) {
      final kw = keywords[i].toLowerCase().trim();
      if (kw == norm || norm.contains(kw)) return palette[i % palette.length];
    }
    return colors.success;
  }

  @override
  bool shouldRepaint(covariant _DlsDetectionsPainter oldDelegate) => true;
}
