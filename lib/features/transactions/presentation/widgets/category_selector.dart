import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/category_icon_widget.dart';

/// A searchable category selector with "Add New" option
class CategorySelector extends StatefulWidget {
  final List<Category> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;
  final ValueChanged<String> onAddNew; // Changed to pass search text

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onAddNew,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Category> _filteredCategories = [];
  bool _isGridView = false;

  static const _prefKey = 'category_selector_grid_view';

  @override
  void initState() {
    super.initState();
    _filteredCategories = widget.categories;
    _loadLayoutPref();
  }

  Future<void> _loadLayoutPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isGridView = prefs.getBool(_prefKey) ?? false);
    }
  }

  Future<void> _toggleLayout() async {
    final next = !_isGridView;
    setState(() => _isGridView = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, next);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex == 'transparent') return Colors.white.withValues(alpha: 0.1);
    final cleaned = hex.replaceFirst('#', '0xFF');
    return Color(int.tryParse(cleaned) ?? 0xFF808080).withValues(alpha: 0.2);
  }

  String _truncate(String name) =>
      name.length > 15 ? '${name.substring(0, 15)}...' : name;

  void _filterCategories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = widget.categories;
      } else {
        _filteredCategories = widget.categories
            .where((cat) => cat.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDefault
            ? const Color(0xFF1A1A2E)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Category',
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAddNew(_searchController.text.trim());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: AppColors.primaryGold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'New',
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _toggleLayout,
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCategories,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: TextStyle(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.primaryGold.withValues(alpha: 0.8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category List / Grid
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: isLight
                              ? const Color(0xFFCBD5E1)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No categories found',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF64748B)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? _buildGrid(context, isLight, isDefault)
                    : _buildList(context, isLight, isDefault),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isLight, bool isDefault) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        final isSelected = category.id == widget.selectedCategoryId;

        return GestureDetector(
          onTap: () {
            widget.onCategorySelected(category.id);
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGold.withValues(alpha: 0.15)
                  : isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGold
                    : isLight
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.15),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _parseColor(category.color),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: CategoryIconWidget(
                    iconString: category.icon,
                    size: 11,
                    color: isSelected
                        ? AppColors.primaryGold
                        : isLight ? AppColors.textPrimaryLight : Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryGold
                          : isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGold,
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, bool isLight, bool isDefault) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        final isSelected = category.id == widget.selectedCategoryId;

        return Tooltip(
          message: category.name,
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: false,
          child: GestureDetector(
            onTap: () {
              widget.onCategorySelected(category.id);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGold.withValues(alpha: 0.15)
                    : isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGold
                      : isLight
                          ? Colors.black.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _parseColor(category.color),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: CategoryIconWidget(
                      iconString: category.icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.primaryGold
                          : isLight ? AppColors.textPrimaryLight : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _truncate(category.name),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryGold
                          : isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
