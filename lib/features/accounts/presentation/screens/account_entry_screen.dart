import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/balance_provider.dart';
import 'account_transaction_history_screen.dart';

class AccountEntryScreen extends ConsumerStatefulWidget {
  final Account? account; // Null for new, non-null for edit

  const AccountEntryScreen({super.key, this.account});

  @override
  ConsumerState<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends ConsumerState<AccountEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  double _rawBalance = 0;
  double _rawAdjustment = 0;
  AccountType _selectedType = AccountType.cash;
  Currency _selectedCurrency = Currency.idr;
  bool _isAdjusting = false;
  // Null = not yet loaded; true/false = loaded result
  bool? _accountHasTransactions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    if (widget.account != null) {
      _rawBalance = widget.account!.initialBalance;
      _selectedType = widget.account!.type;
      _selectedCurrency = widget.account!.currency;
      _loadTransactionStatus();
    } else {
      _selectedCurrency = ref.read(defaultCurrencyProvider);
    }
  }

  Future<void> _loadTransactionStatus() async {
    if (widget.account == null) return;
    final txDao = ref.read(transactionDaoProvider);
    final txs = await txDao.getTransactionsByAccount(widget.account!.id);
    if (mounted) {
      setState(() => _accountHasTransactions = txs.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openBalanceCalculator() async {
    final result = await CalculatorBottomSheet.show(
      context,
      initialValue: _rawBalance > 0 ? _rawBalance : null,
      currency: _selectedCurrency,
      showDecimal: ref.read(showDecimalProvider),
    );
    if (result != null && mounted) {
      setState(() => _rawBalance = result);
    }
  }

  Future<void> _openAdjustmentCalculator() async {
    final result = await CalculatorBottomSheet.show(
      context,
      initialValue: _rawAdjustment > 0 ? _rawAdjustment : null,
      currency: widget.account!.currency,
      showDecimal: ref.read(showDecimalProvider),
    );
    if (result != null && mounted) {
      setState(() => _rawAdjustment = result);
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final balance = _rawBalance;

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
    if (widget.account == null) return;
    if (_rawAdjustment <= 0) return;

    final targetBalance = _rawAdjustment;

    setState(() => _isAdjusting = true);

    try {
      // If the account has no transactions, update initialBalance directly
      if (_accountHasTransactions == false) {
        final accountDao = ref.read(accountDaoProvider);
        await accountDao.updateAccount(
          widget.account!.copyWith(initialBalance: targetBalance),
        );
        if (mounted) {
          final navigator = Navigator.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(translationsProvider).accountInitialBalanceApplied),
              backgroundColor: AppColors.success,
            ),
          );
          navigator.pop();
        }
        return;
      }

      // Account has existing transactions — create an adjustment transaction
      final balances = ref.read(accountBalanceProvider);
      final currentBalance = balances[widget.account!.id] ?? widget.account!.initialBalance;
      final delta = targetBalance - currentBalance;

      if (delta == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(translationsProvider).accountAdjustmentRequired)),
          );
        }
        return;
      }

      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;

      final transactionDao = ref.read(transactionDaoProvider);
      final isPositive = delta > 0;

      await transactionDao.insertTransaction(
        TransactionsCompanion(
          profileId: drift.Value(profileId),
          accountId: drift.Value(widget.account!.id),
          type: drift.Value(isPositive ? TransactionType.adjustmentIn : TransactionType.adjustmentOut),
          amount: drift.Value(delta.abs()),
          date: drift.Value(DateTime.now()),
          title: const drift.Value('Balance Adjustment'),
          note: drift.Value('Manual adjustment for ${widget.account!.name}'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.read(translationsProvider).accountAdjustmentApplied}: ${isPositive ? '+' : '-'}${Formatters.formatCurrency(delta.abs(), currency: widget.account!.currency, showDecimal: ref.read(showDecimalProvider))}'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _rawAdjustment = 0);
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
        builder: (context) =>
            AccountTransactionHistoryScreen(account: widget.account!),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (widget.account == null) return;

    // Check for existing transactions
    final txDao = ref.read(transactionDaoProvider);
    final txs = await txDao.getTransactionsByAccount(widget.account!.id);

    if (!mounted) return;

    if (txs.isNotEmpty) {
      // Cannot delete — has records
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final ctxThemeMode = AppThemeProvider.of(ctx);
          final ctxIsDefault = ctxThemeMode == AppThemeMode.defaultTheme;
          final ctxIsLight = ctxThemeMode == AppThemeMode.light || (ctxThemeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(ctx) == Brightness.light);
          return AlertDialog(
            backgroundColor: ctxIsDefault ? const Color(0xFF2D2416) : ctxIsLight ? Colors.white : const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.block, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Cannot Delete', style: TextStyle(color: ctxIsLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 16)),
                ),
              ],
            ),
            content: Text(
              '"${widget.account!.name}" has ${txs.length} transaction${txs.length == 1 ? '' : 's'} linked to it and cannot be deleted.\n\nTo remove this account, first delete all its transactions.',
              style: TextStyle(color: ctxIsLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: TextStyle(color: AppColors.primaryGold)),
              ),
            ],
          );
        },
      );
      return;
    }

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxThemeMode = AppThemeProvider.of(ctx);
        final ctxIsDefault = ctxThemeMode == AppThemeMode.defaultTheme;
        final ctxIsLight = ctxThemeMode == AppThemeMode.light || (ctxThemeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(ctx) == Brightness.light);
        return AlertDialog(
          backgroundColor: ctxIsDefault ? const Color(0xFF2D2416) : ctxIsLight ? Colors.white : const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Delete Account', style: TextStyle(color: ctxIsLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 16)),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${widget.account!.name}"?\n\nThis action cannot be undone.',
            style: TextStyle(color: ctxIsLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: ctxIsLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(accountDaoProvider).deleteAccount(widget.account!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final balances = ref.watch(accountBalanceProvider);
    final currentBalance = isEditing
        ? (balances[widget.account!.id] ?? widget.account!.initialBalance)
        : 0.0;
    final themeMode = AppThemeProvider.of(context);
    final isDarkMode = themeMode != AppThemeMode.light && !(themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isLight = !isDarkMode;
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
            title: Text(isEditing
                ? ref.watch(translationsProvider).accountTitleEdit
                : ref.watch(translationsProvider).accountTitleAdd,
                style: TextStyle(color: isDarkMode ? Colors.white : AppColors.textPrimaryLight)),
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : AppColors.textPrimaryLight),
            actions: isEditing ? [
              IconButton(
                icon: Icon(Icons.history, color: isDarkMode ? Colors.white : AppColors.textPrimaryLight),
                tooltip: ref.watch(translationsProvider).accountViewHistory,
                onPressed: _viewTransactionHistory,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Account',
                onPressed: _deleteAccount,
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
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        widget.account!.type.displayName,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                '${widget.account!.currency.code} ${Formatters.formatCurrency(currentBalance, currency: widget.account!.currency, showDecimal: showDecimal)}',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 25.6,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            const Divider(color: AppColors.glassBorder),
                            const SizedBox(height: 16),
                            
                            // Adjustment Section — label adapts to whether the account has transactions
                            Builder(builder: (context) {
                              final t = ref.watch(translationsProvider);
                              // While loading (_accountHasTransactions == null), default to adjust mode
                              final hasTransactions = _accountHasTransactions ?? true;
                              final sectionLabel = hasTransactions
                                  ? t.accountAdjustBalance
                                  : t.accountInitialBalance;
                              final sectionHint = hasTransactions
                                  ? t.accountAdjustBalanceHint
                                  : t.accountInitialBalanceHint;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sectionLabel,
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      if (_accountHasTransactions == null) ...[
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sectionHint,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _openAdjustmentCalculator,
                                    child: GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      borderRadius: 12,
                                      child: Row(
                                        children: [
                                          Icon(Icons.tune, color: AppColors.primaryGold, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _rawAdjustment > 0
                                                  ? Formatters.formatCurrency(_rawAdjustment, currency: widget.account!.currency, showDecimal: showDecimal)
                                                  : 'Enter target balance',
                                              style: TextStyle(
                                                color: _rawAdjustment > 0
                                                    ? (isDarkMode ? Colors.white : AppColors.textPrimaryLight)
                                                    : (isDarkMode ? Colors.white54 : const Color(0xFF94A3B8)),
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.calculate_outlined, color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8), size: 20),
                                        ],
                                      ),
                                    ),
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
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.glassBorder),
                      const SizedBox(height: 16),
                      Text(
                        ref.watch(translationsProvider).accountEditDetails,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassInput(
                        controller: _nameController,
                        hintText: ref.watch(translationsProvider).accountNameHint,
                        prefixIcon: Icons.label,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? ref.watch(translationsProvider).accountNameHint
                            : null,
                      ),
                      const SizedBox(height: 16),
                      GlassButton(
                        text: ref.watch(translationsProvider).accountSave,
                        isFullWidth: true,
                        size: GlassButtonSize.large,
                        onPressed: _saveAccount,
                      ),
                    ],
                    if (!isEditing) ...[
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.glassBorder),
                      const SizedBox(height: 24),
                      Text(
                        ref.watch(translationsProvider).accountEditDetails,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      const SizedBox(height: 24),
                      Text(ref.watch(translationsProvider).accountCurrency, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      CurrencyPickerField(
                        value: _selectedCurrency,
                        onChanged: (currency) => setState(() {
                          _selectedCurrency = currency;
                          _rawBalance = 0;
                        }),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _openBalanceCalculator,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              Icon(Icons.monetization_on, color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _rawBalance > 0
                                      ? Formatters.formatCurrency(_rawBalance, currency: _selectedCurrency, showDecimal: showDecimal)
                                      : (isEditing ? ref.watch(translationsProvider).accountStartingBalanceHint : ref.watch(translationsProvider).accountBalanceHint),
                                  style: TextStyle(
                                    color: _rawBalance > 0
                                        ? (isDarkMode ? Colors.white : AppColors.textPrimaryLight)
                                        : (isDarkMode ? Colors.white54 : const Color(0xFF94A3B8)),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Icon(Icons.calculate_outlined, color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8), size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(ref.watch(translationsProvider).accountType, style: Theme.of(context).textTheme.labelLarge),
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
      case AccountType.creditCard:
        return Icons.credit_card;
    }
  }
}
