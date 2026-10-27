import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/i18n.dart';
import 'number_editor.dart';

/// Direct entry for the machine workspace; a touch keypad is an explicit action.
class InlineNumberControl extends StatefulWidget {
  const InlineNumberControl({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.enabled,
    required this.onChanged,
    this.decimal = false,
    this.unit = '',
  });
  final String label, unit;
  final num value, min, max, step;
  final bool enabled, decimal;
  final ValueChanged<num> onChanged;
  @override
  State<InlineNumberControl> createState() => _InlineNumberControlState();
}

class _InlineNumberControlState extends State<InlineNumberControl> {
  late final TextEditingController controller;
  num? get parsed => widget.decimal
      ? double.tryParse(controller.text)
      : int.tryParse(controller.text);
  bool get valid =>
      parsed != null &&
      parsed!.isFinite &&
      parsed! >= widget.min &&
      parsed! <= widget.max;
  String format(num value) =>
      widget.decimal ? value.toStringAsFixed(2) : '${value.toInt()}';
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: format(widget.value));
  }

  @override
  void didUpdateWidget(InlineNumberControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && parsed != widget.value) {
      controller.text = format(widget.value);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void commit(num value) {
    final bounded = value.clamp(widget.min, widget.max);
    final rounded = widget.decimal
        ? double.parse(bounded.toStringAsFixed(2))
        : bounded.toInt();
    controller.text = format(rounded);
    widget.onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 288,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: widget.enabled
              ? () => commit((valid ? parsed! : widget.value) - widget.step)
              : null,
          tooltip: I18n.t(context, 'settings_decrease'),
          icon: const Icon(Icons.remove, size: 18),
          style: IconButton.styleFrom(minimumSize: const Size.square(48)),
        ),
        Expanded(
          child: Semantics(
            label: widget.label,
            child: TextFormField(
              key: ValueKey('setting-number-${widget.label}'),
              controller: controller,
              enabled: widget.enabled,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimal,
                signed: widget.min < 0,
              ),
              textInputAction: TextInputAction.next,
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
                fontFamily: BeenutTheme.fontFamily,
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                suffixText: widget.unit.isEmpty ? null : widget.unit,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (_) => valid ? null : '${widget.min}–${widget.max}',
              onChanged: (_) {
                if (valid) widget.onChanged(parsed!);
              },
              onFieldSubmitted: (_) {
                if (valid) FocusScope.of(context).nextFocus();
              },
            ),
          ),
        ),
        IconButton(
          onPressed: widget.enabled
              ? () => commit((valid ? parsed! : widget.value) + widget.step)
              : null,
          tooltip: I18n.t(context, 'settings_increase'),
          icon: const Icon(Icons.add, size: 18),
          style: IconButton.styleFrom(minimumSize: const Size.square(48)),
        ),
        IconButton(
          key: ValueKey('setting-keypad-${widget.label}'),
          tooltip: I18n.t(context, 'settings_keypad'),
          icon: const Icon(Icons.keyboard_outlined, size: 18),
          style: IconButton.styleFrom(minimumSize: const Size.square(48)),
          onPressed: widget.enabled
              ? () async {
                  final value = await editSettingNumber(
                    context,
                    label: widget.label,
                    value: valid ? parsed! : widget.value,
                    min: widget.min,
                    max: widget.max,
                    decimal: widget.decimal,
                    initialKeypad: true,
                  );
                  if (value != null && mounted) commit(value);
                }
              : null,
        ),
      ],
    ),
  );
}
