import 'package:flutter/material.dart';

@immutable
class WorkbenchColors extends ThemeExtension<WorkbenchColors> {
  const WorkbenchColors({
    required this.action,
    required this.actionHover,
    required this.actionActive,
    required this.actionSoft,
    required this.actionText,
    required this.actionFocus,
    required this.onAction,
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.disabled,
    required this.line,
    required this.lineSubtle,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.previewBlack,
  });

  static const light = WorkbenchColors(
    // Construction Yellow
    action: Color(0xfff1c21b),
    actionHover: Color(0xffd2a106),
    actionActive: Color(0xff8e6a00),
    actionSoft: Color(0xfffff4c2),
    actionText: Color(0xff8e6a00),
    actionFocus: Color(0xfff1c21b),
    onAction: Color(0xff161616),

    // Surfaces
    canvas: Color(0xfff4f4f4),
    surface: Color(0xffffffff),
    raised: Color(0xfff8f8f8),

    // Text
    ink: Color(0xff161616),
    muted: Color(0xff525252),
    disabled: Color(0xff8d8d8d),

    // Borders
    line: Color(0xff8d8d8d),
    lineSubtle: Color(0xffe0e0e0),

    // Status
    success: Color(0xff166534),
    successSoft: Color(0xffdcfce7),

    warning: Color(0xffb45309),
    warningSoft: Color(0xfffff4c2),

    danger: Color(0xffb91c1c),
    dangerSoft: Color(0xfffee2e2),

    info: Color(0xff8e6a00),
    infoSoft: Color(0xfffff4c2),

    previewBlack: Color(0xff09090b),
  );

  static const dark = WorkbenchColors(
    // Construction Yellow
    action: Color(0xfff1c21b),
    actionHover: Color(0xffffd84d),
    actionActive: Color(0xffd2a106),
    actionSoft: Color(0xff3d3100),
    actionText: Color(0xffffd84d),
    actionFocus: Color(0xfff1c21b),
    onAction: Color(0xff161616),

    // Industrial Dark
    canvas: Color(0xff161616),
    surface: Color(0xff262626),
    raised: Color(0xff393939),

    // Text
    ink: Color(0xfff4f4f4),
    muted: Color(0xffc6c6c6),
    disabled: Color(0xff8d8d8d),

    // Borders
    line: Color(0xff6f6f6f),
    lineSubtle: Color(0xff525252),

    // Status
    success: Color(0xff4ade80),
    successSoft: Color(0xff123d24),

    warning: Color(0xffffd84d),
    warningSoft: Color(0xff493b00),

    danger: Color(0xfff87171),
    dangerSoft: Color(0xff4c1d1d),

    info: Color(0xffffd84d),
    infoSoft: Color(0xff3d3100),

    previewBlack: Color(0xff09090b),
  );

  final Color action;
  final Color actionHover;
  final Color actionActive;
  final Color actionSoft;
  final Color actionText;
  final Color actionFocus;
  final Color onAction;
  final Color canvas;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color disabled;
  final Color line;
  final Color lineSubtle;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color previewBlack;

  @override
  WorkbenchColors copyWith({
    Color? action,
    Color? actionHover,
    Color? actionActive,
    Color? actionSoft,
    Color? actionText,
    Color? actionFocus,
    Color? onAction,
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? disabled,
    Color? line,
    Color? lineSubtle,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? previewBlack,
  }) {
    return WorkbenchColors(
      action: action ?? this.action,
      actionHover: actionHover ?? this.actionHover,
      actionActive: actionActive ?? this.actionActive,
      actionSoft: actionSoft ?? this.actionSoft,
      actionText: actionText ?? this.actionText,
      actionFocus: actionFocus ?? this.actionFocus,
      onAction: onAction ?? this.onAction,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      disabled: disabled ?? this.disabled,
      line: line ?? this.line,
      lineSubtle: lineSubtle ?? this.lineSubtle,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      previewBlack: previewBlack ?? this.previewBlack,
    );
  }

  @override
  WorkbenchColors lerp(WorkbenchColors? other, double t) {
    if (other == null) return this;
    return WorkbenchColors(
      action: Color.lerp(action, other.action, t)!,
      actionHover: Color.lerp(actionHover, other.actionHover, t)!,
      actionActive: Color.lerp(actionActive, other.actionActive, t)!,
      actionSoft: Color.lerp(actionSoft, other.actionSoft, t)!,
      actionText: Color.lerp(actionText, other.actionText, t)!,
      actionFocus: Color.lerp(actionFocus, other.actionFocus, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSubtle: Color.lerp(lineSubtle, other.lineSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      previewBlack: Color.lerp(previewBlack, other.previewBlack, t)!,
    );
  }
}

abstract final class WorkbenchSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
}

abstract final class WorkbenchRadius {
  static const double indicator = 0;
  static const double control = 0;
  static const double panel = 0;
}

abstract final class WorkbenchMetric {
  static const double sidebarWidth = 236;
  static const double contentMaxWidth = 920;
  static const double technicianControlHeight = 36;
  static const double technicianHitTarget = 48;
  static const double technicianRowMinHeight = 44;
  static const double operatorControlHeight = 56;
  static const double operatorRowMinHeight = 56;
}

extension WorkbenchThemeAccess on BuildContext {
  WorkbenchColors get workbenchColors =>
      Theme.of(this).extension<WorkbenchColors>()!;
}
