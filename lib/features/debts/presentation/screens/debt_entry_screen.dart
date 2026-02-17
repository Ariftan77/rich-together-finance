import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';


class DebtEntryScreen extends ConsumerStatefulWidget {
  final Debt? debt;

  const DebtEntryScreen({super.key, this.debt});

  @override
  ConsumerState<DebtEntryScreen> createState() => _DebtEntryScreenState();
}

class _DebtEntryScreenState extends ConsumerState<DebtEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _personController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DebtType _selectedType = DebtType.payable;
  Currency _selectedCurrency = Currency.idr;
  DateTime? _dueDate;
  int? _selectedAccountId; // For transaction creation
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _personController =
        TextEditingController(text: widget.debt?.personName ?? '');
    _amountController = TextEditingController(
      text: widget.debt != null 
          ? IndonesianCurrencyInputFormatter.format(widget.debt!.amount.toStringAsFixed(0))
          : '',
    );
    _noteController = TextEditingController(text: widget.debt?.note ?? '');
    if (widget.debt != null) {
      _selectedType = widget.debt!.type;
      _selectedCurrency = widget.debt!.currency;
      _dueDate = widget.debt!.dueDate;
      _selectedAccountId = widget.debt!.creationAccountId;
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
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
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    // specific validation for creation: account required
    if (widget.debt == null && _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr =
          _amountController.text.replaceAll('.', '').replaceAll(',', '');
      final amount = double.parse(amountStr);
      final debtDao = ref.read(debtDaoProvider);

      if (widget.debt == null) {
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

        // 1. Create Debt
        await debtDao.createDebt(
          DebtsCompanion(
            profileId: drift.Value(profileId),
            type: drift.Value(_selectedType),
            personName: drift.Value(_personController.text.trim()),
            amount: drift.Value(amount),
            currency: drift.Value(_selectedCurrency),
            dueDate: drift.Value(_dueDate),
            note: drift.Value(_noteController.text.trim()),
            isSettled: const drift.Value(false),
            paidAmount: const drift.Value(0.0),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
            creationAccountId: drift.Value(_selectedAccountId),
          ),
          _selectedAccountId!
        );

        // 2. Create Transaction (Balance Impact)
        final transactionDao = ref.read(transactionDaoProvider);
        await transactionDao.insertTransaction(
          TransactionsCompanion(
            profileId: drift.Value(profileId),
            accountId: drift.Value(_selectedAccountId!),
            type: drift.Value(_selectedType == DebtType.payable
                ? TransactionType.income // I owe someone -> I got money -> Income
                : TransactionType.expense), // Owed to me -> I gave money -> Expense
            amount: drift.Value(amount),
            title: drift.Value('Debt: ${_personController.text.trim()}'),
            note: drift.Value(_noteController.text.trim()),
            date: drift.Value(DateTime.now()),
            createdAt: drift.Value(DateTime.now()),
          ),
        );

      } else {
        // Edit mode - update debt only
        await debtDao.updateDebt(
          widget.debt!.copyWith(
            type: _selectedType,
            personName: _personController.text.trim(),
            amount: amount,
            currency: _selectedCurrency,
            dueDate: drift.Value(_dueDate),
            note: drift.Value(_noteController.text.trim()),
            updatedAt: DateTime.now(),
          ),
        );

        // Update linked transaction if type or amount changed
        // Only if we have the creation link
        if (widget.debt!.creationAccountId != null) {
          final transactionDao = ref.read(transactionDaoProvider);
          final oldTx = await transactionDao.findDebtTransaction(
            accountId: widget.debt!.creationAccountId!,
            amount: widget.debt!.amount,
            date: widget.debt!.createdAt,
          );

          if (oldTx != null) {
            await transactionDao.updateTransaction(
              oldTx.id,
              TransactionsCompanion(
                type: drift.Value(_selectedType == DebtType.payable
                    ? TransactionType.income
                    : TransactionType.expense),
                amount: drift.Value(amount), // Sync amount change too
                title: drift.Value('Debt: ${_personController.text.trim()}'), // Sync name change
              ),
            );
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving debt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              widget.debt == null ? trans.debtTitleAdd : trans.debtTitleEdit,
              style: const TextStyle(color: Colors.white),
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
                    // Debt Type
                    Text('Type', style: AppTypography.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: DebtType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(type == DebtType.payable
                                ? trans.debtPayable
                                : trans.debtReceivable),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                if (widget.debt != null && widget.debt!.paidAmount > 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Cannot change type of partially settled debt')),
                                    );
                                    return;
                                }
                                setState(() => _selectedType = type);
                              }
                            },
                            selectedColor: type == DebtType.payable
                                ? AppColors.error
                                : AppColors.success,
                            backgroundColor: AppColors.glassBackground,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (widget.debt != null && widget.debt!.paidAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Type cannot be changed because this debt has partial payments.',
                          style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Person Name
                    GlassInput(
                      controller: _personController,
                      hintText: trans.debtPersonNameHint,
                      prefixIcon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return trans.debtPersonName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Amount
                    GlassInput(
                      controller: _amountController,
                      hintText: trans.goalTargetAmount,
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
                    
                    // Account Selection (Only for creation)
                    if (widget.debt == null) ...[
                      Text('Account (Impacts Balance)', style: AppTypography.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      accountsAsync.when(
                        data: (accounts) {
                          if (accounts.isEmpty) {
                            return const Text('No accounts found. Create one first.', style: TextStyle(color: Colors.red));
                          }
                          return DropdownButtonFormField<int>(
                            value: _selectedAccountId,
                            dropdownColor: AppColors.cardSurface,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.glassBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'Select Account',
                              hintStyle: const TextStyle(color: Colors.white54),
                            ),
                            items: accounts.map((account) {
                              return DropdownMenuItem<int>(
                                value: account.id,
                                child: Text(account.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                                setState(() {
                                  _selectedAccountId = val;
                                  // Update currency based on account
                                  final account = accounts.firstWhere((a) => a.id == val);
                                  _selectedCurrency = account.currency;
                                });
                            },
                            validator: (val) => val == null ? 'Required' : null,
                          );
                        },
                        loading: () => const CircularProgressIndicator(color: AppColors.primaryGold),
                        error: (e, s) => Text('Error loading accounts: $e', style: const TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Show Account in Edit Mode (Read Only)
                    if (widget.debt != null && _selectedAccountId != null) ...[
                      Text('Account (Affected)', style: AppTypography.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      accountsAsync.when(
                        data: (accounts) {
                          final account = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
                          return GlassInput(
                            controller: TextEditingController(text: account?.name ?? 'Unknown Account'),
                            readOnly: true,
                            hintText: 'Account Name',
                            prefixIcon: Icons.account_balance_wallet,
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Currency Display (Read-only, derived from Account)
                    Text(trans.goalCurrency, style: AppTypography.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _selectedCurrency.code,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Due Date
                    Text(trans.debtDueDate,
                        style: AppTypography.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDueDate,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: AppColors.primaryGold, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _dueDate != null
                                  ? DateFormat.yMMMd().format(_dueDate!)
                                  : trans.goalNoDeadline,
                              style: TextStyle(
                                color: _dueDate != null
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _dueDate = null),
                                child: const Icon(Icons.clear,
                                    color: Colors.white54, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Note
                    GlassInput(
                      controller: _noteController,
                      hintText: trans.entryNoteHint,
                      prefixIcon: Icons.note_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    GlassButton(
                      text: trans.save,
                      isFullWidth: true,
                      size: GlassButtonSize.large,
                      onPressed: () => _saveDebt(),
                      isLoading: _isLoading,
                    ),

                    // Delete Button (edit mode)
                    if (widget.debt != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2D2416),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Text('Delete Debt?',
                                    style: TextStyle(color: Colors.white)),
                                content: Text(
                                    'This action cannot be undone.',
                                    style: TextStyle(
                                        color: Colors.white.withValues(
                                            alpha: 0.8))),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(trans.cancel,
                                          style: TextStyle(
                                              color: Colors.white54))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(trans.delete,
                                          style: const TextStyle(
                                              color: Colors.red))),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref
                                  .read(debtDaoProvider)
                                  .deleteDebt(widget.debt!.id);
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          child: Text('Delete Debt',
                              style: const TextStyle(color: Colors.red)),
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
