import 'package:flutter/material.dart';
import '../../core/dls_tokens.dart';

/// Interactive touch feedback wrapper that scales child to 0.97 on press.
class KioskTouchScale extends StatefulWidget {
  const KioskTouchScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;

  @override
  State<KioskTouchScale> createState() => _KioskTouchScaleState();
}

class _KioskTouchScaleState extends State<KioskTouchScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value && widget.enabled && widget.onTap != null) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationToken = context.dlsAnimations;
    final desktop = Theme.of(context).platform == TargetPlatform.macOS;
    final scale =
        (!desktop && _isPressed && widget.enabled && widget.onTap != null)
        ? widget.pressedScale
        : 1.0;

    return MouseRegion(
      cursor: widget.onTap != null && widget.enabled
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.onTap?.call();
        },
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: animationToken.fastFeedback,
          curve: desktop ? Curves.easeOutCubic : animationToken.organicSpring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Button variant type.
enum KioskButtonVariant { primary, secondary, outlined, text, danger }

/// Touchscreen-optimized button with 0.97 organic spring tap scale,
/// minimum 48dp touch target enforcement, and high contrast overrides.
class KioskButton extends StatelessWidget {
  const KioskButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = KioskButtonVariant.primary,
    this.height = 48.0,
    this.width,
    this.fullWidth = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KioskButtonVariant variant;
  final double height;
  final double? width;
  final bool fullWidth;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final typography = DlsTypography.bodyKiosk();
    final effectiveHeight = height < 48.0 ? 48.0 : height;
    final isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    BorderSide border;

    switch (variant) {
      case KioskButtonVariant.primary:
        bg = isEnabled ? colors.accent : colors.surfaceSubtle;
        fg = isEnabled ? colors.onAccent : colors.inkDisabled;
        border = BorderSide.none;
        break;
      case KioskButtonVariant.secondary:
        bg = isEnabled ? colors.surfaceRaised : colors.surfaceSubtle;
        fg = isEnabled ? colors.inkPrimary : colors.inkDisabled;
        border = BorderSide(color: colors.borderSubtle);
        break;
      case KioskButtonVariant.outlined:
        bg = isEnabled ? colors.surface : colors.surfaceSubtle;
        fg = isEnabled ? colors.inkPrimary : colors.inkDisabled;
        border = BorderSide(
          color: isEnabled ? colors.border : colors.borderSubtle,
          width: 1.5,
        );
        break;
      case KioskButtonVariant.text:
        bg = Colors.transparent;
        fg = isEnabled ? colors.accent : colors.inkDisabled;
        border = BorderSide.none;
        break;
      case KioskButtonVariant.danger:
        bg = isEnabled ? colors.danger : colors.dangerSoft;
        fg = isEnabled ? colors.surface : colors.inkDisabled;
        border = BorderSide.none;
        break;
    }

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            SizedBox(width: spacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              style: typography.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final boxDecoration = BoxDecoration(
      color: bg,
      borderRadius: radii.borderSm(),
      border: border == BorderSide.none ? null : Border.fromBorderSide(border),
      boxShadow: (isEnabled && variant == KioskButtonVariant.primary)
          ? context.dlsShadows.low
          : null,
    );

    Widget container = Container(
      height: effectiveHeight,
      width: fullWidth ? double.infinity : width,
      constraints: BoxConstraints(minWidth: effectiveHeight),
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      alignment: Alignment.center,
      decoration: boxDecoration,
      child: content,
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: KioskTouchScale(
        enabled: isEnabled,
        onTap: onPressed,
        child: container,
      ),
    );
  }
}

/// Touchscreen Switch component with min 48dp touch height.
class KioskSwitch extends StatelessWidget {
  const KioskSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final isEnabled = enabled && onChanged != null;

    final switchWidget = Switch(
      value: value,
      onChanged: isEnabled ? onChanged : null,
      activeThumbColor: colors.onAccent,
      activeTrackColor: colors.accent,
      inactiveThumbColor: colors.inkSecondary,
      inactiveTrackColor: colors.surfaceRaised,
      trackOutlineColor: WidgetStatePropertyAll(
        value ? Colors.transparent : colors.border,
      ),
    );

