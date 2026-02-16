import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/balance_provider.dart';
import '../../../transactions/presentation/screens/transactions_history_screen.dart';
import '../../../transactions/presentation/providers/search_provider.dart';

class AccountEntryScreen extends ConsumerStatefulWidget {
  final Account? account; // Null for new, non-null for edit

  const AccountEntryScreen({super.key, this.account});

  @override
  ConsumerState<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends ConsumerState<AccountEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _adjustmentController;
  AccountType _selectedType = AccountType.cash;
  Currency _selectedCurrency = Currency.idr;
  bool _isAdjusting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.account?.initialBalance.toString() ?? '',
    );
    _adjustmentController = TextEditingController();
    if (widget.account != null) {
      _selectedType = widget.account!.type;
      _selectedCurrency = widget.account!.currency;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _adjustmentController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    // Parse using Formatters helper
    final balance = Formatters.parseCurrency(_balanceController.text, currency: _selectedCurrency);

    // Check for duplicate account name (only for new accounts or if name changed)
    final dao = ref.read(accountDaoProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final existingAccounts = profileId != null ? await dao.getAllAccountsIncludingInactive(profileId) : <Account>[];
    
    final isDuplicate = existingAccounts.any((account) {
      // For new account: check if name exists
      if (widget.account == null) {
        return account.name.toLowerCase() == name.toLowerCase();
      }
      // For edit: check if name exists in other accounts
      return account.id != widget.account!.id && 
             account.name.toLowerCase() == name.toLowerCase();
    });

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(translationsProvider).accountNameExists),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (widget.account == null) {
      // Create
      if (profileId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(translationsProvider).accountNoProfile),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      await dao.insertAccount(
        AccountsCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(name),
          type: drift.Value(_selectedType), 
          currency: drift.Value(_selectedCurrency),
          initialBalance: drift.Value(balance),
          icon: const drift.Value('wallet'), // Default
          color: const drift.Value('0xFFD4AF37'), // Default Gold
          isActive: const drift.Value(true),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } else {
      // Update
      await dao.updateAccount(
        widget.account!.copyWith(
          name: name,
          type: _selectedType, 
          currency: _selectedCurrency,
          initialBalance: balance,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _applyAdjustment() async {
    final adjustmentAmount = double.tryParse(_adjustmentController.text) ?? 0.0;
    
    if (adjustmentAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider).accountAdjustmentRequired)),
      );
      return;
    }

    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || widget.account == null) return;

    setState(() => _isAdjusting = true);

    try {
      final transactionDao = ref.read(transactionDaoProvider);

      // Determine if positive (income) or negative (expense) adjustment
      final isPositive = adjustmentAmount > 0;

      await transactionDao.insertTransaction(
        TransactionsCompanion(
          profileId: drift.Value(profileId),
          accountId: drift.Value(widget.account!.id),
          type: drift.Value(isPositive ? TransactionType.income : TransactionType.expense),
          amount: drift.Value(adjustmentAmount.abs()),
          date: drift.Value(DateTime.now()),
          title: const drift.Value('Balance Adjustment'),
          note: drift.Value('Manual adjustment for ${widget.account!.name}'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.read(translationsProvider).accountAdjustmentApplied}: ${isPositive ? '+' : '-'}${Formatters.formatCurrency(adjustmentAmount.abs(), currency: widget.account!.currency, showDecimal: ref.read(showDecimalProvider))}'),
            backgroundColor: AppColors.success,
          ),
        );
        _adjustmentController.text = '0';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdjusting = false);
      }
    }
  }

  void _viewTransactionHistory() {
    if (widget.account == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderScope(
          overrides: [
            transactionAccountFilterProvider.overrideWith((ref) => widget.account!.id),
            transactionSearchQueryProvider.overrideWith((ref) => ''),
            transactionTypeFilterProvider.overrideWith((ref) => null),
            dateFromFilterProvider.overrideWith((ref) => null),
            dateToFilterProvider.overrideWith((ref) => null),
          ],
          child: const TransactionsHistoryScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final balances = ref.watch(accountBalanceProvider);
    final currentBalance = isEditing 
        ? (balances[widget.account!.id] ?? widget.account!.initialBalance)
        : 0.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            title: Text(isEditing 
                ? ref.watch(translationsProvider).accountTitleEdit 
                : ref.watch(translationsProvider).accountTitleAdd, 
                style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: isEditing ? [
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: ref.watch(translationsProvider).accountViewHistory,
                onPressed: _viewTransactionHistory,
              ),
            ] : null,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Balance Card (only in edit mode)
                    if (isEditing) ...[
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Name and Type
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getIconForType(widget.account!.type),
                                    color: AppColors.primaryGold,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.account!.name,
                                        style: AppTypography.textTheme.titleMedium?.copyWith(
                                          color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        widget.account!.type.displayName,
                                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                                          color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppColors.glassBorder),
                            const SizedBox(height: 16),
                            
                            // Balance Display
                            Center(
                              child: Text(
                                '${widget.account!.currency == Currency.idr ? 'IDR' : '\$'} ${Formatters.formatCurrency(currentBalance, currency: widget.account!.currency, showDecimal: showDecimal)}',
                                style: AppTypography.textTheme.displaySmall?.copyWith(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            const Divider(color: AppColors.glassBorder),
                            const SizedBox(height: 16),
                            
                            // Adjustment Section
                            Text(
                              ref.watch(translationsProvider).accountBalanceAdjustment,
                              style: AppTypography.textTheme.labelLarge?.copyWith(
                                 color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref.watch(translationsProvider).accountAdjustmentHint,
                              style: AppTypography.textTheme.labelSmall?.copyWith(
                                 color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassInput(
                                    controller: _adjustmentController,
                                    hintText: 'e.g. 50000 or -50000',
                                    prefixIcon: Icons.tune,
                                    keyboardType: TextInputType.numberWithOptions(signed: true, decimal: showDecimal),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GlassButton(
                                  text: ref.watch(translationsProvider).accountApply,
                                  size: GlassButtonSize.small,
                                  onPressed: _applyAdjustment,
                                  isLoading: _isAdjusting,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // View History Button
                            GlassButton(
                              text: ref.watch(translationsProvider).accountViewHistory,
                              icon: Icons.history,
                              isFullWidth: true,
                              isPrimary: false,
                              onPressed: _viewTransactionHistory,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isEditing) ...[
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.glassBorder),
                      const SizedBox(height: 24),
                      Text(
                        ref.watch(translationsProvider).accountEditDetails,
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                           color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassInput(
                        controller: _nameController,
                        hintText: ref.watch(translationsProvider).accountNameHint,
                        prefixIcon: Icons.label,
                        validator: (v) => v!.isEmpty ? ref.watch(translationsProvider).accountNameExists : null, // Reusing localized error or add specific one. Wait "Name required"
                      ),
                      const SizedBox(height: 16),
                        GlassInput(
                        controller: _balanceController,
                        hintText: isEditing ? ref.watch(translationsProvider).accountStartingBalanceHint : ref.watch(translationsProvider).accountBalanceHint,
                        prefixIcon: Icons.monetization_on,
                        keyboardType: TextInputType.numberWithOptions(decimal: showDecimal),
                        inputFormatters: [
                          CurrencyInputFormatter(
                            currency: _selectedCurrency,
                            showDecimal: showDecimal,
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) { // Allow '0' as valid start balance
                            // But wait, if empty string, we might want to say required.
                            // If user clears field, v is empty.
                            return ref.watch(translationsProvider).accountBalanceRequired;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),
                      Text(ref.watch(translationsProvider).accountType, style: AppTypography.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: AccountType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return ChoiceChip(
                            label: Text(type.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedType = type);
                            },
                            selectedColor: AppColors.primaryGold,
                            backgroundColor: isDarkMode ? AppColors.glassBackground : AppColors.glassBackgroundLight,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : (isDarkMode ? Colors.white : AppColors.textPrimaryLight),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(ref.watch(translationsProvider).accountCurrency, style: AppTypography.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: Currency.values.map((currency) {
                          final isSelected = _selectedCurrency == currency;
                          return ChoiceChip(
                            label: Text(currency.code),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCurrency = currency);
                            },
                            selectedColor: AppColors.primaryGold,
                            backgroundColor: isDarkMode ? AppColors.glassBackground : AppColors.glassBackgroundLight,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : (isDarkMode ? Colors.white : AppColors.textPrimaryLight),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      GlassButton(
                        text: ref.watch(translationsProvider).accountSave,
                        isFullWidth: true,
                        size: GlassButtonSize.large,
                        onPressed: _saveAccount,
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
  IconData _getIconForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.wallet;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.eWallet:
        return Icons.phone_android;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }
}
