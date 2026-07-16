import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../../../core/workbench_tokens.dart';
import '../../common/setting_controls.dart';
import '../../common/virtual_keyboard.dart';
import 'file_picker.dart';

class TargetEditDialog extends StatefulWidget {
  const TargetEditDialog({
    super.key,
    required this.part,
    required this.modelLabels,
    required this.onSave,
    this.onDelete,
  });

  final PartType part;
  final List<String> modelLabels;
  final ValueChanged<PartType> onSave;
  final VoidCallback? onDelete;

  @override
  State<TargetEditDialog> createState() => _TargetEditDialogState();
}

class _TargetEditDialogState extends State<TargetEditDialog> {
  late TextEditingController _nameController;
  late String imagePath;
  late List<String> keywords;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.part.name);
    imagePath = widget.part.image;
    keywords = List<String>.from(widget.part.keywords);
    enabled = widget.part.enabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openImagePicker() {
    showDialog(
      context: context,
      builder: (context) => FilePickerDialog(
        pickerKind: 'image',
        initialPath: imagePath,
        onSelect: (path) {
          setState(() => imagePath = path);
          Navigator.of(context).pop();
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _toggleKeyword(String label) {
    setState(() {
      if (keywords.contains(label)) {
        keywords.remove(label);
      } else {
        keywords.add(label);
      }
    });
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    widget.onSave(
      PartType(
        id: widget.part.id,
        name: _nameController.text.trim(),
        image: imagePath.trim(),
        keywords: keywords,
        enabled: enabled,
      ),
    );
    Navigator.of(context).pop();
  }

  void _showFullscreenKeyboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BeenutFullscreenKeyboard(
          initialText: _nameController.text,
          onSave: (newText) {
            setState(() {
              _nameController.text = newText;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.workbenchColors;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 64,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BeenutTheme.radiusPanel,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: tokens.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Target',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        backgroundColor: tokens.raised,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.lineSubtle),

              // Form content
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Target Name
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            readOnly: false,
                            showCursor: true,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              hintText: I18n.t(context, 'enter_target_name'),
                              filled: true,
                              fillColor: tokens.raised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                                borderSide: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                                borderSide: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                                borderSide: BorderSide(
                                  color: scheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: I18n.t(context, 'open_virtual_keyboard'),
                          child: IconButton(
                            icon: Icon(
                              Icons.keyboard_outlined,
                              size: 20,
                              color: scheme.onSurface,
                            ),
                            onPressed: () => _showFullscreenKeyboard(context),
                            style: IconButton.styleFrom(
                              backgroundColor: tokens.raised,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                              side: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Icon & Image Browse
                    Text(
                      'Icon & custom image',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() => imagePath = ''),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: imagePath.trim().isEmpty
                                ? tokens.actionSoft
                                : tokens.surface,
                            foregroundColor: imagePath.trim().isEmpty
                                ? tokens.actionText
                                : tokens.ink,
                            side: BorderSide(
                              color: imagePath.trim().isEmpty
                                  ? tokens.action
                                  : tokens.line,
                            ),
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.hexagon_outlined, size: 16),
                          label: Text(
                            'Default icon',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: imagePath.trim().isEmpty
                                  ? tokens.actionText
                                  : tokens.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _openImagePicker,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: imagePath.trim().isNotEmpty
                                ? tokens.actionSoft
                                : tokens.surface,
                            foregroundColor: imagePath.trim().isNotEmpty
                                ? tokens.actionText
                                : tokens.ink,
                            side: BorderSide(
                              color: imagePath.trim().isNotEmpty
                                  ? tokens.action
                                  : tokens.line,
                            ),
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(
                            'Custom image',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: imagePath.trim().isNotEmpty
                                  ? tokens.actionText
                                  : tokens.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imagePath.trim().isEmpty
                                ? 'Using default target icon'
                                : imagePath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _openImagePicker,
                          icon: const Icon(
                            Icons.folder_open_outlined,
                            size: 14,
                          ),
                          label: Text(I18n.t(context, 'browse')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: BeenutTheme.fontFamily,
                              fontFamilyFallback:
                                  BeenutTheme.fontFamilyFallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Map keywords
                    Text(
                      'Model classes to map',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.modelLabels.isEmpty)
                      Text(
                        I18n.t(context, 'no_classes_in_model'),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in widget.modelLabels)
                            FilterChip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: keywords.contains(label),
                              onSelected: (_) => _toggleKeyword(label),
                              showCheckmark: false,
                              selectedColor: tokens.actionSoft,
                              backgroundColor: tokens.raised,
                              side: BorderSide(
                                color: keywords.contains(label)
                                    ? tokens.action
                                    : tokens.line,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 22),

                    // Enabled status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enabled',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                        WorkbenchSwitch(
                          value: enabled,
                          onChanged: (val) => setState(() => enabled = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.lineSubtle),

              // Footer actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.onDelete != null) ...[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(I18n.t(context, 'delete_this_target')),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          textStyle: const TextStyle(
                            fontFamily: BeenutTheme.fontFamily,
                            fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      child: Text(
                        I18n.t(context, 'cancel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      child: Text(
                        I18n.t(context, 'save_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
