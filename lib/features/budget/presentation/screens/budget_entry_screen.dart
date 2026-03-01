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
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/generic_searchable_dropdown.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../transactions/presentation/widgets/add_category_dialog.dart';

class BudgetEntryScreen extends ConsumerStatefulWidget {
  final Budget? budget;

  const BudgetEntryScreen({super.key, this.budget});

  @override
  ConsumerState<BudgetEntryScreen> createState() => _BudgetEntryScreenState();
}

class _BudgetEntryScreenState extends ConsumerState<BudgetEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  double _rawAmount = 0;
  int? _selectedCategoryId;
  Currency _selectedCurrency = Currency.idr;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _rawAmount = widget.budget!.amount;
      _selectedCategoryId = widget.budget!.categoryId;
      _selectedCurrency = widget.budget!.currency;
      _selectedPeriod = widget.budget!.period;
    }
  }

  Future<void> _openAmountCalculator() async {
    final result = await CalculatorBottomSheet.show(
      context,
      initialValue: _rawAmount > 0 ? _rawAmount : null,
      currency: _selectedCurrency,
      showDecimal: ref.read(showDecimalProvider),
    );
    if (result != null && mounted) {
      setState(() => _rawAmount = result);
    }
  }

  Future<void> _saveBudget() async {
    final trans = ref.read(translationsProvider);
    if (_rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trans.errorInvalidAmount)),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = _rawAmount;
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
            currency: drift.Value(_selectedCurrency),
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
            currency: _selectedCurrency,
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
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);

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
            title: Text(widget.budget == null ? trans.budgetTitleAdd : trans.budgetTitleEdit, style: const TextStyle(color: Colors.white)),
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
                GestureDetector(
                  onTap: _openAmountCalculator,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    borderRadius: 12,
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _rawAmount > 0
                                ? Formatters.formatCurrency(_rawAmount, currency: _selectedCurrency, showDecimal: showDecimal)
                                : trans.budgetAmount,
                            style: TextStyle(
                              color: _rawAmount > 0 ? Colors.white : Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.calculate_outlined, color: Colors.white.withValues(alpha: 0.5), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Currency Selector
                Text(trans.goalCurrency, style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: Currency.values.map((currency) {
                    final isSelected = _selectedCurrency == currency;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(currency.code),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCurrency = currency);
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
                      label: trans.entryCategory,
                      icon: Icons.category_outlined,
                      hint: trans.entrySelectCategory,
                      searchHint: trans.entrySearchCategory,
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
                  error: (err, stack) => Text('${trans.error}: $err'),
                ),
                
                const SizedBox(height: 24),

                // Period Selector
                Text(trans.budgetPeriod, style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: BudgetPeriod.values.map((period) {
                    final isSelected = _selectedPeriod == period;
                    String periodName = period.displayName;
                      switch (period) {
                        case BudgetPeriod.weekly:
                          periodName = trans.recurringWeekly;
                          break;
                        case BudgetPeriod.monthly:
                          periodName = trans.recurringMonthly;
                          break;
                        case BudgetPeriod.yearly:
                          periodName = trans.recurringYearly;
                          break;
                      }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(periodName),
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
                  text: trans.save,
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
                             title: Text(trans.delete),
                             content: const Text('This action cannot be undone.'), // TODO: Add translation
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trans.cancel)),
                               TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(trans.delete, style: const TextStyle(color: Colors.red))),
                             ],
                           ),
                         );

                         if (confirm == true) {
                            await ref.read(budgetDaoProvider).deleteBudget(widget.budget!.id);
                            navigator.pop();
                         }
                       },
                       child: Text(trans.delete, style: const TextStyle(color: Colors.red)),
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
