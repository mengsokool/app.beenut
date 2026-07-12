import 'dart:async';

import 'package:flutter/foundation.dart';
import 'models.dart';
import 'i18n.dart';
import 'service_protocol.dart';
import 'service_transport.dart';

abstract interface class KioskServiceClient {
  MachineSnapshot get snapshot;

  void start();
  void selectPartType(String partType);
  void testTray(bool? present);
  void testLight(bool enabled);
  void countOnce();
  void setPreviewPaused(bool paused);
  void saveConfig(MachineConfig config);
  void shutdown();
  void refreshCapabilities();
  void validateConfig(MachineConfig config);
  void runDiagnostic(String target);
}

class ServiceClient extends ChangeNotifier implements KioskServiceClient {
  ServiceClient({
    this.socketPath = '/tmp/beenutd.sock',
    ServiceTransport? transport,
  }) : _transport = transport ?? createServiceTransport(socketPath);

  final String socketPath;
  final ServiceTransport _transport;
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

  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;
  Timer? _configSaveTimer;
  final _lineFramer = Utf8LineFramer();
  MachineConfig? _serverConfig;
  MachineConfig? _optimisticConfig;
  MachineConfig? _pendingConfigSave;
  MachineConfig? _saveInFlightConfig;
  bool? _desiredPreviewPaused;
  bool _disposed = false;
  int _connectFailures = 0;

