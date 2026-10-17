import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'android_ffi_service_client.dart';
import 'system_permissions.dart';

enum AndroidCameraStatus { idle, initializing, running, paused, error }

/// Owns the Android camera session for the lifetime of the application shell.
///
/// Camera2 and its Flutter texture are deliberately not owned by a preview
/// widget. Responsive layout changes, route transitions, and orientation
/// changes may freely dispose/reparent UI without touching the native camera.
class AndroidCameraController extends ChangeNotifier
    with WidgetsBindingObserver {
  AndroidCameraController({required this.client});

  static const _channel = MethodChannel('com.example.beenut/native_camera');

  final AndroidFfiServiceClient client;

  AndroidCameraStatus _status = AndroidCameraStatus.idle;
  AndroidCameraStatus get status => _status;
  int? _textureId;
  int? get textureId => _textureId;
  int _sensorOrientation = 0;
  int get sensorOrientation => _sensorOrientation;
  int _displayRotation = 0;
  int get displayRotation => _displayRotation;
  // Flutter's SurfaceTexture renderer already applies Android's texture
  // transform matrix. Applying Camera2 sensor/display compensation again
  // rotates portrait frames a second time and makes landscape objects appear
  // tall and stretched.
  int get previewRotation => 0;
  int _previewWidth = 640;
  int get previewWidth => _previewWidth;
  int _previewHeight = 480;
  int get previewHeight => _previewHeight;
  String? _error;
  String? get error => _error;
  bool get isRunning => _status == AndroidCameraStatus.running;
  List<Map<String, dynamic>> _availableCameras = [];
  List<Map<String, dynamic>> get availableCameras => List.unmodifiable(_availableCameras);
  String? _selectedCameraId;
  String? get selectedCameraId => _selectedCameraId;

  Future<List<Map<String, dynamic>>> getAvailableCameras() async {
    try {
      final cameras = await _channel.invokeListMethod<Map<Object?, Object?>>('getAvailableCameras');
      if (cameras != null) {
        _availableCameras = cameras.map((c) => Map<String, dynamic>.from(c)).toList();
        final configDevice = client.snapshot.config.cameraSettings.device;
        if (configDevice.isNotEmpty) {
          _selectedCameraId = configDevice;
        } else if (_selectedCameraId == null && _availableCameras.isNotEmpty) {
          _selectedCameraId = _availableCameras.first['id'] as String?;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to query Android cameras: $e');
    }
    return _availableCameras;
  }

  Future<void> switchCamera(String cameraId) async {
    if (_selectedCameraId == cameraId) return;
    _selectedCameraId = cameraId;
    await _stopAndReleaseNative();
    _textureId = null;
    await ensureInitialized();
  }

  Future<void>? _initialization;
  bool _started = false;
  bool _disposed = false;
  String? _lastEngineSignature;
  Timer? _rotationRefreshTimer;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    client.addListener(_handleClientUpdate);
    unawaited(ensureInitialized());
  }

  Future<void> ensureInitialized() {
    if (_disposed || isRunning) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initialize();
    _initialization = operation;
    return operation.whenComplete(() {
      if (identical(_initialization, operation)) {
        _initialization = null;
      }
    });
  }

  Future<void> _initialize() async {
    _setStatus(AndroidCameraStatus.initializing, error: null);
    try {
      var permission = await SystemPermissions.currentCameraStatus();
      if (permission == CameraPermissionStatus.notDetermined ||
          permission == CameraPermissionStatus.unknown) {
        permission = await SystemPermissions.requestCameraIfNeeded();
      }
      if (permission != CameraPermissionStatus.authorized) {
        throw StateError('Camera permission was not granted.');
      }

      await getAvailableCameras();
      await _stopAndReleaseNative();
      await _syncEngineSettings(force: true);
      final response = await _channel.invokeMethod<Map<Object?, Object?>>(
        'createPreview',
        <String, dynamic>{'cameraId': _selectedCameraId},
      );
      if (response == null || response['textureId'] is! int) {
        throw StateError('Android could not create a preview texture.');
      }

      _textureId = response['textureId']! as int;
      _sensorOrientation =
          (response['sensorOrientation'] as num?)?.toInt() ?? 0;
      _displayRotation = (response['displayRotation'] as num?)?.toInt() ?? 0;
      _previewWidth = (response['previewWidth'] as num?)?.toInt() ?? 640;
      _previewHeight = (response['previewHeight'] as num?)?.toInt() ?? 480;
      _notifySafely();

      final started = await _channel.invokeMethod<bool>(
        'startCamera',
        <String, dynamic>{'cameraId': _selectedCameraId},
      ) ?? false;
      if (!started) {
        throw StateError('Camera2 could not start its capture session.');
      }
      _setStatus(AndroidCameraStatus.running, error: null);
    } catch (error, stackTrace) {
      debugPrint('Android camera initialization failed: $error\n$stackTrace');
      await _stopAndReleaseNative();
      _textureId = null;
      _setStatus(AndroidCameraStatus.error, error: '$error');
    }
  }

  Future<void> _pause() async {
    final pending = _initialization;
    if (pending != null) await pending;
    if (_disposed || !isRunning) return;
    try {
      await _channel.invokeMethod<void>('stopCamera');
      _setStatus(AndroidCameraStatus.paused, error: null);
    } catch (error) {
      _setStatus(AndroidCameraStatus.error, error: '$error');
    }
  }

  Future<void> _resume() async {
    if (_disposed || isRunning) return;
    if (_textureId == null) {
      await ensureInitialized();
      return;
    }
    _setStatus(AndroidCameraStatus.initializing, error: null);
    try {
      await _syncEngineSettings(force: true);
      final started = await _channel.invokeMethod<bool>('startCamera') ?? false;
      if (!started) {
        await _stopAndReleaseNative();
        _textureId = null;
        await ensureInitialized();
        return;
      }
      _setStatus(AndroidCameraStatus.running, error: null);
    } catch (error) {
      _textureId = null;
      _setStatus(AndroidCameraStatus.error, error: '$error');
    }
  }

  void _handleClientUpdate() {
    if (!isRunning) return;
    final targetDevice = client.snapshot.config.cameraSettings.device;
    if (targetDevice.isNotEmpty && targetDevice != _selectedCameraId) {
      unawaited(switchCamera(targetDevice));
      return;
    }
    unawaited(_syncEngineSettings());
  }

  Future<void> _syncEngineSettings({bool force = false}) async {
    final signature = [
      client.engineHandleAddress,
      client.selectedPartTypeId,
      client.snapshot.config.model['max_fps'],
      client.snapshot.config.partTypes.length,
    ].join('|');
    if (!force && signature == _lastEngineSignature) return;
    _lastEngineSignature = signature;
    await client.syncEngineSettings();
  }

  Future<void> _stopAndReleaseNative() async {
    _setStatus(AndroidCameraStatus.idle, error: null);
    try {
      await _channel.invokeMethod<void>('stopCamera');
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('releasePreview');
    } catch (_) {}
  }

  void _setStatus(AndroidCameraStatus value, {required String? error}) {
    _status = value;
    _error = error;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeMetrics() {
    if (_disposed) return;
    _rotationRefreshTimer?.cancel();
    _rotationRefreshTimer = Timer(
      const Duration(milliseconds: 120),
      _refreshDisplayRotation,
    );
  }

  Future<void> _refreshDisplayRotation() async {
    if (_disposed) return;
    try {
      final rotation =
          await _channel.invokeMethod<int>('getDisplayRotation') ?? 0;
      if (!_disposed && rotation != _displayRotation) {
        _displayRotation = rotation;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Failed to refresh Android display rotation: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_resume());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_pause());
      case AppLifecycleState.inactive:
        // Android can become inactive briefly during rotation and permission
        // UI. The app-owned texture/session must survive that transition.
        break;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rotationRefreshTimer?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      client.removeListener(_handleClientUpdate);
    }
    unawaited(_stopAndReleaseNative());
    super.dispose();
  }
}
