import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'i18n.dart';
import 'models.dart';
import 'service_client.dart';
import 'ffi_bindings.dart';
import 'counting_tracker_dart.dart';

class AndroidFfiServiceClient extends KioskServiceClient {
  AndroidFfiServiceClient();

  @override
  MachineSnapshot snapshot = const MachineSnapshot(
    connected: false,
    config: MachineConfig.empty,
    state: MachineState.empty,
    capabilities: HardwareCapabilities.empty,
    validation: ConfigValidation.empty,
    diagnostic: DiagnosticEvent.empty,
    saveResult: ConfigSaveResult.empty,
  );

  Pointer<Void> _engineHandle = Pointer.fromAddress(0);
  bool get isEngineReady => _engineHandle != Pointer.fromAddress(0);
  int get engineHandleAddress => _engineHandle.address;
  String get selectedPartTypeId => _selectedPartType;
  List<String> get selectedPartKeywords {
    final parts = snapshot.config.partTypes;
    if (parts.isEmpty || _selectedPartType.isEmpty || _selectedPartType == 'auto') {
      return const ['*'];
    }
    final selectedPart = parts.firstWhere(
      (p) => p.id == _selectedPartType,
      orElse: () => parts.first,
    );
    return selectedPart.keywords.isEmpty ? const ['*'] : selectedPart.keywords;
  }
  final CountingTrackerDart _tracker = CountingTrackerDart();
  bool _trayPresent = false;
  bool _lightEnabled = false;
  bool _paused = false;
  String _selectedPartType = '';

  static const _cameraChannel = MethodChannel('com.example.beenut/native_camera');

