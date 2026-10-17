import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Native C structs mapped to Dart FFI

final class FFIDetection extends Struct {
  @Array(128)
  external Array<Uint8> label;

  @Float()
  external double confidence;

  @Float()
  external double x;

  @Float()
  external double y;

  @Float()
  external double w;

  @Float()
  external double h;

  String get labelString {
    final bytes = <int>[];
    for (var i = 0; i < 128; i++) {
      final b = label[i];
      if (b == 0) break;
      bytes.add(b);
    }
    return utf8.decode(bytes);
  }
}

final class FFIInferenceResult extends Struct {
  @Int32()
  external int count;

  @Int32()
  external int processingMs;

  @Int32()
  external int detectionsCount;

  @Array(128)
  external Array<FFIDetection> detections;
}

// Function types for FFI

typedef BeenutEngineInitNDK = Pointer<Void> Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> labelsPath,
  Float confidenceThreshold,
  Float iouThreshold,
);
typedef BeenutEngineInitDart = Pointer<Void> Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> labelsPath,
  double confidenceThreshold,
  double iouThreshold,
);

typedef BeenutEngineIsReadyNDK = Bool Function(Pointer<Void> engineHandle);
typedef BeenutEngineIsReadyDart = bool Function(Pointer<Void> engineHandle);

typedef BeenutEngineGetDetailNDK = Pointer<Utf8> Function(Pointer<Void> engineHandle);
typedef BeenutEngineGetDetailDart = Pointer<Utf8> Function(Pointer<Void> engineHandle);

typedef BeenutEngineGetLabelsJsonNDK = Pointer<Utf8> Function(Pointer<Void> engineHandle);
typedef BeenutEngineGetLabelsJsonDart = Pointer<Utf8> Function(Pointer<Void> engineHandle);

typedef BeenutEngineRunNDK = FFIInferenceResult Function(
  Pointer<Void> engineHandle,
  Pointer<Uint8> rgbData,
  Int32 width,
  Int32 height,
  Pointer<Utf8> partType,
  Pointer<Utf8> keywords,
);
typedef BeenutEngineRunDart = FFIInferenceResult Function(
  Pointer<Void> engineHandle,
  Pointer<Uint8> rgbData,
  int width,
  int height,
  Pointer<Utf8> partType,
  Pointer<Utf8> keywords,
);

typedef BeenutEngineFreeNDK = Void Function(Pointer<Void> engineHandle);
typedef BeenutEngineFreeDart = void Function(Pointer<Void> engineHandle);

typedef BeenutYuv420ToRgbNDK = Void Function(
  Pointer<Uint8> yPlane,
  Pointer<Uint8> uPlane,
  Pointer<Uint8> vPlane,
  Int32 yRowStride,
  Int32 uvRowStride,
  Int32 uvPixelStride,
  Int32 width,
  Int32 height,
  Pointer<Uint8> rgbOut,
);
typedef BeenutYuv420ToRgbDart = void Function(
  Pointer<Uint8> yPlane,
  Pointer<Uint8> uPlane,
  Pointer<Uint8> vPlane,
  int yRowStride,
  int uvRowStride,
  int uvPixelStride,
  int width,
  int height,
  Pointer<Uint8> rgbOut,
);

class BeenutFfiBindings {
  BeenutFfiBindings._();

  static DynamicLibrary? _lib;

  static DynamicLibrary get _library {
    if (_lib != null) return _lib!;
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libbeenut_core.so');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libbeenut_core.dylib');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libbeenut_core.so');
    } else {
      throw UnsupportedError('Unsupported FFI platform: ${Platform.operatingSystem}');
    }
    return _lib!;
  }

  static final BeenutEngineInitDart _init =
      _library.lookupFunction<BeenutEngineInitNDK, BeenutEngineInitDart>(
        'beenut_engine_init',
      );

  static final BeenutEngineIsReadyDart _isReady =
      _library.lookupFunction<BeenutEngineIsReadyNDK, BeenutEngineIsReadyDart>(
        'beenut_engine_is_ready',
      );

  static final BeenutEngineGetDetailDart _getDetail =
      _library.lookupFunction<BeenutEngineGetDetailNDK, BeenutEngineGetDetailDart>(
        'beenut_engine_get_detail',
      );

  static final BeenutEngineGetLabelsJsonDart _getLabelsJson =
      _library.lookupFunction<BeenutEngineGetLabelsJsonNDK, BeenutEngineGetLabelsJsonDart>(
        'beenut_engine_get_labels_json',
      );

  static final BeenutEngineRunDart _run =
      _library.lookupFunction<BeenutEngineRunNDK, BeenutEngineRunDart>(
        'beenut_engine_run',
      );

  static final BeenutEngineFreeDart _free =
      _library.lookupFunction<BeenutEngineFreeNDK, BeenutEngineFreeDart>(
        'beenut_engine_free',
      );

  static final BeenutYuv420ToRgbDart yuv420ToRgb =
      _library.lookupFunction<BeenutYuv420ToRgbNDK, BeenutYuv420ToRgbDart>(
        'beenut_yuv420_to_rgb',
      );

  // High-level Dart wrapper methods

  static Pointer<Void> init(
    String modelPath,
    String labelsPath,
    double confidenceThreshold,
    double iouThreshold,
  ) {
    final modelPathPtr = modelPath.toNativeUtf8();
    final labelsPathPtr = labelsPath.toNativeUtf8();
    try {
      return _init(modelPathPtr, labelsPathPtr, confidenceThreshold, iouThreshold);
    } finally {
      malloc.free(modelPathPtr);
      malloc.free(labelsPathPtr);
    }
  }

  static bool isReady(Pointer<Void> engineHandle) {
    if (engineHandle == Pointer.fromAddress(0)) return false;
    return _isReady(engineHandle);
  }

  static String getDetail(Pointer<Void> engineHandle) {
    if (engineHandle == Pointer.fromAddress(0)) return 'Null engine handle';
    final ptr = _getDetail(engineHandle);
    return ptr.toDartString();
  }

  static List<String> getLabels(Pointer<Void> engineHandle) {
    if (engineHandle == Pointer.fromAddress(0)) return const [];
    try {
      final ptr = _getLabelsJson(engineHandle);
      final rawJson = ptr.toDartString();
      final parsed = jsonDecode(rawJson) as List;
      return parsed.cast<String>();
    } catch (_) {
      return const [];
    }
  }

  static FFIInferenceResult run(
    Pointer<Void> engineHandle,
    Pointer<Uint8> rgbData,
    int width,
    int height,
    String partType,
    List<String> keywords,
  ) {
    final partTypePtr = partType.toNativeUtf8();
    final keywordsPtr = keywords.join(',').toNativeUtf8();
    try {
      return _run(engineHandle, rgbData, width, height, partTypePtr, keywordsPtr);
    } finally {
      malloc.free(partTypePtr);
      malloc.free(keywordsPtr);
    }
  }

  static void free(Pointer<Void> engineHandle) {
    if (engineHandle == Pointer.fromAddress(0)) return;
    _free(engineHandle);
  }
}
