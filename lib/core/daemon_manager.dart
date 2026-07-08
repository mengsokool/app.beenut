import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const _appSupportFolderName = 'beenut';
const _controlSocketPath = '/tmp/beenutd.sock';
const _previewSocketPath = '/tmp/beenut-preview.sock';
const _previewDmaBufSocketPath = '/tmp/beenut-preview.sock.dmabuf';
const _configSchemaVersion = 1;

String resolveDaemonBinaryPath({
  required String assetsPath,
  required String currentDirectoryPath,
  required bool isMacOS,
  required bool isLinux,
  bool isWindows = false,
  String? executableDirectoryPath,
}) {
  final exeDir =
      executableDirectoryPath ?? File(Platform.resolvedExecutable).parent.path;
  if (isMacOS) {
    final macosBinary = File('$exeDir/beenutd');
    if (macosBinary.existsSync()) {
      return macosBinary.path;
    }
  } else if (isLinux) {
    final packageRootBinary = File('${File(exeDir).parent.path}/bin/beenutd');
    if (packageRootBinary.existsSync()) {
      return packageRootBinary.path;
    }
  } else if (isWindows) {
    final windowsBinary = File('$exeDir/beenutd.exe');
    if (windowsBinary.existsSync()) {
      return windowsBinary.path;
    }
  }

  final devBinary = File(
    '$currentDirectoryPath/service/build/src/beenutd/beenutd',
  );
  if (devBinary.existsSync()) {
    return devBinary.path;
  }

  final devBinaryWin = File(
    '$currentDirectoryPath/service/build/src/beenutd/Release/beenutd.exe',
  );
  if (devBinaryWin.existsSync()) {
    return devBinaryWin.path;
  }

  final devBinaryWinDebug = File(
    '$currentDirectoryPath/service/build/src/beenutd/Debug/beenutd.exe',
  );
  if (devBinaryWinDebug.existsSync()) {
    return devBinaryWinDebug.path;
  }

  throw UnsupportedError(
    'No beenutd binary found for ${isMacOS
        ? 'macos'
        : isLinux
        ? 'linux'
        : isWindows
        ? 'windows'
        : 'unknown'}',
  );
}

class DaemonManager {
  DaemonManager._();

  static Process? _process;
  static bool _stopping = false;
  static String? _pidPath;

  /// Starts the C++ beenutd daemon.
  static Future<void> start() async {
    if (Platform.environment['BEENUT_NO_LAUNCH_DAEMON'] == '1') {
      debugPrint(
        '[DaemonManager] Skipping daemon launch (BEENUT_NO_LAUNCH_DAEMON is set)',
      );
      return;
    }
    if (_process != null) return;
    _stopping = false;

    final assetsPath = _getAssetsPath();
    final appSupportDir = Directory(_getApplicationSupportDirectory());
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }
    final logDir = Directory('${appSupportDir.path}/logs');
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

    final configPath = '${appSupportDir.path}/config.json';
    await _prepareConfigFile(configPath, assetsPath);

    final pidPath = '${appSupportDir.path}/beenutd.pid';
    _pidPath = pidPath;
    await _killExistingInstances(pidPath);

    final binaryPath = await _prepareDaemonBinary(assetsPath, appSupportDir);
    final logPath = '${logDir.path}/beenutd.log';
    final logSink = File(logPath).openWrite(mode: FileMode.append);

    debugPrint('[DaemonManager] Launching daemon at: $binaryPath');
    debugPrint('[DaemonManager] Using configuration: $configPath');
    debugPrint('[DaemonManager] Writing daemon log to: $logPath');

