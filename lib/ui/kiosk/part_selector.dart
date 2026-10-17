import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../components/part_selector_card.dart';

/// Refactored PartSelector leveraging PartSelectorCard and PartCatalogSelector components.
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
  void _openCatalog() {
    widget.onMenuStateChanged?.call(true);
    PartCatalogSelector.showDropdown(
      context: context,
      parts: widget.parts,
      selectedId: widget.selectedId,
      onSelectPart: (part) {
        widget.onSelected(part.id);
        widget.onMenuStateChanged?.call(false);
      },
    ).then((_) {
      widget.onMenuStateChanged?.call(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPart = widget.parts.firstWhere(
      (part) => part.id == widget.selectedId,
      orElse: () => widget.parts.isNotEmpty
          ? widget.parts.first
          : const PartType(
              id: '',
              name: 'Select Target',
              image: '',
              keywords: [],
              enabled: false,
            ),
    );

    return PartSelectorCard(
      selectedPart: selectedPart,
      availablePartsCount: widget.parts.length,
      onTapOpenCatalog: _openCatalog,
    );
  }
}
