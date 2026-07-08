import 'dart:async';
import 'dart:convert';

import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/service_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps optimistic config while backend status is still stale', () async {
    final client = ServiceClient();

    client.handleBytesForTest(_line(_statusWithTriggerMode('tray_sensor')));
    expect(client.snapshot.config.counting['trigger_mode'], 'tray_sensor');

    final optimisticRoot = client.snapshot.config.toJson();
    optimisticRoot['counting'] = {
      ...Map<String, dynamic>.from(optimisticRoot['counting'] as Map),
      'trigger_mode': 'real_time',
    };
    client.saveConfig(MachineConfig.fromJson(optimisticRoot));
    expect(client.snapshot.config.counting['trigger_mode'], 'real_time');

    client.handleBytesForTest(_line(_statusWithTriggerMode('tray_sensor')));
    expect(client.snapshot.config.counting['trigger_mode'], 'real_time');

    await Future<void>.delayed(const Duration(milliseconds: 260));
    client.handleBytesForTest(
      _line({
        'type': 'configSaveResult',
        'result': {
          'ok': true,
          'message': 'Config saved and applied',
          'timestampMs': 1,
        },
      }),
    );
    expect(client.snapshot.config.counting['trigger_mode'], 'real_time');

    client.dispose();
  });

  test('does not clear a pending theme change with a stale save result', () {
    final client = ServiceClient();

    client.handleBytesForTest(_line(_statusWithTheme('light')));
    expect(client.snapshot.config.uiSettings.theme, 'light');

    final next = client.snapshot.config.copyWithUiSettings(
      client.snapshot.config.uiSettings.copyWith(theme: 'dark'),
    );
    client.saveConfig(next);
    expect(client.snapshot.config.uiSettings.theme, 'dark');

    client.handleBytesForTest(
      _line({
        'type': 'configSaveResult',
        'result': {
          'ok': true,
          'message': 'Previous config saved',
          'timestampMs': 1,
        },
      }),
    );
    expect(client.snapshot.config.uiSettings.theme, 'dark');

    client.handleBytesForTest(_line(_statusWithTheme('light')));
    expect(client.snapshot.config.uiSettings.theme, 'dark');

    client.dispose();
  });

  test('keeps preview pause while backend status is stale', () {
    final client = ServiceClient();

    client.handleBytesForTest(_line(_statusWithTriggerMode('real_time')));
    client.setPreviewPaused(true);
    expect(client.snapshot.state.previewPaused, isTrue);

    client.handleBytesForTest(_line(_statusWithTriggerMode('real_time')));
    expect(client.snapshot.state.previewPaused, isTrue);
    expect(client.snapshot.state.inferenceFps, 0);
    expect(client.snapshot.state.detections, isEmpty);

    client.setPreviewPaused(false);
    expect(client.snapshot.state.previewPaused, isFalse);

    client.dispose();
  });

  test('frames UTF-8 json lines across socket chunks', () {
    final client = ServiceClient();
    final payload = _line({
      'type': 'diagnosticEvent',
      'event': {
        'target': 'camera',
        'ok': true,
        'message': 'กล้องพร้อมใช้งาน',
        'detail': 'ทดสอบแบ่ง byte กลางตัวอักษร',
        'timestampMs': 7,
      },
    });
    final split = payload.indexWhere((byte) => byte > 0x7f) + 1;

    client.handleBytesForTest(payload.sublist(0, split));
    expect(client.snapshot.diagnostic.hasData, isFalse);

    client.handleBytesForTest(payload.sublist(split));
    expect(client.snapshot.diagnostic.message, 'กล้องพร้อมใช้งาน');
    expect(client.snapshot.diagnostic.detail, 'ทดสอบแบ่ง byte กลางตัวอักษร');

    client.dispose();
  });

  test('can use an injected service transport', () async {
    final transport = _FakeTransport();
    final client = ServiceClient(transport: transport);

    client.start();
    await Future<void>.delayed(Duration.zero);

    expect(transport.connected, isTrue);
    expect(transport.sent.map(decodeLineType), contains('getCapabilities'));
    expect(transport.sent.map(decodeLineType), contains('validateConfig'));

    client.dispose();
  });

  test('ignores unknown backend events', () {
    final client = ServiceClient();
    var notifications = 0;
    client.addListener(() => notifications += 1);

    client.handleBytesForTest(_line({'type': 'futureEvent', 'value': 1}));

    expect(notifications, 0);
    expect(client.snapshot.connected, isFalse);

    client.dispose();
  });
}

List<int> _line(Map<String, dynamic> payload) =>
    utf8.encode('${jsonEncode(payload)}\n');

Map<String, dynamic> _statusWithTriggerMode(String mode) => {
  'type': 'status',
  'config': {
    'camera': {},
    'model': {},
    'gpio': {},
    'counting': {'selected_part_type': '', 'trigger_mode': mode},
    'safe_mode': false,
  },
  'state': {},
};

Map<String, dynamic> _statusWithTheme(String theme) => {
  'type': 'status',
  'config': {
    'camera': {},
    'model': {},
    'gpio': {},
    'counting': {'selected_part_type': '', 'trigger_mode': 'real_time'},
    'ui': {'theme': theme},
    'safe_mode': false,
  },
  'state': {},
};

String decodeLineType(String line) =>
    (jsonDecode(line) as Map<String, dynamic>)['type'] as String;

class _FakeTransport implements ServiceTransport {
  final sent = <String>[];
  final _controller = StreamController<List<int>>.broadcast();
  bool connected = false;

  @override
  Stream<List<int>> get bytes => _controller.stream;

  @override
  Future<void> connect() async {
    connected = true;
  }

  @override
  void send(String line) {
    sent.add(line);
  }

  @override
  Future<void> close() async {
    connected = false;
  }
}
