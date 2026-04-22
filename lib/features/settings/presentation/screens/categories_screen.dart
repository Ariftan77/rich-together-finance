import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/database/daos/transaction_dao.dart';
import '../../../../shared/utils/color_utils.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../core/models/enums.dart';
import '../../../transactions/presentation/widgets/add_category_dialog.dart';
import '../widgets/category_icon_picker.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? _editingCategoryId;
  String? _editingIcon;
  String? _editingColor;
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Filter state: null = All, otherwise specific type
  CategoryType? _selectedFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _editController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    if (profileId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final categoriesStream = ref.watch(transactionDaoProvider).watchCategoriesWithUsageCount(profileId);

    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(trans.categoriesTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            titleTextStyle: Theme.of(context).textTheme.displaySmall?.copyWith(color: isLight ? AppColors.textPrimaryLight : Colors.white),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddCategoryDialog,
            backgroundColor: AppColors.primaryGold,
            child: const Icon(Icons.add, color: Colors.black),
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: trans.categoriesSearchHint,
                      hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4), fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: AppColors.primaryGold.withValues(alpha: 0.8), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5), size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Filter Bubbles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterBubble(trans.filterAll, null, isLight),
                    const SizedBox(width: 8),
                    _buildFilterBubble(trans.categoriesFilterExpense, CategoryType.expense, isLight),
                    const SizedBox(width: 8),
                    _buildFilterBubble(trans.categoriesFilterIncome, CategoryType.income, isLight),
                  ],
                ),
              ),

              // List
              Expanded(
                child: StreamBuilder<List<CategoryWithUsage>>(
                  stream: categoriesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                    }

                    // Filter logic
                    final allCategories = snapshot.data!;
                    final categories = allCategories.where((c) {
                      final matchesType = _selectedFilter == null || c.category.type == _selectedFilter;
                      final matchesSearch = _searchQuery.isEmpty ||
                          c.category.name.toLowerCase().contains(_searchQuery.toLowerCase());
                      return matchesType && matchesSearch;
                    }).toList();

                    if (categories.isEmpty) {
                      return Center(child: Text(trans.categoryNoneFound, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5))));
                    }
          
                    return ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        return _buildCategoryTile(item, isLight);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBubble(String label, CategoryType? type, bool isLight) {
    final isSelected = _selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : (isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : (isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : (isLight ? AppColors.textPrimaryLight : Colors.white),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddCategoryDialog(
        type: CategoryType.expense, // Default type
        canChangeType: true,
      ),
    );

    if (result != null && result['name'] != null && (result['name'] as String).isNotEmpty) {
      try {
        final profileId = ref.read(activeProfileIdProvider);
        if (profileId != null) {
          await ref.read(categoryDaoProvider).createCategory(
            CategoriesCompanion(
              profileId: drift.Value(profileId),
              name: drift.Value(result['name']),
              type: drift.Value(result['type']),
              icon: drift.Value(result['icon'] ?? '📦'), // Custom icon
              color: drift.Value(result['color'] ?? '#BDC3C7'), // Custom color (String)
              isSystem: const drift.Value(false),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ref.read(translationsProvider).categoryAdded), backgroundColor: AppColors.success),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${ref.read(translationsProvider).categoryAddError}: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Widget _buildCategoryTile(CategoryWithUsage item, bool isLight) {
    final isEditing = _editingCategoryId == item.category.id;
    final isSystem = item.category.isSystem;
    final themeMode = AppThemeProvider.of(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          GestureDetector(
            onTap: isEditing ? () => _showIconPicker(item.category) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _parseColor(isEditing ? (_editingColor ?? item.category.color) : item.category.color),
                    shape: BoxShape.circle,
                  ),
                  child: CategoryIconWidget(
                    iconString: isEditing ? (_editingIcon ?? item.category.icon) : item.category.icon,
                    size: 20,
                    color: isDefault ? AppColors.primaryGold : isLight ? AppColors.textPrimaryLight : Colors.white,
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  Text(
                    ref.watch(translationsProvider).categoryTapToEditIcon,
                    style: TextStyle(
                      color: AppColors.primaryGold.withValues(alpha: 0.8),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: isEditing
                ? TextField(
                    controller: _editController,
                    autofocus: true,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: ref.watch(translationsProvider).entryCategory,
                      hintStyle: TextStyle(color: isLight ? const Color(0xFFCBD5E1) : Colors.white30),
                    ),
                    onSubmitted: (_) => _saveCategory(item.category),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.name,
                        style: TextStyle(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ref.watch(translationsProvider).categoryUsedInTransactions(item.usageCount),
                        style: TextStyle(
                          color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Actions
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.success),
              onPressed: () => _saveCategory(item.category),
            ),
            IconButton(
              icon: Icon(Icons.close, color: isLight ? const Color(0xFF64748B) : Colors.white70),
              onPressed: _cancelEdit,
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: isLight ? const Color(0xFF64748B) : Colors.white70),
              onPressed: () => _startEdit(item.category),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _deleteCategory(item),
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String? hex) =>
      parseHexColor(hex).withValues(alpha: 0.2);

  void _startEdit(Category category) {
    setState(() {
      _editingCategoryId = category.id;
      _editController.text = category.name;
      _editingIcon = category.icon;
      _editingColor = category.color;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCategoryId = null;
      _editingIcon = null;
      _editingColor = null;
      _editController.clear();
    });
  }

  Future<void> _showIconPicker(Category category) async {
    final result = await CategoryIconPicker.show(
      context,
      initialIcon: _editingIcon ?? category.icon,
      initialColorHex: _editingColor ?? category.color ?? 'transparent',
    );
    if (result != null) {
      setState(() {
        _editingIcon = result['icon'];
        _editingColor = result['color'];
      });
    }
  }

  Future<void> _saveCategory(Category category) async {
    final newName = _editController.text.trim();
    if (newName.isEmpty) return;

    try {
      final updatedCategory = category.copyWith(
        name: newName,
        icon: _editingIcon ?? category.icon,
        color: drift.Value(_editingColor ?? category.color),
      );
      await ref.read(categoryDaoProvider).updateCategory(updatedCategory);
      _cancelEdit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(translationsProvider).categoryUpdated), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.read(translationsProvider).categoryUpdateError}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteCategory(CategoryWithUsage item) async {
    final trans = ref.read(translationsProvider);

    // 1. Check usage
    if (item.usageCount > 0) {
      showDialog(
        context: context,
        builder: (context) {
          final themeMode = AppThemeProvider.of(context);
          final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
          final isDefault = themeMode == AppThemeMode.defaultTheme;
          return AlertDialog(
          backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(trans.categoryCannotDeleteTitle, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
          content: Text(
            trans.categoryCannotDeleteContent(item.usageCount),
            style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(trans.ok, style: const TextStyle(color: AppColors.primaryGold)),
            ),
          ],
          );
        },
      );
      return;
    }

    // 2. Confirm delete
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
        backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${trans.delete} ${trans.entryCategory}?', style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
        content: Text(
          '"${item.category.name}"',
          style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(trans.cancel, style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(trans.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref.read(categoryDaoProvider).deleteCategory(item.category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trans.categoryDeleted), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${trans.categoryDeleteError}: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