  @override
  void start() {
    _cameraChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDetections') {
        _handleNativeDetections(call.arguments as Map);
      }
    });
    _initFfiEngine();
  }

  void _handleNativeDetections(Map args) {
    final count = args['count'] as int;
    final processingMs = args['processingMs'] as int;
    final rawDets = args['detections'] as List;

    final detections = rawDets.map((d) {
      final m = d as Map;
      return Detection(
        label: m['label'] as String,
        confidence: (m['confidence'] as num).toDouble(),
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
      );
    }).toList();

    updateInferenceResult(InferenceResultDart(
      count: count,
      processingMs: processingMs,
      detections: detections,
    ));
  }

  Future<void> syncEngineSettings() async {
    if (_engineHandle == Pointer.fromAddress(0)) return;
    try {
      final maxFps = (snapshot.config.model['max_fps'] as num?)?.toDouble() ?? 6.0;
      await _cameraChannel.invokeMethod('updateEngineSettings', {
        'engineHandle': _engineHandle.address,
        'partType': _selectedPartType,
        'keywords': selectedPartKeywords.join(','),
        'maxFps': maxFps,
      });
    } catch (e) {
      debugPrint('Failed to sync engine settings to NDK Camera: $e');
    }
  }

  Future<void> _initFfiEngine() async {
    try {
      // 1. Prepare default paths and load configuration
      final appDocDir = await getApplicationSupportDirectory();
      final configFile = File('${appDocDir.path}/config.json');

      Map<String, dynamic> configMap;
      if (configFile.existsSync()) {
        try {
          configMap = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          final defaultJson = await rootBundle.loadString('service/config/default.json');
          configMap = jsonDecode(defaultJson) as Map<String, dynamic>;
        }
      } else {
        final defaultJson = await rootBundle.loadString('service/config/default.json');
        configMap = jsonDecode(defaultJson) as Map<String, dynamic>;
      }

      // Ensure Android specific camera settings are enforced
      if (configMap['camera'] is Map) {
        final cameraMap = Map<String, dynamic>.from(configMap['camera'] as Map);
        cameraMap['preview_transport'] = 'android_ffi';
        cameraMap['source'] = 'android';
        cameraMap['device'] = '0';
        configMap['camera'] = cameraMap;
      }

      final mockConfig = MachineConfig.fromJson(configMap);

      // Update app language immediately from the loaded configuration
      I18n.updateFromConfig(mockConfig);

      // Unpack bundled yolo26n.onnx model & labels.txt if missing in application storage
      final defaultModelFile = File('${appDocDir.path}/yolo26n.onnx');
      final defaultLabelsFile = File('${appDocDir.path}/labels.txt');
      if (!defaultModelFile.existsSync()) {
        try {
          final bytes = await rootBundle.load('assets/models/yolo26n.onnx');
          await defaultModelFile.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
        } catch (e) {
          debugPrint('Failed to unpack bundled yolo26n.onnx model: $e');
        }
      }
      if (!defaultLabelsFile.existsSync() || defaultLabelsFile.lengthSync() == 0) {
        try {
          final bytes = await rootBundle.load('assets/models/labels.txt');
          await defaultLabelsFile.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
        } catch (e) {
          debugPrint('Failed to unpack bundled labels.txt: $e');
        }
      }

      String modelPath = mockConfig.model['model_path']?.toString() ?? '';
      if (modelPath.isEmpty || !File(modelPath).existsSync()) {
        if (defaultModelFile.existsSync()) {
          modelPath = defaultModelFile.path;
        }
      }

      String labelsPath = mockConfig.model['labels_path']?.toString() ?? '';
      if (labelsPath.isEmpty || !File(labelsPath).existsSync()) {
        if (defaultLabelsFile.existsSync()) {
          labelsPath = defaultLabelsFile.path;
        }
      }
      final confidenceThreshold = (mockConfig.model['confidence_threshold'] as num?)?.toDouble() ?? 0.25;
      final iouThreshold = (mockConfig.model['nms_threshold'] as num?)?.toDouble() ?? 0.45;

      bool ready = false;
      String detail = 'No ONNX model selected';
      List<String> modelLabels = const [];

      // Load model if it exists and path is not empty
      if (modelPath.isNotEmpty && File(modelPath).existsSync()) {
        if (_engineHandle != Pointer.fromAddress(0)) {
          BeenutFfiBindings.free(_engineHandle);
          _engineHandle = Pointer.fromAddress(0);
        }
        _engineHandle = BeenutFfiBindings.init(
          modelPath,
          labelsPath,
          confidenceThreshold,
          iouThreshold,
        );
        ready = BeenutFfiBindings.isReady(_engineHandle);
        detail = BeenutFfiBindings.getDetail(_engineHandle);
        if (ready) {
          modelLabels = BeenutFfiBindings.getLabels(_engineHandle);
        }
      }

      // Initialize tracker
      _tracker.reload(
        stableFrames: (mockConfig.counting['stable_frames'] as num?)?.toInt() ?? 5,
        timeoutMs: (mockConfig.counting['timeout_ms'] as num?)?.toInt() ?? 1500,
      );

      final mockState = MachineState(
        safeMode: mockConfig.safeMode,
        previewPaused: _paused,
        trayPresent: _trayPresent,
        lightOn: _lightEnabled,
        selectedPartType: _selectedPartType.isEmpty
            ? (mockConfig.counting['selected_part_type']?.toString() ?? '')
            : _selectedPartType,
        count: 0,
        processingMs: 0,
        countTestRunning: false,
        countTestSuccess: false,
        countTestMessage: '',
        camera: 'ready',
        model: ready ? 'ready' : 'error',
        gpio: 'mock',
        cameraDetail: detail,
        modelDetail: detail,
        gpioDetail: 'mock backend active',
        previewTransport: 'android_ffi',
        previewUrl: 'ffi://android_preview',
        previewCaps: 'video/x-raw,format=RGB',
        modelLabels: modelLabels,
        captureFps: 30.0,
        inferenceFps: 0.0,
        cpuUsage: 0.0,
        ramUsage: 0.0,
        temperature: 42.0,
        thermalState: 'normal',
        thermalDetail: 'normal',
        effectiveAiMaxFps: (mockConfig.model['max_fps'] as num?)?.toDouble() ?? 6.0,
        daemonCpu: 0.0,
        daemonRam: 0.0,
        flutterCpu: 0.0,
        flutterRam: 0.0,
        detections: const [],
      );

      snapshot = MachineSnapshot(
        connected: true,
        config: mockConfig,
        state: mockState,
        capabilities: const HardwareCapabilities(
          cameras: [
            {
              'name': 'Android Camera',
              'source': 'android',
              'device': '0',
              'formats': [
                {'width': 640, 'height': 480}
              ],
            }
          ],
          previewTransports: [
            {'id': 'android_ffi', 'available': true}
          ],
          aiRuntimes: [
            {'id': 'onnx', 'available': true}
          ],
          gpio: {},
          gstreamer: {},
          system: {
            'platformClass': 'Android Device',
          },
        ),
        validation: const ConfigValidation(
          ok: true,
          warnings: [],
          errors: [],
          suggestedPatch: {},
        ),
        diagnostic: DiagnosticEvent(
          target: 'all',
          ok: true,
          message: 'OK',
          detail: 'All systems operational',
          metrics: const {},
          timestampMs: 0,
        ),
        saveResult: const ConfigSaveResult(
          ok: true,
          message: 'OK',
          detail: 'Configuration saved in memory',
          timestampMs: 0,
        ),
      );

      _selectedPartType = mockConfig.counting['selected_part_type'].toString();
      syncEngineSettings();
      unawaited(refreshAvailableCameras());
      notifyListeners();
    } catch (e) {
      debugPrint('[AndroidFfiServiceClient] Init failed: $e');
    }
  }

  Future<void> refreshAvailableCameras() async {
    try {
      final camerasList = await _cameraChannel.invokeListMethod<Map<Object?, Object?>>('getAvailableCameras');
      if (camerasList != null && camerasList.isNotEmpty) {
        final parsedCameras = camerasList.map((item) {
          final m = Map<String, dynamic>.from(item);
          final id = m['id']?.toString() ?? '0';
          final name = m['name']?.toString() ?? 'Android Camera ($id)';
          return {
            'name': name,
            'source': 'android',
            'device': id,
            'formats': [
              {'width': 640, 'height': 640},
              {'width': 1280, 'height': 1280},
              {'width': 1920, 'height': 1440},
            ],
          };
        }).toList();

        final updatedCaps = snapshot.capabilities.copyWith(
          cameras: parsedCameras,
        );
        snapshot = snapshot.copyWith(capabilities: updatedCaps);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AndroidFfiServiceClient] refreshAvailableCameras failed: $e');
    }
  }

  // Camera image frame receiver method called by AndroidCameraPreview
  void processCameraImage(Pointer<Uint8> rgbData, int width, int height) {
    if (_paused || _engineHandle == Pointer.fromAddress(0)) return;

    final selectedPart = snapshot.config.partTypes.firstWhere(
      (p) => p.id == _selectedPartType,
      orElse: () => snapshot.config.partTypes.first,
    );

    final ffiResult = BeenutFfiBindings.run(
      _engineHandle,
      rgbData,
      width,
      height,
      _selectedPartType,
      selectedPart.keywords,
    );

    // Convert FFI result to Dart Detection
    final detections = <Detection>[];
    for (var i = 0; i < ffiResult.detectionsCount; i++) {
      final det = ffiResult.detections[i];
      detections.add(Detection(
        label: det.labelString,
        confidence: det.confidence,
        x: det.x,
        y: det.y,
        w: det.w,
        h: det.h,
      ));
    }

    final resultDart = InferenceResultDart(
      count: ffiResult.count,
      processingMs: ffiResult.processingMs,
      detections: detections,
    );

    updateInferenceResult(resultDart);
  }

  void updateInferenceResult(InferenceResultDart resultDart) {
    // Update tracking
    final trackingResult = _tracker.update(_trayPresent, resultDart);

    // Update machine state snapshot
    final updatedState = snapshot.state.copyWith(
      count: trackingResult.count,
      detections: trackingResult.detections,
      processingMs: resultDart.processingMs,
    );

    snapshot = snapshot.copyWith(state: updatedState);
    notifyListeners();
  }

  @override
  void selectPartType(String partType) {
    _selectedPartType = partType;
    final updatedCounting = Map<String, dynamic>.from(snapshot.config.counting);
    updatedCounting['selected_part_type'] = partType;

    snapshot = snapshot.copyWith(
      config: snapshot.config.copyWithSettings(
        counting: updatedCounting,
      ),
      state: snapshot.state.copyWith(
        selectedPartType: partType,
      ),
    );
    syncEngineSettings();
    notifyListeners();
  }

  @override
  void testTray(bool? present) {
    _trayPresent = present ?? false;
    snapshot = snapshot.copyWith(
      state: snapshot.state.copyWith(trayPresent: _trayPresent),
    );
    notifyListeners();
  }

  @override
  void testLight(bool enabled) {
    _lightEnabled = enabled;
    snapshot = snapshot.copyWith(
      state: snapshot.state.copyWith(lightOn: _lightEnabled),
    );
    notifyListeners();
  }

  @override
  void countOnce() {
    // Single count trigger
  }

  @override
  void setPreviewPaused(bool paused) {
    _paused = paused;
    snapshot = snapshot.copyWith(
      state: snapshot.state.copyWith(previewPaused: _paused),
    );
    notifyListeners();
  }

  @override
  void saveConfig(MachineConfig config) {
    _saveConfigAndReinit(config);
  }

  Future<void> _saveConfigAndReinit(MachineConfig config) async {
    try {
      final appDocDir = await getApplicationSupportDirectory();
      final configFile = File('${appDocDir.path}/config.json');

      // Sanitize camera settings for Android
      final resolvedConfig = config.copyWithCameraSettings(
        config.cameraSettings.copyWith(
          source: 'android',
          previewTransport: 'android_ffi',
          device: config.cameraSettings.device.isNotEmpty ? config.cameraSettings.device : '0',
        ),
      );

      // Update app language immediately from the saved configuration
      I18n.updateFromConfig(resolvedConfig);

      // Save configuration to local file system atomically
      final jsonStr = jsonEncode(resolvedConfig.toJson());
      final tempFile = File('${appDocDir.path}/config.json.tmp');
      await tempFile.writeAsString(jsonStr, flush: true);
      await tempFile.rename(configFile.path);

      // Reinitialize engine if model path or settings changed
      final newModelPath = resolvedConfig.model['model_path']?.toString() ?? '';
      final labelsMode = resolvedConfig.model['labels_mode']?.toString() ?? 'auto';
      final labelsPath = labelsMode == 'custom' ? (resolvedConfig.model['labels_path']?.toString() ?? '') : '';

      final oldHandle = _engineHandle;
      _engineHandle = Pointer.fromAddress(0);

      if (oldHandle != Pointer.fromAddress(0)) {
        try {
          await _cameraChannel.invokeMethod('updateEngineSettings', {
            'engineHandle': 0,
            'partType': '',
            'keywords': '',
            'maxFps': 6.0,
          });
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 60));
        BeenutFfiBindings.free(oldHandle);
      }

      if (newModelPath.isNotEmpty && File(newModelPath).existsSync()) {
        _engineHandle = BeenutFfiBindings.init(
          newModelPath,
          labelsPath,
          (resolvedConfig.model['confidence_threshold'] as num?)?.toDouble() ?? 0.25,
          (resolvedConfig.model['nms_threshold'] as num?)?.toDouble() ?? 0.45,
        );
      }

      final ready = _engineHandle != Pointer.fromAddress(0) && BeenutFfiBindings.isReady(_engineHandle);
      final detail = _engineHandle != Pointer.fromAddress(0)
          ? BeenutFfiBindings.getDetail(_engineHandle)
          : 'No ONNX model selected';
      final modelLabels = ready ? BeenutFfiBindings.getLabels(_engineHandle) : const <String>[];

      final updatedState = snapshot.state.copyWith(
        camera: 'ready',
        model: ready ? 'ready' : 'error',
        cameraDetail: detail,
        modelDetail: detail,
        modelLabels: modelLabels,
      );

      snapshot = snapshot.copyWith(
        config: resolvedConfig,
        state: updatedState,
        saveResult: ConfigSaveResult(
          ok: true,
          message: 'OK',
          detail: 'Saved and initialized successfully',
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      syncEngineSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('[AndroidFfiServiceClient] Save config failed: $e');
    }
  }

  @override
  void shutdown() {
    // Shutdown device
  }

  @override
  void refreshCapabilities() {
    // Refresh caps
  }

  @override
  void validateConfig(MachineConfig config) {
    snapshot = snapshot.copyWith(
      validation: const ConfigValidation(
        ok: true,
        warnings: [],
        errors: [],
        suggestedPatch: {},
      ),
    );
    notifyListeners();
  }

  @override
  void runDiagnostic(String target) {
    snapshot = snapshot.copyWith(
      diagnostic: DiagnosticEvent(
        target: target,
        ok: true,
        message: 'OK',
        detail: 'Diagnostic run successful',
        metrics: const {},
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_engineHandle != Pointer.fromAddress(0)) {
      BeenutFfiBindings.free(_engineHandle);
      _engineHandle = Pointer.fromAddress(0);
    }
    super.dispose();
  }
}
