import 'package:flutter/material.dart';
import '../../../../core/database/database.dart';
import '../../../../shared/theme/colors.dart';

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

  @override
  void initState() {
    super.initState();
    _filteredCategories = widget.categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2D2416),
            const Color(0xFF1A1410),
          ],
        ),
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
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6)),
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCategories,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
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

          // Category List
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No categories found',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : Colors.white.withValues(alpha: 0.15),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primaryGold
                                        : Colors.white,
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryGold,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Add New Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onAddNew(_searchController.text.trim());
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFF4E5A1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Color(0xFF1A1410)),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Category',
                      style: TextStyle(
                        color: Color(0xFF1A1410),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
