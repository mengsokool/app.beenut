import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';

class PartSelector extends StatefulWidget {
  const PartSelector({
    super.key,
    required this.parts,
    required this.selectedId,
    required this.onSelected,
    this.onMenuStateChanged,
  });

  final List<PartType> parts;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<bool>? onMenuStateChanged;

  @override
  State<PartSelector> createState() => _PartSelectorState();
}

class _PartSelectorState extends State<PartSelector> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final selectedPart = widget.parts.firstWhere(
      (part) => part.id == widget.selectedId,
      orElse: () => widget.parts.isNotEmpty
          ? widget.parts.first
          : PartType(
              id: '',
              name: I18n.t(context, 'select_target'),
              image: '',
              keywords: const [],
              enabled: false,
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menuController,
          onOpen: () => widget.onMenuStateChanged?.call(true),
          onClose: () => widget.onMenuStateChanged?.call(false),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(tokens.raised),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(3),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BeenutTheme.radiusPanel,
                side: BorderSide(color: tokens.line),
              ),
            ),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, double.infinity),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: WorkbenchSpace.x1),
            ),
          ),
          menuChildren: [
            for (final part in widget.parts)
              MenuItemButton(
                onPressed: () {
                  widget.onSelected(part.id);
                  _menuController.close();
                },
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(constraints.maxWidth, 52),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: WorkbenchSpace.x3),
                  ),
                  alignment: Alignment.centerLeft,
                  shape: const WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BeenutTheme.radiusSharp,
                    ),
                  ),
                ),
                leadingIcon: _PartImage(part: part, size: 34),
                child: Text(
                  part.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: Tooltip(
            message: I18n.t(context, 'select_target'),
            child: Semantics(
              button: true,
              label:
                  '${I18n.t(context, 'selected_target_label')}: ${selectedPart.name}',
              child: Material(
                color: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BeenutTheme.radiusPanel,
                  side: BorderSide(color: tokens.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.parts.isEmpty
                      ? null
                      : () {
                          if (_menuController.isOpen) {
                            _menuController.close();
                          } else {
                            _menuController.open();
                          }
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: WorkbenchSpace.x3,
                        vertical: WorkbenchSpace.x2,
                      ),
                      child: Row(
                        children: [
                          _PartImage(part: selectedPart, size: 40),
                          const SizedBox(width: WorkbenchSpace.x3),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  I18n.t(context, 'selected_target_label'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: WorkbenchSpace.x1),
                                Text(
                                  selectedPart.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: tokens.ink),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: WorkbenchSpace.x2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: widget.parts.isEmpty
                                ? tokens.disabled
                                : tokens.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PartImage extends StatelessWidget {
  const _PartImage({required this.part, required this.size});

  final PartType part;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    Widget fallback() =>
        Icon(Icons.hexagon_outlined, size: size * 0.5, color: tokens.muted);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BeenutTheme.radiusSharp,
        border: Border.all(color: tokens.lineSubtle),
      ),
      child: part.image.isEmpty
          ? fallback()
          : part.image.startsWith('assets/')
          ? Image.asset(
              part.image,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback(),
            )
          : Image.file(
              File(part.image),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }
}