    try {
      var logOpen = true;
      void writeLog(String data) {
        if (!logOpen) return;
        try {
          logSink.write(data);
        } catch (e) {
          stderr.writeln('[DaemonManager] Failed to write daemon log: $e');
        }
      }

      _process = await Process.start(
        binaryPath,
        ['--config', configPath],
        workingDirectory: appSupportDir.path,
        environment: _daemonEnvironment(),
      );
      await File(pidPath).writeAsString('${_process!.pid}\n');

      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[beenutd stdout] $data');
        writeLog(data);
      });

      // Only forward stderr lines that look like real errors; suppress verbose
      // ONNX/CoreML info/warning chatter to keep the console clean.
      bool isErrorLine(String line) {
        const markers = [
          '[E]',
          '[e]',
          'Fatal',
          'fatal',
          'Error:',
          'error:',
          'Segfault',
          'SIGABRT',
          'SIGSEGV',
          'Traceback',
          'Exception',
        ];
        return markers.any((m) => line.contains(m));
      }

      _process!.stderr.transform(utf8.decoder).listen((data) {
        writeLog(data);
        if (isErrorLine(data)) {
          debugPrint('[beenutd stderr] $data');
        }
      });

      _process!.exitCode.then((code) {
        debugPrint('[DaemonManager] Daemon exited with code: $code');
        writeLog('[DaemonManager] Daemon exited with code: $code\n');
        logOpen = false;
        unawaited(logSink.close());
        _deletePidFile(pidPath);
        _process = null;
        if (!_stopping) {
          debugPrint('[DaemonManager] Unexpected daemon exit. Restarting...');
          Future.delayed(const Duration(seconds: 2), start);
        }
      });
    } catch (e) {
      debugPrint('[DaemonManager] Failed to launch daemon: $e');
      await logSink.close();
      _deletePidFile(pidPath);
    }
  }

  /// Stops the beenutd daemon.
  static Future<void> stop() async {
    _stopping = true;
    final process = _process;
    if (process == null && _pidPath == null) return;

    _process = null;
    if (process != null) {
      debugPrint('[DaemonManager] Stopping daemon...');
      await _terminateManagedProcess(process);
    }
    final pidPath =
        _pidPath ??
        '${Directory(_getApplicationSupportDirectory()).path}/beenutd.pid';
    final configPath =
        '${Directory(_getApplicationSupportDirectory()).path}/config.json';
    await _terminatePidFileProcess(pidPath);
    await _terminateAppOwnedDaemonProcesses(configPath);
    _removeRuntimeFiles();
    _deletePidFile(pidPath);
  }

  static String _getAssetsPath() {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    if (Platform.isMacOS) {
      // macOS structure: BeeNut.app/Contents/MacOS/BeeNut
      // Assets: BeeNut.app/Contents/Frameworks/App.framework/Resources/flutter_assets
      final assetsDir = Directory(
        '${File(exeDir).parent.path}/Frameworks/App.framework/Resources/flutter_assets',
      );
      if (assetsDir.existsSync()) {
        return assetsDir.path;
      }
    } else if (Platform.isLinux) {
      // Linux structure: bundle/beenut
      // Assets: bundle/data/flutter_assets
      final assetsDir = Directory('$exeDir/data/flutter_assets');
      if (assetsDir.existsSync()) {
        return assetsDir.path;
      }
    }

    // Development fallback to current project directory
    return Directory.current.path;
  }

  static String _getDaemonBinaryPath(String assetsPath) {
    return resolveDaemonBinaryPath(
      assetsPath: assetsPath,
      currentDirectoryPath: Directory.current.path,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
      isWindows: Platform.isWindows,
    );
  }

  static String _getApplicationSupportDirectory() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/$_appSupportFolderName';
    } else if (Platform.isLinux) {
      final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
      if (xdgConfig != null && xdgConfig.isNotEmpty) {
        return '$xdgConfig/$_appSupportFolderName';
      }
      return '$home/.config/$_appSupportFolderName';
    } else {
      return '$home/.$_appSupportFolderName';
    }
  }

  static Future<String> _prepareDaemonBinary(
    String assetsPath,
    Directory appSupportDir,
  ) async {
    final sourcePath = _getDaemonBinaryPath(assetsPath);
    final appMacOSDir = Directory(
      File(Platform.resolvedExecutable).parent.path,
    );
    if (Platform.isMacOS &&
        File(sourcePath).parent.path == appMacOSDir.path &&
        File(sourcePath).existsSync()) {
      return sourcePath;
    }

    final binDir = Directory('${appSupportDir.path}/bin');
    if (!binDir.existsSync()) {
      binDir.createSync(recursive: true);
    }
    final targetPath = Platform.isWindows
        ? '${binDir.path}/beenutd.exe'
        : '${binDir.path}/beenutd';
    final source = File(sourcePath);
    final target = File(targetPath);

    var shouldCopy = !target.existsSync();
    if (!shouldCopy) {
      final sourceStat = await source.stat();
      final targetStat = await target.stat();
      shouldCopy =
          sourceStat.size != targetStat.size ||
          sourceStat.modified.isAfter(targetStat.modified);
    }
    if (shouldCopy) {
      await source.copy(targetPath);
    }

    if (Platform.isMacOS || Platform.isLinux) {
      try {
        await Process.run('chmod', ['0755', targetPath]);
        if (Platform.isMacOS) {
          await Process.run('codesign', ['-f', '-s', '-', targetPath]);
        }
      } catch (e) {
        debugPrint('[DaemonManager] Failed to chmod/codesign binary: $e');
      }
    }
    return targetPath;
  }

  static Future<void> _prepareConfigFile(
    String configPath,
    String assetsPath,
  ) async {
    final configFile = File(configPath);
    Map<String, dynamic> configMap;

    // 1. Locate default config in assets or project directory
    File defaultConfigFile = File('$assetsPath/service/config/default.json');
    if (!defaultConfigFile.existsSync()) {
      defaultConfigFile = File(
        '${Directory.current.path}/service/config/default.json',
      );
    }

    if (configFile.existsSync()) {
      try {
        configMap =
            jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        configMap =
            jsonDecode(await defaultConfigFile.readAsString())
                as Map<String, dynamic>;
      }
    } else {
      configMap =
          jsonDecode(await defaultConfigFile.readAsString())
              as Map<String, dynamic>;
    }

    configMap['schema_version'] = _configSchemaVersion;
    configMap['model'] = resolveDaemonModelConfig(
      modelConfig: configMap['model'],
      assetsPath: assetsPath,
      currentDirectoryPath: Directory.current.path,
    );

    configMap['controlSocket'] = _controlSocketPath;
    configMap['previewSocket'] = _previewSocketPath;

    final camera =
        (configMap['camera'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    if (Platform.isMacOS) {
      final source = '${camera['source'] ?? 'auto'}';
      if (source == 'auto' ||
          source == 'libcamera' ||
          source == 'picamera2' ||
          source == 'v4l2') {
        camera['source'] = 'avfoundation';
        camera['device'] = '${camera['device'] ?? '0'}'.isEmpty
            ? '0'
            : '${camera['device']}';
      }
      final previewTransport = '${camera['preview_transport'] ?? 'auto'}';
      if (previewTransport == 'auto' || previewTransport == 'dmabuf_egl') {
        camera['preview_transport'] = 'iosurface_nv12';
      }
    } else if (Platform.isLinux) {
      camera['preview_transport'] ??= 'auto';
    }
    configMap['camera'] = camera;

    await _writeJsonFileAtomically(configFile, configMap);
  }

  @visibleForTesting
  static Map<String, dynamic> resolveDaemonModelConfig({
    required Object? modelConfig,
    required String assetsPath,
    required String currentDirectoryPath,
  }) {
    final defaultModelPath = _resolveBundledAssetPath(
      assetsPath,
      'service/models/yolo26n/yolo26n.onnx',
      currentDirectoryPath,
    );
    final defaultLabelsPath = _resolveBundledAssetPath(
      assetsPath,
      'service/models/yolo26n/labels.txt',
      currentDirectoryPath,
    );

    final model =
        (modelConfig as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    model['model_path'] = _resolveConfiguredModelPath(
      model['model_path'],
      assetsPath: assetsPath,
      currentDirectoryPath: currentDirectoryPath,
      fallbackPath: defaultModelPath,
    );
    model['labels_path'] = _resolveConfiguredLabelsPath(
      model['labels_path'],
      assetsPath: assetsPath,
      currentDirectoryPath: currentDirectoryPath,
      fallbackPath: defaultLabelsPath,
      labelsMode: '${model['labels_mode'] ?? 'auto'}',
    );
    return model;
  }

  static String _resolveBundledAssetPath(
    String assetsPath,
    String relativePath,
    String currentDirectoryPath,
  ) {
    final assetPath = '$assetsPath/$relativePath';
    if (File(assetPath).existsSync()) {
      return assetPath;
    }
    return '$currentDirectoryPath/$relativePath';
  }

  static String _resolveConfiguredModelPath(
    Object? configuredPath, {
    required String assetsPath,
    required String currentDirectoryPath,
    required String fallbackPath,
  }) {
    final resolved = _resolveConfiguredAssetPath(
      configuredPath,
      assetsPath,
      currentDirectoryPath,
    );
    if (resolved != null && File(resolved).existsSync()) {
      return resolved;
    }
    return fallbackPath;
  }

  static String _resolveConfiguredLabelsPath(
    Object? configuredPath, {
    required String assetsPath,
    required String currentDirectoryPath,
    required String fallbackPath,
    required String labelsMode,
  }) {
    final resolved = _resolveConfiguredAssetPath(
      configuredPath,
      assetsPath,
      currentDirectoryPath,
    );
    if (resolved != null && File(resolved).existsSync()) {
      return resolved;
    }
    if (labelsMode == 'custom' && resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return fallbackPath;
  }

  static String? _resolveConfiguredAssetPath(
    Object? configuredPath,
    String assetsPath,
    String currentDirectoryPath,
  ) {
    final raw = configuredPath?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    if (File(raw).isAbsolute) return raw;

    final assetPath = '$assetsPath/$raw';
    if (File(assetPath).existsSync()) {
      return assetPath;
    }
    final projectPath = '$currentDirectoryPath/$raw';
    if (File(projectPath).existsSync()) {
      return projectPath;
    }
    return raw;
  }

  static Future<void> _writeJsonFileAtomically(
    File target,
    Map<String, dynamic> json,
  ) async {
    final directory = target.parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    if (target.existsSync()) {
      final backup = File('${target.path}.bak');
      if (backup.existsSync()) {
        await backup.delete();
      }
      await target.copy(backup.path);
    }

    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temp.writeAsString(
        const JsonEncoder.withIndent('    ').convert(json),
        flush: true,
      );
      if (target.existsSync()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } catch (_) {
      if (temp.existsSync()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  static Future<void> _killExistingInstances(String pidPath) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final configPath =
            '${Directory(_getApplicationSupportDirectory()).path}/config.json';
        await _terminatePidFileProcess(pidPath);
        await _terminateAppOwnedDaemonProcesses(configPath);
        _removeRuntimeFiles();
      }
    } catch (_) {}
  }

  static Future<void> _terminateManagedProcess(Process process) async {
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 1500));
      return;
    } catch (_) {
      stderr.writeln('[DaemonManager] Daemon did not exit after SIGTERM.');
    }

    try {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      stderr.writeln('[DaemonManager] Failed to force-stop daemon: $e');
    }
  }

  static Future<void> _terminatePidFileProcess(String pidPath) async {
    final pidFile = File(pidPath);
    if (!pidFile.existsSync()) return;

    final pid = int.tryParse(pidFile.readAsStringSync().trim());
    if (pid != null) {
      await _terminatePid(pid, ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _isPidAlive(pid)) {
        await _terminatePid(pid, ProcessSignal.sigkill);
      }
    }
    _deletePidFile(pidPath);
  }

  static Future<void> _terminateAppOwnedDaemonProcesses(
    String configPath,
  ) async {
    final pids = await _findAppOwnedDaemonPids(configPath);
    if (pids.isEmpty) return;

    stdout.writeln('[DaemonManager] Cleaning stale daemon PIDs: $pids');
    for (final pid in pids) {
      await _terminatePid(pid, ProcessSignal.sigterm);
    }
    await Future.delayed(const Duration(milliseconds: 800));

    for (final pid in pids) {
      if (await _isPidAlive(pid)) {
        await _terminatePid(pid, ProcessSignal.sigkill);
      }
    }
  }

  static Future<List<int>> _findAppOwnedDaemonPids(String configPath) async {
    if (!Platform.isMacOS && !Platform.isLinux) return const [];

    final daemonPaths = <String>{
      '${File(Platform.resolvedExecutable).parent.path}/beenutd',
      '${Directory(_getApplicationSupportDirectory()).path}/bin/beenutd',
    };

    final result = await Process.run('/bin/ps', ['-axo', 'pid=,command=']);
    if (result.exitCode != 0) return const [];

    final pids = <int>[];
    for (final line in '${result.stdout}'.split('\n')) {
      final trimmed = line.trimLeft();
      final separator = trimmed.indexOf(' ');
      if (separator <= 0) continue;

      final pid = int.tryParse(trimmed.substring(0, separator));
      if (pid == null) continue;
      final command = trimmed.substring(separator + 1);
      final isOurDaemon = daemonPaths.any(command.contains);
      if (isOurDaemon &&
          command.contains('--config') &&
          command.contains(configPath)) {
        pids.add(pid);
      }
    }
    return pids;
  }

  static Future<void> _terminatePid(int pid, ProcessSignal signal) async {
    final signalName = signal == ProcessSignal.sigkill ? '-KILL' : '-TERM';
    try {
      await Process.run('/bin/kill', [signalName, pid.toString()]);
    } catch (_) {}
  }

  static Future<bool> _isPidAlive(int pid) async {
    try {
      final result = await Process.run('/bin/kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static void _removeRuntimeFiles() {
    for (final path in [
      _controlSocketPath,
      _previewSocketPath,
      _previewDmaBufSocketPath,
    ]) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  static void _deletePidFile(String pidPath) {
    try {
      final pidFile = File(pidPath);
      if (pidFile.existsSync()) {
        pidFile.deleteSync();
      }
    } catch (_) {}
  }

  static Map<String, String> _daemonEnvironment() {
    final environment = Map<String, String>.from(Platform.environment);
    final libraryDirs = <String>[
      if (Directory('/opt/homebrew/lib').existsSync()) '/opt/homebrew/lib',
      if (Directory('/usr/local/lib').existsSync()) '/usr/local/lib',
    ];
    final pluginDirs = <String>[
      if (Directory('/opt/homebrew/lib/gstreamer-1.0').existsSync())
        '/opt/homebrew/lib/gstreamer-1.0',
      if (Directory('/usr/local/lib/gstreamer-1.0').existsSync())
        '/usr/local/lib/gstreamer-1.0',
    ];
    final typelibDirs = <String>[
      if (Directory('/opt/homebrew/lib/girepository-1.0').existsSync())
        '/opt/homebrew/lib/girepository-1.0',
      if (Directory('/usr/local/lib/girepository-1.0').existsSync())
        '/usr/local/lib/girepository-1.0',
    ];

    void prependPath(String key, List<String> values) {
      if (values.isEmpty) return;
      final existing = environment[key];
      environment[key] = [
        ...values,
        if (existing != null && existing.isNotEmpty) existing,
      ].join(':');
    }

    prependPath('DYLD_LIBRARY_PATH', libraryDirs);
    prependPath('GST_PLUGIN_PATH_1_0', pluginDirs);
    prependPath('GI_TYPELIB_PATH', typelibDirs);
    if (Platform.isMacOS) {
      environment['BEENUT_PREVIEW_IOSURFACE'] = '1';
    }
    return environment;
  }
}
