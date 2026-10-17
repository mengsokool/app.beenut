import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/workbench_tokens.dart';
import '../components/part_selector_card.dart';

ButtonStyle _kioskSecondaryButtonStyle(
  BuildContext context, {
  required Size minimumSize,
}) {
  final colors = context.workbenchColors;
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(minimumSize),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return colors.disabled;
      if (states.contains(WidgetState.pressed)) return const Color(0xff262626);
      if (states.contains(WidgetState.hovered)) return const Color(0xff6f6f6f);
      return const Color(0xff525252);
    }),
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    side: const WidgetStatePropertyAll(BorderSide.none),
  );
}

/// The operator surface keeps the camera and current result in view.
/// Status copy is reserved for states that need operator attention.
class TouchWorkbench extends StatelessWidget {
  const TouchWorkbench({
    super.key,
    required this.preview,
    required this.parts,
    required this.selectedId,
    required this.detections,
    required this.count,
    required this.completed,
    required this.paused,
    required this.counting,
    required this.needsAttention,
    required this.statusTitle,
    required this.statusDetail,
    required this.onSelectPart,
    required this.onOpenSettings,
    required this.onTogglePause,
  });

  final Widget preview;
  final List<PartType> parts;
  final String selectedId;
  final List<Detection> detections;
  final int count;
  final bool completed;
  final bool paused;
  final bool counting;
  final bool needsAttention;
  final String statusTitle;
  final String statusDetail;
  final ValueChanged<String> onSelectPart;
  final VoidCallback onOpenSettings;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final colors = context.workbenchColors;
    final selectedPart = parts
        .where((part) => part.id == selectedId)
        .firstOrNull;

    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget controls() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _targetPicker(context, selectedPart),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    key: const ValueKey('kiosk-count-panel'),
                    padding: const EdgeInsets.all(12),
                    child: needsAttention || paused
                        ? Center(child: _attention(context))
                        : _result(context, selectedPart),
                  ),
                ),
                const SizedBox(height: 8),
                _toolbar(context),
              ],
            );
            if (constraints.maxWidth < 700 &&
                constraints.maxHeight > constraints.maxWidth) {
              final size = math.min(
                constraints.maxWidth,
                constraints.maxHeight * .46,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    key: const ValueKey('kiosk-preview'),
                    height: size,
                    child: preview,
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: controls()),
                ],
              );
            }
            final previewWidth = math.min(
              constraints.maxHeight,
              constraints.maxWidth - 308,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('kiosk-preview'),
                  width: previewWidth,
                  height: previewWidth,
                  child: preview,
                ),
                const SizedBox(width: 8),
                Expanded(child: controls()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _targetPicker(BuildContext context, PartType? selectedPart) {
    final colors = context.workbenchColors;
    final name = selectedPart?.name.isNotEmpty == true
        ? selectedPart!.name
        : I18n.t(context, 'select_target');

    return Tooltip(
      message: I18n.t(context, 'select_target'),
      child: Builder(
        builder: (anchorContext) => Material(
          color: colors.surface,
          child: InkWell(
            onTap: parts.isEmpty
                ? null
                : () => PartCatalogSelector.showDropdown(
                    context: anchorContext,
                    parts: parts,
                    selectedId: selectedId,
                    onSelectPart: (part) => onSelectPart(part.id),
                  ),
            borderRadius: BorderRadius.zero,
            child: SizedBox(
              key: const ValueKey('kiosk-target-action'),
              height: 64,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.line)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (selectedPart != null &&
                        selectedPart.image.isNotEmpty) ...[
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: selectedPart.image.startsWith('assets/')
                            ? Image.asset(
                                selectedPart.image,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(selectedPart.image),
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, PartType? selectedPart) {
    final colors = context.workbenchColors;
    final compact = MediaQuery.sizeOf(context).height < 420;
    final keywords = selectedPart?.keywords ?? const <String>[];

    final rowHeight = compact ? 44.0 : 56.0;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (counting) ...[
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  I18n.t(context, 'counting'),
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      key: const ValueKey('touch-count-value'),
                      style: TextStyle(
                        color: colors.ink,
                        fontFamily: 'IBMPlexSans',
                        fontSize: compact ? 88 : 112,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      I18n.t(context, 'items_unit'),
                      style: TextStyle(color: colors.muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (keywords.length > 1)
            SizedBox(
              height: math.min(
                rowHeight * keywords.length,
                constraints.maxHeight * .52,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: keywords.length,
                itemExtent: rowHeight,
                itemBuilder: (_, index) => _classRow(
                  context,
                  selectedPart!,
                  keywords[index],
                  rowHeight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _classRow(
    BuildContext context,
    PartType part,
    String keyword,
    double height,
  ) {
    final colors = context.workbenchColors;
    final normalized = keyword.toLowerCase().trim();
    final classCount = detections.where((detection) {
      final label = detection.label.toLowerCase().trim();
      return label == normalized;
    }).length;

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.lineSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              part.displayNameForClass(keyword),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$classCount',
            key: ValueKey('class-count-$keyword'),
            style: TextStyle(
              color: colors.ink,
              fontFamily: 'IBMPlexSans',
              fontSize: 32,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            I18n.t(context, 'items_unit'),
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _attention(BuildContext context) {
    if (!needsAttention) return const SizedBox.shrink();
    final colors = context.workbenchColors;
    final isFault = needsAttention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isFault ? colors.danger : colors.muted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusTitle,
                key: const ValueKey('touch-attention-title'),
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (statusDetail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            statusDetail,
            style: TextStyle(color: colors.muted, fontSize: 14),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isFault ? onOpenSettings : onTogglePause,
          style: _kioskSecondaryButtonStyle(
            context,
            minimumSize: const Size(160, 56),
          ),
          icon: Icon(
            isFault ? Icons.settings_outlined : Icons.play_arrow_rounded,
            size: 20,
          ),
          label: Text(
            isFault
                ? I18n.t(context, 'settings_title')
                : I18n.t(context, 'resume_preview'),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('kiosk-settings-action'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(I18n.t(context, 'settings_title')),
              style: _kioskSecondaryButtonStyle(
                context,
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: paused
                ? FilledButton.icon(
                    key: const ValueKey('kiosk-pause-action'),
                    onPressed: onTogglePause,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(I18n.t(context, 'resume_preview')),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.workbenchColors.action,
                      minimumSize: const Size.fromHeight(56),
                    ),
                  )
                : FilledButton.icon(
                    key: const ValueKey('kiosk-pause-action'),
                    onPressed: onTogglePause,
                    icon: const Icon(Icons.pause_rounded, size: 20),
                    label: Text(I18n.t(context, 'pause_preview')),
                    style: _kioskSecondaryButtonStyle(
                      context,
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
