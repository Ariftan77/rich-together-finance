import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../providers/budget_provider.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../settings/presentation/widgets/category_icon_picker.dart';

class BudgetEntryScreen extends ConsumerStatefulWidget {
  /// Pass the full [BudgetWithSpending] when editing so that the linked
  /// categories can be pre-populated.  Pass null to create a new budget.
  final BudgetWithSpending? budgetWithSpending;

  const BudgetEntryScreen({super.key, this.budgetWithSpending});

  @override
  ConsumerState<BudgetEntryScreen> createState() => _BudgetEntryScreenState();
}

class _BudgetEntryScreenState extends ConsumerState<BudgetEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  double _rawAmount = 0;
  List<int> _selectedCategoryIds = [];
  Currency _selectedCurrency = Currency.idr;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  bool _isLoading = false;
  String? _selectedIcon;
  String? _selectedIconColor;

  Budget? get _editingBudget => widget.budgetWithSpending?.budget;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _editingBudget?.name ?? '');

    if (_editingBudget != null) {
      _rawAmount = _editingBudget!.amount;
      _selectedCurrency = _editingBudget!.currency;
      _selectedPeriod = _editingBudget!.period;
      // Pre-populate category IDs from the already-loaded BudgetWithSpending.
      _selectedCategoryIds = widget.budgetWithSpending!.categories
          .map((c) => c.id)
          .toList();
      // Pre-populate icon and icon color from saved budget (may be null).
      _selectedIcon = _editingBudget!.icon;
      _selectedIconColor = _editingBudget!.iconColor;
    } else {
      _selectedCurrency = ref.read(defaultCurrencyProvider);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _openIconPicker() async {
    final result = await CategoryIconPicker.show(
      context,
      initialIcon: _selectedIcon ?? '📦',
      initialColorHex: _selectedIconColor ?? 'transparent',
    );
    if (result != null && mounted) {
      setState(() {
        _selectedIcon = result['icon'] as String?;
        _selectedIconColor = result['color'] as String?;
      });
    }
  }

  Future<void> _openCategoryPicker(List<Category> expenseCategories) async {
    final updated = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiCategoryPickerSheet(
        categories: expenseCategories,
        selectedIds: Set<int>.from(_selectedCategoryIds),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _selectedCategoryIds = updated);
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
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dao = ref.read(budgetDaoProvider);
      final budgetName = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();

      if (_editingBudget == null) {
        // --- Create ---
        final profileId = ref.read(activeProfileIdProvider);
        if (profileId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No active profile. Please set up a profile first.')),
            );
          }
          return;
        }
        final budgetId = await dao.createBudget(
          BudgetsCompanion(
            profileId: drift.Value(profileId),
            name: drift.Value(budgetName),
            icon: drift.Value(_selectedIcon),
            iconColor: drift.Value(_selectedIconColor),
            amount: drift.Value(_rawAmount),
            currency: drift.Value(_selectedCurrency),
            period: drift.Value(_selectedPeriod),
            startDate: drift.Value(DateTime.now()),
            isActive: const drift.Value(true),
            createdAt: drift.Value(DateTime.now()),
          ),
        );
        for (final catId in _selectedCategoryIds) {
          await dao.linkCategoryToBudget(budgetId, catId);
        }
        AnalyticsService.trackFirstBudgetCreated();
      } else {
        // --- Update ---
        await dao.updateBudget(
          _editingBudget!.copyWith(
            name: drift.Value(budgetName),
            icon: drift.Value(_selectedIcon),
            iconColor: drift.Value(_selectedIconColor),
            amount: _rawAmount,
            currency: _selectedCurrency,
            period: _selectedPeriod,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
        await dao.unlinkAllCategoriesFromBudget(_editingBudget!.id);
        for (final catId in _selectedCategoryIds) {
          await dao.linkCategoryToBudget(_editingBudget!.id, catId);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
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
              _editingBudget == null
                  ? trans.budgetTitleAdd
                  : trans.budgetTitleEdit,
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
                    // ----------------------------------------------------------
                    // Optional Budget Name
                    // ----------------------------------------------------------
                    _SectionLabel(
                      label: 'Budget Name (optional)',
                      isLight: isLight,
                    ),
                    const SizedBox(height: 8),
                    _NameField(
                      controller: _nameController,
                      isLight: isLight,
                    ),
                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // Budget Icon Picker
                    // ----------------------------------------------------------
                    _SectionLabel(
                      label: 'Budget Icon (optional)',
                      isLight: isLight,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openIconPicker,
                      child: Container(
                        height: 52,
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
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: () {
                                  if (_selectedIconColor == null ||
                                      _selectedIconColor!.isEmpty ||
                                      _selectedIconColor == 'transparent') {
                                    return AppColors.primaryGold.withValues(alpha: 0.15);
                                  }
                                  final hex = _selectedIconColor!.replaceFirst('#', '0xFF');
                                  return Color(int.parse(hex));
                                }(),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _selectedIcon != null
                                  ? CategoryIconWidget(
                                      iconString: _selectedIcon!,
                                      size: 18,
                                      color: AppColors.primaryGold,
                                    )
                                  : Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: AppColors.primaryGold.withValues(alpha: 0.8),
                                      size: 18,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedIcon != null
                                    ? 'Icon selected — tap to change'
                                    : 'Tap to choose an icon',
                                style: TextStyle(
                                  color: _selectedIcon != null
                                      ? (isLight
                                          ? AppColors.textPrimaryLight
                                          : Colors.white)
                                      : (isLight
                                          ? const Color(0xFF94A3B8)
                                          : Colors.white54),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_selectedIcon != null)
                              GestureDetector(
                                onTap: () => setState(() { _selectedIcon = null; _selectedIconColor = null; }),
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  Icons.close,
                                  color: isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right,
                                color: isLight
                                    ? const Color(0xFFCBD5E1)
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // Amount
                    // ----------------------------------------------------------
                    GestureDetector(
                      onTap: _openAmountCalculator,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Icon(Icons.monetization_on,
                                color: AppColors.primaryGold, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _rawAmount > 0
                                    ? Formatters.formatCurrency(_rawAmount,
                                        currency: _selectedCurrency,
                                        showDecimal: showDecimal)
                                    : trans.budgetAmount,
                                style: TextStyle(
                                  color: _rawAmount > 0
                                      ? (isLight
                                          ? AppColors.textPrimaryLight
                                          : Colors.white)
                                      : (isLight
                                          ? const Color(0xFF94A3B8)
                                          : Colors.white54),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calculate_outlined,
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // Currency Selector
                    // ----------------------------------------------------------
                    Text(trans.goalCurrency,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    CurrencyPickerField(
                      value: _selectedCurrency,
                      onChanged: (currency) =>
                          setState(() => _selectedCurrency = currency),
                    ),
                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // Multi-Category Picker
                    // ----------------------------------------------------------
                    categoriesAsync.when(
                      data: (allCategories) {
                        final expenseCategories = allCategories
                            .where((c) => c.type == CategoryType.expense)
                            .toList();
                        final selectedCategories = expenseCategories
                            .where((c) =>
                                _selectedCategoryIds.contains(c.id))
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                              label: trans.entryCategory.toUpperCase(),
                              isLight: isLight,
                            ),
                            const SizedBox(height: 8),

                            // Selected category chips
                            if (selectedCategories.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedCategories.map((cat) {
                                  return _CategoryChip(
                                    category: cat,
                                    isLight: isLight,
                                    onRemove: () {
                                      setState(() => _selectedCategoryIds
                                          .remove(cat.id));
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Picker trigger
                            GestureDetector(
                              onTap: () => _openCategoryPicker(
                                  expenseCategories),
                              child: _PickerTrigger(
                                isLight: isLight,
                                hasSelection:
                                    selectedCategories.isNotEmpty,
                                displayText: selectedCategories.isEmpty
                                    ? trans.entrySelectCategory
                                    : '${selectedCategories.length} categor${selectedCategories.length == 1 ? 'y' : 'ies'} selected',
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (err, _) =>
                          Text('${trans.error}: $err'),
                    ),

                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // Period Selector
                    // ----------------------------------------------------------
                    Text(trans.budgetPeriod,
                        style: Theme.of(context).textTheme.labelLarge),
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
                            if (selected) {
                              setState(() => _selectedPeriod = period);
                            }
                          },
                          selectedColor: AppColors.primaryGold,
                          backgroundColor: AppColors.glassBackground,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white),
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

                    if (_editingBudget != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(trans.delete),
                                content: const Text(
                                    'This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: Text(trans.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: Text(
                                      trans.delete,
                                      style: const TextStyle(
                                          color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(budgetDaoProvider)
                                  .deleteBudget(_editingBudget!.id);
                              navigator.pop();
                            }
                          },
                          child: Text(
                            trans.delete,
                            style: const TextStyle(color: Colors.red),
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
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isLight;

  const _SectionLabel({required this.label, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: isLight
              ? const Color(0xFF64748B)
              : Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLight;

  const _NameField({required this.controller, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
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
            Icons.label_outline,
            color: AppColors.primaryGold.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Budget name (optional)',
                hintStyle: TextStyle(
                  color: isLight
                      ? const Color(0xFF94A3B8)
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTrigger extends StatelessWidget {
  final bool isLight;
  final bool hasSelection;
  final String displayText;

  const _PickerTrigger({
    required this.isLight,
    required this.hasSelection,
    required this.displayText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              displayText,
              style: TextStyle(
                color: hasSelection
                    ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                    : (isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4)),
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
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isLight;
  final VoidCallback onRemove;

  const _CategoryChip({
    required this.category,
    required this.isLight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryIconWidget(
            iconString: category.icon,
            size: 14,
            color: isLight ? AppColors.textPrimaryLight : Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              color: isLight
                  ? const Color(0xFF64748B)
                  : Colors.white.withValues(alpha: 0.6),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-category picker bottom sheet
// ---------------------------------------------------------------------------

class _MultiCategoryPickerSheet extends StatefulWidget {
  final List<Category> categories;
  final Set<int> selectedIds;

  const _MultiCategoryPickerSheet({
    required this.categories,
    required this.selectedIds,
  });

  @override
  State<_MultiCategoryPickerSheet> createState() =>
      _MultiCategoryPickerSheetState();
}

class _MultiCategoryPickerSheetState
    extends State<_MultiCategoryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Set<int> _current;
  late List<Category> _filtered;

  @override
  void initState() {
    super.initState();
    _current = Set.from(widget.selectedIds);
    _filtered = widget.categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.categories
          : widget.categories
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    });
  }

  void _toggle(int categoryId) {
    setState(() {
      if (_current.contains(categoryId)) {
        _current.remove(categoryId);
      } else {
        _current.add(categoryId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _current = widget.categories.map((c) => c.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() => _current.clear());
  }

  bool get _allSelected =>
      widget.categories.every((c) => _current.contains(c.id));

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final Color bgColor = isDefault
        ? const Color(0xFF1A1A2E)
        : isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0A0A0A);

    final Color borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.1);

    final Color handleColor = isLight
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.3);

    final Color titleColor =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;

    final Color searchBg = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.08);

    final Color itemPrimaryColor =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color itemSecondaryColor =
        isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    final Color checkboxBorderColor =
        isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title + select-all / deselect-all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: _allSelected ? _deselectAll : _selectAll,
                  child: Text(
                    _allSelected ? 'Deselect All' : 'Select All',
                    style: const TextStyle(
                        color: AppColors.primaryGold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: TextStyle(color: itemPrimaryColor, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search categories…',
                  hintStyle: TextStyle(
                    color: isLight
                        ? AppColors.textTertiaryLight
                        : AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isLight
                        ? AppColors.textSecondaryLight
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),

          // Category list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No categories found',
                      style: TextStyle(color: itemSecondaryColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final cat = _filtered[index];
                      final isSelected = _current.contains(cat.id);

                      return InkWell(
                        onTap: () => _toggle(cat.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          color: isSelected
                              ? AppColors.primaryGold.withValues(alpha: 0.1)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              CategoryIconWidget(
                                iconString: cat.icon,
                                size: 22,
                                color: itemPrimaryColor,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    color: itemPrimaryColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Checkbox
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryGold
                                        : checkboxBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.black, size: 16)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () =>
                    Navigator.pop(context, _current.toList()),
                child: Text(
                  _current.isEmpty
                      ? 'Confirm (none selected)'
                      : 'Confirm (${_current.length} selected)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
