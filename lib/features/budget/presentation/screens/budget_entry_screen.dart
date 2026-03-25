import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/widgets/glass_button.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../transactions/presentation/widgets/category_selector.dart';
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
  Currency _selectedCurrency = Currency.idr; // overwritten in initState
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
    } else {
      _selectedCurrency = ref.read(defaultCurrencyProvider);
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

  Future<void> _createNewCategory(String name, {String? icon, String? color}) async {
    try {
      final dao = ref.read(categoryDaoProvider);
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;

      final newCategoryId = await dao.createCategory(
        CategoriesCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(name),
          type: const drift.Value(CategoryType.expense),
          icon: drift.Value(icon ?? '📦'),
          color: drift.Value(color ?? '#BDC3C7'),
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
            ),
            title: Text(
              widget.budget == null ? trans.budgetTitleAdd : trans.budgetTitleEdit,
              style: TextStyle(
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
              ),
            ),
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
                              color: _rawAmount > 0
                                  ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                  : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calculate_outlined,
                          color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Currency Selector
                Text(trans.goalCurrency, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                CurrencyPickerField(
                  value: _selectedCurrency,
                  onChanged: (currency) => setState(() => _selectedCurrency = currency),
                ),
                const SizedBox(height: 24),

                // Category Selector (bottom sheet — same as transaction entry)
                categoriesAsync.when(
                  data: (categories) {
                    final expenseCategories = categories.where((c) => c.type == CategoryType.expense).toList();
                    final selectedCategory = _selectedCategoryId != null
                        ? expenseCategories.where((c) => c.id == _selectedCategoryId).firstOrNull
                        : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            trans.entryCategory.toUpperCase(),
                            style: TextStyle(
                              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (modalContext) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                                ),
                                child: CategorySelector(
                                  categories: expenseCategories,
                                  selectedCategoryId: _selectedCategoryId,
                                  onCategorySelected: (id) {
                                    setState(() => _selectedCategoryId = id);
                                  },
                                  onAddNew: (searchText) async {
                                    final name = searchText.trim();
                                    if (name.isNotEmpty) {
                                      await _createNewCategory(name);
                                    } else {
                                      FocusScope.of(context).unfocus();
                                      await Future.delayed(const Duration(milliseconds: 100));

                                      if (!mounted) return;

                                      final result = await showDialog<Map<String, dynamic>>(
                                        context: context,
                                        builder: (context) => const AddCategoryDialog(
                                          type: CategoryType.expense,
                                        ),
                                      );

                                      if (mounted) {
                                        FocusScope.of(context).unfocus();
                                      }

                                      if (result != null && result['name'] != null) {
                                        await _createNewCategory(
                                          result['name'] as String,
                                          icon: result['icon'] as String?,
                                          color: result['color'] as String?,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            child: Row(
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primaryGold.withValues(alpha: 0.8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedCategory?.name ?? trans.entrySelectCategory,
                                    style: TextStyle(
                                      color: selectedCategory != null
                                          ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                          : (isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4)),
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more,
                                  color: isLight
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('${trans.error}: $err'),
                ),

                const SizedBox(height: 24),

                // Period Selector
                Text(trans.budgetPeriod, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
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

                    return ChoiceChip(
                      label: Text(periodName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPeriod = period);
                      },
                      selectedColor: AppColors.primaryGold,
                      backgroundColor: AppColors.glassBackground,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (isLight ? AppColors.textPrimaryLight : Colors.white),
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
