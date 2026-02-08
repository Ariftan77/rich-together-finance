import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';

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
        await dao.createBudget(
          BudgetsCompanion(
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.budget == null ? 'New Budget' : 'Edit Budget'),
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
                Text('Category', style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  data: (categories) {
                    // Filter only expense categories usually? But maybe income targets too?
                    // Typically budget is for expenses.
                    final expenseCategories = categories.where((c) => c.type == CategoryType.expense.index).toList();
                    
                    return DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      dropdownColor: AppColors.cardSurface,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.glassBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: expenseCategories.map((category) {
                        return DropdownMenuItem<int>(
                          value: category.id,
                          child: Row(
                            children: [
                              Text(category.icon),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
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
                         final confirm = await showDialog<bool>(
                           context: context,
                           builder: (context) => AlertDialog(
                             title: const Text('Delete Budget?'),
                             content: const Text('This action cannot be undone.'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                               TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                             ],
                           ),
                         );
                         
                         if (confirm == true) {
                            await ref.read(budgetDaoProvider).deleteBudget(widget.budget!.id);
                            if (mounted) Navigator.pop(context);
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
    );
  }
}
