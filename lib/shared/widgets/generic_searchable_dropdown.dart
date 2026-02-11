import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// An inline searchable dropdown that opens a filtered list below the field.
/// Matches the app's glass/dark style. No modal — just tap the field to expand.
class GenericSearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemLabelBuilder;
  final ValueChanged<T> onItemSelected;
  final String label;
  final IconData icon;
  final String hint;
  final String searchHint;
  final String noItemsFoundText;
  /// Max visible items before scrolling kicks in (default 4).
  final int maxVisibleItems;

  const GenericSearchableDropdown({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.itemLabelBuilder,
    required this.onItemSelected,
    required this.label,
    this.icon = Icons.arrow_drop_down_circle_outlined,
    this.hint = 'Select...',
    this.searchHint = 'Search...',
    this.noItemsFoundText = 'No items found',
    this.maxVisibleItems = 4,
  });

  @override
  State<GenericSearchableDropdown<T>> createState() =>
      _GenericSearchableDropdownState<T>();
}

class _GenericSearchableDropdownState<T>
    extends State<GenericSearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void didUpdateWidget(covariant GenericSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-filter when items change
    if (widget.items != oldWidget.items) {
      _filterItems(_searchController.text);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => widget
                .itemLabelBuilder(item)
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
    // Rebuild overlay to reflect new filtered list
    _overlayEntry?.markNeedsBuild();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    // Focus the search field after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    _filteredItems = widget.items;
    if (mounted) setState(() => _isOpen = false);
  }

  void _selectItem(T item) {
    widget.onItemSelected(item);
    _removeOverlay();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    // Each item row height (padding + text)
    const itemHeight = 48.0;
    const searchFieldHeight = 48.0;
    const verticalPadding = 8.0;
    final listHeight =
        (_filteredItems.isEmpty ? itemHeight : _filteredItems.length * itemHeight)
            .clamp(itemHeight, widget.maxVisibleItems * itemHeight);
    final totalHeight = searchFieldHeight + verticalPadding * 2 + listHeight + 8;

    return OverlayEntry(
      builder: (context) {
        // Recalculate list height on rebuild (filtering)
        final currentListHeight =
            (_filteredItems.isEmpty ? itemHeight : _filteredItems.length * itemHeight)
                .clamp(itemHeight, widget.maxVisibleItems * itemHeight);
        final currentTotalHeight =
            searchFieldHeight + verticalPadding * 2 + currentListHeight + 8;

        return Stack(
          children: [
            // Dismiss layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Dropdown
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: currentTotalHeight),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2416),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search field
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Container(
                            height: searchFieldHeight,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _filterItems,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: widget.searchHint,
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: AppColors.primaryGold
                                      .withValues(alpha: 0.7),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        // Items list
                        Flexible(
                          child: _filteredItems.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    widget.noItemsFoundText,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  shrinkWrap: true,
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    final isSelected =
                                        item == widget.selectedItem;

                                    return InkWell(
                                      onTap: () => _selectItem(item),
                                      child: Container(
                                        height: itemHeight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        color: isSelected
                                            ? AppColors.primaryGold
                                                .withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget
                                                    .itemLabelBuilder(item),
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppColors.primaryGold
                                                      : Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check,
                                                color: AppColors.primaryGold,
                                                size: 18,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.selectedItem != null
        ? widget.itemLabelBuilder(widget.selectedItem as T)
        : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleDropdown,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOpen
                      ? AppColors.primaryGold.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: AppColors.primaryGold.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedLabel ?? widget.hint,
                      style: TextStyle(
                        color: selectedLabel != null
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
