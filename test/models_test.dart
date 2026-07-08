import 'package:beenut/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MachineConfig round-trips structured settings and target catalog', () {
    final config = MachineConfig.fromJson({
      'schema_version': 1,
      'controlSocket': '/tmp/custom.sock',
      'previewSocket': '/tmp/custom-preview.sock',
      'poweroffCommand': '/usr/bin/env true',
      'camera': {
        'source': 'mock',
        'width': 720,
        'height': 720,
        'preview_transport': 'shm_nv12',
      },
      'model': {
        'engine': 'onnx',
        'model_path': 'service/models/model.onnx',
        'hef_path': 'service/models/model.hef',
        'labels_mode': 'auto',
        'input_size': '512',
        'confidence_threshold': '0.6',
        'nms_threshold': 0.4,
        'max_fps': 12,
      },
      'gpio': {
        'enabled': true,
        'backend': 'libgpiod',
        'chip': 'gpiochip4',
        'tray_sensor_pin': 17,
        'relay_pin': 27,
        'active_low': 'true',
      },
      'counting': {
        'selected_part_type': 'target-a',
        'trigger_mode': 'real_time',
        'stable_frames': '7',
        'timeout_ms': 2500,
        'part_types': [
          {
            'id': 'target-a',
            'name': 'Target A',
            'image': '',
            'keywords': ['target', 'class-a'],
            'enabled': true,
          },
        ],
      },
      'ui': {'scale': '1.15'},
      'safe_mode': false,
    });

    final roundTrip = MachineConfig.fromJson(config.toJson());

    expect(roundTrip.schemaVersion, 1);
    expect(roundTrip.controlSocket, '/tmp/custom.sock');
    expect(roundTrip.previewSocket, '/tmp/custom-preview.sock');
    expect(roundTrip.poweroffCommand, '/usr/bin/env true');
    expect(roundTrip.toJson()['poweroffCommand'], '/usr/bin/env true');
    expect(roundTrip.camera['preview_transport'], 'shm_nv12');
    expect(roundTrip.model['engine'], 'onnx');
    expect(roundTrip.gpio['relay_pin'], 27);
    expect(roundTrip.counting['trigger_mode'], 'real_time');
    expect(roundTrip.ui['scale'], '1.15');
    expect(roundTrip.uiSettings.scale, 1.15);
    expect(roundTrip.safeMode, isFalse);
    expect(roundTrip.partTypes, hasLength(1));
    expect(roundTrip.partTypes.single.id, 'target-a');
    expect(roundTrip.partTypes.single.keywords, ['target', 'class-a']);
  });

  test('MachineConfig exposes typed sub-config views', () {
    final config = MachineConfig.fromJson({
      'camera': {
        'source': 'gstreamer',
        'width': '1280',
        'height': 720,
        'fps': 30,
        'idle_fps': '4',
        'warmup_frames': 3,
        'preview_transport': 'iosurface_nv12',
        'device': '/dev/video2',
        'exposure_mode': 'manual',
        'flip_horizontal': 'yes',
        'flip_vertical': 0,
      },
      'model': {
        'engine': 'hailo',
        'model_path': '/opt/beenut/model.onnx',
        'hef_path': '/opt/beenut/model.hef',
        'labels_mode': 'custom',
        'labels_path': '/opt/beenut/labels.txt',
        'input_size': '512',
        'confidence_threshold': '0.55',
        'nms_threshold': 0.35,
        'max_fps': '8.5',
      },
      'gpio': {
        'enabled': 1,
        'backend': 'libgpiod',
        'chip': 'gpiochip4',
        'tray_sensor_pin': '17',
        'relay_pin': 27,
        'active_low': 'true',
        'debounce_ms': '95',
      },
      'counting': {
        'selected_part_type': 'part-a',
        'trigger_mode': 'real_time',
        'stable_frames': '9',
        'timeout_ms': '3000',
      },
      'ui': {'scale': '0.9'},
    });

    expect(config.cameraSettings.source, 'gstreamer');
    expect(config.cameraSettings.width, 1280);
    expect(config.cameraSettings.idleFps, 4);
    expect(config.cameraSettings.previewTransport, 'iosurface_nv12');
    expect(config.cameraSettings.flipHorizontal, isTrue);
    expect(config.cameraSettings.flipVertical, isFalse);

    expect(config.modelSettings.engine, 'hailo');
    expect(config.modelSettings.hefPath, '/opt/beenut/model.hef');
    expect(config.modelSettings.labelsMode, 'custom');
    expect(config.modelSettings.inputSize, 512);
    expect(config.modelSettings.confidenceThreshold, 0.55);
    expect(config.modelSettings.maxFps, 8.5);

    expect(config.gpioSettings.enabled, isTrue);
    expect(config.gpioSettings.backend, 'libgpiod');
    expect(config.gpioSettings.chip, 'gpiochip4');
    expect(config.gpioSettings.traySensorPin, 17);
    expect(config.gpioSettings.activeLow, isTrue);
    expect(config.gpioSettings.debounceMs, 95);

    expect(config.countingSettings.selectedPartType, 'part-a');
    expect(config.countingSettings.triggerMode, 'real_time');
    expect(config.countingSettings.stableFrames, 9);
    expect(config.countingSettings.timeoutMs, 3000);

    expect(config.uiSettings.scale, 0.9);
    expect(
      MachineConfig.fromJson({
        'ui': {'scale': 2},
      }).uiSettings.scale,
      2.0,
    );
    expect(
      MachineConfig.fromJson({
        'ui': {'scale': 0.2},
      }).uiSettings.scale,
      0.5,
    );
  });

  test('MachineConfig patch helpers preserve sibling config sections', () {
    final config = MachineConfig.fromJson({
      'camera': {
        'source': 'v4l2',
        'device': '/dev/video0',
        'width': 720,
        'height': 720,
      },
      'model': {'engine': 'onnx', 'model_path': '/models/a.onnx', 'max_fps': 6},
      'gpio': {'tray_sensor_pin': 22, 'relay_pin': 27, 'active_low': false},
      'counting': {
        'selected_part_type': 'target-a',
        'trigger_mode': 'tray_sensor',
        'stable_frames': 5,
        'part_types': [
          {
            'id': 'target-a',
            'name': 'Target A',
            'image': '',
            'keywords': ['target'],
            'enabled': true,
          },
        ],
      },
      'ui': {'scale': 1.1},
      'safe_mode': false,
    });

    final next = config.copyWithSettings(
      camera: {'width': 1080},
      model: {'max_fps': 3},
      gpio: {'active_low': true},
      counting: {'trigger_mode': 'real_time'},
      ui: {'scale': 0.95},
      safeMode: true,
    );

    expect(next.cameraSettings.source, 'v4l2');
    expect(next.cameraSettings.device, '/dev/video0');
    expect(next.cameraSettings.width, 1080);
    expect(next.modelSettings.engine, 'onnx');
    expect(next.modelSettings.modelPath, '/models/a.onnx');
    expect(next.modelSettings.maxFps, 3);
    expect(next.gpioSettings.traySensorPin, 22);
    expect(next.gpioSettings.activeLow, isTrue);
    expect(next.countingSettings.selectedPartType, 'target-a');
    expect(next.countingSettings.triggerMode, 'real_time');
    expect(next.partTypes.single.id, 'target-a');
    expect(next.uiSettings.scale, 0.95);
    expect(next.safeMode, isTrue);
  });

  test('typed settings copyWith helpers preserve config schema keys', () {
    final config = MachineConfig.fromJson({
      'camera': {
        'source': 'v4l2',
        'device': '/dev/video0',
        'width': 720,
        'height': 720,
        'preview_transport': 'shm_nv12',
      },
      'model': {
        'engine': 'onnx',
        'model_path': '/models/a.onnx',
        'hef_path': '/models/a.hef',
        'labels_mode': 'auto',
        'labels_path': '',
        'input_size': 640,
        'confidence_threshold': 0.45,
        'nms_threshold': 0.5,
        'max_fps': 10,
      },
      'gpio': {
        'backend': 'libgpiod',
        'chip': 'gpiochip0',
        'tray_sensor_pin': 22,
        'relay_pin': 27,
        'active_low': false,
        'debounce_ms': 80,
      },
      'counting': {
        'selected_part_type': 'target-a',
        'trigger_mode': 'tray_sensor',
        'stable_frames': 5,
        'timeout_ms': 2500,
        'part_types': [
          {
            'id': 'target-a',
            'name': 'Target A',
            'image': '',
            'keywords': ['target'],
            'enabled': true,
          },
        ],
      },
      'ui': {'scale': 1.05},
    });

    final next = config
        .copyWithCameraSettings(
          config.cameraSettings.copyWith(width: 1080, height: 1080),
        )
        .copyWithModelSettings(
          config.modelSettings.copyWith(
            modelPath: '/models/b.onnx',
            labelsMode: 'custom',
            confidenceThreshold: 0.6,
            maxFps: 8,
          ),
        )
        .copyWithGpioSettings(
          config.gpioSettings.copyWith(traySensorPin: 17, activeLow: true),
        )
        .copyWithCountingSettings(
          config.countingSettings.copyWith(triggerMode: 'real_time'),
        )
        .copyWithUiSettings(config.uiSettings.copyWith(scale: 1.2));
    final json = next.toJson();

    expect((json['camera'] as Map)['preview_transport'], 'shm_nv12');
    expect((json['camera'] as Map)['width'], 1080);
    expect((json['model'] as Map)['model_path'], '/models/b.onnx');
    expect((json['model'] as Map)['labels_mode'], 'custom');
    expect((json['model'] as Map)['confidence_threshold'], 0.6);
    expect((json['model'] as Map)['max_fps'], 8);
    expect((json['gpio'] as Map)['tray_sensor_pin'], 17);
    expect((json['gpio'] as Map)['active_low'], isTrue);
    expect((json['counting'] as Map)['trigger_mode'], 'real_time');
    expect((json['counting'] as Map)['part_types'], isNotEmpty);
    expect((json['ui'] as Map)['scale'], 1.2);
  });

  test(
    'part catalog helper serializes targets and falls back selected target',
    () {
      final config = MachineConfig.fromJson({
        'counting': {
          'selected_part_type': 'target-a',
          'trigger_mode': 'tray_sensor',
          'stable_frames': 5,
          'timeout_ms': 2500,
          'part_types': [
            {
              'id': 'target-a',
              'name': 'Target A',
              'image': '',
              'keywords': ['a'],
              'enabled': true,
            },
          ],
        },
      });

      final next = config.copyWithPartCatalog(
        selectedPartType: 'missing-target',
        partTypes: [
          const PartType(
            id: 'target-b',
            name: 'Target B',
            image: '/images/b.png',
            keywords: ['b', 'class-b'],
            enabled: false,
          ),
        ],
      );
      final counting = next.toJson()['counting'] as Map<String, dynamic>;
      final serializedParts = counting['part_types'] as List;

      expect(counting['selected_part_type'], 'target-b');
      expect(counting['trigger_mode'], 'tray_sensor');
      expect(serializedParts, hasLength(1));
      expect(serializedParts.single['id'], 'target-b');
      expect(serializedParts.single['keywords'], ['b', 'class-b']);
      expect(serializedParts.single['enabled'], isFalse);
    },
  );

  test('MachineConfig.empty has no default target catalog', () {
    expect(MachineConfig.empty.partTypes, isEmpty);
    expect(MachineConfig.empty.counting, isEmpty);

    final json = MachineConfig.empty.toJson();
    final counting = json['counting'] as Map<String, dynamic>;
    expect(counting['part_types'], isEmpty);
    expect(counting.containsKey('selected_part_type'), isFalse);
  });

  test('MachineState.fromJson defaults selected part type to empty string', () {
    expect(MachineState.fromJson({}).selectedPartType, '');
  });

  test('MachineSnapshot.copyWith preserves unchanged fields', () {
    const snapshot = MachineSnapshot(
      connected: false,
      config: MachineConfig.empty,
      state: MachineState.empty,
    );

    final next = snapshot.copyWith(connected: true);

    expect(next.connected, isTrue);
    expect(next.config, same(snapshot.config));
    expect(next.state, same(snapshot.state));
    expect(next.capabilities, same(snapshot.capabilities));
    expect(next.validation, same(snapshot.validation));
    expect(next.diagnostic, same(snapshot.diagnostic));
    expect(next.saveResult, same(snapshot.saveResult));
  });
}
