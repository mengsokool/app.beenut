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
    action: Color(0xfff4a900),
    actionHover: Color(0xffd98900),
    actionActive: Color(0xffc47a00),
    actionSoft: Color(0xfffff2cc),
    actionText: Color(0xff8a4b00),
    actionFocus: Color(0xffb76a00),
    onAction: Color(0xff171717),
    canvas: Color(0xfff3f4f6),
    surface: Color(0xffffffff),
    raised: Color(0xfff9fafb),
    ink: Color(0xff171717),
    muted: Color(0xff52525b),
    disabled: Color(0xffa1a1aa),
    line: Color(0xffd4d4d8),
    lineSubtle: Color(0xffe4e4e7),
    success: Color(0xff166534),
    successSoft: Color(0xffdcfce7),
    warning: Color(0xff9a3412),
    warningSoft: Color(0xffffedd5),
    danger: Color(0xffb91c1c),
    dangerSoft: Color(0xfffee2e2),
    info: Color(0xff1d4ed8),
    infoSoft: Color(0xffdbeafe),
    previewBlack: Color(0xff09090b),
  );

  static const dark = WorkbenchColors(
    action: Color(0xffffc23d),
    actionHover: Color(0xffffd36a),
    actionActive: Color(0xffe8a820),
    actionSoft: Color(0xff3a2a00),
    actionText: Color(0xffffd36a),
    actionFocus: Color(0xffffc23d),
    onAction: Color(0xff171717),
    canvas: Color(0xff0f0f0f),
    surface: Color(0xff18181b),
    raised: Color(0xff27272a),
    ink: Color(0xfffafafa),
    muted: Color(0xffa1a1aa),
    disabled: Color(0xff71717a),
    line: Color(0xff3f3f46),
    lineSubtle: Color(0xff303036),
    success: Color(0xff4ade80),
    successSoft: Color(0xff123d24),
    warning: Color(0xfffb923c),
    warningSoft: Color(0xff4a2412),
    danger: Color(0xfff87171),
    dangerSoft: Color(0xff4c1d1d),
    info: Color(0xff60a5fa),
    infoSoft: Color(0xff172f52),
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
  static const double indicator = 2;
  static const double control = 4;
  static const double panel = 6;
}

abstract final class WorkbenchMetric {
  static const double sidebarWidth = 236;
  static const double contentMaxWidth = 920;
  static const double technicianControlHeight = 36;
  static const double technicianHitTarget = 40;
  static const double technicianRowMinHeight = 44;
  static const double operatorControlHeight = 48;
  static const double operatorRowMinHeight = 56;
}

extension WorkbenchThemeAccess on BuildContext {
  WorkbenchColors get workbenchColors =>
      Theme.of(this).extension<WorkbenchColors>()!;
}
