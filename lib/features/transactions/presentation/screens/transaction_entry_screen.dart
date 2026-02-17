import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';

import '../../../../shared/utils/formatters.dart';

import '../../../../shared/utils/currency_input_formatter.dart';
import '../widgets/category_selector.dart';
import '../widgets/add_category_dialog.dart';
import '../../../../shared/widgets/generic_searchable_dropdown.dart';
import '../../../../core/providers/locale_provider.dart';
import '../widgets/account_selector.dart';

class TransactionEntryScreen extends ConsumerStatefulWidget {
  final int? transactionId;  // If provided, edit mode
  
  const TransactionEntryScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends ConsumerState<TransactionEntryScreen> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();
  
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  int? _selectedAccountId;
  int? _selectedToAccountId;
  int? _selectedCategoryId;
  
  // Currency Conversion (background)
  double? _estimatedDestinationAmount;
  double? _exchangeRate;
  
  // Suggested Titles
  Future<List<String>>? _frequentTitlesFuture;
  
  // Raw amount value (without formatting)
  String _rawAmount = '';

  @override
  void initState() {
    super.initState();
    _amountController.text = '0';  // Default to single zero
    
    // Auto focus amount field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
      // Fetch frequent titles
      setState(() {
         _frequentTitlesFuture = ref.read(transactionDaoProvider).getMostFrequentTitles(5);
      });
    });

    // Load transaction data if editing
    if (widget.transactionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTransaction();
      });
    }
  }

  Future<void> _loadTransaction() async {
    final dao = ref.read(transactionDaoProvider);
    final transaction = await dao.getTransactionById(widget.transactionId!);
    
    if (transaction != null && mounted) {
      // Get account to determine currency
      final accountDao = ref.read(accountDaoProvider);
      final account = await accountDao.getAccountById(transaction.accountId);
      if (!mounted) return;
      final currency = account?.currency ?? Currency.idr;
      final showDecimal = ref.read(showDecimalProvider);

      setState(() {
        _selectedType = transaction.type;
        _selectedAccountId = transaction.accountId;
        _selectedCategoryId = transaction.categoryId;
        _selectedToAccountId = transaction.toAccountId;
        _selectedDate = transaction.date;
        _rawAmount = transaction.amount.toString();
        
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
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    
    // Capture messenger and navigator early to avoid "deactivated widget" errors after async gaps
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Unfocus to prevent keyboard/focus issues during navigation
    _amountFocusNode.unfocus();
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
      // Validate sufficient balance for expenses
      if (_selectedType == TransactionType.expense) {
        final accountBalance = await ref.read(transactionDaoProvider).calculateAccountBalance(_selectedAccountId!);
        if (amount > accountBalance) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Insufficient balance. Available: ${Formatters.formatNumber(accountBalance)}')),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      // Validate sufficient balance for transfers
      if (_selectedType == TransactionType.transfer) {
        final accountBalance = await ref.read(transactionDaoProvider).calculateAccountBalance(_selectedAccountId!);
        if (amount > accountBalance) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Insufficient balance. Available: ${Formatters.formatNumber(accountBalance)}')),
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
        date: drift.Value(_selectedDate),
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
      debugPrint('❌ ERROR saving transaction: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  void _updateAmount(String value, List<Account> accounts) {
    if (value.isEmpty) {
      setState(() {
        _rawAmount = '';
      });
      return;
    }

    final currency = _getCurrency(accounts);
    final amount = Formatters.parseCurrency(value, currency: currency);
    
    setState(() {
      _rawAmount = amount.toString();
    });
  }

  Currency _getCurrency(List<Account> accounts) {
    if (_selectedAccountId == null) return Currency.idr;
    // Find account or default
    try {
      return accounts.firstWhere((a) => a.id == _selectedAccountId).currency;
    } catch (_) {
      return Currency.idr; 
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGold,
              surface: Color(0xFF221D10),
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

  Future<void> _deleteTransaction() async {
    if (widget.transactionId == null) return;

    // Unfocus to prevent keyboard/focus issues during navigation
    _amountFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D2416),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Transaction?',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone. The account balance will be updated accordingly.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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
            child: Text(
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
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF221D10),
        title: const Text('Add Note', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _noteController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
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
    
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF221D10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Currency Conversion', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sending: ${Formatters.formatCurrency(sourceAmount, currency: fromCurrency)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              'Amount Received in ${toCurrency.code}:', // e.g. USD
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: '${toCurrency.symbol} ',
                prefixStyle: const TextStyle(color: AppColors.primaryGold),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
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
    if (_selectedAccountId == null) return 'IDR ';  // Default to IDR
    final account = accounts.firstWhere((a) => a.id == _selectedAccountId);
    return account.currency == Currency.idr ? 'IDR ' : '\$ ';
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



// ... inside the class ...

  Widget _buildAccountSelector({
    required BuildContext context,
    required List<Account> accounts,
    required bool isToAccount,
    required String label,
  }) {
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
              color: Colors.white.withValues(alpha: 0.6),
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
                  onAccountSelected: (id) {
                    setState(() {
                      if (isToAccount) {
                        _selectedToAccountId = id;
                      } else {
                        _selectedAccountId = id;
                      }
                    });
                  },
                ),
              ),
            );
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
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
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  color: Colors.white.withValues(alpha: 0.3),
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
    
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // const Color(0xFF221D10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
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
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.transactionId != null ? trans.entryTitleEdit : trans.entryTitleAdd,
                    style: const TextStyle(
                      color: Colors.white,
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
                          icon: const Icon(Icons.repeat, color: Colors.white),
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
                    const SizedBox(height: 40),

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
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    prefix.trim(),
                                    style: const TextStyle(
                                      color: AppColors.primaryGold,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: IntrinsicWidth(
                                    child: TextField(
                                      controller: _amountController,
                                      focusNode: _amountFocusNode,
                                      keyboardType: TextInputType.numberWithOptions(decimal: ref.watch(showDecimalProvider)),
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: [
                                        CurrencyInputFormatter(
                                          currency: _getCurrency(accounts),
                                          showDecimal: ref.watch(showDecimalProvider),
                                        ),
                                      ],
                                      onChanged: (val) => _updateAmount(val, accounts),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 56,  // Reduced from 72
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '0',
                                        hintStyle: TextStyle(
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                          error: (_, __) => const Text('Error loading accounts'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Transaction Type Segmented Control
                      GlassSegmentedControl<TransactionType>(
                        value: _selectedType,
                        options: const [
                          TransactionType.income,
                          TransactionType.expense,
                          TransactionType.transfer,
                        ],

                        labels: [trans.entryTypeIncome, trans.entryTypeExpense, trans.entryTypeTransfer],
                        onChanged: (type) {
                          setState(() => _selectedType = type);
                          if (type == TransactionType.transfer) {
                            _amountFocusNode.requestFocus();
                          }
                        },
                        highlightValue: TransactionType.expense,
                      ),

                    const SizedBox(height: 32),

                    // Title Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'TITLE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter title...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Frequent Titles Suggestions
                        if (_frequentTitlesFuture != null && _selectedType != TransactionType.transfer)
                          FutureBuilder<List<String>>(
                            future: _frequentTitlesFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                              return Container(
                                height: 36,
                                margin: const EdgeInsets.only(top: 12),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: snapshot.data!.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final title = snapshot.data![index];
                                    return GestureDetector(
                                      onTap: () {
                                        _titleController.text = title;
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
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
                                    color: Colors.white.withValues(alpha: 0.6),
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
                                                 await _createNewCategory(result['name'] as String, categoryType!);
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
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
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
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.4),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.expand_more,
                                        color: Colors.white.withValues(alpha: 0.3),
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



                    // Date and Note Row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(_selectedDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _addNote,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _noteController.text.isEmpty ? trans.entryAddNote : _noteController.text,
                                      style: TextStyle(
                                        color: _noteController.text.isEmpty
                                            ? Colors.white.withValues(alpha: 0.6)
                                            : Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 24),
                      SizedBox(width: 12),
                      Text(
                        // 'Save Transaction' -> trans.entrySaveButton
                        // Needs to be accessed via ref in build method context to be cleaner
                        // But here we are inside a method? No, this is build method structure
                        // Wait, I need access to `trans` variable.
                        // I'll add `final trans = ref.watch(translationsProvider);` at start of build.
                        'Save Transaction', 
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      debugPrint('Error creating recurring transaction: $e');
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

  Future<void> _createNewCategory(String name, CategoryType type) async {
    try {
      final dao = ref.read(categoryDaoProvider);
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;

      final newCategoryId = await dao.createCategory(
        CategoriesCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(name),
          type: drift.Value(type),
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
            content: Text(ref.read(translationsProvider).entryCategoryCreated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating category: $e');
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
    return Dialog(
      backgroundColor: const Color(0xFF2D2416),
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
                const Expanded(
                  child: Text(
                    'Set as Recurring',
                    style: TextStyle(
                      color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'FREQUENCY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
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
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGold
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      freq.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1A1410)
                            : Colors.white.withValues(alpha: 0.8),
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
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Starts from ${DateFormat.yMMMd().format(widget.initialDate)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
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
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
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
