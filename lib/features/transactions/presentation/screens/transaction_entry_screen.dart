import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';
import '../../../../shared/widgets/glass_dropdown_field.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';
import '../widgets/category_selector.dart';
import '../widgets/add_category_dialog.dart';

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
  
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  int? _selectedAccountId;
  int? _selectedToAccountId;
  int? _selectedCategoryId;
  
  // Currency Conversion (background)
  double? _estimatedDestinationAmount;
  double? _exchangeRate;
  
  // Raw amount value (without formatting)
  String _rawAmount = '';

  @override
  void initState() {
    super.initState();
    _amountController.text = '0';  // Default to single zero
    
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
      setState(() {
        _selectedType = transaction.type;
        _selectedAccountId = transaction.accountId;
        _selectedCategoryId = transaction.categoryId;
        _selectedToAccountId = transaction.toAccountId;
        _selectedDate = transaction.date;
        _rawAmount = transaction.amount.toString();
        // Format with Indonesian locale for edit mode - NO DECIMALS
        final formatter = NumberFormat('#,##0', 'id_ID');
        _amountController.text = formatter.format(transaction.amount);
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
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    
    if (_selectedType == TransactionType.transfer && _selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account')),
      );
      return;
    }
    
    if (_selectedType != TransactionType.transfer && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amount = double.tryParse(_rawAmount) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Validate sufficient balance for expenses
    if (_selectedType == TransactionType.expense) {
      final accountBalance = await ref.read(transactionDaoProvider).calculateAccountBalance(_selectedAccountId!);
      if (amount > accountBalance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Insufficient balance. Available: ${Formatters.formatNumber(accountBalance)}')),
          );
        }
        return;
      }
    }

    // Validate sufficient balance for transfers
    if (_selectedType == TransactionType.transfer) {
      final accountBalance = await ref.read(transactionDaoProvider).calculateAccountBalance(_selectedAccountId!);
      if (amount > accountBalance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Insufficient balance. Available: ${Formatters.formatNumber(accountBalance)}')),
          );
        }
        return;
      }
    }
    
    final dao = ref.read(transactionDaoProvider);

    try {
      if (widget.transactionId != null) {
        // Update existing transaction
        await dao.updateTransaction(
          widget.transactionId!,
          TransactionsCompanion(
            accountId: drift.Value(_selectedAccountId!),
            categoryId: _selectedCategoryId != null ? drift.Value(_selectedCategoryId!) : const drift.Value.absent(),
            toAccountId: _selectedToAccountId != null ? drift.Value(_selectedToAccountId!) : const drift.Value.absent(),
            destinationAmount: _estimatedDestinationAmount != null ? drift.Value(_estimatedDestinationAmount) : const drift.Value.absent(),
            exchangeRate: _exchangeRate != null ? drift.Value(_exchangeRate) : const drift.Value.absent(),
            type: drift.Value(_selectedType),
            amount: drift.Value(amount),
            date: drift.Value(_selectedDate),
            title: drift.Value(_titleController.text),
            note: drift.Value(_noteController.text),
          ),
        );
        print('✅ Transaction updated with ID: ${widget.transactionId}');
      } else {
        // Insert new transaction
        final transactionId = await dao.insertTransaction(
          TransactionsCompanion(
            accountId: drift.Value(_selectedAccountId!),
            categoryId: _selectedCategoryId != null ? drift.Value(_selectedCategoryId!) : const drift.Value.absent(),
            toAccountId: _selectedToAccountId != null ? drift.Value(_selectedToAccountId!) : const drift.Value.absent(),
            destinationAmount: _estimatedDestinationAmount != null ? drift.Value(_estimatedDestinationAmount) : const drift.Value.absent(),
            exchangeRate: _exchangeRate != null ? drift.Value(_exchangeRate) : const drift.Value.absent(),
            type: drift.Value(_selectedType),
            amount: drift.Value(amount),
            date: drift.Value(_selectedDate),
            title: drift.Value(_titleController.text),
            note: drift.Value(_noteController.text),
            createdAt: drift.Value(DateTime.now()),
          ),
        );
        print('✅ Transaction saved with ID: $transactionId');
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e, stackTrace) {
      print('❌ ERROR saving transaction: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  void _updateAmount(String value) {
    // Extract digits only for storage
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      setState(() {
        _rawAmount = '';
      });
      return;
    }

    // Parse as whole number (not cents since we removed decimals)
    final amount = int.parse(digitsOnly);
    
    setState(() {
      _rawAmount = amount.toString();
    });
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

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
      print('🗑️ Deleting transaction ID: ${widget.transactionId}');
      
      final dao = ref.read(transactionDaoProvider);
      await dao.deleteTransaction(widget.transactionId!);
      
      print('✅ Transaction deleted successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted'),
            backgroundColor: AppColors.primaryGold,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      return 'Today';
    } else if (selectedDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF221D10),
      body: SafeArea(
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
                    widget.transactionId != null ? 'Edit Entry' : 'New Entry',
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
                          tooltip: 'Delete transaction',
                        ),
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.white),
                        onPressed: () {
                          // Show help dialog
                        },
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
                          'ENTER AMOUNT',
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
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        IndonesianCurrencyInputFormatter(),
                                      ],
                                      onChanged: _updateAmount,
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
                      labels: const ['Income', 'Expense', 'Transfer'],
                      onChanged: (type) => setState(() => _selectedType = type),
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
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Category Dropdown
                    if (_selectedType != TransactionType.transfer)
                      categoriesAsync.when(
                        data: (categories) {
                          print('📋 Categories loaded: ${categories.length} total');
                          
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
                          
                          print('📋 Filtered categories (${categoryType?.name}): ${filteredCategories.length}');
                          print('📋 Category names: ${filteredCategories.map((c) => c.name).join(", ")}');
                          
                          // Get selected category name
                          final selectedCategory = filteredCategories
                              .where((c) => c.id == _selectedCategoryId)
                              .firstOrNull;
                          
                          print('📋 Selected category ID: $_selectedCategoryId, Name: ${selectedCategory?.name}');
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'CATEGORY',
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
                                    builder: (context) => CategorySelector(
                                      categories: filteredCategories,
                                      selectedCategoryId: _selectedCategoryId,
                                      onCategorySelected: (id) {
                                        setState(() => _selectedCategoryId = id);
                                      },
                                      onAddNew: (searchText) async {
                                        // Show add category dialog with pre-filled search text
                                        final categoryName = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AddCategoryDialog(
                                            type: categoryType!,
                                            initialName: searchText,
                                          ),
                                        );
                                        
                                        if (categoryName != null && categoryName.isNotEmpty) {
                                          try {
                                            print('🔵 Creating category: $categoryName');
                                            // Save to database
                                            final dao = ref.read(categoryDaoProvider);
                                            final newCategoryId = await dao.createCategory(
                                              CategoriesCompanion(
                                                name: drift.Value(categoryName),
                                                type: drift.Value(categoryType!),
                                                icon: const drift.Value('category'), // Default icon
                                                isSystem: const drift.Value(false),
                                                sortOrder: drift.Value(999), // Put at end
                                              ),
                                            );
                                            
                                            print('✅ Category created with ID: $newCategoryId');
                                            
                                            // Select the newly created category
                                            setState(() {
                                              _selectedCategoryId = newCategoryId;
                                            });
                                            
                                            print('✅ Category selected: $_selectedCategoryId');
                                            
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Category "$categoryName" created!'),
                                                  backgroundColor: AppColors.primaryGold,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            print('❌ Error creating category: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error creating category: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
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
                                          selectedCategory?.name ?? 'Select category',
                                          style: TextStyle(
                                            color: selectedCategory != null
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.4),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
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

                    // Account Dropdown
                    accountsAsync.when(
                      data: (accounts) {
                        return GlassDropdownField<int>(
                          label: _selectedType == TransactionType.transfer ? 'From Account' : 'Account',
                          icon: Icons.account_balance_wallet_outlined,
                          value: _selectedAccountId,
                          hint: 'Select account',
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedAccountId = value),
                        );
                      },
                      loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                      error: (_, __) => const Text('Error loading accounts'),
                    ),

                    const SizedBox(height: 16),

                    // To Account Dropdown (for transfers)
                    if (_selectedType == TransactionType.transfer)
                      accountsAsync.when(
                        data: (accounts) {
                          return GlassDropdownField<int>(
                            label: 'To Account',
                            icon: Icons.account_balance_wallet_outlined,
                            value: _selectedToAccountId,
                            hint: 'Select destination',
                            items: accounts
                                .where((a) => a.id != _selectedAccountId)
                                .map((a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedToAccountId = value),
                          );
                        },
                        loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                        error: (_, __) => const Text('Error loading accounts'),
                      ),

                    if (_selectedType == TransactionType.transfer)
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
                                    _formatDateDisplay(),
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
                                      _noteController.text.isEmpty ? 'Add Note' : _noteController.text,
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
    );
  }
}
