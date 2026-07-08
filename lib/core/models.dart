import 'package:flutter/foundation.dart';

@immutable
class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    label: json['label'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 0,
    h: (json['h'] as num?)?.toDouble() ?? 0,
  );

  final String label;
  final double confidence;
  final double x;
  final double y;
  final double w;
  final double h;
}

@immutable
class PartType {
  const PartType({
    required this.id,
    required this.name,
    required this.image,
    required this.keywords,
    required this.enabled,
  });

  factory PartType.fromJson(Map<String, dynamic> json) => PartType(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    image: json['image'] as String? ?? '',
    keywords: ((json['keywords'] as List?) ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList(),
    enabled: json['enabled'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String image;
  final List<String> keywords;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'keywords': keywords,
    'enabled': enabled,
  };

  PartType copyWith({
    String? id,
    String? name,
    String? image,
    List<String>? keywords,
    bool? enabled,
  }) => PartType(
    id: id ?? this.id,
    name: name ?? this.name,
    image: image ?? this.image,
    keywords: keywords ?? this.keywords,
    enabled: enabled ?? this.enabled,
  );
}

Map<String, dynamic> _objectMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return <String, dynamic>{};
}

String _stringValue(Map<String, dynamic> json, String key, String fallback) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

int _intValue(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double _doubleValue(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _boolValue(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

@immutable
class CameraSettings {
  const CameraSettings({
    required this.source,
    required this.width,
    required this.height,
    required this.fps,
    required this.idleFps,
    required this.warmupFrames,
    required this.previewTransport,
    required this.device,
    required this.exposureMode,
    required this.flipHorizontal,
    required this.flipVertical,
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) => CameraSettings(
    source: _stringValue(json, 'source', 'auto'),
    width: _intValue(json, 'width', 1280),
    height: _intValue(json, 'height', 1280),
    fps: _intValue(json, 'fps', 30),
    idleFps: _intValue(json, 'idle_fps', 5),
    warmupFrames: _intValue(json, 'warmup_frames', 5),
    previewTransport: _stringValue(json, 'preview_transport', 'auto'),
    device: _stringValue(json, 'device', ''),
    exposureMode: _stringValue(json, 'exposure_mode', 'auto'),
    flipHorizontal: _boolValue(json, 'flip_horizontal', false),
    flipVertical: _boolValue(json, 'flip_vertical', false),
  );

  final String source;
  final int width;
  final int height;
  final int fps;
  final int idleFps;
  final int warmupFrames;
  final String previewTransport;
  final String device;
  final String exposureMode;
  final bool flipHorizontal;
  final bool flipVertical;

  Map<String, dynamic> toJson() => {
    'source': source,
    'width': width,
    'height': height,
    'fps': fps,
    'idle_fps': idleFps,
    'warmup_frames': warmupFrames,
    'preview_transport': previewTransport,
    'device': device,
    'exposure_mode': exposureMode,
    'flip_horizontal': flipHorizontal,
    'flip_vertical': flipVertical,
  };

  CameraSettings copyWith({
    String? source,
    int? width,
    int? height,
    int? fps,
    int? idleFps,
    int? warmupFrames,
    String? previewTransport,
    String? device,
    String? exposureMode,
    bool? flipHorizontal,
    bool? flipVertical,
  }) => CameraSettings(
    source: source ?? this.source,
    width: width ?? this.width,
    height: height ?? this.height,
    fps: fps ?? this.fps,
    idleFps: idleFps ?? this.idleFps,
    warmupFrames: warmupFrames ?? this.warmupFrames,
    previewTransport: previewTransport ?? this.previewTransport,
    device: device ?? this.device,
    exposureMode: exposureMode ?? this.exposureMode,
    flipHorizontal: flipHorizontal ?? this.flipHorizontal,
    flipVertical: flipVertical ?? this.flipVertical,
  );
}

@immutable
class ModelSettings {
  const ModelSettings({
    required this.engine,
    required this.modelPath,
    required this.hefPath,
    required this.labelsMode,
    required this.labelsPath,
    required this.inputSize,
    required this.confidenceThreshold,
    required this.nmsThreshold,
    required this.maxFps,
  });

  factory ModelSettings.fromJson(Map<String, dynamic> json) => ModelSettings(
    engine: _stringValue(json, 'engine', 'mock'),
    modelPath: _stringValue(json, 'model_path', ''),
    hefPath: _stringValue(json, 'hef_path', ''),
    labelsMode: _stringValue(json, 'labels_mode', 'auto'),
    labelsPath: _stringValue(json, 'labels_path', ''),
    inputSize: _intValue(json, 'input_size', 640),
    confidenceThreshold: _doubleValue(json, 'confidence_threshold', 0.45),
    nmsThreshold: _doubleValue(json, 'nms_threshold', 0.5),
    maxFps: _doubleValue(json, 'max_fps', 10),
  );

  final String engine;
  final String modelPath;
  final String hefPath;
  final String labelsMode;
  final String labelsPath;
  final int inputSize;
  final double confidenceThreshold;
  final double nmsThreshold;
  final double maxFps;

  Map<String, dynamic> toJson() => {
    'engine': engine,
    'model_path': modelPath,
    'hef_path': hefPath,
    'labels_mode': labelsMode,
    'labels_path': labelsPath,
    'input_size': inputSize,
    'confidence_threshold': confidenceThreshold,
    'nms_threshold': nmsThreshold,
    'max_fps': maxFps,
  };

  ModelSettings copyWith({
    String? engine,
    String? modelPath,
    String? hefPath,
    String? labelsMode,
    String? labelsPath,
    int? inputSize,
    double? confidenceThreshold,
    double? nmsThreshold,
    double? maxFps,
  }) => ModelSettings(
    engine: engine ?? this.engine,
    modelPath: modelPath ?? this.modelPath,
    hefPath: hefPath ?? this.hefPath,
    labelsMode: labelsMode ?? this.labelsMode,
    labelsPath: labelsPath ?? this.labelsPath,
    inputSize: inputSize ?? this.inputSize,
    confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
    nmsThreshold: nmsThreshold ?? this.nmsThreshold,
    maxFps: maxFps ?? this.maxFps,
  );
}

@immutable
class GpioSettings {
  const GpioSettings({
    required this.enabled,
    required this.backend,
    required this.chip,
    required this.traySensorPin,
    required this.relayPin,
    required this.activeLow,
    required this.debounceMs,
  });

  factory GpioSettings.fromJson(Map<String, dynamic> json) => GpioSettings(
    enabled: _boolValue(json, 'enabled', false),
    backend: _stringValue(json, 'backend', 'auto'),
    chip: _stringValue(json, 'chip', 'gpiochip0'),
    traySensorPin: _intValue(json, 'tray_sensor_pin', 17),
    relayPin: _intValue(json, 'relay_pin', 27),
    activeLow: _boolValue(json, 'active_low', false),
    debounceMs: _intValue(json, 'debounce_ms', 80),
  );

  final bool enabled;
  final String backend;
  final String chip;
  final int traySensorPin;
  final int relayPin;
  final bool activeLow;
  final int debounceMs;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'backend': backend,
    'chip': chip,
    'tray_sensor_pin': traySensorPin,
    'relay_pin': relayPin,
    'active_low': activeLow,
    'debounce_ms': debounceMs,
  };

  GpioSettings copyWith({
    bool? enabled,
    String? backend,
    String? chip,
    int? traySensorPin,
    int? relayPin,
    bool? activeLow,
    int? debounceMs,
  }) => GpioSettings(
    enabled: enabled ?? this.enabled,
    backend: backend ?? this.backend,
    chip: chip ?? this.chip,
    traySensorPin: traySensorPin ?? this.traySensorPin,
    relayPin: relayPin ?? this.relayPin,
    activeLow: activeLow ?? this.activeLow,
    debounceMs: debounceMs ?? this.debounceMs,
  );
}

@immutable
class CountingSettings {
  const CountingSettings({
    required this.selectedPartType,
    required this.triggerMode,
    required this.stableFrames,
    required this.timeoutMs,
  });

  factory CountingSettings.fromJson(Map<String, dynamic> json) =>
      CountingSettings(
        selectedPartType: _stringValue(json, 'selected_part_type', ''),
        triggerMode: _stringValue(json, 'trigger_mode', 'tray_sensor'),
        stableFrames: _intValue(json, 'stable_frames', 5),
        timeoutMs: _intValue(json, 'timeout_ms', 2500),
      );

  final String selectedPartType;
  final String triggerMode;
  final int stableFrames;
  final int timeoutMs;

  Map<String, dynamic> toJson() => {
    'selected_part_type': selectedPartType,
    'trigger_mode': triggerMode,
    'stable_frames': stableFrames,
    'timeout_ms': timeoutMs,
  };

  CountingSettings copyWith({
    String? selectedPartType,
    String? triggerMode,
    int? stableFrames,
    int? timeoutMs,
  }) => CountingSettings(
    selectedPartType: selectedPartType ?? this.selectedPartType,
    triggerMode: triggerMode ?? this.triggerMode,
    stableFrames: stableFrames ?? this.stableFrames,
    timeoutMs: timeoutMs ?? this.timeoutMs,
  );
}

@immutable
class UiSettings {
  const UiSettings({
    required this.scale,
    required this.language,
    required this.theme,
  });

  factory UiSettings.fromJson(Map<String, dynamic> json) => UiSettings(
    scale: _doubleValue(json, 'scale', 1).clamp(0.5, 2.0).toDouble(),
    language: _stringValue(json, 'language', 'en'),
    theme: _stringValue(json, 'theme', 'system'),
  );

  final double scale;
  final String language;
  final String theme;

  Map<String, dynamic> toJson() => {
    'scale': scale,
    'language': language,
    'theme': theme,
  };

  UiSettings copyWith({
    double? scale,
    String? language,
    String? theme,
  }) =>
      UiSettings(
        scale: (scale ?? this.scale).clamp(0.5, 2.0).toDouble(),
        language: language ?? this.language,
        theme: theme ?? this.theme,
      );
}

@immutable
class MachineConfig {
  const MachineConfig({
    required this.schemaVersion,
    required this.controlSocket,
    required this.previewSocket,
    required this.poweroffCommand,
    required this.camera,
    required this.model,
    required this.gpio,
    required this.counting,
    required this.ui,
    required this.safeMode,
    required this.partTypes,
  });

  factory MachineConfig.fromJson(Map<String, dynamic> json) {
    final counting = _objectMap(json['counting']);
    return MachineConfig(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      controlSocket: json['controlSocket'] as String? ?? '/tmp/beenutd.sock',
      previewSocket:
          json['previewSocket'] as String? ?? '/tmp/beenut-preview.sock',
      poweroffCommand: json['poweroffCommand'] as String? ?? '',
      camera: _objectMap(json['camera']),
      model: _objectMap(json['model']),
      gpio: _objectMap(json['gpio']),
      counting: counting,
      ui: _objectMap(json['ui']),
      safeMode: json['safe_mode'] as bool? ?? false,
      partTypes: ((counting['part_types'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PartType.fromJson)
          .where((part) => part.id.isNotEmpty)
          .toList(),
    );
  }

  static const empty = MachineConfig(
    schemaVersion: 1,
    controlSocket: '/tmp/beenutd.sock',
    previewSocket: '/tmp/beenut-preview.sock',
    poweroffCommand: '',
    camera: {},
    model: {},
    gpio: {},
    counting: {},
    ui: {},
    safeMode: true,
    partTypes: [],
  );

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'controlSocket': controlSocket,
    'previewSocket': previewSocket,
    'poweroffCommand': poweroffCommand,
    'gpio': Map<String, dynamic>.from(gpio),
    'camera': Map<String, dynamic>.from(camera),
    'model': Map<String, dynamic>.from(model),
    'counting': {
      ...Map<String, dynamic>.from(counting),
      'part_types': [for (final part in partTypes) part.toJson()],
    },
    'ui': Map<String, dynamic>.from(ui),
    'safe_mode': safeMode,
  };

  MachineConfig copyWithJson(Map<String, dynamic> root) =>
      MachineConfig.fromJson({...toJson(), ...root});

  MachineConfig copyWithSettings({
    Map<String, dynamic>? camera,
    Map<String, dynamic>? model,
    Map<String, dynamic>? gpio,
    Map<String, dynamic>? counting,
    Map<String, dynamic>? ui,
    bool? safeMode,
  }) {
    final root = toJson();
    if (camera != null) {
      root['camera'] = {..._objectMap(root['camera']), ...camera};
    }
    if (model != null) {
      root['model'] = {..._objectMap(root['model']), ...model};
    }
    if (gpio != null) {
      root['gpio'] = {..._objectMap(root['gpio']), ...gpio};
    }
    if (counting != null) {
      root['counting'] = {..._objectMap(root['counting']), ...counting};
    }
    if (ui != null) {
      root['ui'] = {..._objectMap(root['ui']), ...ui};
    }
    if (safeMode != null) {
      root['safe_mode'] = safeMode;
    }
    return MachineConfig.fromJson(root);
  }

  MachineConfig copyWithCamera(Map<String, dynamic> patch) =>
      copyWithSettings(camera: patch);

  MachineConfig copyWithModel(Map<String, dynamic> patch) =>
      copyWithSettings(model: patch);

  MachineConfig copyWithGpio(Map<String, dynamic> patch) =>
      copyWithSettings(gpio: patch);

  MachineConfig copyWithCounting(Map<String, dynamic> patch) =>
      copyWithSettings(counting: patch);

  MachineConfig copyWithUi(Map<String, dynamic> patch) =>
      copyWithSettings(ui: patch);

  MachineConfig copyWithCameraSettings(CameraSettings settings) =>
      copyWithSettings(camera: settings.toJson());

  MachineConfig copyWithModelSettings(ModelSettings settings) =>
      copyWithSettings(model: settings.toJson());

  MachineConfig copyWithGpioSettings(GpioSettings settings) =>
      copyWithSettings(gpio: settings.toJson());

  MachineConfig copyWithCountingSettings(CountingSettings settings) =>
      copyWithSettings(counting: settings.toJson());

  MachineConfig copyWithUiSettings(UiSettings settings) =>
      copyWithSettings(ui: settings.toJson());

  MachineConfig copyWithPartCatalog({
    required List<PartType> partTypes,
    required String selectedPartType,
  }) => copyWithSettings(
    counting: {
      'selected_part_type': partTypes.any((part) => part.id == selectedPartType)
          ? selectedPartType
          : partTypes.firstOrNull?.id ?? '',
      'part_types': [for (final part in partTypes) part.toJson()],
    },
  );

  CameraSettings get cameraSettings => CameraSettings.fromJson(camera);
  ModelSettings get modelSettings => ModelSettings.fromJson(model);
  GpioSettings get gpioSettings => GpioSettings.fromJson(gpio);
  CountingSettings get countingSettings => CountingSettings.fromJson(counting);
  UiSettings get uiSettings => UiSettings.fromJson(ui);

  final String controlSocket;
  final int schemaVersion;
  final String previewSocket;
  final String poweroffCommand;
  final Map<String, dynamic> camera;
  final Map<String, dynamic> model;
  final Map<String, dynamic> gpio;
  final Map<String, dynamic> counting;
  final Map<String, dynamic> ui;
  final bool safeMode;
  final List<PartType> partTypes;
}

@immutable
class MachineState {
  const MachineState({
    required this.safeMode,
    required this.previewPaused,
    required this.trayPresent,
    required this.lightOn,
    required this.selectedPartType,
    required this.count,
    required this.processingMs,
    required this.countTestRunning,
    required this.countTestSuccess,
    required this.countTestMessage,
    required this.camera,
    required this.model,
    required this.gpio,
    required this.cameraDetail,
    required this.modelDetail,
    required this.gpioDetail,
    required this.previewTransport,
    required this.previewUrl,
    required this.previewCaps,
    required this.modelLabels,
    required this.captureFps,
    required this.inferenceFps,
    required this.cpuUsage,
    required this.ramUsage,
    required this.temperature,
    required this.thermalState,
    required this.thermalDetail,
    required this.effectiveAiMaxFps,
    required this.daemonCpu,
    required this.daemonRam,
    required this.flutterCpu,
    required this.flutterRam,
    required this.detections,
  });

  factory MachineState.fromJson(Map<String, dynamic> json) => MachineState(
    safeMode: json['safeMode'] as bool? ?? false,
    previewPaused: json['previewPaused'] as bool? ?? false,
    trayPresent: json['trayPresent'] as bool? ?? false,
    lightOn: json['lightOn'] as bool? ?? false,
    selectedPartType: json['selectedPartType'] as String? ?? '',
    count: json['count'] as int? ?? 0,
    processingMs: json['processingMs'] as int? ?? 0,
    countTestRunning: json['countTestRunning'] as bool? ?? false,
    countTestSuccess: json['countTestSuccess'] as bool? ?? false,
    countTestMessage: json['countTestMessage'] as String? ?? '',
    camera: json['camera'] as String? ?? 'missing',
    model: json['model'] as String? ?? 'missing',
    gpio: json['gpio'] as String? ?? 'missing',
    cameraDetail: json['cameraDetail'] as String? ?? '',
    modelDetail: json['modelDetail'] as String? ?? '',
    gpioDetail: json['gpioDetail'] as String? ?? '',
    previewTransport: json['previewTransport'] as String? ?? 'gstreamer-shm',
    previewUrl: json['previewUrl'] as String? ?? '',
    previewCaps: json['previewCaps'] as String? ?? '',
    modelLabels: ((json['modelLabels'] as List?) ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(),
    captureFps: (json['captureFps'] as num?)?.toDouble() ?? 0,
    inferenceFps: (json['inferenceFps'] as num?)?.toDouble() ?? 0,
    cpuUsage: (json['cpuUsage'] as num?)?.toDouble() ?? 0,
    ramUsage: (json['ramUsage'] as num?)?.toDouble() ?? 0,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    thermalState: json['thermalState'] as String? ?? 'unknown',
    thermalDetail: json['thermalDetail'] as String? ?? '',
    effectiveAiMaxFps: (json['effectiveAiMaxFps'] as num?)?.toDouble() ?? 0,
    daemonCpu: (json['daemonCpu'] as num?)?.toDouble() ?? 0,
    daemonRam: (json['daemonRam'] as num?)?.toDouble() ?? 0,
    flutterCpu: (json['flutterCpu'] as num?)?.toDouble() ?? 0,
    flutterRam: (json['flutterRam'] as num?)?.toDouble() ?? 0,
    detections: ((json['detections'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Detection.fromJson)
        .toList(),
  );

  static const empty = MachineState(
    safeMode: true,
    previewPaused: false,
    trayPresent: false,
    lightOn: false,
    selectedPartType: '',
    count: 0,
    processingMs: 0,
    countTestRunning: false,
    countTestSuccess: false,
    countTestMessage: '',
    camera: 'missing',
    model: 'missing',
    gpio: 'missing',
    cameraDetail: '',
    modelDetail: '',
    gpioDetail: '',
    previewTransport: 'gstreamer-shm',
    previewUrl: '',
    previewCaps: '',
    modelLabels: [],
    captureFps: 0,
    inferenceFps: 0,
    cpuUsage: 0,
    ramUsage: 0,
    temperature: 0,
    thermalState: 'unknown',
    thermalDetail: '',
    effectiveAiMaxFps: 0,
    daemonCpu: 0,
    daemonRam: 0,
    flutterCpu: 0,
    flutterRam: 0,
    detections: [],
  );

  final bool safeMode;
  final bool previewPaused;
  final bool trayPresent;
  final bool lightOn;
  final String selectedPartType;
  final int count;
  final int processingMs;
  final bool countTestRunning;
  final bool countTestSuccess;
  final String countTestMessage;
  final String camera;
  final String model;
  final String gpio;
  final String cameraDetail;
  final String modelDetail;
  final String gpioDetail;
  final String previewTransport;
  final String previewUrl;
  final String previewCaps;
  final List<String> modelLabels;
  final double captureFps;
  final double inferenceFps;
  final double cpuUsage;
  final double ramUsage;
  final double temperature;
  final String thermalState;
  final String thermalDetail;
  final double effectiveAiMaxFps;
  final double daemonCpu;
  final double daemonRam;
  final double flutterCpu;
  final double flutterRam;
  final List<Detection> detections;

  MachineState copyWith({
    bool? safeMode,
    bool? previewPaused,
    bool? trayPresent,
    bool? lightOn,
    String? selectedPartType,
    int? count,
    int? processingMs,
    bool? countTestRunning,
    bool? countTestSuccess,
    String? countTestMessage,
    String? camera,
    String? model,
    String? gpio,
    String? cameraDetail,
    String? modelDetail,
    String? gpioDetail,
    String? previewTransport,
    String? previewUrl,
    String? previewCaps,
    List<String>? modelLabels,
    double? captureFps,
    double? inferenceFps,
    double? cpuUsage,
    double? ramUsage,
    double? temperature,
    String? thermalState,
    String? thermalDetail,
    double? effectiveAiMaxFps,
    double? daemonCpu,
    double? daemonRam,
    double? flutterCpu,
    double? flutterRam,
    List<Detection>? detections,
  }) => MachineState(
    safeMode: safeMode ?? this.safeMode,
    previewPaused: previewPaused ?? this.previewPaused,
    trayPresent: trayPresent ?? this.trayPresent,
    lightOn: lightOn ?? this.lightOn,
    selectedPartType: selectedPartType ?? this.selectedPartType,
    count: count ?? this.count,
    processingMs: processingMs ?? this.processingMs,
    countTestRunning: countTestRunning ?? this.countTestRunning,
    countTestSuccess: countTestSuccess ?? this.countTestSuccess,
    countTestMessage: countTestMessage ?? this.countTestMessage,
    camera: camera ?? this.camera,
    model: model ?? this.model,
    gpio: gpio ?? this.gpio,
    cameraDetail: cameraDetail ?? this.cameraDetail,
    modelDetail: modelDetail ?? this.modelDetail,
    gpioDetail: gpioDetail ?? this.gpioDetail,
    previewTransport: previewTransport ?? this.previewTransport,
    previewUrl: previewUrl ?? this.previewUrl,
    previewCaps: previewCaps ?? this.previewCaps,
    modelLabels: modelLabels ?? this.modelLabels,
    captureFps: captureFps ?? this.captureFps,
    inferenceFps: inferenceFps ?? this.inferenceFps,
    cpuUsage: cpuUsage ?? this.cpuUsage,
    ramUsage: ramUsage ?? this.ramUsage,
    temperature: temperature ?? this.temperature,
    thermalState: thermalState ?? this.thermalState,
    thermalDetail: thermalDetail ?? this.thermalDetail,
    effectiveAiMaxFps: effectiveAiMaxFps ?? this.effectiveAiMaxFps,
    daemonCpu: daemonCpu ?? this.daemonCpu,
    daemonRam: daemonRam ?? this.daemonRam,
    flutterCpu: flutterCpu ?? this.flutterCpu,
    flutterRam: flutterRam ?? this.flutterRam,
    detections: detections ?? this.detections,
  );
}

@immutable
class HardwareCapabilities {
  const HardwareCapabilities({
    required this.cameras,
    required this.previewTransports,
    required this.aiRuntimes,
    required this.gpio,
    required this.gstreamer,
    required this.system,
  });

  factory HardwareCapabilities.fromJson(Map<String, dynamic> json) =>
      HardwareCapabilities(
        cameras: _mapList(json['cameras']),
        previewTransports: _mapList(json['previewTransports']),
        aiRuntimes: _mapList(json['aiRuntimes']),
        gpio: json['gpio'] as Map<String, dynamic>? ?? const {},
        gstreamer: json['gstreamer'] as Map<String, dynamic>? ?? const {},
        system: json['system'] as Map<String, dynamic>? ?? const {},
      );

  static List<Map<String, dynamic>> _mapList(Object? raw) =>
      ((raw as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  static const empty = HardwareCapabilities(
    cameras: [],
    previewTransports: [],
    aiRuntimes: [],
    gpio: {},
    gstreamer: {},
    system: {},
  );

  final List<Map<String, dynamic>> cameras;
  final List<Map<String, dynamic>> previewTransports;
  final List<Map<String, dynamic>> aiRuntimes;
  final Map<String, dynamic> gpio;
  final Map<String, dynamic> gstreamer;
  final Map<String, dynamic> system;

  bool get hasData =>
      cameras.isNotEmpty ||
      previewTransports.isNotEmpty ||
      aiRuntimes.isNotEmpty ||
      gpio.isNotEmpty ||
      gstreamer.isNotEmpty ||
      system.isNotEmpty;
}

@immutable
class ConfigValidation {
  const ConfigValidation({
    required this.ok,
    required this.warnings,
    required this.errors,
    required this.suggestedPatch,
  });

  factory ConfigValidation.fromJson(Map<String, dynamic> json) =>
      ConfigValidation(
        ok: json['ok'] as bool? ?? true,
        warnings: _stringList(json['warnings']),
        errors: _stringList(json['errors']),
        suggestedPatch:
            json['suggestedPatch'] as Map<String, dynamic>? ?? const {},
      );

  static List<String> _stringList(Object? raw) => ((raw as List?) ?? const [])
      .map((value) => value.toString())
      .where((value) => value.trim().isNotEmpty)
      .toList();

  static const empty = ConfigValidation(
    ok: true,
    warnings: [],
    errors: [],
    suggestedPatch: {},
  );

  final bool ok;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> suggestedPatch;

  bool get hasMessages => warnings.isNotEmpty || errors.isNotEmpty;
}

@immutable
class DiagnosticEvent {
  const DiagnosticEvent({
    required this.target,
    required this.ok,
    required this.message,
    required this.detail,
    required this.metrics,
    required this.timestampMs,
  });

  factory DiagnosticEvent.fromJson(Map<String, dynamic> json) =>
      DiagnosticEvent(
        target: json['target'] as String? ?? '',
        ok: json['ok'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        metrics: json['metrics'] as Map<String, dynamic>? ?? const {},
        timestampMs: json['timestampMs'] as int? ?? 0,
      );

  static const empty = DiagnosticEvent(
    target: '',
    ok: true,
    message: '',
    detail: '',
    metrics: {},
    timestampMs: 0,
  );

  final String target;
  final bool ok;
  final String message;
  final String detail;
  final Map<String, dynamic> metrics;
  final int timestampMs;

  bool get hasData => target.isNotEmpty || message.isNotEmpty;
}

@immutable
class ConfigSaveResult {
  const ConfigSaveResult({
    required this.ok,
    required this.message,
    required this.detail,
    required this.timestampMs,
  });

  factory ConfigSaveResult.fromJson(Map<String, dynamic> json) =>
      ConfigSaveResult(
        ok: json['ok'] as bool? ?? true,
        message: json['message'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        timestampMs: json['timestampMs'] as int? ?? 0,
      );

  static const empty = ConfigSaveResult(
    ok: true,
    message: '',
    detail: '',
    timestampMs: 0,
  );

  final bool ok;
  final String message;
  final String detail;
  final int timestampMs;

  bool get hasData => message.isNotEmpty || detail.isNotEmpty;
}

@immutable
class MachineSnapshot {
  const MachineSnapshot({
    required this.connected,
    required this.config,
    required this.state,
    this.capabilities = HardwareCapabilities.empty,
    this.validation = ConfigValidation.empty,
    this.diagnostic = DiagnosticEvent.empty,
    this.saveResult = ConfigSaveResult.empty,
  });

  final bool connected;
  final MachineConfig config;
  final MachineState state;
  final HardwareCapabilities capabilities;
  final ConfigValidation validation;
  final DiagnosticEvent diagnostic;
  final ConfigSaveResult saveResult;

  MachineSnapshot copyWith({
    bool? connected,
    MachineConfig? config,
    MachineState? state,
    HardwareCapabilities? capabilities,
    ConfigValidation? validation,
    DiagnosticEvent? diagnostic,
    ConfigSaveResult? saveResult,
  }) => MachineSnapshot(
    connected: connected ?? this.connected,
    config: config ?? this.config,
    state: state ?? this.state,
    capabilities: capabilities ?? this.capabilities,
    validation: validation ?? this.validation,
    diagnostic: diagnostic ?? this.diagnostic,
    saveResult: saveResult ?? this.saveResult,
  );
}
