import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';

import '../../../../shared/utils/formatters.dart';

import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../widgets/category_selector.dart';
import '../widgets/add_category_dialog.dart';
import '../../../../shared/widgets/generic_searchable_dropdown.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/recurring_service.dart';
import '../widgets/account_selector.dart';
import '../widgets/add_account_dialog.dart';
import '../../../../shared/widgets/category_icon_widget.dart';

class TransactionEntryScreen extends ConsumerStatefulWidget {
  final int? transactionId;  // If provided, edit mode
  /// When provided, pre-sets the transaction type before the first build,
  /// preventing an AnimatedSwitcher mid-animation setState during edit loads.
  final TransactionType? transactionType;

  const TransactionEntryScreen({super.key, this.transactionId, this.transactionType});

  @override
  ConsumerState<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends ConsumerState<TransactionEntryScreen> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _selectedAccountId;
  int? _selectedToAccountId;
  int? _selectedCategoryId;
  
  // Currency Conversion (background)
  double? _estimatedDestinationAmount;
  double? _exchangeRate;
  
  // Suggested Titles
  List<String> _frequentTitles = [];
  String _titleFilter = '';

  // Raw amount value (without formatting)
  String _rawAmount = '';

  // Original values when editing (to correctly validate balance changes)
  double? _originalAmount;
  int? _originalAccountId;

  // Focus node for title field (to detect when user finishes typing)
  final _titleFocusNode = FocusNode();

  // Track if auto-select has been applied (only once per title)
  bool _autoSelectApplied = false;

