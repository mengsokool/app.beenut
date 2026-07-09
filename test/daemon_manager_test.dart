import 'dart:io';

import 'package:beenut/core/daemon_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('linux daemon resolution uses built service binary', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-daemon-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final devBinary = File('${tempDir.path}/service/build/src/beenutd/beenutd');
    devBinary.createSync(recursive: true);

    final resolved = resolveDaemonBinaryPath(
      assetsPath: '${tempDir.path}/assets',
      currentDirectoryPath: tempDir.path,
      isMacOS: false,
      isLinux: true,
    );

    expect(resolved, devBinary.path);
  });

  test('macOS daemon resolution prefers helper next to app executable', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-daemon-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final appBinary = File('${tempDir.path}/Beenut.app/Contents/MacOS/beenutd');
    appBinary.createSync(recursive: true);

    final resolved = resolveDaemonBinaryPath(
      assetsPath: tempDir.path,
      currentDirectoryPath: '${tempDir.path}/missing-project',
      isMacOS: true,
      isLinux: false,
      executableDirectoryPath: appBinary.parent.path,
    );

    expect(resolved, appBinary.path);
  });

  test('macOS daemon resolution uses built service binary in development', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-daemon-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final devBinary = File('${tempDir.path}/service/build/src/beenutd/beenutd');
    devBinary.createSync(recursive: true);

    final resolved = resolveDaemonBinaryPath(
      assetsPath: tempDir.path,
      currentDirectoryPath: tempDir.path,
      isMacOS: true,
      isLinux: false,
      executableDirectoryPath: '${tempDir.path}/Beenut.app/Contents/MacOS',
    );

    expect(resolved, devBinary.path);
  });

  test(
    'Windows daemon resolution uses built Release/Debug/installed binary',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'beenut-daemon-test-',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final appBinary = File('${tempDir.path}/beenutd.exe');
      appBinary.createSync(recursive: true);

      final resolved = resolveDaemonBinaryPath(
        assetsPath: tempDir.path,
        currentDirectoryPath: '${tempDir.path}/missing-project',
        isMacOS: false,
        isLinux: false,
        isWindows: true,
        executableDirectoryPath: tempDir.path,
      );

      expect(resolved, appBinary.path);
    },
  );

  test('daemon resolution throws when no platform binary exists', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-daemon-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    expect(
      () => resolveDaemonBinaryPath(
        assetsPath: tempDir.path,
        currentDirectoryPath: tempDir.path,
        isMacOS: true,
        isLinux: false,
        executableDirectoryPath: '${tempDir.path}/Beenut.app/Contents/MacOS',
      ),
      throwsUnsupportedError,
    );
  });

  test('model config resolves selected relative model and labels paths', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-model-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final modelFile = File('${tempDir.path}/assets/models/yolo.onnx')
      ..createSync(recursive: true);
    final labelsFile = File('${tempDir.path}/assets/models/labels.txt')
      ..createSync(recursive: true);

    final resolved = DaemonManager.resolveDaemonModelConfig(
      modelConfig: {
        'engine': 'onnx',
        'model_path': 'models/yolo.onnx',
        'labels_path': 'models/labels.txt',
      },
      assetsPath: '${tempDir.path}/assets',
      currentDirectoryPath: tempDir.path,
    );

    expect(resolved['model_path'], modelFile.path);
    expect(resolved['labels_path'], labelsFile.path);
  });

  test('model config keeps absolute custom model paths', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-model-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final customModel = File('${tempDir.path}/custom/pills.onnx')
      ..createSync(recursive: true);
    final customLabels = File('${tempDir.path}/custom/labels.txt')
      ..createSync(recursive: true);
    final resolved = DaemonManager.resolveDaemonModelConfig(
      modelConfig: {
        'model_path': customModel.path,
        'labels_path': customLabels.path,
      },
      assetsPath: '${tempDir.path}/assets',
      currentDirectoryPath: tempDir.path,
    );

    expect(resolved['model_path'], customModel.path);
    expect(resolved['labels_path'], customLabels.path);
  });

  test('model config preserves missing model paths for backend validation', () {
    final tempDir = Directory.systemTemp.createTempSync('beenut-model-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final resolved = DaemonManager.resolveDaemonModelConfig(
      modelConfig: {
        'model_path': '${tempDir.path}/missing/pills.onnx',
        'labels_path': '${tempDir.path}/missing/labels.txt',
      },
      assetsPath: '${tempDir.path}/assets',
      currentDirectoryPath: tempDir.path,
    );

    expect(resolved['model_path'], '${tempDir.path}/missing/pills.onnx');
    expect(resolved['labels_path'], '${tempDir.path}/missing/labels.txt');
  });

  test(
    'empty model config stays empty instead of selecting a bundled model',
    () {
      final tempDir = Directory.systemTemp.createTempSync('beenut-model-test-');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final resolved = DaemonManager.resolveDaemonModelConfig(
        modelConfig: const {},
        assetsPath: '${tempDir.path}/assets',
        currentDirectoryPath: tempDir.path,
      );

      expect(resolved['model_path'], '');
      expect(resolved['labels_path'], '');
    },
  );
}
