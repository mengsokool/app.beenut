import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../common/widgets.dart';

class ConfigEditor extends StatefulWidget {
  const ConfigEditor({
    super.key,
    required this.config,
    required this.capabilities,
    required this.enabled,
    required this.onSave,
  });

  final MachineConfig config;
  final HardwareCapabilities capabilities;
  final bool enabled;
  final ValueChanged<MachineConfig> onSave;

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  static const fallbackGpioPins = [
    5,
    6,
    12,
    13,
    16,
    17,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
  ];
  static const fallbackResolutionPresets = [
    (label: '480p', width: 480, height: 480),
    (label: '640p', width: 640, height: 640),
    (label: '720p', width: 720, height: 720),
    (label: '1080p', width: 1080, height: 1080),
  ];
  static const previewTransportLabels = {
    'auto': 'Auto',
    'iosurface_nv12': 'IOSurface NV12',
    'dmabuf_egl': 'DMA-BUF/EGL',
    'shm_nv12': 'Shared memory NV12',
    'gstreamer_shm': 'GStreamer SHM',
    'mjpeg': 'MJPEG fallback',
  };
  static const configurablePreviewTransports = {
    'iosurface_nv12',
    'dmabuf_egl',
    'shm_nv12',
  };

  void _updateCamera(CameraSettings camera) =>
      widget.onSave(widget.config.copyWithCameraSettings(camera));

  void _updateGpio(GpioSettings gpio) =>
      widget.onSave(widget.config.copyWithGpioSettings(gpio));

  void _updateCounting(CountingSettings counting) =>
      widget.onSave(widget.config.copyWithCountingSettings(counting));

  String _previewTransportLabel(String id) => previewTransportLabels[id] ?? id;

  String _previewTransportId(String label) {
    for (final entry in previewTransportLabels.entries) {
      if (entry.value == label) return entry.key;
    }
    return label;
  }

  List<int> _gpioPinOptions(Map<String, dynamic> capability) {
    final pins =
        ((capability['availablePins'] as List?) ?? const [])
            .map((value) => value is int ? value : int.tryParse('$value'))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    return pins.isNotEmpty ? pins : fallbackGpioPins;
  }

  String _resolutionLabel(int width, int height) {
    final size = width < height ? width : height;
    return '${size}p';
  }

  List<({String label, int width, int height})> _resolutionOptions({
    required String source,
    required String device,
    required int currentWidth,
    required int currentHeight,
  }) {
    final options = <String, ({String label, int width, int height})>{};
    for (final camera in widget.capabilities.cameras) {
      if (source != 'auto' && camera['source'] != source) continue;
      if (source != 'auto' && device.isNotEmpty && camera['device'] != device) {
        continue;
      }
      for (final format in (camera['formats'] as List?) ?? const []) {
        if (format is! Map<String, dynamic>) continue;
        final width = format['width'];
        final height = format['height'];
        if (width is! int || height is! int) continue;
        final label = _resolutionLabel(width, height);
        options[label] = (label: label, width: width, height: height);
      }
      if (options.isNotEmpty) break;
    }
    if (options.isEmpty) {
      for (final preset in fallbackResolutionPresets) {
        options[preset.label] = preset;
      }
    }
    final currentLabel = _resolutionLabel(currentWidth, currentHeight);
    options.putIfAbsent(
      currentLabel,
      () => (label: currentLabel, width: currentWidth, height: currentHeight),
    );
    final sorted = options.values.toList()
      ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
    return sorted;
  }

