import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/i18n.dart';

class BeenutFullscreenKeyboard extends StatefulWidget {
  const BeenutFullscreenKeyboard({
    super.key,
    required this.initialText,
    required this.onSave,
  });

  final String initialText;
  final ValueChanged<String> onSave;

  @override
  State<BeenutFullscreenKeyboard> createState() =>
      _BeenutFullscreenKeyboardState();
}

class _BeenutFullscreenKeyboardState extends State<BeenutFullscreenKeyboard> {
  late TextEditingController _textController;
  bool _isThai = false;
  bool _isShifted = false;

  static final List<List<String>> _enKeys = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static final List<List<String>> _enShiftedKeys = [
    ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static final List<List<String>> _thNormal = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['ๅ', 'ภ', 'ถ', 'ุ', 'ึ', 'ค', 'ต', 'จ', 'ข', 'ช'],
    ['ๆ', 'ไ', 'ำ', 'พ', 'ะ', 'ั', 'ี', 'ร', 'น', 'ย', 'บ', 'ล'],
    ['ฟ', 'ห', 'ก', 'ด', 'เ', '้', '่', 'า', 'ส', 'ว', 'ง'],
    ['ผ', 'ป', 'แ', 'อ', 'ิ', 'ื', 'ท', 'ม', 'ใ', 'ฝ'],
  ];

  static final List<List<String>> _thShifted = [
    ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
    ['+', '๑', '๒', '๓', '๔', 'ู', '฿', '๕', '๖', '๗'],
    ['๏', 'ณ', 'ฯ', 'ญ', 'ฐ', 'ฅ', 'ฤ', 'ฆ', 'ฏ', 'โ'],
    ['ฌ', '็', '๋', 'ษ', 'ศ', 'ซ', 'ฉ', 'ฮ', 'ธ', '์'],
    ['ฒ', 'ฬ', 'ฃ', 'ํ', '๊', '(', ')', '?', '"', '/'],
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onKeyPress(String char) {
    final text = _textController.text;
    final selection = _textController.selection;

    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final newText = text.replaceRange(start, end, char);
    setState(() {
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + char.length),
      );
    });
  }

  void _onBackspace() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (text.isEmpty) return;

    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    setState(() {
      if (start == end) {
        if (start == 0) return;
        final newText = text.replaceRange(start - 1, start, '');
        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - 1),
        );
      } else {
        final newText = text.replaceRange(start, end, '');
        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _isThai
        ? (_isShifted ? _thShifted : _thNormal)
        : (_isShifted ? _enShiftedKeys : _enKeys);

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;

    final double keyHeight = isSmallScreen ? 34.0 : 48.0;
    final double rowSpacing = isSmallScreen ? 3.0 : 6.0;
    final double previewPaddingVertical = isSmallScreen ? 6.0 : 12.0;
    final double previewFontSize = isSmallScreen ? 18.0 : 22.0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: isSmallScreen ? 6 : 12,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + (isSmallScreen ? 8 : 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isThai
                    ? I18n.t(context, 'edit_target_name_th')
                    : I18n.t(context, 'edit_target_name_en'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: BeenutTheme.inkColor(context),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: isSmallScreen ? 18 : 20,
                  color: BeenutTheme.mutedColor(context),
                ),
                onPressed: () => Navigator.of(context).pop(),
                constraints: BoxConstraints.tightFor(
                  width: isSmallScreen ? 28 : 32,
                  height: isSmallScreen ? 28 : 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: previewPaddingVertical,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.all(Radius.circular(4)),
              border: Border.all(color: scheme.outlineVariant, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _textController.text,
                          style: TextStyle(
                            fontSize: previewFontSize,
                            fontWeight: FontWeight.w400,
                            color: BeenutTheme.inkColor(context),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _BlinkingCursor(height: previewFontSize),
                      ],
                    ),
                  ),
                ),
                if (_textController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color: BeenutTheme.mutedColor(context),
                    ),
                    onPressed: () {
                      setState(() {
                        _textController.clear();
                      });
                    },
                    constraints: BoxConstraints.tightFor(
                      width: isSmallScreen ? 28 : 32,
                      height: isSmallScreen ? 28 : 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 12),
          for (int i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((_isThai && i == 4) || (!_isThai && i == 3)) ...[
                  Expanded(
                    flex: 15,
                    child: _buildSpecialKey(
                      'Shift',
                      isPressed: _isShifted,
                      height: keyHeight,
                      onTap: () {
                        setState(() {
                          _isShifted = !_isShifted;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                for (final key in rows[i])
                  Expanded(flex: 10, child: _buildKey(key, keyHeight)),
                if ((_isThai && i == 4) || (!_isThai && i == 3)) ...[
                  const SizedBox(width: 3),
                  Expanded(
                    flex: 15,
                    child: _buildSpecialKey(
                      I18n.t(context, 'delete_btn'),
                      icon: Icons.backspace_outlined,
                      height: keyHeight,
                      onTap: _onBackspace,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: rowSpacing),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSpecialKey(
                  _isThai ? 'EN' : 'TH',
                  height: keyHeight,
                  onTap: () {
                    setState(() {
                      _isThai = !_isThai;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 6,
                child: _buildSpecialKey(
                  'Space',
                  height: keyHeight,
                  onTap: () => _onKeyPress(' '),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _buildSpecialKey(
                  I18n.t(context, 'save_btn'),
                  color: scheme.primary,
                  textColor: scheme.onPrimary,
                  height: keyHeight,
                  onTap: () {
                    widget.onSave(_textController.text);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, double height) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: SizedBox(
        height: height,
        child: Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            onTap: () {
              _onKeyPress(label);
              if (_isShifted) {
                setState(() {
                  _isShifted = false;
                });
              }
            },
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: height < 40 ? 11 : 14,
                  fontWeight: FontWeight.w500,
                  color: BeenutTheme.inkColor(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
    String label, {
    IconData? icon,
    bool isPressed = false,
    Color? color,
    Color? textColor,
    required double height,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Material(
        color:
            color ??
            (isPressed
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHighest),
        borderRadius: BorderRadius.all(Radius.circular(4)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: height < 40 ? 14 : 16,
                    color:
                        textColor ??
                        (isPressed
                            ? scheme.onSecondaryContainer
                            : scheme.onSurface),
                  ),
                  if (label.isNotEmpty) const SizedBox(width: 4),
                ],
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: height < 40 ? 10 : 12,
                      fontWeight: FontWeight.w500,
                      color:
                          textColor ??
                          (isPressed
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({this.height = 22});

  final double height;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: widget.height,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
