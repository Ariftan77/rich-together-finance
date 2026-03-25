import 'package:flutter/material.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

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
  /// Optional callback to add a new item. If provided, an "Add New" button appears.
  final ValueChanged<String>? onAddNew;

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
    this.onAddNew,
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
      FocusScope.of(context).unfocus();
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

    // Calculate extra height for "Add New" button
    final addNewHeight = widget.onAddNew != null ? 49.0 : 0.0; // 48 button + 1 divider

    final totalHeight = searchFieldHeight + verticalPadding * 2 + listHeight + 8 + addNewHeight;

    return OverlayEntry(
      builder: (context) {
        // Recalculate list height on rebuild (filtering)
        final currentListHeight =
            (_filteredItems.isEmpty ? itemHeight : _filteredItems.length * itemHeight)
                .clamp(itemHeight, widget.maxVisibleItems * itemHeight);
        final currentTotalHeight =
            searchFieldHeight + verticalPadding * 2 + currentListHeight + 8 + addNewHeight;

        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;

        // Dropdown popup background:
        // default=warm dark, dark=true black, light=light gray
        final Color dropdownBg = isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A);

        // Search field fill
        final Color searchBg = isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.05);

        // Search field border
        final Color searchBorder = isLight
            ? Colors.black.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.12);

        // Text colors
        final Color textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
        final Color hintColor = isLight
            ? const Color(0xFF94A3B8)
            : Colors.white.withValues(alpha: 0.35);

        // Divider
        final Color dividerColor = isLight
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1);

        // Item text
        final Color itemTextColor = isLight ? AppColors.textPrimaryLight : Colors.white;

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
                      color: dropdownBg,
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
                              color: searchBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: searchBorder),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _filterItems,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.searchHint,
                                hintStyle: TextStyle(
                                  color: hintColor,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: AppColors.primaryGold.withValues(alpha: 0.7),
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
                                      color: isLight
                                          ? const Color(0xFF94A3B8)
                                          : Colors.white.withValues(alpha: 0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  shrinkWrap: true,
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    final isSelected = item == widget.selectedItem;

                                    return InkWell(
                                      onTap: () => _selectItem(item),
                                      child: Container(
                                        height: itemHeight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        color: isSelected
                                            ? AppColors.primaryGold.withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.itemLabelBuilder(item),
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppColors.primaryGold
                                                      : itemTextColor,
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
                        // Add New Button (if provided)
                        if (widget.onAddNew != null) ...[
                          Divider(height: 1, color: dividerColor),
                          InkWell(
                            onTap: () {
                              final text = _searchController.text.trim();
                              _removeOverlay();
                              widget.onAddNew!(text);
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.primaryGold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _searchController.text.trim().isEmpty
                                          ? 'Add New Category'
                                          : 'Add "${_searchController.text.trim()}"',
                                      style: const TextStyle(
                                        color: AppColors.primaryGold,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final selectedLabel = widget.selectedItem != null
        ? widget.itemLabelBuilder(widget.selectedItem as T)
        : null;

    // Label color
    final Color labelColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    // Trigger container fill
    final Color containerBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.05);

    // Trigger border
    final Color containerBorder = _isOpen
        ? AppColors.primaryGold.withValues(alpha: 0.5)
        : (isLight
            ? Colors.black.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.15));

    // Value/hint text color
    final Color valueColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final Color hintColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.4);

    // Chevron icon
    final Color chevronColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.3);

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
                color: labelColor,
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
                color: containerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: containerBorder),
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
                        color: selectedLabel != null ? valueColor : hintColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: chevronColor),
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
