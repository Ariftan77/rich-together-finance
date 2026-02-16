import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/generic_searchable_dropdown.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';
import '../../../transactions/presentation/widgets/add_category_dialog.dart';

class BudgetEntryScreen extends ConsumerStatefulWidget {
  final Budget? budget;

  const BudgetEntryScreen({super.key, this.budget});

  @override
  ConsumerState<BudgetEntryScreen> createState() => _BudgetEntryScreenState();
}

class _BudgetEntryScreenState extends ConsumerState<BudgetEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  int? _selectedCategoryId;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.budget?.amount.toStringAsFixed(0) ?? '',
    );
    if (widget.budget != null) {
      _selectedCategoryId = widget.budget!.categoryId;
      _selectedPeriod = widget.budget!.period;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr = _amountController.text.replaceAll('.', '').replaceAll(',', '');
      final amount = double.parse(amountStr);
      final dao = ref.read(budgetDaoProvider);

      // Check if a budget already exists for this category and period
      // (Except if we are editing the same budget)
      // Logic for checking duplicate budget is pending in DAO, but we can iterate user side or add method
      // For now we rely on Unique constraints in DB but handle error if duplicate

      if (widget.budget == null) {
        // Create
        final profileId = ref.read(activeProfileIdProvider);
        if (profileId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active profile. Please set up a profile first.')),
            );
          }
          return;
        }
        await dao.createBudget(
          BudgetsCompanion(
            profileId: drift.Value(profileId),
            categoryId: drift.Value(_selectedCategoryId!),
            amount: drift.Value(amount),
            period: drift.Value(_selectedPeriod),
            startDate: drift.Value(DateTime.now()),
            isActive: const drift.Value(true),
            createdAt: drift.Value(DateTime.now()),
          ),
        );
      } else {
        // Update
        await dao.updateBudget(
          widget.budget!.copyWith(
            categoryId: _selectedCategoryId!,
            amount: amount,
            period: _selectedPeriod,
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // Simple error handling for unique constraint
        if (e.toString().contains('UNIQUE constraint failed')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget for this category and period already exists')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving budget: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewCategory(String name) async {
    try {
      final dao = ref.read(categoryDaoProvider);
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;

      final newCategoryId = await dao.createCategory(
        CategoriesCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(name),
          type: const drift.Value(CategoryType.expense),
          icon: const drift.Value('category'),
          isSystem: const drift.Value(false),
          sortOrder: const drift.Value(999),
        ),
      );

      setState(() {
        _selectedCategoryId = newCategoryId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating category: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(widget.budget == null ? 'New Budget' : 'Edit Budget', style: const TextStyle(color: Colors.white)),
          ),
          body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Input
                GlassInput(
                  controller: _amountController,
                  hintText: 'Budget Amount',
                  prefixIcon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                  inputFormatters: [IndonesianCurrencyInputFormatter()],
                  validator: (v) {
                    if (v == null || v.isEmpty || v == '0') {
                      return 'Amount required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Category Selector
                categoriesAsync.when(
                  data: (categories) {
                    final expenseCategories = categories.where((c) => c.type == CategoryType.expense).toList();
                    final selectedCategory = _selectedCategoryId != null
                        ? expenseCategories.where((c) => c.id == _selectedCategoryId).firstOrNull
                        : null;

                    return GenericSearchableDropdown<Category>(
                      items: expenseCategories,
                      selectedItem: selectedCategory,
                      itemLabelBuilder: (c) => c.name,
                      onItemSelected: (category) {
                        setState(() => _selectedCategoryId = category.id);
                      },
                      label: 'Category',
                      icon: Icons.category_outlined,
                      hint: 'Select category',
                      searchHint: 'Search categories...',
                      onAddNew: (searchText) async {
                        final name = searchText.trim();
                        if (name.isNotEmpty) {
                          await _createNewCategory(name);
                        } else {
                          final result = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (context) => const AddCategoryDialog(
                              type: CategoryType.expense,
                            ),
                          );
                          if (result != null && result['name'] != null) {
                            await _createNewCategory(result['name'] as String);
                          }
                        }
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('Error: $err'),
                ),
                
                const SizedBox(height: 24),

                // Period Selector
                Text('Period', style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: BudgetPeriod.values.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(period.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedPeriod = period);
                        },
                        selectedColor: AppColors.primaryGold,
                        backgroundColor: AppColors.glassBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),
                
                GlassButton(
                  text: 'Save Budget',
                  isFullWidth: true,
                  size: GlassButtonSize.large,
                  onPressed: () => _saveBudget(),
                  isLoading: _isLoading,
                ),
                
                if (widget.budget != null) ...[
                   const SizedBox(height: 16),
                   Center(
                     child: TextButton(
                       onPressed: () async {
                         final navigator = Navigator.of(context);
                         final confirm = await showDialog<bool>(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text('Delete Budget?'),
                             content: const Text('This action cannot be undone.'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                               TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                             ],
                           ),
                         );

                         if (confirm == true) {
                            await ref.read(budgetDaoProvider).deleteBudget(widget.budget!.id);
                            navigator.pop();
                         }
                       },
                       child: const Text('Delete Budget', style: TextStyle(color: Colors.red)),
                     ),
                   ),
                ]
              ],
            ),
          ),
        ),
      ),
      ),
      ],
    );
  }
}