  // Swipe animation direction for tab switching
  double _slideDirection = 1.0;
  static const _typeOptions = [
    TransactionType.income,
    TransactionType.expense,
    TransactionType.transfer,
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = '0';  // Default to single zero

    // Pre-set the transaction type synchronously before the first build so that
    // edit mode never triggers AnimatedSwitcher mid-animation via setState.
    if (widget.transactionType != null) {
      _selectedType = widget.transactionType!;
    }

    // Filter bubbles as user types
    _titleController.addListener(_onTitleChanged);

    // Listen for title field focus loss to auto-select account/category (new only)
    if (widget.transactionId == null) {
      _titleFocusNode.addListener(_onTitleFocusChanged);
    }

    // Delay work until the page transition animation has completed so that
    // heavy operations don't compete with the incoming route animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route?.animation?.isCompleted == true) {
        _loadFrequentTitles();
      } else {
        route?.animation?.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _loadFrequentTitles();
          }
        });
      }
    });

    // Load transaction data if editing — wait for the route animation to finish
    // so the setState inside _loadTransaction doesn't compete with the slide-in.
    if (widget.transactionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context);
        if (route?.animation?.isCompleted == true || route?.animation == null) {
          _loadTransaction();
        } else {
          route?.animation?.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _loadTransaction();
            }
          });
        }
      });
    } else {
      // Auto-open calculator for new transactions — wait for transition to finish
      // so the bottom sheet doesn't fight the page slide animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context);
        if (route?.animation?.isCompleted == true) {
          _autoOpenCalculator();
        } else {
          route?.animation?.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _autoOpenCalculator();
            }
          });
        }
      });
    }
  }

  Color _parseCategoryColor(String? hex) {
    if (hex == null || hex == 'transparent') return Colors.white.withValues(alpha: 0.1);
    final cleaned = hex.replaceFirst('#', '0xFF');
    return Color(int.tryParse(cleaned) ?? 0xFF808080).withValues(alpha: 0.2);
  }

  Future<void> _loadTransaction() async {
    final dao = ref.read(transactionDaoProvider);
    final transaction = await dao.getTransactionById(widget.transactionId!);
    
    if (transaction != null && mounted) {
      // Get account to determine currency
      final accountDao = ref.read(accountDaoProvider);
      final account = await accountDao.getAccountById(transaction.accountId);
      if (!mounted) return;
      final Currency currency = account?.currency ?? ref.read(defaultCurrencyProvider);
      final showDecimal = ref.read(showDecimalProvider);

      setState(() {
        _selectedType = transaction.type;
        _selectedAccountId = transaction.accountId;
        _selectedCategoryId = transaction.categoryId;
        _selectedToAccountId = transaction.toAccountId;
        _selectedDate = transaction.date;
        _selectedTime = TimeOfDay.fromDateTime(transaction.date);
        _rawAmount = transaction.amount.toString();
        _originalAmount = transaction.amount;
        _originalAccountId = transaction.accountId;
        
        // Format amount
        _amountController.text = Formatters.formatCurrency(
          transaction.amount, 
          currency: currency, 
          showDecimal: showDecimal
        );

        _titleController.text = transaction.title ?? '';
        _noteController.text = transaction.note ?? '';
        _estimatedDestinationAmount = transaction.destinationAmount;
        _exchangeRate = transaction.exchangeRate;
      });
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleFocusNode.dispose();
    _titleController.removeListener(_onTitleChanged);
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _autoOpenCalculator() async {
    if (!mounted) return;
    final accountsAsync = ref.read(accountsStreamProvider);
    final accounts = accountsAsync.valueOrNull;
    final currency = accounts != null ? _getCurrency(accounts) : ref.read(defaultCurrencyProvider);
    final showDecimal = ref.read(showDecimalProvider);

    final result = await CalculatorBottomSheet.show(
      context,
      initialValue: 0,
      currency: currency,
      showDecimal: showDecimal,
    );
    if (result != null && mounted) {
      setState(() {
        _rawAmount = result.toString();
        _amountController.text = Formatters.formatCurrency(
          result,
          currency: currency,
          showDecimal: showDecimal,
        );
      });
    }
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus) {
      _autoSelectFromTitle(_titleController.text.trim());
    }
  }

  Future<void> _autoSelectFromTitle(String title) async {
    if (title.isEmpty) return;
    if (widget.transactionId != null) return; // edit mode, skip
    if (_autoSelectApplied && _selectedAccountId != null) return;

    final dao = ref.read(transactionDaoProvider);
    final profileId = ref.read(activeProfileIdProvider);

    // Auto-select account if not already selected
    if (_selectedAccountId == null) {
      final accountId = await dao.getMostUsedAccountForTitle(title, _selectedType, profileId: profileId);
      if (accountId != null && mounted) {
        setState(() => _selectedAccountId = accountId);
      }
    }

    // Auto-select category if not already selected (skip for transfers)
    if (_selectedCategoryId == null && _selectedType != TransactionType.transfer) {
      final categoryId = await dao.getMostUsedCategoryForTitle(title, _selectedType, profileId: profileId);
      if (categoryId != null && mounted) {
        setState(() => _selectedCategoryId = categoryId);
      }
    }

    _autoSelectApplied = true;
  }

  void _onTitleChanged() {
    final text = _titleController.text.trim();
    if (text != _titleFilter) {
      setState(() => _titleFilter = text);
      // Reset auto-select when title changes so it can re-trigger
      _autoSelectApplied = false;
    }
  }

  Future<void> _loadFrequentTitles() async {
    final profileId = ref.read(activeProfileIdProvider);
    final titles = await ref.read(transactionDaoProvider)
        .getMostFrequentTitlesByType(_selectedType, 100, profileId: profileId);
    if (mounted) {
      setState(() => _frequentTitles = titles);
    }
  }

  List<String> get _filteredTitles {
    if (_titleFilter.isEmpty) return _frequentTitles;
    final q = _titleFilter.toLowerCase();
    return _frequentTitles.where((t) => t.toLowerCase().contains(q)).toList();
  }

  bool _isSaving = false;

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    
    // Capture messenger and navigator early to avoid "deactivated widget" errors after async gaps
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Unfocus to prevent keyboard/focus issues during navigation
    FocusScope.of(context).unfocus();

    if (_selectedAccountId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    
    if (_selectedType == TransactionType.transfer && _selectedToAccountId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a destination account')),
      );
      return;
    }
    
    if (_selectedType != TransactionType.transfer && _selectedCategoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amount = double.tryParse(_rawAmount) ?? 0.0;
    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check if selected account is a credit card (no balance limit)
      final selectedAccount = await ref.read(accountDaoProvider).getAccountById(_selectedAccountId!);
      final isCreditCard = selectedAccount?.type.isCreditCard ?? false;

      // Validate sufficient balance for expenses and transfers
      final isEditing = widget.transactionId != null;
      final sameAccount = _selectedAccountId == _originalAccountId;
      // Skip only when editing the same account with the same amount (net effect on balance is zero)
      final skipBalanceCheck = isEditing && _originalAmount != null && sameAccount && amount == _originalAmount;

      if ((_selectedType == TransactionType.expense || _selectedType == TransactionType.transfer) &&
          !isCreditCard && !skipBalanceCheck) {
        final accountBalance = await ref.read(transactionDaoProvider).calculateAccountBalance(_selectedAccountId!);
        // When editing the same account, add back the original amount since it's already deducted
        // in the stored balance. This gives the true available balance before this transaction.
        final effectiveBalance = (isEditing && sameAccount && _originalAmount != null)
            ? accountBalance + _originalAmount!
            : accountBalance;
        if (amount > effectiveBalance) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Insufficient balance. Available: ${Formatters.formatNumber(effectiveBalance)}')),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }
      
      final dao = ref.read(transactionDaoProvider);

      double? finalDestinationAmount;
      double? finalExchangeRate;

      // Check for cross-currency transfer
      if (_selectedType == TransactionType.transfer && _selectedToAccountId != null) {
        final accountDao = ref.read(accountDaoProvider);
        final fromAccount = await accountDao.getAccountById(_selectedAccountId!);
        final toAccount = await accountDao.getAccountById(_selectedToAccountId!);

        if (fromAccount != null && toAccount != null) {
           if (fromAccount.currency != toAccount.currency) {
              if (!mounted) return;
              
              // Always show dialog for cross-currency to ensure we get the correct receiving amount
              final destinationAmount = await _showConversionDialog(
                context, 
                amount, 
                fromAccount.currency, 
                toAccount.currency
              );

              if (destinationAmount == null) {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
                return; // User cancelled
              }
              
              // EXPLICITLY set values
              finalDestinationAmount = destinationAmount;
              if (destinationAmount > 0) {
                finalExchangeRate = amount / destinationAmount;
                
                // Append rate note
                 final rateText = 'Rate: 1 ${toAccount.currency.code} = ${Formatters.formatNumber(finalExchangeRate!)} ${fromAccount.currency.code}';
                if (!_noteController.text.contains('Rate:')) {
                   if (_noteController.text.isNotEmpty) {
                    _noteController.text += '\n$rateText';
                  } else {
                    _noteController.text = rateText;
                  }
                }
              }
           } else {
             // Same currency
             finalDestinationAmount = amount;
             finalExchangeRate = 1.0;
           }
        }
      }

      // If it is a transfer but NOT cross-currency (or accounts not loaded?), default to amount
      if (_selectedType == TransactionType.transfer && finalDestinationAmount == null) {
         finalDestinationAmount = amount;
         finalExchangeRate = 1.0;
      }
      
      // Update state for next time
      _estimatedDestinationAmount = finalDestinationAmount;
      _exchangeRate = finalExchangeRate;

      final transactionCompanion = TransactionsCompanion(
        profileId: ref.read(activeProfileIdProvider) != null ? drift.Value(ref.read(activeProfileIdProvider)!) : const drift.Value.absent(),
        accountId: drift.Value(_selectedAccountId!),
        categoryId: _selectedCategoryId != null ? drift.Value(_selectedCategoryId!) : const drift.Value.absent(),
        toAccountId: _selectedToAccountId != null ? drift.Value(_selectedToAccountId!) : const drift.Value.absent(),
        destinationAmount: finalDestinationAmount != null ? drift.Value(finalDestinationAmount) : const drift.Value.absent(),
        exchangeRate: finalExchangeRate != null ? drift.Value(finalExchangeRate) : const drift.Value.absent(),
        type: drift.Value(_selectedType),
        amount: drift.Value(amount),
        date: drift.Value(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute)),
        title: drift.Value(_titleController.text),
        note: drift.Value(_noteController.text),
        createdAt: widget.transactionId == null ? drift.Value(DateTime.now()) : const drift.Value.absent(),
      );

      if (widget.transactionId != null) {
        // Update existing transaction
        await dao.updateTransaction(widget.transactionId!, transactionCompanion);
      } else {
        // Insert new transaction
        if (transactionCompanion.profileId.present) {
           await dao.insertTransaction(transactionCompanion);
           // TODO: Ideally only fire on the first ever transaction (count == 0
           // before insert). For now fires on every new transaction save.
           AnalyticsService.trackFirstTransactionAdded();
        } else {
           if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('No active profile. Please set up a profile first.')),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }
      
      if (mounted) {
        navigator.pop();
      }
    } catch (e, stackTrace) {


      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }


  Currency _getCurrency(List<Account> accounts) {
    if (_selectedAccountId == null) return ref.read(defaultCurrencyProvider);
    // Find account or default
    try {
      return accounts.firstWhere((a) => a.id == _selectedAccountId).currency;
    } catch (_) {
      return ref.read(defaultCurrencyProvider);
    }
  }

  Future<void> _selectDate() async {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final pickerSurface = isDefault ? const Color(0xFF221D10) : isLight ? Colors.white : const Color(0xFF0A0A0A);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: isLight ? ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGold,
              surface: pickerSurface,
            ),
          ) : ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryGold,
              surface: pickerSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final pickerSurface = isDefault ? const Color(0xFF221D10) : isLight ? Colors.white : const Color(0xFF0A0A0A);
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: isLight ? ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGold,
              surface: pickerSurface,
            ),
          ) : ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryGold,
              surface: pickerSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _deleteTransaction() async {
    if (widget.transactionId == null) return;

    // Unfocus to prevent keyboard/focus issues during navigation
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show confirmation dialog
    final themeModeDelete = AppThemeProvider.of(context);
    final isLightDelete = themeModeDelete == AppThemeMode.light || (themeModeDelete == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefaultDelete = themeModeDelete == AppThemeMode.defaultTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDefaultDelete ? const Color(0xFF2D2416) : isLightDelete ? Colors.white : const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Transaction?',
              style: TextStyle(color: isLightDelete ? AppColors.textPrimaryLight : Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone. The account balance will be updated accordingly.',
          style: TextStyle(color: isLightDelete ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isLightDelete ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dao = ref.read(transactionDaoProvider);
      await dao.deleteTransaction(widget.transactionId!);

      final title = _titleController.text;
      final profileId = ref.read(activeProfileIdProvider);

      // Debt settlement deleted → reverse paid amount on the debt
      const paymentPrefix = 'Debt Payment: ';
      if (title.startsWith(paymentPrefix) && _originalAmount != null && profileId != null) {
        final personName = title.substring(paymentPrefix.length).trim();
        if (personName.isNotEmpty) {
          await ref.read(debtDaoProvider).reverseDebtPayment(profileId, personName, _originalAmount!);
        }
      }

      // Debt creation transaction deleted → delete the linked debt record
      const creationPrefix = 'Debt: ';
      if ((_selectedType == TransactionType.debtIn || _selectedType == TransactionType.debtOut) &&
          title.startsWith(creationPrefix) && profileId != null) {
        final personName = title.substring(creationPrefix.length).trim();
        if (personName.isNotEmpty) {
          final debtType = _selectedType == TransactionType.debtIn ? DebtType.payable : DebtType.receivable;
          final txDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day,
            _selectedTime.hour, _selectedTime.minute,
          );
          final debt = await ref.read(debtDaoProvider).findDebtByNameAndType(
            profileId, personName, debtType,
            accountId: _selectedAccountId,
            date: txDate,
          );
          if (debt != null) {
            await ref.read(debtDaoProvider).deleteDebt(debt.id);
          }
        }
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    navigator.pop(true);
  }

  Future<void> _addNote() async {
    final themeModeNote = AppThemeProvider.of(context);
    final isLightNote = themeModeNote == AppThemeMode.light || (themeModeNote == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefaultNote = themeModeNote == AppThemeMode.defaultTheme;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDefaultNote ? const Color(0xFF1A1410) : isLightNote ? const Color(0xFFF8FAFC) : const Color(0xFF111111),
        title: Text('Add Note', style: TextStyle(color: isLightNote ? AppColors.textPrimaryLight : Colors.white)),
        content: TextField(
          controller: _noteController,
          autofocus: true,
          style: TextStyle(color: isLightNote ? AppColors.textPrimaryLight : Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: isLightNote ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isLightNote ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryGold),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isLightNote ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _noteController.text),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {});
    }
  }

  Future<double?> _showConversionDialog(
    BuildContext context, 
    double sourceAmount,
    Currency fromCurrency, 
    Currency toCurrency,
  ) async {
    final controller = TextEditingController();
    
    final themeModeConv = AppThemeProvider.of(context);
    final isLightConv = themeModeConv == AppThemeMode.light || (themeModeConv == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefaultConv = themeModeConv == AppThemeMode.defaultTheme;
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDefaultConv ? const Color(0xFF1A1410) : isLightConv ? const Color(0xFFF8FAFC) : const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Currency Conversion', style: TextStyle(color: isLightConv ? AppColors.textPrimaryLight : Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sending: ${Formatters.formatCurrency(sourceAmount, currency: fromCurrency)}',
              style: TextStyle(color: isLightConv ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              'Amount Received in ${toCurrency.code}:', // e.g. USD
              style: TextStyle(color: isLightConv ? AppColors.textPrimaryLight : Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: isLightConv ? AppColors.textPrimaryLight : Colors.white),
              decoration: InputDecoration(
                prefixText: '${toCurrency.symbol} ',
                prefixStyle: const TextStyle(color: AppColors.primaryGold),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isLightConv ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryGold),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isLightConv ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              // Use robust parser based on target currency
              final amount = Formatters.parseCurrency(controller.text, currency: toCurrency);
              if (amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _getCurrencyPrefix(List<Account> accounts) {
    if (_selectedAccountId == null) return '${ref.read(defaultCurrencyProvider).code} ';
    final account = accounts.firstWhere((a) => a.id == _selectedAccountId);
    return '${account.currency.code} ';
  }

  void _switchType(TransactionType newType) {
    final oldIndex = _typeOptions.indexOf(_selectedType);
    final newIndex = _typeOptions.indexOf(newType);
    if (oldIndex == newIndex) return;
    setState(() {
      _slideDirection = newIndex > oldIndex ? 1.0 : -1.0;
      _selectedType = newType;
    });
    _loadFrequentTitles();
  }

  String _formatDateDisplay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    if (selectedDay == today) {
      return ref.read(translationsProvider).commonToday;
    } else if (selectedDay == today.subtract(const Duration(days: 1))) {
      return ref.read(translationsProvider).commonYesterday;
    } else {
      return DateFormat('MMM dd, yyyy').format(_selectedDate);
    }
  }



  Future<void> _openAddAccountDialog({required bool isToAccount}) async {
    // Small delay so the bottom sheet fully closes before showing the dialog
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final newId = await showDialog<int>(
      context: context,
      builder: (ctx) => const AddAccountDialog(),
    );

    if (newId != null && mounted) {
      setState(() {
        if (isToAccount) {
          _selectedToAccountId = newId;
        } else {
          _selectedAccountId = newId;
        }
      });
    }
  }

  Widget _buildAccountSelector({
    required BuildContext context,
    required List<Account> accounts,
    required bool isToAccount,
    required String label,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final selectedId = isToAccount ? _selectedToAccountId : _selectedAccountId;
    final selectedAccount = accounts.where((a) => a.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
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
                child: AccountSelector(
                  accounts: accounts,
                  selectedAccountId: selectedId,
                  showDecimal: ref.read(showDecimalProvider),
                  onAccountSelected: (id) {
                    setState(() {
                      if (isToAccount) {
                        _selectedToAccountId = id;
                      } else {
                        _selectedAccountId = id;
                      }
                    });
                  },
                  onAddNew: () => _openAddAccountDialog(isToAccount: isToAccount),
                ),
              ),
            );
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryGold.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedAccount?.name ?? ref.read(translationsProvider).entrySelectAccount,
                    style: TextStyle(
                      color: selectedAccount != null
                          ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                          : (isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4)),
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// ... inside build method ...
                    // Account Selection
  @override
  Widget build(BuildContext context) {
    // Watch translations
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: Colors.transparent, // const Color(0xFF221D10),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: isLight ? AppColors.textPrimaryLight : Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.transactionId != null ? trans.entryTitleEdit : trans.entryTitleAdd,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.transactionId != null) // Only show in edit mode
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _deleteTransaction,
                          tooltip: trans.delete,
                        ),
                      if (_selectedType != TransactionType.transfer)
                        IconButton(
                          icon: Icon(Icons.repeat, color: isLight ? AppColors.textPrimaryLight : Colors.white),
                          onPressed: _showRecurringDialog,
                          tooltip: 'Set as Recurring',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Amount Input Section
                    Column(
                      children: [
                        Text(
                          trans.entryAmount,
                          style: TextStyle(
                            color: AppColors.primaryGold.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        accountsAsync.when(
                          data: (accounts) {
                            final prefix = _getCurrencyPrefix(accounts);
                            final currency = _getCurrency(accounts);
                            final showDecimal = ref.watch(showDecimalProvider);
                            return GestureDetector(
                              onTap: () async {
                                // Dismiss any active keyboard
                                FocusScope.of(context).unfocus();

                                final currentAmount = double.tryParse(_rawAmount) ?? 0.0;
                                final result = await CalculatorBottomSheet.show(
                                  context,
                                  initialValue: currentAmount,
                                  currency: currency,
                                  showDecimal: showDecimal,
                                );
                                if (result != null && mounted) {
                                  setState(() {
                                    _rawAmount = result.toString();
                                    _amountController.text = Formatters.formatCurrency(
                                      result,
                                      currency: currency,
                                      showDecimal: showDecimal,
                                    );
                                  });
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    prefix.trim(),
                                    style: const TextStyle(
                                      color: AppColors.primaryGold,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _amountController.text.isEmpty || _amountController.text == '0'
                                          ? '0'
                                          : _amountController.text,
                                      style: TextStyle(
                                        color: _amountController.text.isEmpty || _amountController.text == '0'
                                            ? (isLight ? const Color(0xFFCBD5E1) : Colors.white24)
                                            : (isLight ? AppColors.textPrimaryLight : Colors.white),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.calculate_outlined,
                                    color: AppColors.primaryGold.withValues(alpha: 0.5),
                                    size: 24,
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                          error: (_, __) => const Text('Error loading accounts'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Transaction Type Segmented Control
                    GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final currentIndex = _typeOptions.indexOf(_selectedType);
                        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                          if (currentIndex < 2) _switchType(_typeOptions[currentIndex + 1]);
                        } else if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                          if (currentIndex > 0) _switchType(_typeOptions[currentIndex - 1]);
                        }
                      },
                      child: GlassSegmentedControl<TransactionType>(
                        value: _selectedType,
                        options: const [
                          TransactionType.income,
                          TransactionType.expense,
                          TransactionType.transfer,
                        ],
                        labels: [trans.entryTypeIncome, trans.entryTypeExpense, trans.entryTypeTransfer],
                        onChanged: _switchType,
                        highlightValue: TransactionType.expense,
                      ),
                    ),

                    const SizedBox(height: 20),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Column(
                        key: ValueKey(_selectedType),
                        children: [
                          // Debt info banner (edit mode only)
                          if (widget.transactionId != null && (
                              _selectedType == TransactionType.debtIn ||
                              _selectedType == TransactionType.debtOut ||
                              _titleController.text.startsWith('Debt Payment: '))) ...[
                            Builder(builder: (context) {
                              final isCreation = _selectedType == TransactionType.debtIn || _selectedType == TransactionType.debtOut;
                              final title = _titleController.text;
                              final prefix = isCreation ? 'Debt: ' : 'Debt Payment: ';
                              final personName = title.startsWith(prefix)
                                  ? title.substring(prefix.length).trim()
                                  : title;
                              final typeLabel = _selectedType == TransactionType.debtIn
                                  ? trans.debtPayable
                                  : _selectedType == TransactionType.debtOut
                                      ? trans.debtReceivable
                                      : (isCreation ? '' : trans.debtSettle);

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined,
                                        color: AppColors.primaryGold, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCreation ? 'Debt Record' : 'Debt Payment',
                                            style: const TextStyle(
                                              color: AppColors.primaryGold,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '$personName${typeLabel.isNotEmpty ? ' · $typeLabel' : ''}',
                                            style: TextStyle(
                                              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Edit debt details in the Debt module',
                                            style: TextStyle(
                                              color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                          ],

                          // Title Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  trans.entryTitle.toUpperCase(),
                                  style: TextStyle(
                                    color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.title,
                                      color: AppColors.primaryGold.withValues(alpha: 0.8),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _titleController,
                                        focusNode: _titleFocusNode,
                                        style: TextStyle(
                                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: trans.entryTitleHint,
                                          hintStyle: TextStyle(
                                            color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                                            fontSize: 15,
                                          ),
                                        ),
                                        onSubmitted: (_) {
                                          if (widget.transactionId == null) {
                                            _autoSelectFromTitle(_titleController.text.trim());
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Frequent Titles Suggestions (filtered by type + text input)
                              if (_filteredTitles.isNotEmpty)
                                Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(top: 12),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filteredTitles.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final title = _filteredTitles[index];
                                      return GestureDetector(
                                        onTap: () {
                                          _titleController.text = title;
                                          _titleController.selection = TextSelection.fromPosition(
                                            TextPosition(offset: title.length),
                                          );
                                          // Auto-select account/category for new transactions
                                          if (widget.transactionId == null) {
                                            _autoSelectFromTitle(title);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.9),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Category Dropdown
                          if (_selectedType != TransactionType.transfer)
                            categoriesAsync.when(
                              data: (categories) {
                                // Categories loaded

                                // Convert TransactionType to CategoryType
                                CategoryType? categoryType;
                                if (_selectedType == TransactionType.income) {
                                  categoryType = CategoryType.income;
                                } else if (_selectedType == TransactionType.expense) {
                                  categoryType = CategoryType.expense;
                                }

                                final filteredCategories = categoryType != null
                                    ? categories.where((c) => c.type == categoryType).toList()
                                    : <Category>[];

                                // Get selected category
                                final selectedCategory = filteredCategories
                                    .where((c) => c.id == _selectedCategoryId)
                                    .firstOrNull;

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
                                              categories: filteredCategories,
                                              selectedCategoryId: _selectedCategoryId,
                                              onCategorySelected: (id) {
                                                setState(() => _selectedCategoryId = id);
                                              },
                                              onAddNew: (searchText) async {
                                                // Safety check for category type
                                                if (categoryType == null) return;

                                                // Direct create if search text is provided
                                                final name = searchText.trim();

                                                if (name.isNotEmpty) {
                                                  // Direct creation path
                                                  await _createNewCategory(name, categoryType!);
                                                } else {
                                                  // Fallback to dialog if no text entered
                                                  // Use parent 'context', not the disposed 'modalContext'
                                                  FocusScope.of(context).unfocus();
                                                  await Future.delayed(const Duration(milliseconds: 100));

                                                  if (!mounted) return;

                                                  final result = await showDialog<Map<String, dynamic>>(
                                                    context: context,
                                                    builder: (context) => AddCategoryDialog(
                                                      type: categoryType!,
                                                      initialName: '',
                                                    ),
                                                  );

                                                  if (mounted) {
                                                    FocusScope.of(context).unfocus();
                                                  }

                                                  if (result != null && result['name'] != null) {
                                                    await _createNewCategory(
                                                      result['name'] as String,
                                                      categoryType!,
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
                                          color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            if (selectedCategory != null)
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: _parseCategoryColor(selectedCategory.color),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: CategoryIconWidget(
                                                  iconString: selectedCategory.icon,
                                                  size: 16,
                                                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                                ),
                                              )
                                            else
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
                                              color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                              error: (_, __) => const Text('Error loading categories'),
                            ),

                          if (_selectedType != TransactionType.transfer)
                            const SizedBox(height: 16),

                          // Account Selection
                          accountsAsync.when(
                            data: (accounts) {
                              return Column(
                                children: [
                                  _buildAccountSelector(
                                    context: context,
                                    accounts: accounts,
                                    isToAccount: false,
                                    label: _selectedType == TransactionType.transfer ? trans.entryFromAccount : trans.entryAccount,
                                  ),
                                  if (_selectedType == TransactionType.transfer) ...[
                                    const SizedBox(height: 16),
                                    _buildAccountSelector(
                                      context: context,
                                      accounts: accounts,
                                      isToAccount: true,
                                      label: trans.entryToAccount,
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                            error: (_, __) => const Text('Error loading accounts'),
                          ),

                          const SizedBox(height: 16),

                          // Date and Time Row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: GestureDetector(
                                  onTap: _selectDate,
                                  child: Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(_selectedDate),
                                          style: TextStyle(
                                            color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: _selectTime,
                                  child: Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedTime.format(context),
                                          style: TextStyle(
                                            color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Note Row
                          GestureDetector(
                            onTap: _addNote,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _noteController.text.isEmpty ? trans.entryAddNote : _noteController.text,
                                      style: TextStyle(
                                        color: _noteController.text.isEmpty
                                            ? (isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6))
                                            : (isLight ? AppColors.textPrimaryLight : Colors.white),
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          Container(
                            width: double.infinity,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _saveTransaction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                                foregroundColor: const Color(0xFF221D10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    trans.entrySaveButton,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Future<void> _showRecurringDialog() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_selectedAccountId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amount = double.tryParse(_rawAmount) ?? 0.0;
    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final selectedFrequency = await showDialog<RecurringFrequency>(
      context: context,
      builder: (context) => _RecurringFrequencyDialog(
        initialDate: _selectedDate,
        transactionTitle: _titleController.text,
      ),
    );

    if (selectedFrequency == null) return;

    await _createRecurringEntry(selectedFrequency);
  }

  Future<void> _createRecurringEntry(RecurringFrequency frequency) async {
    final messenger = ScaffoldMessenger.of(context);
    final profileId = ref.read(activeProfileIdProvider);

    if (profileId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No active profile. Please set up a profile first.')),
      );
      return;
    }

    final amount = double.tryParse(_rawAmount) ?? 0.0;
    final name = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : '${_selectedType.displayName} - ${Formatters.formatNumber(amount)}';

    try {
      final recurringDao = ref.read(recurringDaoProvider);
      final nextDate = recurringDao.calculateNextDate(_selectedDate, frequency);
      await recurringDao.createRecurring(
        RecurringCompanion.insert(
          profileId: profileId,
          name: name,
          type: _selectedType,
          amount: amount,
          accountId: _selectedAccountId!,
          categoryId: drift.Value(_selectedCategoryId),
          frequency: frequency,
          nextDate: nextDate,
          createdAt: DateTime.now(),
        ),
      );

      // If the start date is in the past, immediately generate due transactions
      if (nextDate.isBefore(DateTime.now())) {
        await ref.read(recurringServiceProvider).checkAndGenerateRecurringTransactions();
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.repeat, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Recurring ${frequency.displayName.toLowerCase()} transaction created'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error creating recurring: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createNewCategory(String name, CategoryType type, {String? icon, String? color}) async {
    try {
      final dao = ref.read(categoryDaoProvider);
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;

      // Check for existing category with same name (case-insensitive) and type
      final allByType = await dao.getCategoriesByType(type);
      final trimmedName = name.trim();
      Category? existing;
      for (final c in allByType) {
        if (c.profileId == profileId &&
            c.name.toLowerCase() == trimmedName.toLowerCase()) {
          existing = c;
          break;
        }
      }

      if (existing != null) {
        setState(() {
          _selectedCategoryId = existing!.id;
        });
        return;
      }

      final newCategoryId = await dao.createCategory(
        CategoriesCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(trimmedName),
          type: drift.Value(type),
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
            content: Text(ref.read(translationsProvider).entryCategoryCreated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _RecurringFrequencyDialog extends StatefulWidget {
  final DateTime initialDate;
  final String transactionTitle;

  const _RecurringFrequencyDialog({
    required this.initialDate,
    required this.transactionTitle,
  });

  @override
  State<_RecurringFrequencyDialog> createState() => _RecurringFrequencyDialogState();
}

class _RecurringFrequencyDialogState extends State<_RecurringFrequencyDialog> {
  RecurringFrequency _frequency = RecurringFrequency.monthly;

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    return Dialog(
      backgroundColor: isDefault ? const Color(0xFF2D2416) : isLight ? Colors.white : const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat, color: AppColors.primaryGold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set as Recurring',
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.transactionTitle.isNotEmpty)
              Text(
                '"${widget.transactionTitle}"',
                style: TextStyle(
                  color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'FREQUENCY',
              style: TextStyle(
                color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecurringFrequency.values.map((freq) {
                final isSelected = _frequency == freq;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = freq),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGold
                          : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGold
                            : (isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: Text(
                      freq.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1A1410)
                            : (isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.8)),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Starts from ${DateFormat.yMMMd().format(widget.initialDate)}',
                    style: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _frequency),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primaryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Color(0xFF1A1410),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
