import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/database/daos/transaction_dao.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../core/models/enums.dart';
import '../../../transactions/presentation/widgets/add_category_dialog.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  // Track which category is being edited
  int? _editingCategoryId;
  final TextEditingController _editController = TextEditingController();
  
  // Filter state: null = All, otherwise specific type
  CategoryType? _selectedFilter;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    
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
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Manage Categories'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: AppTypography.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddCategoryDialog,
            backgroundColor: AppColors.primaryGold,
            child: const Icon(Icons.add, color: Colors.black),
          ),
          body: Column(
            children: [
              // Filter Bubbles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterBubble('All', null),
                    const SizedBox(width: 8),
                    _buildFilterBubble('Expense', CategoryType.expense),
                    const SizedBox(width: 8),
                    _buildFilterBubble('Income', CategoryType.income),
                  ],
                ),
              ),
              
              // List
              Expanded(
                child: StreamBuilder<List<CategoryWithUsage>>(
                  stream: categoriesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                    }
          
                    // Filter logic
                    final allCategories = snapshot.data!;
                    final categories = _selectedFilter == null 
                        ? allCategories 
                        : allCategories.where((c) => c.category.type == _selectedFilter).toList();
          
                    if (categories.isEmpty) {
                      return Center(child: Text('No categories found', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
                    }
          
                    return ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        return _buildCategoryTile(item);
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

  Widget _buildFilterBubble(String label, CategoryType? type) {
    final isSelected = _selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
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
              icon: const drift.Value('category'), // Default icon
              color: const drift.Value('0xFFFFFFFF'), // Default color (String)
              isSystem: const drift.Value(false),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category added'), backgroundColor: AppColors.success),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding category: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Widget _buildCategoryTile(CategoryWithUsage item) {
    final isEditing = _editingCategoryId == item.category.id;
    final isSystem = item.category.isSystem;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_outlined,
              color: AppColors.primaryGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: isEditing
                ? TextField(
                    controller: _editController,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: 'Category Name',
                      hintStyle: TextStyle(color: Colors.white30),
                    ),
                    onSubmitted: (_) => _saveCategory(item.category),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.usageCount == 1 
                            ? 'Used in 1 transaction' 
                            : 'Used in ${item.usageCount} transactions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _cancelEdit,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
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

  void _startEdit(Category category) {
    setState(() {
      _editingCategoryId = category.id;
      _editController.text = category.name;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCategoryId = null;
      _editController.clear();
    });
  }

  Future<void> _saveCategory(Category category) async {
    final newName = _editController.text.trim();
    if (newName.isEmpty) return;

    try {
      final updatedCategory = category.copyWith(name: newName);
      await ref.read(categoryDaoProvider).updateCategory(updatedCategory);
      _cancelEdit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating category: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteCategory(CategoryWithUsage item) async {
    // 1. Check usage
    if (item.usageCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgDarkEnd,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cannot Delete Category', style: TextStyle(color: Colors.white)),
          content: Text(
            'This category is used in ${item.usageCount} transactions. You cannot delete it while it counts towards your records.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppColors.primaryGold)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Confirm delete
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDarkEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${item.category.name}"? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(categoryDaoProvider).deleteCategory(item.category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
