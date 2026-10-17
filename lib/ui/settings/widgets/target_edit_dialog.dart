import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/dls_tokens.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../common/virtual_keyboard.dart';
import 'file_picker.dart';

class TargetEditDialog extends StatefulWidget {
  const TargetEditDialog({
    super.key,
    required this.part,
    required this.modelLabels,
    required this.onSave,
    this.onDelete,
    this.allowClassMapping = true,
  });

  final PartType part;
  final List<String> modelLabels;
  final ValueChanged<PartType> onSave;
  final VoidCallback? onDelete;
  final bool allowClassMapping;

  @override
  State<TargetEditDialog> createState() => _TargetEditDialogState();
}

class _TargetEditDialogState extends State<TargetEditDialog> {
  late TextEditingController _nameController;
  late String imagePath;
  late List<String> keywords;
  late bool enabled;
  final Map<String, TextEditingController> _classNameControllers = {};
  final TextEditingController _classSearchController = TextEditingController();
  bool _choosingClasses = false;
  List<String> _chooserLabels = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.part.name);
    imagePath = widget.part.image;
    keywords = List<String>.from(widget.part.keywords);
    enabled = widget.part.enabled;
    for (final label in {
      ...widget.modelLabels,
      ...widget.part.keywords,
      ...widget.part.classNames.keys,
    }) {
      _classNameControllers[label] = TextEditingController(
        text: widget.part.classNames[label] ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classSearchController.dispose();
    for (final controller in _classNameControllers.values) {
      controller.dispose();
    }
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
        classNames: {
          for (final entry in _classNameControllers.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        },
      ),
    );
    Navigator.of(context).pop();
  }

  void _showFullscreenKeyboard(
    BuildContext context, {
    TextEditingController? controller,
    required String label,
  }) {
    final target = controller ?? _nameController;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BeenutFullscreenKeyboard(
          initialText: target.text,
          label: label,
          onSave: (newText) {
            setState(() {
              target.text = newText;
            });
          },
        );
      },
    );
  }

  void _openClassChooser() {
    FocusScope.of(context).unfocus();
    _classSearchController.clear();
    setState(() {
      _chooserLabels = {...keywords, ...widget.modelLabels}.toList();
      _choosingClasses = true;
    });
  }

  void _closeClassChooser() {
    FocusScope.of(context).unfocus();
    setState(() => _choosingClasses = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: !_choosingClasses,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _choosingClasses) _closeClassChooser();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          key: const ValueKey('target-edit-form'),
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: (media.size.height - media.viewInsets.bottom - 32).clamp(
              160.0,
              640.0,
            ),
          ),
          child: Column(
            mainAxisSize: _choosingClasses
                ? MainAxisSize.max
                : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _choosingClasses ? 4 : 16,
                  8,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    if (_choosingClasses)
                      IconButton(
                        tooltip: I18n.t(context, 'back_to_target'),
                        onPressed: _closeClassChooser,
                        icon: const Icon(Icons.arrow_back, size: 20),
                        style: _iconStyle,
                      ),
                    Expanded(
                      child: Text(
                        I18n.t(
                          context,
                          _choosingClasses
                              ? 'choose_classes'
                              : 'edit_target_title',
                        ),
                        style: TextStyle(
                          color: colors.inkPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_choosingClasses)
                Expanded(child: _classChooser())
              else
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('target-details-scroll'),
                    padding: const EdgeInsets.all(16),
                    child: _details(),
                  ),
                ),
              Divider(height: 1, color: colors.borderSubtle),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _iconStyle => IconButton.styleFrom(
    minimumSize: const Size.square(48),
    backgroundColor: Colors.transparent,
  );

  Widget _keyboardButton(TextEditingController controller, String label) =>
      IconButton(
        tooltip: I18n.t(context, 'open_virtual_keyboard'),
        onPressed: () => _showFullscreenKeyboard(
          context,
          controller: controller,
          label: label,
        ),
        icon: const Icon(Icons.keyboard_outlined, size: 20),
        style: _iconStyle,
      );

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    border: const UnderlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    suffixIcon: suffix,
  );

  Widget _details() {
    final colors = context.dlsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('target-name'),
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 16),
          decoration: _fieldDecoration(
            label: I18n.t(context, 'target_name'),
            suffix: _keyboardButton(
              _nameController,
              I18n.t(context, 'target_name'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(width: 40, height: 40, child: _imagePreview()),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(72, 48),
                ),
                onPressed: _openImagePicker,
                icon: const Icon(Icons.image_outlined, size: 20),
                label: Text(I18n.t(context, 'choose_target_image')),
              ),
            ),
            if (imagePath.isNotEmpty)
              IconButton(
                tooltip: I18n.t(context, 'remove_target_image'),
                onPressed: () => setState(() => imagePath = ''),
                icon: const Icon(Icons.close, size: 20),
                style: _iconStyle,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                I18n.t(context, 'counted_objects'),
                style: TextStyle(
                  color: colors.inkPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.allowClassMapping)
              OutlinedButton.icon(
                key: const ValueKey('add-class'),
                onPressed: widget.modelLabels.isEmpty
                    ? null
                    : _openClassChooser,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(72, 48),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(I18n.t(context, 'add_class')),
              ),
          ],
        ),
        if (keywords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              I18n.t(
                context,
                widget.modelLabels.isEmpty
                    ? 'no_classes_in_model'
                    : 'select_classes_prompt',
              ),
              style: TextStyle(color: colors.inkSecondary, fontSize: 14),
            ),
          )
        else ...[
          Text(
            I18n.t(context, 'operator_names_hint'),
            style: TextStyle(color: colors.inkSecondary, fontSize: 13),
          ),
          for (final label in keywords)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('class-name-$label'),
                      controller: _classNameControllers[label],
                      style: const TextStyle(fontSize: 15),
                      decoration: _fieldDecoration(
                        label: widget.allowClassMapping
                            ? label
                            : I18n.t(
                                context,
                                'settings_item_name',
                                args: {
                                  'index': '${keywords.indexOf(label) + 1}',
                                },
                              ),
                        hint: I18n.t(context, 'operator_class_name'),
                        suffix: _keyboardButton(
                          _classNameControllers[label]!,
                          widget.allowClassMapping
                              ? '${I18n.t(context, 'operator_class_name')} · $label'
                              : I18n.t(context, 'operator_class_name'),
                        ),
                      ),
                    ),
                  ),
                  if (widget.allowClassMapping) const SizedBox(width: 4),
                  if (widget.allowClassMapping)
                    IconButton(
                      key: ValueKey('remove-class-$label'),
                      tooltip: I18n.t(context, 'remove_class'),
                      onPressed: () => _toggleKeyword(label),
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: colors.inkSecondary,
                      ),
                      style: _iconStyle,
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            I18n.t(context, 'target_enabled'),
            style: const TextStyle(fontSize: 15),
          ),
          value: enabled,
          onChanged: (value) => setState(() => enabled = value),
        ),
      ],
    );
  }

  Widget _classChooser() {
    final colors = context.dlsColors;
    final query = _classSearchController.text.trim().toLowerCase();
    final filtered = _chooserLabels
        .where(
          (label) =>
              label.toLowerCase().contains(query) ||
              (_classNameControllers[label]?.text ?? '').toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('class-search'),
            controller: _classSearchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15),
            decoration: _fieldDecoration(
              hint: I18n.t(context, 'search_classes'),
              suffix: _keyboardButton(
                _classSearchController,
                I18n.t(context, 'search_classes'),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            I18n.t(
              context,
              'selected_classes_count',
              args: {'count': '${keywords.length}'},
            ),
            style: TextStyle(color: colors.inkSecondary, fontSize: 13),
          ),
        ),
        Divider(height: 1, color: colors.borderSubtle),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    I18n.t(context, 'no_matching_classes'),
                    style: TextStyle(color: colors.inkSecondary),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('class-chooser-list'),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final label = filtered[index];
                    final alias =
                        _classNameControllers[label]?.text.trim() ?? '';
                    return CheckboxListTile(
                      key: ValueKey('choose-class-$label'),
                      value: keywords.contains(label),
                      onChanged: (_) => _toggleKeyword(label),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      title: Text(
                        alias.isEmpty ? label : alias,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: alias.isEmpty
                          ? null
                          : Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.inkSecondary,
                              ),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _footer() {
    final colors = context.dlsColors;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          if (!_choosingClasses && widget.onDelete != null)
            IconButton(
              tooltip: I18n.t(context, 'delete_this_target'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete!();
              },
              icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
              style: _iconStyle,
            ),
          const Spacer(),
          if (!_choosingClasses) ...[
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(72, 48)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18n.t(context, 'cancel')),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton(
            key: ValueKey(_choosingClasses ? 'classes-done' : 'target-save'),
            style: FilledButton.styleFrom(minimumSize: const Size(80, 48)),
            onPressed: _choosingClasses
                ? _closeClassChooser
                : (_nameController.text.trim().isEmpty ? null : _save),
            child: Text(
              I18n.t(context, _choosingClasses ? 'done_selecting' : 'save_btn'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    Widget fallback() => Icon(
      Icons.hexagon_outlined,
      color: context.dlsColors.inkSecondary,
      size: 30,
    );
    if (imagePath.isEmpty) return fallback();
    return imagePath.startsWith('assets/')
        ? Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback(),
          )
        : Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback(),
          );
  }
}