  List<String> _previewTransportOptions(String current) {
    final options = <String>{'Auto'};
    if (widget.capabilities.previewTransports.isEmpty) {
      options.addAll(const [
        'IOSurface NV12',
        'Shared memory NV12',
        'DMA-BUF/EGL',
      ]);
    } else {
      for (final item in widget.capabilities.previewTransports) {
        final id = '${item['id'] ?? ''}';
        if (configurablePreviewTransports.contains(id) &&
            (item['available'] as bool? ?? false)) {
          options.add(_previewTransportLabel(id));
        }
      }
    }
    if (current != 'auto') {
      options.add(_previewTransportLabel(current));
    }
    return options.toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final camera = widget.config.cameraSettings;
    final gpio = widget.config.gpioSettings;
    final counting = widget.config.countingSettings;
    final width = camera.width;
    final height = camera.height;
    final source = camera.source;
    final previewTransport = camera.previewTransport;
    final trayPin = gpio.traySensorPin;
    final relayPin = gpio.relayPin;
    final triggerMode = counting.triggerMode;
    final gpioCapability = widget.capabilities.gpio;
    final gpioAvailable = gpioCapability['available'] as bool? ?? false;
    final gpioSupported = gpioCapability['hardwareSupported'] as bool? ?? false;
    final gpioBackend = '${gpioCapability['backend'] ?? 'mock'}';
    final gpioDetail = '${gpioCapability['detail'] ?? ''}';
    final gpioPins = _gpioPinOptions(gpioCapability);
    final platformClass =
        '${gpioCapability['platformClass'] ?? widget.capabilities.system['platformClass'] ?? 'unknown'}';
    final hardwareTriggerAvailable = gpioAvailable;
    final resolutionOptions = _resolutionOptions(
      source: source,
      device: camera.device,
      currentWidth: width,
      currentHeight: height,
    );
    final resolutionLabel = _resolutionLabel(width, height);
    final cameraOptionsMap = <String, ({String source, String device})>{};
    cameraOptionsMap[I18n.t(context, 'auto_detect')] = (
      source: 'auto',
      device: '',
    );
    for (final item in widget.capabilities.cameras) {
      final name = item['name'] as String? ?? '';
      final src = item['source'] as String? ?? '';
      final dev = item['device'] as String? ?? '';
      if (name.isNotEmpty && src.isNotEmpty) {
        cameraOptionsMap[name] = (source: src, device: dev);
      }
    }
    if (!cameraOptionsMap.containsKey('Test pattern (Mock)')) {
      cameraOptionsMap['Test pattern (Mock)'] = (source: 'mock', device: '');
    }

    String activeCameraOption = I18n.t(context, 'auto_detect');
    for (final entry in cameraOptionsMap.entries) {
      if (entry.value.source == source && entry.value.device == camera.device) {
        activeCameraOption = entry.key;
        break;
      }
    }

    final triggerModeLabel = triggerMode == 'real_time'
        ? I18n.t(context, 'live_stream')
        : (hardwareTriggerAvailable
              ? I18n.t(context, 'tray_triggered')
              : I18n.t(context, 'live_stream'));
    final triggerModeOptions = hardwareTriggerAvailable
        ? [I18n.t(context, 'tray_triggered'), I18n.t(context, 'live_stream')]
        : [I18n.t(context, 'live_stream')];

    return Column(
      children: [
        SettingsGroup(
          title: I18n.t(context, 'camera_basics'),
          icon: Icons.camera_alt_outlined,
          children: [
            SelectSettingRow(
              label: I18n.t(context, 'camera_source'),
              description: I18n.t(context, 'camera_source_desc'),
              value: activeCameraOption,
              options: cameraOptionsMap.keys.toList(),
              enabled: widget.enabled,
              onSelected: (value) {
                final selected = cameraOptionsMap[value];
                if (selected != null) {
                  Map<String, dynamic>? matchedCamera;
                  for (final item in widget.capabilities.cameras) {
                    if (item['source'] == selected.source &&
                        item['device'] == selected.device) {
                      matchedCamera = item;
                      break;
                    }
                  }

                  int? defaultWidth;
                  int? defaultHeight;
                  if (matchedCamera != null) {
                    final formats = matchedCamera['formats'] as List?;
                    if (formats != null && formats.isNotEmpty) {
                      final firstFormat = formats.first;
                      if (firstFormat is Map<String, dynamic>) {
                        defaultWidth = firstFormat['width'] as int?;
                        defaultHeight = firstFormat['height'] as int?;
                      }
                    }
                  }

                  _updateCamera(
                    camera.copyWith(
                      source: selected.source,
                      device: selected.device,
                      width: defaultWidth ?? camera.width,
                      height: defaultHeight ?? camera.height,
                    ),
                  );
                }
              },
            ),
            SelectSettingRow(
              label: I18n.t(context, 'resolution'),
              description: I18n.t(context, 'resolution_desc'),
              value:
                  resolutionOptions.any(
                    (item) => item.width == width && item.height == height,
                  )
                  ? resolutionLabel
                  : 'Custom ($width x $height)',
              options: [
                if (!resolutionOptions.any(
                  (item) => item.width == width && item.height == height,
                ))
                  'Custom ($width x $height)',
                for (final item in resolutionOptions) item.label,
              ],
              enabled: widget.enabled,
              onSelected: (value) {
                for (final option in resolutionOptions) {
                  if (option.label == value) {
                    _updateCamera(
                      camera.copyWith(
                        width: option.width,
                        height: option.height,
                      ),
                    );
                    break;
                  }
                }
              },
            ),
            SwitchSettingRow(
              label: I18n.t(context, 'flip_horizontal'),
              description: I18n.t(context, 'flip_horizontal_desc'),
              value: camera.flipHorizontal,
              enabled: widget.enabled,
              onChanged: (value) =>
                  _updateCamera(camera.copyWith(flipHorizontal: value)),
            ),
            SwitchSettingRow(
              label: I18n.t(context, 'flip_vertical'),
              description: I18n.t(context, 'flip_vertical_desc'),
              value: camera.flipVertical,
              enabled: widget.enabled,
              onChanged: (value) =>
                  _updateCamera(camera.copyWith(flipVertical: value)),
            ),
          ],
        ),
        SettingsGroup(
          title: I18n.t(context, 'camera_pipeline'),
          description: I18n.t(context, 'camera_pipeline_desc'),
          icon: Icons.settings_input_component_outlined,
          collapsible: true,
          initiallyExpanded: false,
          children: [
            SelectSettingRow(
              label: I18n.t(context, 'preview_transport'),
              description: I18n.t(context, 'preview_transport_desc'),
              value: _previewTransportLabel(previewTransport),
              options: _previewTransportOptions(previewTransport),
              enabled: widget.enabled,
              onSelected: (value) => _updateCamera(
                camera.copyWith(previewTransport: _previewTransportId(value)),
              ),
            ),
            StepperSettingRow(
              label: I18n.t(context, 'warmup_frames'),
              description: I18n.t(context, 'warmup_frames_desc'),
              value: camera.warmupFrames,
              min: 0,
              max: 30,
              enabled: widget.enabled,
              onChanged: (value) =>
                  _updateCamera(camera.copyWith(warmupFrames: value)),
            ),
          ],
        ),
        SettingsGroup(
          title: I18n.t(context, 'count_trigger'),
          icon: Icons.play_circle_outline,
          children: [
            IconInfoRow(
              icon: hardwareTriggerAvailable
                  ? Icons.memory_outlined
                  : Icons.desktop_windows_outlined,
              iconColor: hardwareTriggerAvailable
                  ? scheme.tertiary
                  : scheme.onSurfaceVariant,
              label: I18n.t(context, 'hardware_io'),
              description: hardwareTriggerAvailable
                  ? I18n.t(context, 'gpio_detected')
                  : (gpioSupported
                        ? gpioDetail
                        : I18n.t(context, 'gpio_mock_mode')),
              value: hardwareTriggerAvailable ? gpioBackend : platformClass,
              tone: hardwareTriggerAvailable
                  ? RowTone.success
                  : RowTone.neutral,
            ),
            SelectSettingRow(
              label: I18n.t(context, 'trigger_mode'),
              description: hardwareTriggerAvailable
                  ? I18n.t(context, 'trigger_mode_desc')
                  : I18n.t(context, 'no_gpio_live_only'),
              value: triggerModeLabel,
              options: triggerModeOptions,
              enabled: widget.enabled,
              onSelected: (value) {
                final mode =
                    (value == I18n.t(context, 'live_stream') ||
                        value == 'เรียลไทม์สด')
                    ? 'real_time'
                    : 'tray_sensor';
                _updateCounting(counting.copyWith(triggerMode: mode));
              },
            ),
          ],
        ),
        if (hardwareTriggerAvailable)
          SettingsGroup(
            title: I18n.t(context, 'gpio_mapping'),
            description: I18n.t(context, 'gpio_mapping_desc'),
            icon: Icons.developer_board_outlined,
            collapsible: true,
            initiallyExpanded: false,
            children: [
              if (triggerMode == 'tray_sensor') ...[
                SelectSettingRow(
                  label: I18n.t(context, 'tray_sensor_pin'),
                  description: I18n.t(context, 'tray_sensor_pin_desc'),
                  value: 'GPIO $trayPin',
                  options: [
                    if (!gpioPins.contains(trayPin)) 'GPIO $trayPin',
                    for (final pin in gpioPins) 'GPIO $pin',
                  ],
                  enabled: widget.enabled,
                  onSelected: (value) => _updateGpio(
                    gpio.copyWith(
                      traySensorPin: int.parse(value.split(' ').last),
                    ),
                  ),
                ),
                StepperSettingRow(
                  label: I18n.t(context, 'debounce_time'),
                  description: I18n.t(context, 'debounce_time_desc'),
                  value: gpio.debounceMs,
                  unit: 'ms',
                  min: 0,
                  max: 1000,
                  step: 5,
                  enabled: widget.enabled,
                  onChanged: (value) =>
                      _updateGpio(gpio.copyWith(debounceMs: value)),
                ),
              ],
              SelectSettingRow(
                label: I18n.t(context, 'led_relay_pin'),
                description: I18n.t(context, 'led_relay_pin_desc'),
                value: 'GPIO $relayPin',
                options: [
                  if (!gpioPins.contains(relayPin)) 'GPIO $relayPin',
                  for (final pin in gpioPins) 'GPIO $pin',
                ],
                enabled: widget.enabled,
                onSelected: (value) => _updateGpio(
                  gpio.copyWith(relayPin: int.parse(value.split(' ').last)),
                ),
              ),
              SwitchSettingRow(
                label: I18n.t(context, 'active_low_relay'),
                description: I18n.t(context, 'active_low_relay_desc'),
                value: gpio.activeLow,
                enabled: widget.enabled,
                onChanged: (value) =>
                    _updateGpio(gpio.copyWith(activeLow: value)),
              ),
            ],
          ),
      ],
    );
  }
}