  @override
  void start() {
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    try {
      await _transport.connect();
      if (_disposed) {
        await _transport.close();
        return;
      }
      _connectFailures = 0;
      _updateSnapshot(snapshot.copyWith(connected: true));
      _subscription = _transport.bytes.listen(
        _onBytes,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
      _send({'type': 'getCapabilities'});
      _send({'type': 'validateConfig', 'config': snapshot.config.toJson()});
      final desiredPreviewPaused = _desiredPreviewPaused;
      if (desiredPreviewPaused != null) {
        _send({'type': 'setPreviewPaused', 'paused': desiredPreviewPaused});
      }
    } catch (e) {
      _connectFailures += 1;
      if (_connectFailures == 1 || _connectFailures % 10 == 0) {
        debugPrint('Waiting for backend socket $socketPath: $e');
      }
      if (!_disposed) {
        _scheduleReconnect();
      }
    }
  }

  void _onBytes(List<int> bytes) {
    for (final line in _lineFramer.add(bytes)) {
      if (line.trim().isEmpty) continue;
      final root = decodeProtocolLine(line);
      _handleEvent(root);
    }
  }

  void _handleEvent(Map<String, dynamic> root) {
    switch (root['type']) {
      case 'status':
        _handleStatusEvent(root);
        break;
      case 'capabilities':
        _updateSnapshot(
          snapshot.copyWith(
            connected: true,
            capabilities: HardwareCapabilities.fromJson(
              root['capabilities'] as Map<String, dynamic>? ?? {},
            ),
          ),
        );
        break;
      case 'configValidation':
        _updateSnapshot(
          snapshot.copyWith(
            connected: true,
            validation: ConfigValidation.fromJson(
              root['validation'] as Map<String, dynamic>? ?? {},
            ),
          ),
        );
        break;
      case 'diagnosticEvent':
        _updateSnapshot(
          snapshot.copyWith(
            connected: true,
            diagnostic: DiagnosticEvent.fromJson(
              root['event'] as Map<String, dynamic>? ?? {},
            ),
          ),
        );
        break;
      case 'configSaveResult':
        _handleConfigSaveResultEvent(root);
        break;
    }
  }

  void _handleStatusEvent(Map<String, dynamic> root) {
    final serverConfig = MachineConfig.fromJson(
      root['config'] as Map<String, dynamic>? ?? {},
    );
    final serverState = MachineState.fromJson(
      root['state'] as Map<String, dynamic>? ?? {},
    );
    final desiredPreviewPaused = _desiredPreviewPaused;
    final mergedState = desiredPreviewPaused == null
        ? serverState
        : _stateWithPreviewPause(serverState, desiredPreviewPaused);
    if (desiredPreviewPaused != null &&
        serverState.previewPaused != desiredPreviewPaused) {
      _send({'type': 'setPreviewPaused', 'paused': desiredPreviewPaused});
    }
    _serverConfig = serverConfig;
    _updateSnapshot(
      snapshot.copyWith(
        connected: true,
        config: _optimisticConfig ?? serverConfig,
        state: mergedState,
      ),
    );
  }

  void _handleConfigSaveResultEvent(Map<String, dynamic> root) {
    final result = ConfigSaveResult.fromJson(
      root['result'] as Map<String, dynamic>? ?? {},
    );
    if (result.ok) {
      final saved = _saveInFlightConfig;
      if (saved != null) {
        _serverConfig = saved;
      }
      if (saved != null &&
          (_optimisticConfig == null ||
              _sameConfig(saved, _optimisticConfig!))) {
        _optimisticConfig = null;
      }
      _saveInFlightConfig = null;
    } else {
      _optimisticConfig = null;
      _saveInFlightConfig = null;
      _pendingConfigSave = null;
      _configSaveTimer?.cancel();
    }
    _updateSnapshot(
      snapshot.copyWith(
        connected: true,
        config: _optimisticConfig ?? _serverConfig ?? snapshot.config,
        saveResult: result,
      ),
    );
  }

  @visibleForTesting
  void handleBytesForTest(List<int> bytes) {
    _onBytes(bytes);
  }

  @override
  void selectPartType(String partType) {
    _updateSnapshot(
      snapshot.copyWith(
        state: snapshot.state.copyWith(selectedPartType: partType),
      ),
    );
    _send({'type': 'selectPartType', 'partType': partType});
  }

  @override
  void testTray(bool? present) {
    if (present != null) {
      _updateSnapshot(
        snapshot.copyWith(state: snapshot.state.copyWith(trayPresent: present)),
      );
    }
    _send({'type': 'testTray', 'present': present});
  }

  @override
  void testLight(bool enabled) {
    _updateSnapshot(
      snapshot.copyWith(state: snapshot.state.copyWith(lightOn: enabled)),
    );
    _send({'type': 'testLight', 'enabled': enabled});
  }

  @override
  void countOnce() {
    _send({'type': 'countOnce'});
  }

  @override
  void setPreviewPaused(bool paused) {
    _desiredPreviewPaused = paused;
    _updateSnapshot(
      snapshot.copyWith(state: _stateWithPreviewPause(snapshot.state, paused)),
    );
    _send({'type': 'setPreviewPaused', 'paused': paused});
  }

  @override
  void saveConfig(MachineConfig config) {
    _optimisticConfig = config;
    _updateSnapshot(
      snapshot.copyWith(
        config: config,
        state: snapshot.state.copyWith(safeMode: config.safeMode),
      ),
    );
    _scheduleConfigSave(config);
  }

  @override
  void shutdown() {
    _send({'type': 'shutdown'});
  }

  @override
  void refreshCapabilities() {
    _send({'type': 'refreshCapabilities'});
    _send({'type': 'validateConfig', 'config': snapshot.config.toJson()});
  }

  @override
  void validateConfig(MachineConfig config) {
    _send({'type': 'validateConfig', 'config': config.toJson()});
  }

  @override
  void runDiagnostic(String target) {
    _send({'type': 'runDiagnostic', 'target': target});
  }

  void _scheduleConfigSave(MachineConfig config) {
    _pendingConfigSave = config;
    _configSaveTimer?.cancel();
    _configSaveTimer = Timer(const Duration(milliseconds: 220), () {
      final pending = _pendingConfigSave;
      _pendingConfigSave = null;
      if (pending == null || _disposed) return;
      _saveInFlightConfig = pending;
      final json = pending.toJson();
      _send({'type': 'validateConfig', 'config': json});
      _send({'type': 'saveConfig', 'config': json});
    });
  }

  void _send(Map<String, Object?> payload) {
    _transport.send(encodeProtocolLine(payload));
  }

  void _updateSnapshot(MachineSnapshot next) {
    snapshot = next;
    I18n.updateFromConfig(next.config);
    notifyListeners();
  }

  MachineState _stateWithPreviewPause(MachineState state, bool paused) =>
      state.copyWith(
        previewPaused: paused,
        countTestRunning: paused ? false : state.countTestRunning,
        inferenceFps: paused ? 0 : state.inferenceFps,
        processingMs: paused ? 0 : state.processingMs,
        detections: paused ? const [] : state.detections,
      );

  bool _sameConfig(MachineConfig left, MachineConfig right) =>
      encodeProtocolLine(left.toJson()) == encodeProtocolLine(right.toJson());

  void _scheduleReconnect() {
    if (_disposed) return;
    _subscription?.cancel();
    unawaited(_transport.close());
    _updateSnapshot(snapshot.copyWith(connected: false));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 750), _connect);
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _configSaveTimer?.cancel();
    _subscription?.cancel();
    unawaited(_transport.close());
    super.dispose();
  }
}
