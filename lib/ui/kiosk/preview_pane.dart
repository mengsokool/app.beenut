import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/models.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';

class NativePreviewPane extends StatefulWidget {
  const NativePreviewPane({
    super.key,
    required this.state,
    required this.connected,
    required this.previewSocket,
    this.aspectRatio = 16 / 9,
  });

  final MachineState state;
  final bool connected;
  final String previewSocket;
  final double aspectRatio;

  @override
  State<NativePreviewPane> createState() => _NativePreviewPaneState();
}

class _NativePreviewPaneState extends State<NativePreviewPane> {
  final GlobalKey _boundaryKey = GlobalKey();
  ui.Image? _lastFrameImage;

  @override
  void didUpdateWidget(covariant NativePreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If it was paused externally
    if (widget.state.previewPaused &&
        !oldWidget.state.previewPaused &&
        _lastFrameImage == null) {
      _captureLastFrame();
    }
  }

  Future<void> _captureLastFrame() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        // Capture at 0.25 pixel ratio to be extremely fast and low-memory
        final image = await boundary.toImage(pixelRatio: 0.25);
        if (mounted) {
          setState(() {
            _lastFrameImage = image;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to capture frame: $e');
    }
  }

  Widget _buildOverlay({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool translucent = false,
    bool isLoading = false,
  }) {
    return Container(
      color: translucent
          ? Colors.black.withValues(alpha: 0.58)
          : Colors.black.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 72,
              height: 6,
              child: LinearProgressIndicator(
                minHeight: 6,
                color: Colors.white70,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            )
          else
            Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool hasCameraFault =
        widget.state.camera == 'error' || widget.state.camera == 'missing';

    final previewContent = Stack(
      fit: StackFit.expand,
      children: [
        if ((widget.state.previewTransport == 'shm_nv12' ||
                widget.state.previewTransport == 'iosurface_nv12' ||
                widget.state.previewTransport == 'dmabuf_egl') &&
            widget.state.previewUrl.isNotEmpty)
          ShmNv12Preview(path: widget.state.previewUrl)
        else if (widget.state.previewTransport == 'mjpeg-http' &&
            widget.state.previewUrl.isNotEmpty)
          MjpegPreview(url: widget.state.previewUrl),

        AnimatedDetectionsOverlay(
          detections: widget.state.previewPaused
              ? const []
              : widget.state.detections,
          enabled:
              widget.connected &&
              !hasCameraFault &&
              !widget.state.previewPaused,
        ),
      ],
    );

    // Show the blurred placeholder while paused.
    final bool showPlaceholder = widget.state.previewPaused;
    final cachedImage = _lastFrameImage;

    return Center(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BeenutTheme.radiusPanel,
          child: ColoredBox(
            color: BeenutTheme.previewBlack,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Live preview wrapped in RepaintBoundary to capture it
                RepaintBoundary(key: _boundaryKey, child: previewContent),

                // 2. Blurred placeholder overlay
                if (showPlaceholder && cachedImage != null)
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: RawImage(image: cachedImage, fit: BoxFit.cover),
                  ),

                // 3. Status text overlays
                if (widget.state.previewPaused)
                  _buildOverlay(
                    icon: Icons.pause_outlined,
                    iconColor: Colors.white,
                    title: I18n.t(context, 'suspended'),
                    subtitle: I18n.t(context, 'video_paused_save_power'),
                    translucent: true,
                  )
                else if (!widget.connected)
                  _buildOverlay(
                    icon: Icons.wifi_off_outlined,
                    iconColor: scheme.secondary,
                    title: I18n.t(context, 'connection_lost'),
                    subtitle: I18n.t(context, 'attempting_reconnect'),
                  )
                else if (hasCameraFault)
                  _buildOverlay(
                    icon: Icons.videocam_off_outlined,
                    iconColor: scheme.error,
                    title: I18n.t(context, 'camera_error'),
                    subtitle: I18n.t(context, 'check_camera_connection'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShmNv12Preview extends StatefulWidget {
  const ShmNv12Preview({super.key, required this.path});

  final String path;

  @override
  State<ShmNv12Preview> createState() => _ShmNv12PreviewState();
}

class _ShmNv12PreviewState extends State<ShmNv12Preview> {
  static const MethodChannel _channel = MethodChannel('beenut/preview_texture');
  int? _textureId;

  @override
  void initState() {
    super.initState();
    _createTexture();
  }

  @override
  void didUpdateWidget(covariant ShmNv12Preview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _disposeTexture();
      _createTexture();
    }
  }

  Future<void> _createTexture() async {
    try {
      final textureId = await _channel.invokeMethod<int>('create', {
        'path': widget.path,
      });
      if (!mounted) {
        if (textureId != null) {
          await _channel.invokeMethod<void>('dispose', {
            'textureId': textureId,
          });
        }
        return;
      }
      setState(() => _textureId = textureId);
    } catch (_) {
      if (mounted) setState(() => _textureId = null);
    }
  }

  Future<void> _disposeTexture() async {
    final textureId = _textureId;
    _textureId = null;
    if (textureId == null) return;
    try {
      await _channel.invokeMethod<void>('dispose', {'textureId': textureId});
    } catch (_) {
      // The texture is best-effort; backend preview state will surface failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textureId = _textureId;
    if (textureId == null) return const SizedBox.expand();
    return Texture(textureId: textureId);
  }

  @override
  void dispose() {
    unawaited(_disposeTexture());
    super.dispose();
  }
}

class MjpegPreview extends StatefulWidget {
  const MjpegPreview({super.key, required this.url});

  final String url;

  @override
  State<MjpegPreview> createState() => _MjpegPreviewState();
}

class _MjpegPreviewState extends State<MjpegPreview> {
  static const _connectTimeout = Duration(seconds: 2);
  static const _frameTimeout = Duration(seconds: 3);
  static const _reconnectDelay = Duration(milliseconds: 500);

  final HttpClient _client = HttpClient()..connectionTimeout = _connectTimeout;
  StreamSubscription<List<int>>? _subscription;
  Timer? _frameTimer;
  Timer? _reconnectTimer;
  final List<int> _buffer = [];
  Uint8List? _frame;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant MjpegPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopStream();
      setState(() {
        _buffer.clear();
        _frame = null;
        _error = null;
      });
      _connect();
    }
  }

  Future<void> _connect() async {
    _reconnectTimer?.cancel();
    _frameTimer?.cancel();
    try {
      final request = await _client
          .getUrl(Uri.parse(widget.url))
          .timeout(_connectTimeout);
      final response = await request.close().timeout(_connectTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('MJPEG HTTP ${response.statusCode}');
      }
      if (mounted && _error != null) {
        setState(() => _error = null);
      }
      _armFrameTimeout();
      _subscription = response.listen(
        _appendBytes,
        onDone: _reconnect,
        onError: (_) => _reconnect(),
        cancelOnError: true,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _previewErrorLabel(error));
      }
      _reconnect();
    }
  }

  void _reconnect() {
    if (!mounted) return;
    _stopStream(keepReconnectTimer: true);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (mounted) _connect();
    });
  }

  void _armFrameTimeout() {
    _frameTimer?.cancel();
    _frameTimer = Timer(_frameTimeout, () {
      if (!mounted) return;
      setState(() => _error = I18n.t(context, 'timeout_preview_frame'));
      _reconnect();
    });
  }

  String _previewErrorLabel(Object error) {
    if (error is TimeoutException) {
      return I18n.t(context, 'failed_connect_preview');
    }
    if (error is FormatException) {
      return I18n.t(context, 'invalid_preview_address');
    }
    return I18n.t(context, 'mjpeg_preview_not_ready');
  }

  void _stopStream({bool keepReconnectTimer = false}) {
    _frameTimer?.cancel();
    _frameTimer = null;
    if (!keepReconnectTimer) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _appendBytes(List<int> bytes) {
    _buffer.addAll(bytes);
    while (true) {
      final start = _findMarker(_buffer, 0xff, 0xd8, 0);
      if (start < 0) {
        if (_buffer.length > 1024 * 1024) _buffer.clear();
        return;
      }
      final end = _findMarker(_buffer, 0xff, 0xd9, start + 2);
      if (end < 0) {
        if (start > 0) _buffer.removeRange(0, start);
        return;
      }
      final frame = Uint8List.fromList(_buffer.sublist(start, end + 2));
      _buffer.removeRange(0, end + 2);
      if (mounted) {
        _armFrameTimeout();
        setState(() {
          _frame = frame;
          _error = null;
        });
      }
    }
  }

  int _findMarker(List<int> data, int a, int b, int from) {
    for (var i = from; i < data.length - 1; i++) {
      if (data[i] == a && data[i + 1] == b) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) {
      return _MjpegStatus(error: _error);
    }
    return Image.memory(
      frame,
      gaplessPlayback: true,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  void dispose() {
    _stopStream();
    _client.close(force: true);
    super.dispose();
  }
}

class _MjpegStatus extends StatelessWidget {
  const _MjpegStatus({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = error ?? I18n.t(context, 'connecting_to_preview');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 72,
            height: 6,
            child: LinearProgressIndicator(
              minHeight: 6,
              color: Colors.white70,
              backgroundColor: Colors.white24,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedDetectionsOverlay extends StatefulWidget {
  const AnimatedDetectionsOverlay({
    super.key,
    required this.detections,
    required this.enabled,
  });

  final List<Detection> detections;
  final bool enabled;

  @override
  State<AnimatedDetectionsOverlay> createState() =>
      _AnimatedDetectionsOverlayState();
}

class _AnimatedDetectionsOverlayState extends State<AnimatedDetectionsOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_AnimatedBox> _boxes = [];
  bool _inspectionMode = false;
  int? _focusedBoxId;

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
  void didUpdateWidget(covariant AnimatedDetectionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.detections.isEmpty) {
      _inspectionMode = false;
      _focusedBoxId = null;
    }
    _matchDetections(widget.detections);
  }

  void _handleTapDown(TapDownDetails details, Size size) {
    if (!widget.enabled) return;

    final hitBox = _hitTestBox(details.localPosition, size);
    setState(() {
      if (!_inspectionMode) {
        _inspectionMode = true;
        _focusedBoxId = null;
        return;
      }

      if (hitBox == null) {
        _inspectionMode = false;
        _focusedBoxId = null;
        return;
      }

      if (_focusedBoxId == hitBox.id) {
        _focusedBoxId = null;
        return;
      }

      _focusedBoxId = hitBox.id;
    });
  }

  _AnimatedBox? _hitTestBox(Offset position, Size size) {
    for (final box in _boxes.reversed) {
      if (box.currentOpacity <= 0.08) continue;
      final rect = Rect.fromLTWH(
        box.currentX * size.width,
        box.currentY * size.height,
        box.currentW * size.width,
        box.currentH * size.height,
      ).inflate(8);
      if (rect.contains(position)) {
        return box;
      }
    }
    return null;
  }

  void _matchDetections(List<Detection> newDetections) {
    for (final box in _boxes) {
      box.matched = false;
    }

    for (final det in newDetections) {
      _AnimatedBox? bestMatch;
      double minDistance = double.infinity;

      for (final box in _boxes) {
        if (box.matched) continue;
        if (box.label != det.label) continue;

        final double boxCenterX = box.targetX + box.targetW / 2;
        final double boxCenterY = box.targetY + box.targetH / 2;
        final double detCenterX = det.x + det.w / 2;
        final double detCenterY = det.y + det.h / 2;

        final double dx = boxCenterX - detCenterX;
        final double dy = boxCenterY - detCenterY;
        final double distance = dx * dx + dy * dy;

        if (distance < minDistance) {
          minDistance = distance;
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
          _AnimatedBox(
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
            id: _AnimatedBox.nextId(),
            currentOpacity: 0.0,
            targetOpacity: 1.0,
          )..matched = true,
        );
      }
    }

    for (final box in _boxes) {
      if (!box.matched) {
        box.targetOpacity = 0.0;
      }
    }
    _syncTicker();
  }

  void _syncTicker() {
    final shouldAnimate =
        widget.detections.isNotEmpty ||
        _boxes.any(
          (box) =>
              box.currentOpacity > 0.02 ||
              box.targetOpacity > 0.0 ||
              (box.currentX - box.targetX).abs() > 0.001 ||
              (box.currentY - box.targetY).abs() > 0.001 ||
              (box.currentW - box.targetW).abs() > 0.001 ||
              (box.currentH - box.targetH).abs() > 0.001,
        );
    if (shouldAnimate && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldAnimate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    bool hasChanges = false;
    const double lerpFactor = 0.18;

    for (int i = _boxes.length - 1; i >= 0; i--) {
      final box = _boxes[i];

      box.currentX += (box.targetX - box.currentX) * lerpFactor;
      box.currentY += (box.targetY - box.currentY) * lerpFactor;
      box.currentW += (box.targetW - box.currentW) * lerpFactor;
      box.currentH += (box.targetH - box.currentH) * lerpFactor;
      box.currentOpacity +=
          (box.targetOpacity - box.currentOpacity) * lerpFactor;

      if (box.targetOpacity == 0.0 && box.currentOpacity < 0.02) {
        if (_focusedBoxId == box.id) {
          _focusedBoxId = null;
        }
        _boxes.removeAt(i);
      }
      hasChanges = true;
    }

    if (_inspectionMode && _boxes.isEmpty) {
      _inspectionMode = false;
      _focusedBoxId = null;
    }

    if (hasChanges) {
      setState(() {});
    }
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: widget.enabled
              ? (details) => _handleTapDown(details, size)
              : null,
          child: CustomPaint(
            painter: _AnimatedDetectionsPainter(
              _boxes,
              inspectionMode: _inspectionMode,
              focusedBoxId: _focusedBoxId,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBox {
  _AnimatedBox({
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
    required this.id,
    required this.currentOpacity,
    required this.targetOpacity,
  });

  static int _nextId = 0;
  static int nextId() => _nextId++;

  final int id;
  final String label;
  double currentX;
  double currentY;
  double currentW;
  double currentH;
  double targetX;
  double targetY;
  double targetW;
  double targetH;
  double confidence;
  double currentOpacity;
  double targetOpacity;
  bool matched = false;
}

class _AnimatedDetectionsPainter extends CustomPainter {
  _AnimatedDetectionsPainter(
    this.boxes, {
    required this.inspectionMode,
    required this.focusedBoxId,
  });

  final List<_AnimatedBox> boxes;
  final bool inspectionMode;
  final int? focusedBoxId;

  @override
  void paint(Canvas canvas, Size size) {
    final focusedBox = focusedBoxId == null
        ? null
        : boxes.where((box) => box.id == focusedBoxId).firstOrNull;
    if (focusedBox != null && focusedBox.currentOpacity > 0.01) {
      final dimPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, dimPaint);
    }

    for (final box in boxes) {
      if (box.id == focusedBox?.id) continue;
      _paintBox(canvas, size, box, focused: false);
    }
    if (focusedBox != null) {
      _paintBox(canvas, size, focusedBox, focused: true);
    }
  }

  void _paintBox(
    Canvas canvas,
    Size size,
    _AnimatedBox box, {
    required bool focused,
  }) {
    if (box.currentOpacity <= 0.01) return;

    final emphasis = focused ? 1.0 : (focusedBoxId == null ? 1.0 : 0.42);
    final opacity = (box.currentOpacity * emphasis).clamp(0.0, 1.0);
    final boxPaint = Paint()
      ..color = const Color(0xff22d3ee).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 3.0 : 1.5;

    final rect = Rect.fromLTWH(
      box.currentX * size.width,
      box.currentY * size.height,
      box.currentW * size.width,
      box.currentH * size.height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      boxPaint,
    );

    if (inspectionMode && (focusedBoxId == null || focused)) {
      _paintLabel(canvas, size, rect, box, focused: focused);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Rect boxRect,
    _AnimatedBox box, {
    required bool focused,
  }) {
    final label = '${box.label} ${(box.confidence * 100).round()}%';
    final opacity = box.currentOpacity.clamp(0.0, 1.0);
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: focused ? 14 : 11,
        fontWeight: FontWeight.w700,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: (size.width - 16).clamp(32.0, 220.0));

    final padding = focused
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final labelWidth = textPainter.width + padding.horizontal;
    final labelHeight = textPainter.height + padding.vertical;
    final labelLeft = boxRect.left.clamp(4.0, size.width - labelWidth - 4);
    final preferredTop = boxRect.top - labelHeight - (focused ? 14 : 4);
    final labelTop = preferredTop >= 4 ? preferredTop : boxRect.top + 4;
    final labelRect = Rect.fromLTWH(
      labelLeft,
      labelTop.clamp(4.0, size.height - labelHeight - 4),
      labelWidth,
      labelHeight,
    );

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(
        alpha: (focused ? 0.86 : 0.70) * opacity,
      )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
      backgroundPaint,
    );
    textPainter.paint(
      canvas,
      Offset(labelRect.left + padding.left, labelRect.top + padding.top),
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedDetectionsPainter oldDelegate) => true;
}
