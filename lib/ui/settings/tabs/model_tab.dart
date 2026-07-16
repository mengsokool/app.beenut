import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../../common/widgets.dart';
import '../widgets/file_picker.dart';

enum ModelSettingsSection { model, counting, service }

class ModelSettingsTab extends StatelessWidget {
  const ModelSettingsTab({
    super.key,
    required this.config,
    required this.state,
    required this.capabilities,
    required this.enabled,
    required this.onSave,
    this.section = ModelSettingsSection.model,
  });

  final MachineConfig config;
  final MachineState state;
  final HardwareCapabilities capabilities;
  final bool enabled;
  final ValueChanged<MachineConfig> onSave;
  final ModelSettingsSection section;

  void _update(ModelSettings model) =>
      onSave(config.copyWithModelSettings(model));

  void _updateCounting(CountingSettings counting) =>
      onSave(config.copyWithCountingSettings(counting));

  void _updateSafeMode(bool safeMode) =>
      onSave(config.copyWithSettings(safeMode: safeMode));

  void _openPicker(
    BuildContext context,
    String kind,
    String initialPath,
    ValueChanged<String> onSelect,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FilePickerDialog(
        pickerKind: kind,
        initialPath: initialPath,
        onSelect: (path) {
          onSelect(path);
          Navigator.of(context).pop();
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = config.modelSettings;
    final counting = config.countingSettings;
    final engine = model.engine;
    final modelPath = engine == 'hailo' ? model.hefPath : model.modelPath;
    final labelsMode = model.labelsMode == 'custom' ? 'custom' : 'auto';
    final customLabelsPath = model.labelsPath;
    final runtimeById = {
      for (final runtime in capabilities.aiRuntimes)
        '${runtime['id']}': runtime,
    };
    ChoiceOption runtimeOption(
      String id,
      String title,
      String fallbackDetail,
      IconData icon,
    ) {
      final runtime = runtimeById[id];
      return ChoiceOption(
        value: id,
        title: title,
        detail: '${runtime?['detail'] ?? fallbackDetail}',
        icon: icon,
        available: runtime == null ? true : runtime['available'] == true,
      );
    }

    return Column(
      children: [
        if (section == ModelSettingsSection.model)
          SettingsGroup(
            title: I18n.t(context, 'model_runtime'),
            icon: Icons.memory_outlined,
            children: [
              ChoiceCardsRow(
                options: [
                  runtimeOption(
                    'onnx',
                    'ONNX',
                    I18n.t(context, 'run_onnx_general'),
                    Icons.memory_outlined,
                  ),
                  runtimeOption(
                    'hailo',
                    'Hailo',
                    I18n.t(context, 'run_hailo_production'),
                    Icons.developer_board_outlined,
                  ),
                  runtimeOption(
                    'mock',
                    'Mock',
                    I18n.t(context, 'run_mock_ui'),
                    Icons.science_outlined,
                  ),
                ],
                value: engine,
                enabled: enabled,
                onSelected: (value) => _update(model.copyWith(engine: value)),
              ),
            ],
          ),
        if (section == ModelSettingsSection.model)
          SettingsGroup(
            title: I18n.t(context, 'model_source'),
            icon: Icons.folder_open_outlined,
            children: [
              PathSettingRow(
                label: engine == 'hailo' ? 'Hailo HEF path' : 'ONNX model path',
                description: '',
                value: modelPath,
                buttonLabel: I18n.t(context, 'select_model_btn'),
                enabled: enabled,
                onBrowse: () {
                  _openPicker(context, 'model', modelPath, (path) {
                    if (engine == 'hailo') {
                      _update(model.copyWith(hefPath: path));
                    } else {
                      _update(model.copyWith(modelPath: path));
                    }
                  });
                },
              ),
              SelectSettingRow(
                label: 'Labels',
                description: '',
                value: labelsMode == 'auto' ? 'Auto detect' : 'Custom file',
                options: const ['Auto detect', 'Custom file'],
                enabled: enabled,
                onSelected: (value) => _update(
                  model.copyWith(
                    labelsMode: value == 'Custom file' ? 'custom' : 'auto',
                  ),
                ),
              ),
              if (labelsMode == 'custom')
                PathSettingRow(
                  label: 'Labels path',
                  description: '',
                  value: customLabelsPath,
                  buttonLabel: I18n.t(context, 'select_labels_btn'),
                  enabled: enabled,
                  onBrowse: () {
                    _openPicker(context, 'labels', customLabelsPath, (path) {
                      _update(
                        model.copyWith(labelsPath: path, labelsMode: 'custom'),
                      );
                    });
                  },
                )
              else
                _ModelLabelsPreviewRow(
                  labels: state.modelLabels,
                  detail: state.modelDetail,
                  mode: labelsMode,
                ),
              if (labelsMode == 'custom')
                _ModelLabelsPreviewRow(
                  labels: state.modelLabels,
                  detail: state.modelDetail,
                  mode: labelsMode,
                ),
            ],
          ),
        if (section == ModelSettingsSection.model)
          SettingsGroup(
            title: I18n.t(context, 'model_tuning'),
            description: I18n.t(context, 'model_tuning_desc'),
            icon: Icons.tune_outlined,
            collapsible: true,
            initiallyExpanded: false,
            children: [
              DecimalStepperSettingRow(
                label: 'Confidence',
                value: model.confidenceThreshold,
                min: 0.1,
                max: 0.95,
                step: 0.01,
                enabled: enabled,
                onChanged: (value) =>
                    _update(model.copyWith(confidenceThreshold: value)),
              ),
              DecimalStepperSettingRow(
                label: 'NMS',
                value: model.nmsThreshold,
                min: 0.1,
                max: 0.95,
                step: 0.01,
                enabled: enabled,
                onChanged: (value) =>
                    _update(model.copyWith(nmsThreshold: value)),
              ),
              StepperSettingRow(
                label: 'Max inference FPS',
                description: '',
                value: model.maxFps.toInt(),
                min: 1,
                max: 30,
                enabled: enabled,
                unit: 'fps',
                onChanged: (value) =>
                    _update(model.copyWith(maxFps: value.toDouble())),
              ),
              StepperSettingRow(
                label: 'Model input size',
                description: '',
                value: model.inputSize,
                min: 64,
                max: 2048,
                step: 32,
                enabled: enabled,
                unit: 'px',
                onChanged: (value) => _update(model.copyWith(inputSize: value)),
              ),
            ],
          ),
        if (section == ModelSettingsSection.counting)
          SettingsGroup(
            title: I18n.t(context, 'counting_behavior'),
            icon: Icons.filter_alt_outlined,
            children: [
              StepperSettingRow(
                label: I18n.t(context, 'stabilization_frames'),
                description: '',
                value: counting.stableFrames,
                min: 1,
                max: 30,
                enabled: enabled,
                onChanged: (value) =>
                    _updateCounting(counting.copyWith(stableFrames: value)),
              ),
              StepperSettingRow(
                label: I18n.t(context, 'max_timeout'),
                description: '',
                value: counting.timeoutMs,
                unit: 'ms',
                min: 500,
                max: 20000,
                step: 100,
                enabled: enabled,
                onChanged: (value) =>
                    _updateCounting(counting.copyWith(timeoutMs: value)),
              ),
            ],
          ),
        if (section == ModelSettingsSection.service)
          SettingsGroup(
            title: I18n.t(context, 'safety_fallback'),
            description: I18n.t(context, 'safety_fallback_desc'),
            icon: Icons.shield_outlined,
            collapsible: true,
            initiallyExpanded: false,
            children: [
              SwitchSettingRow(
                label: I18n.t(context, 'force_safe_mode'),
                description: '',
                value: config.safeMode,
                enabled: enabled,
                onChanged: _updateSafeMode,
              ),
            ],
          ),
      ],
    );
  }
}

class _ModelLabelsPreviewRow extends StatelessWidget {
  const _ModelLabelsPreviewRow({
    required this.labels,
    required this.detail,
    required this.mode,
  });

  final List<String> labels;
  final String detail;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleLabels = labels.take(6).toList();
    final remaining = labels.length - visibleLabels.length;
    final isUnavailable =
        labels.isEmpty &&
        detail.toLowerCase().contains('auto labels unavailable');
    final tone = labels.isNotEmpty
        ? RowTone.success
        : isUnavailable
        ? RowTone.warning
        : RowTone.neutral;
    final source = mode == 'custom' ? 'custom file' : 'ONNX metadata';
    final value = labels.isEmpty ? 'no classes' : '${labels.length} classes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingIcon(
                icon: labels.isEmpty
                    ? Icons.label_off_outlined
                    : Icons.label_outline,
                color: labels.isEmpty ? scheme.secondary : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      labels.isEmpty
                          ? (isUnavailable
                                ? I18n.t(context, 'err_no_metadata_labels')
                                : I18n.t(
                                    context,
                                    'no_loaded_classes',
                                    args: {'source': source},
                                  ))
                          : I18n.t(
                              context,
                              'loaded_from_source',
                              args: {'source': source},
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: BeenutTheme.mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusPill(value: value, tone: tone),
            ],
          ),
          if (visibleLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in visibleLabels) _ClassChip(label: label),
                  if (remaining > 0)
                    _ClassChip(
                      label: '+$remaining more',
                      onTap: () => _showAllClassesDialog(context, labels),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllClassesDialog(BuildContext context, List<String> labels) {
    showDialog(
      context: context,
      builder: (context) => _AllClassesDialog(labels: labels),
    );
  }
}

class _AllClassesDialog extends StatefulWidget {
  const _AllClassesDialog({required this.labels});

  final List<String> labels;

  @override
  State<_AllClassesDialog> createState() => _AllClassesDialogState();
}

class _AllClassesDialogState extends State<_AllClassesDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Model classes (${widget.labels.length})',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 620,
        height: 420,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int index = 0; index < widget.labels.length; index++)
                  _ClassChip(label: '${index + 1}. ${widget.labels[index]}'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            I18n.t(context, 'close'),
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      constraints: BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: onTap == null
            ? scheme.surfaceContainerHighest
            : scheme.tertiaryContainer,
        border: Border.all(
          color: onTap == null ? scheme.outlineVariant : scheme.tertiary,
        ),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: onTap == null
              ? scheme.onSurfaceVariant
              : scheme.onTertiaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      onTap: onTap,
      child: chip,
    );
  }
}
