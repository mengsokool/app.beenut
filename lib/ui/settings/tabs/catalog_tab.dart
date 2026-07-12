import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../widgets/target_edit_dialog.dart';

class PartCatalogEditor extends StatefulWidget {
  const PartCatalogEditor({
    super.key,
    required this.config,
    required this.modelLabels,
    required this.enabled,
    required this.onSave,
  });

  final MachineConfig config;
  final List<String> modelLabels;
  final bool enabled;
  final ValueChanged<MachineConfig> onSave;

  @override
  State<PartCatalogEditor> createState() => _PartCatalogEditorState();
}

class _PartCatalogEditorState extends State<PartCatalogEditor> {
  late List<PartType> parts;
  late String selectedId;

  @override
  void initState() {
    super.initState();
    _load(widget.config);
  }

  @override
  void didUpdateWidget(covariant PartCatalogEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _load(widget.config);
    }
  }

  void _load(MachineConfig config) {
    parts = List<PartType>.from(config.partTypes);
    selectedId = config.countingSettings.selectedPartType;
    if (!parts.any((part) => part.id == selectedId)) {
      selectedId = parts.firstOrNull?.id ?? '';
    }
  }

  void _addPartManually() {
    _showEditDialog(
      context,
      PartType(
        id: 'target_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        name: 'Target ${parts.length + 1}',
        image: '',
        keywords: const [],
        enabled: true,
      ),
      isAddMode: true,
    );
  }

  void _removePart(PartType part) {
    if (parts.length <= 1) {
      _showAlertDialog(
        context,
        title: I18n.t(context, 'cannot_delete_target'),
        description: I18n.t(context, 'at_least_one_target'),
        actionLabel: I18n.t(context, 'ok'),
      );
      return;
    }

    _showConfirmDialog(
      context,
      title: I18n.t(context, 'confirm_delete_target'),
      description: I18n.t(
        context,
        'confirm_delete_target_body',
        args: {'name': part.name},
      ),
      confirmLabel: I18n.t(context, 'delete_target'),
      isDestructive: true,
      onConfirm: () {
        setState(() {
          parts.removeWhere((p) => p.id == part.id);
          if (selectedId == part.id) {
            selectedId = parts.first.id;
          }
        });
        _save();
      },
    );
  }

  void _togglePartEnabled(PartType part) {
    final idx = parts.indexWhere((p) => p.id == part.id);
    if (idx == -1) return;
    setState(() {
      parts[idx] = part.copyWith(enabled: !part.enabled);
    });
    _save();
  }

  void _save() {
    widget.onSave(
      widget.config.copyWithPartCatalog(
        partTypes: parts,
        selectedPartType: selectedId,
      ),
    );
  }

  void _showAlertDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        content: Text(description, style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              actionLabel,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String confirmLabel,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        content: Text(description, style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              I18n.t(context, 'cancel'),
              style: TextStyle(color: BeenutTheme.mutedColor(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(
              confirmLabel,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    PartType part, {
    bool isAddMode = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TargetEditDialog(
        part: part,
        modelLabels: widget.modelLabels,
        onSave: (updated) {
          setState(() {
            if (isAddMode) {
              parts.add(updated);
            } else {
              final idx = parts.indexWhere((p) => p.id == part.id);
              if (idx != -1) parts[idx] = updated;
            }
          });
          _save();
        },
        onDelete: isAddMode ? null : () => _removePart(part),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Targets Header Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.t(
                  context,
                  'targets_to_count',
                  args: {'count': parts.length.toString()},
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              FilledButton.icon(
                onPressed: widget.enabled ? _addPartManually : null,
                icon: const Icon(Icons.add, size: 16),
                label: Text(I18n.t(context, 'add_target')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: BeenutTheme.fontFamily,
                    fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Targets Reorderable List
          if (parts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.all(Radius.circular(4)),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Text(
                I18n.t(context, 'no_targets_found'),
                style: TextStyle(
                  fontSize: 13,
                  color: BeenutTheme.mutedColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = parts.removeAt(oldIndex);
                  parts.insert(newIndex, item);
                });
                _save();
              },
              children: [
                for (var index = 0; index < parts.length; index++)
                  Padding(
                    key: ValueKey(parts[index].id),
                    padding: EdgeInsets.only(
                      bottom: index < parts.length - 1 ? 8.0 : 0.0,
                    ),
                    child: _TargetCardRow(
                      part: parts[index],
                      dragHandle: widget.enabled
                          ? ReorderableDragStartListener(
                              index: index,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              child: Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: scheme.outlineVariant,
                              ),
                            ),
                      onToggleEnabled: () => _togglePartEnabled(parts[index]),
                      onTap: () => _showEditDialog(context, parts[index]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TargetCardRow extends StatelessWidget {
  const _TargetCardRow({
    required this.part,
    required this.dragHandle,
    required this.onToggleEnabled,
    required this.onTap,
  });

  final PartType part;
  final Widget dragHandle;
  final VoidCallback onToggleEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: part.enabled ? 1.0 : 0.42,
        child: Row(
          children: [
            // Left: Reorder drag handle
            dragHandle,
            Container(width: 1, height: 46, color: scheme.outlineVariant),
            const SizedBox(width: 10),

            // Middle: Clickable Body (Image + Details)
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.all(Radius.circular(4)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Center-Left: Image Preview
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: part.image.isEmpty
                            ? Icon(
                                Icons.hexagon_outlined,
                                color: BeenutTheme.mutedColor(context),
                              )
                            : part.image.startsWith('assets/')
                            ? Image.asset(
                                part.image,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.hexagon_outlined,
                                      color: BeenutTheme.mutedColor(context),
                                    ),
                              )
                            : Image.file(
                                File(part.image),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.hexagon_outlined,
                                      color: BeenutTheme.mutedColor(context),
                                    ),
                              ),
                      ),
                      const SizedBox(width: 14),

                      // Center: Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  part.name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(4),
                                    ),
                                  ),
                                  child: Text(
                                    part.id,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (part.keywords.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final keyword in part.keywords)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.secondaryContainer,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(4),
                                        ),
                                      ),
                                      child: Text(
                                        keyword,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: scheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Right: Toggle Enabled Switch
            Switch(value: part.enabled, onChanged: (_) => onToggleEnabled()),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
