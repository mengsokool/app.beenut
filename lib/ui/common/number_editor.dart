import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/i18n.dart';
import '../../core/workbench_tokens.dart';
import 'settings_experience.dart';

Future<num?> editSettingNumber(
  BuildContext context, {
  required String label,
  required num value,
  required num min,
  required num max,
  bool decimal = false,
  bool? initialKeypad,
}) => showDialog<num>(
  context: context,
  builder: (_) => _NumberEditor(
    label: label,
    value: value,
    min: min,
    max: max,
    decimal: decimal,
    initialKeypad: initialKeypad ?? !SettingsExperience.isDeveloper(context),
  ),
);

class _NumberEditor extends StatefulWidget {
  const _NumberEditor({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.decimal,
    required this.initialKeypad,
  });
  final String label;
  final num value, min, max;
  final bool decimal;
  final bool initialKeypad;
  @override
  State<_NumberEditor> createState() => _NumberEditorState();
}

class _NumberEditorState extends State<_NumberEditor> {
  late final TextEditingController controller;
  bool keypad = false;

  @override
  void initState() {
    super.initState();
    keypad = widget.initialKeypad;
    controller = TextEditingController(text: '${widget.value}');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  num? get parsed => widget.decimal
      ? double.tryParse(controller.text)
      : int.tryParse(controller.text);
  bool get valid =>
      parsed != null &&
      parsed!.isFinite &&
      parsed! >= widget.min &&
      parsed! <= widget.max;

  void insert(String character) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    if (character == '⌫') {
      if (start == 0 && start == end) return;
      final from = start == end ? start - 1 : start;
      controller.value = TextEditingValue(
        text: text.replaceRange(from, end, ''),
        selection: TextSelection.collapsed(offset: from),
      );
    } else {
      final candidate = text.replaceRange(start, end, character);
      if (!RegExp(
        widget.decimal ? r'^-?\d*\.?\d*$' : r'^-?\d*$',
      ).hasMatch(candidate)) {
        return;
      }
      controller.value = TextEditingValue(
        text: candidate,
        selection: TextSelection.collapsed(offset: start + character.length),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.workbenchColors;
    final compactKeypad =
        keypad &&
        MediaQuery.sizeOf(context).height < 560 &&
        MediaQuery.sizeOf(context).width >= 600;
    final numberField = TextField(
      key: const ValueKey('settings-number-input'),
      controller: controller,
      autofocus: !keypad,
      readOnly: keypad,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.decimal,
        signed: widget.min < 0,
      ),
      inputFormatters: [
        TextInputFormatter.withFunction(
          (before, after) =>
              RegExp(
                widget.decimal ? r'^-?\d*\.?\d*$' : r'^-?\d*$',
              ).hasMatch(after.text)
              ? after
              : before,
        ),
      ],
      style: const TextStyle(
        fontFamily: 'IBMPlexSans',
        fontSize: 28,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        helperText: I18n.t(
          context,
          'settings_number_hint',
          args: {'min': '${widget.min}', 'max': '${widget.max}'},
        ),
        errorText: valid
            ? null
            : I18n.t(
                context,
                'settings_number_hint',
                args: {'min': '${widget.min}', 'max': '${widget.max}'},
              ),
        suffixIcon: IconButton(
          key: const ValueKey('settings-number-keyboard'),
          tooltip: I18n.t(context, 'settings_keypad'),
          icon: const Icon(Icons.keyboard_outlined),
          onPressed: () => setState(() {
            keypad = !keypad;
            if (keypad) FocusScope.of(context).unfocus();
          }),
        ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (valid) Navigator.pop(context, parsed);
      },
    );
    final keypadGrid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in [
          ['7', '8', '9'],
          ['4', '5', '6'],
          ['1', '2', '3'],
          [widget.decimal ? '.' : (widget.min < 0 ? '-' : ''), '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (final character in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: OutlinedButton(
                        onPressed: character.isEmpty
                            ? null
                            : () => insert(character),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: colors.raised,
                        ),
                        child: Text(
                          character,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexSans',
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      title: Text(widget.label),
      content: SizedBox(
        width: compactKeypad ? 520 : 320,
        child: SingleChildScrollView(
          child: compactKeypad
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: numberField),
                    const SizedBox(width: 16),
                    Expanded(child: keypadGrid),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    numberField,
                    if (keypad) ...[const SizedBox(height: 16), keypadGrid],
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(I18n.t(context, 'cancel')),
        ),
        FilledButton(
          key: const ValueKey('settings-number-done'),
          onPressed: valid ? () => Navigator.pop(context, parsed) : null,
          child: Text(I18n.t(context, 'done_selecting')),
        ),
      ],
    );
  }
}
