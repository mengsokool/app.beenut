import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../../../core/workbench_tokens.dart';
import '../../common/setting_controls.dart';
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
              style: TextStyle(fontWeight: FontWeight.w500),
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
              style: TextStyle(fontWeight: FontWeight.w500),
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
    final tokens = context.workbenchColors;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BeenutTheme.radiusPanel,
        side: BorderSide(color: tokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TargetListToolbar(
            countLabel: I18n.t(
              context,
              'targets_to_count',
              args: {'count': parts.length.toString()},
            ),
            addLabel: I18n.t(context, 'add_target'),
            onAdd: widget.enabled ? _addPartManually : null,
          ),
          Divider(height: 1, color: tokens.lineSubtle),
          if (parts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkbenchSpace.x4,
                vertical: WorkbenchSpace.x8,
              ),
              child: Text(
                I18n.t(context, 'no_targets_found'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.muted),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: parts.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = parts.removeAt(oldIndex);
                  parts.insert(newIndex, item);
                });
                _save();
              },
              itemBuilder: (context, index) {
                final part = parts[index];
                return Column(
                  key: ValueKey(part.id),
                  children: [
                    _TargetListRow(
                      part: part,
                      dragHandle: _TargetDragHandle(
                        index: index,
                        enabled: widget.enabled,
                      ),
                      onToggleEnabled: () => _togglePartEnabled(part),
                      onTap: () => _showEditDialog(context, part),
                    ),
                    if (index < parts.length - 1)
                      Divider(height: 1, indent: 40, color: tokens.lineSubtle),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TargetListToolbar extends StatelessWidget {
  const _TargetListToolbar({
    required this.countLabel,
    required this.addLabel,
    required this.onAdd,
  });

  final String countLabel;
  final String addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchSpace.x3,
        vertical: WorkbenchSpace.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: tokens.ink),
            ),
          ),
          const SizedBox(width: WorkbenchSpace.x3),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 15),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }
}

class _TargetDragHandle extends StatelessWidget {
  const _TargetDragHandle({required this.index, required this.enabled});

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final handle = SizedBox(
      width: 40,
      child: Icon(
        Icons.drag_indicator,
        size: 16,
        color: enabled ? tokens.muted : tokens.disabled,
      ),
    );
    if (!enabled) return handle;
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: handle),
    );
  }
}

class _TargetListRow extends StatelessWidget {
  const _TargetListRow({
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
    final tokens = context.workbenchColors;
    return Row(
      children: [
        dragHandle,
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: WorkbenchSpace.x2,
                ),
                child: Row(
                  children: [
                    Opacity(
                      opacity: part.enabled ? 1 : 0.45,
                      child: _TargetThumbnail(part: part),
                    ),
                    const SizedBox(width: WorkbenchSpace.x3),
                    Expanded(
                      child: Opacity(
                        opacity: part.enabled ? 1 : 0.55,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              part.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: WorkbenchSpace.x1),
                            Text(
                              part.keywords.isEmpty
                                  ? I18n.t(context, 'target_no_model_classes')
                                  : I18n.t(
                                      context,
                                      'target_model_classes',
                                      args: {
                                        'classes': part.keywords.join(', '),
                                      },
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: part.keywords.isEmpty
                                        ? tokens.warning
                                        : tokens.muted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: WorkbenchSpace.x3),
                    Icon(Icons.chevron_right, size: 16, color: tokens.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
          child: WorkbenchSwitch(
            value: part.enabled,
            onChanged: (_) => onToggleEnabled(),
          ),
        ),
      ],
    );
  }
}

class _TargetThumbnail extends StatelessWidget {
  const _TargetThumbnail({required this.part});

  final PartType part;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    Widget fallback() =>
        Icon(Icons.hexagon_outlined, size: 20, color: tokens.muted);

    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.lineSubtle),
        borderRadius: BeenutTheme.radiusSharp,
      ),
      child: part.image.isEmpty
          ? fallback()
          : part.image.startsWith('assets/')
          ? Image.asset(
              part.image,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback(),
            )
          : Image.file(
              File(part.image),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}
