import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
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
            backgroundColor: WidgetStatePropertyAll(
              scheme.surfaceContainerHigh,
            ),
            surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(2),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: 0.10),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BeenutTheme.radiusPanel,
                side: BorderSide(color: BeenutTheme.outlineVariant(context)),
              ),
            ),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, double.infinity),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
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
                    Size(constraints.maxWidth, 48),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12),
                  ),
                  alignment: Alignment.centerLeft,
                  shape: const WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                leadingIcon: Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: BeenutTheme.outlineVariant(context),
                    ),
                    borderRadius: BeenutTheme.radiusSharp,
                  ),
                  child: part.image.isEmpty
                      ? Icon(
                          Icons.hexagon_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        )
                      : Image.file(
                          File(part.image),
                          errorBuilder: (_, _, _) => Icon(
                            Icons.hexagon_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                child: Text(
                  part.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
          ],
          // M3 trigger: uses InkWell + Card-like surface for the selector trigger
          child: Tooltip(
            message: I18n.t(context, 'select_target'),
            child: InkWell(
              onTap: () {
                if (_menuController.isOpen) {
                  _menuController.close();
                } else {
                  _menuController.open();
                }
              },
              borderRadius: BeenutTheme.radiusPanel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  border: Border.all(
                    color: BeenutTheme.outlineVariant(context),
                  ),
                  borderRadius: BeenutTheme.radiusPanel,
                ),
                child: Row(
                  children: [
                    // Selected item image box
                    Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BeenutTheme.radiusSharp,
                      ),
                      child: selectedPart.image.isEmpty
                          ? Icon(
                              Icons.hexagon_outlined,
                              size: 20,
                              color: BeenutTheme.mutedColor(context),
                            )
                          : selectedPart.image.startsWith('assets/')
                          ? Image.asset(
                              selectedPart.image,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.hexagon_outlined,
                                size: 20,
                                color: BeenutTheme.mutedColor(context),
                              ),
                            )
                          : Image.file(
                              File(selectedPart.image),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.hexagon_outlined,
                                size: 20,
                                color: BeenutTheme.mutedColor(context),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    // Selected item label
                    Expanded(
                      child: Text(
                        selectedPart.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: BeenutTheme.inkColor(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: BeenutTheme.mutedColor(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
