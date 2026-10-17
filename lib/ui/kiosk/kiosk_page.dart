import 'package:flutter/material.dart';

import '../../core/android_camera_controller.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import 'preview_pane.dart';
import 'touch_workbench.dart';

class KioskPage extends StatelessWidget {
  const KioskPage({
    super.key,
    required this.snapshot,
    required this.client,
    this.cameraController,
    required this.cameraPermission,
    required this.onOpenSettings,
  });

  final MachineSnapshot snapshot;
  final KioskServiceClient client;
  final AndroidCameraController? cameraController;
  final CameraPermissionStatus cameraPermission;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final state = snapshot.state;
    final parts = snapshot.config.partTypes
        .where((part) => part.enabled)
        .toList();
    final model = snapshot.config.modelSettings;
    final isModelUnconfigured =
        model.modelPath.trim().isEmpty && model.hefPath.trim().isEmpty;
    final hasFault =
        !snapshot.connected ||
        cameraPermission.blocksCamera ||
        state.safeMode ||
        state.camera == 'error' ||
        state.camera == 'missing' ||
        (state.model == 'error' && !isModelUnconfigured) ||
        state.model == 'missing';

    final statusTitle = cameraPermission.blocksCamera
        ? I18n.t(context, 'camera_permission_denied')
        : hasFault
        ? I18n.t(context, 'machine_error')
        : isModelUnconfigured
        ? I18n.t(context, 'model_unconfigured')
        : I18n.t(context, 'suspended');
    final statusDetail = cameraPermission.blocksCamera
        ? I18n.t(context, 'check_camera_permissions')
        : hasFault
        ? I18n.t(context, 'diagnostic_mode')
        : isModelUnconfigured
        ? I18n.t(context, 'select_model_prompt')
        : I18n.t(context, 'paused');

    final selectedPart = parts
        .where((part) => part.id == state.selectedPartType)
        .firstOrNull;
    return TouchWorkbench(
      preview: NativePreviewPane(
        state: state,
        connected: snapshot.connected,
        previewSocket: snapshot.config.previewSocket,
        keywords: selectedPart?.keywords ?? const [],
        classNames: selectedPart?.classNames ?? const {},
        client: client,
        cameraController: cameraController,
        aspectRatio: 1,
      ),
      parts: parts,
      selectedId: state.selectedPartType,
      count: state.count,
      detections: state.detections,
      completed: state.trayPresent && !state.countTestRunning,
      paused: state.previewPaused,
      counting: state.countTestRunning,
      needsAttention: hasFault || isModelUnconfigured,
      statusTitle: statusTitle,
      statusDetail: statusDetail,
      onSelectPart: client.selectPartType,
      onOpenSettings: onOpenSettings,
      onTogglePause: () => client.setPreviewPaused(!state.previewPaused),
    );
  }
}
