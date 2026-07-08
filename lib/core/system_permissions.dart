import 'dart:io';

import 'package:flutter/services.dart';

enum CameraPermissionStatus {
  authorized,
  denied,
  restricted,
  notDetermined,
  unsupported,
  unknown;

  bool get blocksCamera => this == denied || this == restricted;

  String get label => switch (this) {
    CameraPermissionStatus.authorized => 'authorized',
    CameraPermissionStatus.denied => 'denied',
    CameraPermissionStatus.restricted => 'restricted',
    CameraPermissionStatus.notDetermined => 'not determined',
    CameraPermissionStatus.unsupported => 'unsupported',
    CameraPermissionStatus.unknown => 'unknown',
  };

  String get message => switch (this) {
    CameraPermissionStatus.denied =>
      'macOS denied camera access. Open Privacy & Security > Camera and enable BeeNut.',
    CameraPermissionStatus.restricted =>
      'Camera access is restricted by macOS policy.',
    CameraPermissionStatus.notDetermined =>
      'Camera permission has not been requested.',
    CameraPermissionStatus.authorized => 'Camera permission is granted.',
    CameraPermissionStatus.unsupported =>
      'Camera permission preflight is not required on this platform.',
    CameraPermissionStatus.unknown => 'Camera permission status is unknown.',
  };

  static CameraPermissionStatus parse(String value) => switch (value) {
    'authorized' => CameraPermissionStatus.authorized,
    'denied' => CameraPermissionStatus.denied,
    'restricted' => CameraPermissionStatus.restricted,
    'not_determined' => CameraPermissionStatus.notDetermined,
    'unsupported' => CameraPermissionStatus.unsupported,
    _ => CameraPermissionStatus.unknown,
  };
}

class SystemPermissions {
  SystemPermissions._();

  static const MethodChannel _channel = MethodChannel(
    'beenut/system_permissions',
  );

  static Future<CameraPermissionStatus> currentCameraStatus() async {
    if (!Platform.isMacOS) {
      return CameraPermissionStatus.unsupported;
    }
    try {
      final raw = await _channel.invokeMethod<String>('cameraStatus');
      return CameraPermissionStatus.parse(raw ?? 'unknown');
    } catch (_) {
      return CameraPermissionStatus.unknown;
    }
  }

  static Future<CameraPermissionStatus> requestCameraIfNeeded() async {
    if (!Platform.isMacOS) {
      return CameraPermissionStatus.unsupported;
    }
    try {
      final raw = await _channel.invokeMethod<String>('requestCamera');
      return CameraPermissionStatus.parse(raw ?? 'unknown');
    } catch (_) {
      return CameraPermissionStatus.unknown;
    }
  }

  static Future<void> openCameraPrivacySettings() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('openCameraSettings');
    } catch (_) {}
  }
}
