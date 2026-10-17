import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'virtual_keyboard.dart';

Future<String?> editSettingText(
  BuildContext context, {
  required String label,
  required String value,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextEditor(label: label, value: value),
);

class _TextEditor extends StatefulWidget {
  const _TextEditor({required this.label, required this.value});
  final String label, value;
  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            tooltip: I18n.t(context, 'open_virtual_keyboard'),
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: () {
              FocusScope.of(context).unfocus();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => BeenutFullscreenKeyboard(
                  initialText: controller.text,
                  label: widget.label,
                  onSave: (value) => setState(() => controller.text = value),
                ),
              );
            },
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(I18n.t(context, 'cancel')),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: Text(I18n.t(context, 'done_selecting')),
      ),
    ],
  );
}