    if (label == null) {
      return SizedBox(height: 48.0, child: switchWidget);
    }

    return KioskTouchScale(
      enabled: isEnabled,
      onTap: isEnabled ? () => onChanged!(!value) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48.0),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radii.borderSm(),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label!,
                    style: DlsTypography.bodyKiosk(
                      color: isEnabled ? colors.inkPrimary : colors.inkDisabled,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: DlsTypography.captionKiosk(
                        color: isEnabled
                            ? colors.inkSecondary
                            : colors.inkDisabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: spacing.md),
            IgnorePointer(child: switchWidget),
          ],
        ),
      ),
    );
  }
}

/// Touchscreen Slider component with min 48dp touch target height.
class KioskSlider extends StatelessWidget {
  const KioskSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.valueLabel,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String? valueLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;
    final isEnabled = enabled && onChanged != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 48.0),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || valueLabel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: DlsTypography.bodyKiosk(
                      color: isEnabled ? colors.inkPrimary : colors.inkDisabled,
                    ),
                  ),
                if (valueLabel != null)
                  Text(
                    valueLabel!,
                    style: DlsTypography.captionKiosk(
                      color: isEnabled ? colors.accent : colors.inkDisabled,
                    ),
                  ),
              ],
            ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isEnabled ? colors.accent : colors.inkDisabled,
              inactiveTrackColor: colors.surfaceRaised,
              thumbColor: isEnabled ? colors.accent : colors.inkDisabled,
              overlayColor: colors.accentSoft,
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: isEnabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Touchscreen Text Field component with min 48dp hit area, rounded border,
/// and high contrast overrides.
class KioskTextField extends StatelessWidget {
  const KioskTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.trailingAction,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailingAction;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final desktop = Theme.of(context).platform == TargetPlatform.macOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: DlsTypography.captionKiosk(
              color: enabled ? colors.inkSecondary : colors.inkDisabled,
            ),
          ),
          SizedBox(height: spacing.xs),
        ],
        Container(
          constraints: const BoxConstraints(minHeight: 48.0),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: radii.borderSm(),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  readOnly: readOnly,
                  enabled: enabled,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: DlsTypography.bodyStandard(
                    color: enabled ? colors.inkPrimary : colors.inkDisabled,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: DlsTypography.bodyStandard(
                      color: colors.inkSecondary,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: desktop ? spacing.sm : spacing.md,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (trailingAction != null) ...[
                Padding(
                  padding: EdgeInsets.only(right: spacing.xs),
                  child: trailingAction!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft organic card container with standard radii and shadows.
class KioskCard extends StatelessWidget {
  const KioskCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final shadows = context.dlsShadows;

    final cardChild = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: borderRadius ?? radii.borderMd(),
        border: Border.all(color: borderColor ?? colors.borderSubtle),
        boxShadow: onTap == null ? shadows.softSm : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return KioskTouchScale(onTap: onTap, child: cardChild);
    }

    return cardChild;
  }
}

/// Touchscreen Modal Dialog Shell component.
class KioskDialog extends StatelessWidget {
  const KioskDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.onClose,
    this.width = 460,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final VoidCallback? onClose;
  final double width;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
    IconData? icon,
    VoidCallback? onClose,
    double width = 460,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => KioskDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
        onClose: onClose ?? () => Navigator.of(context).pop(),
        width: width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final shadows = context.dlsShadows;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - spacing.hero * 2,
          ),
          margin: EdgeInsets.all(spacing.xl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: radii.borderLg(),
            border: Border.all(color: colors.border),
            boxShadow: shadows.softLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 24, color: colors.accent),
                      SizedBox(width: spacing.md),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: DlsTypography.titleSection(
                          color: colors.inkPrimary,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      SizedBox(
                        width: 48.0,
                        height: 48.0,
                        child: IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: colors.inkSecondary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceRaised,
                            shape: RoundedRectangleBorder(
                              borderRadius: radii.borderXs(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSubtle),

              // Body Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.xl),
                  child: content,
                ),
              ),
              Divider(height: 1, color: colors.borderSubtle),

              // Footer Actions
              Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
