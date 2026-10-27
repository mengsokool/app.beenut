import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/i18n.dart';
import 'virtual_keyboard.dart';

class InlineTextControl extends StatefulWidget {
  const InlineTextControl({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label, value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<InlineTextControl> createState() => _InlineTextControlState();
}

class _InlineTextControlState extends State<InlineTextControl> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(InlineTextControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('setting-path-${widget.label}'),
    controller: controller,
    enabled: widget.enabled,
    maxLines: 3,
    minLines: 1,
    style: const TextStyle(fontFamily: BeenutTheme.fontFamily, fontSize: 14),
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      hintText: I18n.t(context, 'no_file_selected'),
      suffixIcon: IconButton(
        tooltip: I18n.t(context, 'open_virtual_keyboard'),
        icon: const Icon(Icons.keyboard_outlined, size: 20),
        onPressed: widget.enabled
            ? () {
                FocusScope.of(context).unfocus();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BeenutFullscreenKeyboard(
                    label: widget.label,
                    initialText: controller.text,
                    onSave: (value) {
                      controller.text = value;
                      widget.onChanged(value);
                    },
                  ),
                );
              }
            : null,
      ),
    ),
  );
}
