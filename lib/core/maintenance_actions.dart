import 'dart:io';

class MaintenanceActionResult {
  const MaintenanceActionResult({
    required this.ok,
    required this.message,
    required this.detail,
    this.artifactPath = '',
  });

  final bool ok;
  final String message;
  final String detail;
  final String artifactPath;
}

class MaintenanceActions {
  const MaintenanceActions._();

  static Future<MaintenanceActionResult> collectDiagnostics() async {
    final script = _findScript('collect-diagnostics.sh');
    if (script == null) {
      return const MaintenanceActionResult(
        ok: false,
        message: 'Diagnostics script not found',
        detail:
            'Expected /opt/beenut/scripts/collect-diagnostics.sh or packaging/scripts/collect-diagnostics.sh',
      );
    }

    final outputDir = await _diagnosticsOutputDir();
    final environment = Map<String, String>.from(Platform.environment)
      ..putIfAbsent('OUTPUT_DIR', () => outputDir.path)
      ..putIfAbsent('RUNTIME_DIR', () => '/tmp');

    final result = await Process.run('bash', [
      script.path,
    ], environment: environment);
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    final artifact =
        stdoutText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .lastOrNull
            ?.trim() ??
        '';
    final detail = [
      if (stdoutText.isNotEmpty) stdoutText,
      if (stderrText.isNotEmpty) stderrText,
    ].join('\n');

    if (result.exitCode == 0) {
      return MaintenanceActionResult(
        ok: true,
        message: 'Diagnostics exported',
        detail: detail.isEmpty ? outputDir.path : detail,
        artifactPath: artifact,
      );
    }

    return MaintenanceActionResult(
      ok: false,
      message: 'Diagnostics export failed',
      detail: detail.isEmpty ? 'Exit code ${result.exitCode}' : detail,
    );
  }

  static Future<MaintenanceActionResult> factoryReset({
    bool restartServices = true,
  }) async {
    final script = _findScript('factory-reset.sh');
    if (script == null) {
      return const MaintenanceActionResult(
        ok: false,
        message: 'Factory reset script not found',
        detail:
            'Expected /opt/beenut/scripts/factory-reset.sh or packaging/scripts/factory-reset.sh',
      );
    }

    final args = [script.path, if (!restartServices) '--no-restart'];
    final result = await Process.run('bash', args);
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    final detail = [
      if (stdoutText.isNotEmpty) stdoutText,
      if (stderrText.isNotEmpty) stderrText,
    ].join('\n');

    if (result.exitCode == 0) {
      return MaintenanceActionResult(
        ok: true,
        message: 'Factory reset complete',
        detail: detail.isEmpty
            ? 'Runtime config restored to package default'
            : detail,
      );
    }

    return MaintenanceActionResult(
      ok: false,
      message: 'Factory reset failed',
      detail: detail.isEmpty ? 'Exit code ${result.exitCode}' : detail,
    );
  }

  static List<String> findUsbUpdateDirectories() {
    final roots = <String>[
      if (Platform.isMacOS) '/Volumes',
      if (Platform.isLinux) ...['/media', '/mnt', '/run/media'],
    ];
    final matches = <String>{};
    for (final root in roots) {
      final rootDir = Directory(root);
      if (!rootDir.existsSync()) continue;
      try {
        for (final mount
            in rootDir.listSync(followLinks: false).whereType<Directory>()) {
          _addUpdateDirectoryMatch(matches, mount);
          for (final child
              in mount.listSync(followLinks: false).whereType<Directory>()) {
            _addUpdateDirectoryMatch(matches, child);
          }
        }
      } catch (_) {}
    }
    final sorted = matches.toList()..sort();
    return sorted;
  }

  static Future<MaintenanceActionResult> applyUsbUpdate({
    required String updateDir,
    bool dryRun = true,
    bool restartServices = true,
  }) async {
    final script = _findScript('apply-usb-update.sh');
    if (script == null) {
      return const MaintenanceActionResult(
        ok: false,
        message: 'USB update script not found',
        detail:
            'Expected /opt/beenut/scripts/apply-usb-update.sh or packaging/scripts/apply-usb-update.sh',
      );
    }
    if (!_looksLikeUpdateDirectory(Directory(updateDir))) {
      return MaintenanceActionResult(
        ok: false,
        message: 'Update folder is not valid',
        detail: 'Expected checksums/manifest and a .deb under $updateDir',
      );
    }

    final args = [
      script.path,
      if (dryRun) '--dry-run',
      if (!restartServices) '--no-restart',
      updateDir,
    ];
    final result = await Process.run('bash', args);
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    final detail = [
      if (stdoutText.isNotEmpty) stdoutText,
      if (stderrText.isNotEmpty) stderrText,
    ].join('\n');

    if (result.exitCode == 0) {
      return MaintenanceActionResult(
        ok: true,
        message: dryRun ? 'USB update dry run passed' : 'USB update complete',
        detail: detail.isEmpty ? updateDir : detail,
        artifactPath: updateDir,
      );
    }

    return MaintenanceActionResult(
      ok: false,
      message: dryRun ? 'USB update dry run failed' : 'USB update failed',
      detail: detail.isEmpty ? 'Exit code ${result.exitCode}' : detail,
      artifactPath: updateDir,
    );
  }

  static File? _findScript(String name) {
    final candidates = [
      File('/opt/beenut/scripts/$name'),
      File('packaging/scripts/$name'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }
    return null;
  }

  static bool _looksLikeUpdateDirectory(Directory directory) {
    if (!directory.existsSync()) return false;
    final directDebs = directory
        .listSync(followLinks: false)
        .whereType<File>()
        .any((file) => file.path.toLowerCase().endsWith('.deb'));
    final packageDir = Directory('${directory.path}/packages');
    final nestedDebs =
        packageDir.existsSync() &&
        packageDir
            .listSync(followLinks: false)
            .whereType<File>()
            .any((file) => file.path.toLowerCase().endsWith('.deb'));
    return directDebs ||
        nestedDebs ||
        File('${directory.path}/manifest.json').existsSync() ||
        File('${directory.path}/checksums.sha256').existsSync();
  }

  static void _addUpdateDirectoryMatch(
    Set<String> matches,
    Directory directory,
  ) {
    final name = directory.path.split(Platform.pathSeparator).last;
    if (name == 'beenut-update' && _looksLikeUpdateDirectory(directory)) {
      matches.add(directory.path);
      return;
    }
    final nested = Directory('${directory.path}/beenut-update');
    if (_looksLikeUpdateDirectory(nested)) {
      matches.add(nested.path);
    }
  }

  static Future<Directory> _diagnosticsOutputDir() async {
    final home = Platform.environment['HOME'];
    final base = home == null || home.isEmpty
        ? Directory.systemTemp.path
        : home;
    final directory = Directory('$base/BeeNut Diagnostics');
    await directory.create(recursive: true);
    return directory;
  }
}
