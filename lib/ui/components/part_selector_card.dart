import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/dls_tokens.dart';
import '../../core/models.dart';
import '../../core/i18n.dart';
import 'kiosk_form_controls.dart';

/// Touchscreen Part Selector Card displaying active part with touch scale feedback.
class PartSelectorCard extends StatelessWidget {
  const PartSelectorCard({
    super.key,
    required this.selectedPart,
    required this.availablePartsCount,
    required this.onTapOpenCatalog,
    this.height = 56.0,
  });

  final PartType? selectedPart;
  final int availablePartsCount;
  final VoidCallback onTapOpenCatalog;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final spacing = context.dlsSpacing;

    final partName = selectedPart?.name.isNotEmpty == true
        ? selectedPart!.name
        : 'Select Part Target';

    return Tooltip(
      message: 'Select target',
      child: KioskCard(
        onTap: availablePartsCount > 0 ? onTapOpenCatalog : null,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xs,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSubtitle = constraints.maxHeight >= 36;
            return Row(
              children: [
                // Thumbnail container
                _buildThumbnail(context, selectedPart),
                SizedBox(width: spacing.md),

                // Target Name & Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        partName,
                        style: DlsTypography.bodyStandard(
                          color: colors.inkPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSubtitle) ...[
                        const SizedBox(height: 1),
                        Text(
                          selectedPart != null &&
                                  selectedPart!.keywords.isNotEmpty
                              ? '${selectedPart!.keywords.length} classes mapped'
                              : '$availablePartsCount parts available',
                          style: DlsTypography.captionSmall(
                            color: colors.inkSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Dropdown Chevron Indicator
                Padding(
                  padding: EdgeInsets.only(left: spacing.xs),
                  child: Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: availablePartsCount > 0
                        ? colors.inkSecondary
                        : colors.inkDisabled,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, PartType? part) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    const double size = 32.0;

    Widget fallback() =>
        Icon(Icons.hexagon_outlined, size: 18, color: colors.inkSecondary);

    Widget imageWidget = fallback();
    if (part != null && part.image.isNotEmpty) {
      if (part.image.startsWith('assets/')) {
        imageWidget = Image.asset(
          part.image,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback(),
        );
      } else {
        imageWidget = Image.file(
          File(part.image),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback(),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(spacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: radii.borderSm(),
      ),
      child: imageWidget,
    );
  }
}

/// Interactive Part Catalog Selector Sheet / Dialog.
class PartCatalogSelector extends StatefulWidget {
  const PartCatalogSelector({
    super.key,
    required this.parts,
    required this.selectedId,
    required this.onSelectPart,
    this.onClose,
  });

  final List<PartType> parts;
  final String selectedId;
  final ValueChanged<PartType> onSelectPart;
  final VoidCallback? onClose;

  static Future<void> showDropdown({
    required BuildContext context,
    required List<PartType> parts,
    required String selectedId,
    required ValueChanged<PartType> onSelectPart,
  }) async {
    final anchor = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final colors = context.dlsColors;
    final width = anchor.size.width.clamp(160.0, overlay.size.width - 32);
    final selected = await showMenu<PartType>(
      context: context,
      positionBuilder: (_, _) {
        final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
        return RelativeRect.fromRect(
          Rect.fromLTWH(
            origin.dx,
            origin.dy + anchor.size.height + 4,
            anchor.size.width,
            0,
          ),
          Offset.zero & overlay.size,
        );
      },
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: colors.border),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      items: [
        for (final part in parts.where((part) => part.enabled))
          PopupMenuItem<PartType>(
            value: part,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Semantics(
              selected: part.id == selectedId,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      part.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.inkPrimary,
                        fontSize: 16,
                        fontWeight: part.id == selectedId
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    child: part.id == selectedId
                        ? Icon(Icons.check, size: 22, color: colors.accent)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (selected != null) onSelectPart(selected);
  }

  @override
  State<PartCatalogSelector> createState() => _PartCatalogSelectorState();
}

class _PartCatalogSelectorState extends State<PartCatalogSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final enabledParts = widget.parts.where((part) => part.enabled).toList();
    final filteredParts = enabledParts
        .where(
          (part) => part.name.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          ),
        )
        .toList();
    final media = MediaQuery.of(context);

    return Container(
      width: 420,
      constraints: BoxConstraints(
        maxHeight: (media.size.height - media.viewInsets.bottom - 48).clamp(
          120.0,
          560.0,
        ),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    I18n.t(context, 'choose_part'),
                    style: TextStyle(
                      color: colors.inkPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: I18n.t(context, 'cancel'),
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: Colors.transparent,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: colors.inkSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (enabledParts.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: I18n.t(context, 'search_parts'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ),
          Divider(height: 1, color: colors.borderSubtle),
          Flexible(
            child: filteredParts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      I18n.t(context, 'no_matching_parts'),
                      style: TextStyle(
                        color: colors.inkSecondary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredParts.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: colors.borderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      final part = filteredParts[index];
                      final selected = part.id == widget.selectedId;
                      return Semantics(
                        selected: selected,
                        child: Material(
                          color: selected ? colors.accentSoft : colors.surface,
                          child: InkWell(
                            onTap: () => widget.onSelectPart(part),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 64),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    if (part.image.isNotEmpty) ...[
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: _partImage(part),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        part.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.inkPrimary,
                                          fontSize: 16,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 24,
                                      child: selected
                                          ? Icon(
                                              Icons.check,
                                              color: colors.accent,
                                              size: 22,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _partImage(PartType part) => part.image.startsWith('assets/')
      ? Image.asset(
          part.image,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        )
      : Image.file(
          File(part.image),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
}
