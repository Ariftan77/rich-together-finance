import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../transactions/presentation/widgets/account_selector.dart';


class DebtEntryScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  final DebtType? initialType;

  const DebtEntryScreen({super.key, this.debt, this.initialType});

  @override
  ConsumerState<DebtEntryScreen> createState() => _DebtEntryScreenState();
}

class _DebtEntryScreenState extends ConsumerState<DebtEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _personController;
  double _rawAmount = 0;
  late TextEditingController _noteController;
  DebtType _selectedType = DebtType.payable;
  Currency _selectedCurrency = Currency.idr; // overwritten in initState
  DateTime? _dueDate;
  int? _selectedAccountId; // For transaction creation
  bool _isLoading = false;

  // Person name suggestions
  List<String> _frequentNames = [];
  String _nameFilter = '';

  @override
  void initState() {
    super.initState();
    _personController =
        TextEditingController(text: widget.debt?.personName ?? '');
    _noteController = TextEditingController(text: widget.debt?.note ?? '');
    if (widget.debt != null) {
      _rawAmount = widget.debt!.amount;
      _selectedType = widget.debt!.type;
      _selectedCurrency = widget.debt!.currency;
      _dueDate = widget.debt!.dueDate;
      _selectedAccountId = widget.debt!.creationAccountId;
    } else {
      _selectedCurrency = ref.read(defaultCurrencyProvider);
      if (widget.initialType != null) _selectedType = widget.initialType!;
    }
    _personController.addListener(_onNameChanged);
    _loadFrequentNames();
  }

  void _onNameChanged() {
    final text = _personController.text.trim();
    if (text != _nameFilter) {
      setState(() => _nameFilter = text);
    }
  }

  Future<void> _loadFrequentNames() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final names = await ref.read(debtDaoProvider).getFrequentPersonNames(profileId);
    if (mounted) setState(() => _frequentNames = names);
  }

  List<String> get _filteredNames {
    if (_nameFilter.isEmpty) return _frequentNames;
    final q = _nameFilter.toLowerCase();
    return _frequentNames.where((n) => n.toLowerCase().contains(q)).toList();
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

  @override
  void dispose() {
    _personController.removeListener(_onNameChanged);
    _personController.dispose();
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
    if (_rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider).errorInvalidAmount)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = _rawAmount;
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
        final now = DateTime.now();
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
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
            creationAccountId: drift.Value(_selectedAccountId),
          ),
        );

        AnalyticsService.logFirstDebtCreated();

        // 2. Create Transaction (Balance Impact) — only if account was selected
        if (_selectedAccountId != null) {
          final transactionDao = ref.read(transactionDaoProvider);
          await transactionDao.insertTransaction(
            TransactionsCompanion(
              profileId: drift.Value(profileId),
              accountId: drift.Value(_selectedAccountId!),
              type: drift.Value(_selectedType == DebtType.payable
                  ? TransactionType.debtIn // I owe someone -> I got money -> adds to balance
                  : TransactionType.debtOut), // Owed to me -> I gave money -> subtracts from balance
              amount: drift.Value(amount),
              title: drift.Value('Debt: ${_personController.text.trim()}'),
              note: drift.Value(_noteController.text.trim()),
              date: drift.Value(now),
              createdAt: drift.Value(now),
            ),
          );
        }

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
                    ? TransactionType.debtIn
                    : TransactionType.debtOut),
                amount: drift.Value(amount),
                title: drift.Value('Debt: ${_personController.text.trim()}'),
                note: drift.Value(_noteController.text.trim()),
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final trans = ref.watch(translationsProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
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
              widget.debt == null ? trans.debtTitleAdd : trans.debtTitleEdit,
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
                    // Debt Type
                    Text('Type', style: Theme.of(context).textTheme.labelLarge),
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
                              color: isSelected
                                  ? Colors.white
                                  : (isLight
                                      ? const Color(0xFF64748B)
                                      : Colors.white70),
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
                    if (_filteredNames.isNotEmpty)
                      Container(
                        height: 36,
                        margin: const EdgeInsets.only(top: 10),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filteredNames.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final name = _filteredNames[index];
                            return GestureDetector(
                              onTap: () {
                                _personController.text = name;
                                _personController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: name.length),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: isLight
                                        ? AppColors.textPrimaryLight
                                        : Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Amount
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
                                    : trans.goalTargetAmount,
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

                    // Account + Currency Row
                    if (widget.debt == null) ...[
                      // Creation mode: Account selector + Currency badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Account selector (left, expanded)
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Account', style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),
                                accountsAsync.when(
                                  data: (accounts) {
                                    if (accounts.isEmpty) {
                                      return const Text('No accounts found.', style: TextStyle(color: Colors.red, fontSize: 13));
                                    }
                                    final selectedAccount = _selectedAccountId != null
                                        ? accounts.where((a) => a.id == _selectedAccountId).firstOrNull
                                        : null;
                                    return GestureDetector(
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
                                              selectedAccountId: _selectedAccountId,
                                              showDecimal: ref.read(showDecimalProvider),
                                              onAccountSelected: (id) {
                                                if (id != null) {
                                                  setState(() {
                                                    _selectedAccountId = id;
                                                    final account = accounts.firstWhere((a) => a.id == id);
                                                    _selectedCurrency = account.currency;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.glassBackground,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isLight
                                                ? Colors.black.withValues(alpha: 0.08)
                                                : Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet_outlined,
                                              color: AppColors.primaryGold,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedAccount?.name ?? trans.entrySelectAccount,
                                                style: TextStyle(
                                                  color: selectedAccount != null
                                                      ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                                      : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.expand_more,
                                              color: isLight
                                                  ? const Color(0xFFCBD5E1)
                                                  : Colors.white.withValues(alpha: 0.3),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))),
                                  error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Currency display (right, compact)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trans.goalCurrency, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),
                                Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.currency_exchange,
                                        color: isLight
                                            ? const Color(0xFF64748B)
                                            : Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedCurrency.code,
                                        style: TextStyle(
                                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Edit mode: Account (read-only) + Currency in one row
                    if (widget.debt != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedAccountId != null) ...[
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Account', style: Theme.of(context).textTheme.labelLarge),
                                  const SizedBox(height: 8),
                                  accountsAsync.when(
                                    data: (accounts) {
                                      final account = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
                                      return Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.glassBackground,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isLight
                                                ? Colors.black.withValues(alpha: 0.08)
                                                : Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet_outlined,
                                              color: isLight
                                                  ? const Color(0xFF64748B)
                                                  : Colors.white70,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                account?.name ?? 'Unknown',
                                                style: TextStyle(
                                                  color: isLight
                                                      ? const Color(0xFF64748B)
                                                      : Colors.white70,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    loading: () => const SizedBox(height: 50),
                                    error: (_, __) => const SizedBox(height: 50),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: _selectedAccountId != null ? 2 : 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trans.goalCurrency, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),
                                Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.currency_exchange,
                                        color: isLight
                                            ? const Color(0xFF64748B)
                                            : Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedCurrency.code,
                                        style: TextStyle(
                                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Dates section
                    if (widget.debt != null) ...[
                      // Edit mode: Created Date + Due Date side by side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trans.debtCreatedDate, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),
                                Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: isLight
                                            ? const Color(0xFF94A3B8)
                                            : Colors.white54,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          DateFormat.yMMMd(ref.watch(localeProvider).languageCode)
                                              .format(widget.debt!.createdAt),
                                          style: TextStyle(
                                            color: isLight
                                                ? const Color(0xFF64748B)
                                                : Colors.white70,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trans.debtDueDate, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _selectDueDate,
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.glassBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLight
                                            ? Colors.black.withValues(alpha: 0.08)
                                            : Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.event,
                                            color: AppColors.primaryGold, size: 16),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _dueDate != null
                                                ? DateFormat.yMMMd().format(_dueDate!)
                                                : trans.goalNoDeadline,
                                            style: TextStyle(
                                              color: _dueDate != null
                                                  ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                                  : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_dueDate != null) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () => setState(() => _dueDate = null),
                                            child: Icon(
                                              Icons.clear,
                                              color: isLight
                                                  ? const Color(0xFF94A3B8)
                                                  : Colors.white54,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Creation mode: Due Date only (full width)
                      Text(trans.debtDueDate,
                          style: Theme.of(context).textTheme.labelLarge),
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
                                      ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                      : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _dueDate = null),
                                  child: Icon(
                                    Icons.clear,
                                    color: isLight
                                        ? const Color(0xFF94A3B8)
                                        : Colors.white54,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: isDefault
                                      ? const Color(0xFF2D2416)
                                      : isLight ? Colors.white : const Color(0xFF0A0A0A),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: Text(
                                    'Delete Debt?',
                                    style: TextStyle(
                                      color: isLight
                                          ? AppColors.textPrimaryLight
                                          : Colors.white,
                                    ),
                                  ),
                                  content: Text(
                                    'This action cannot be undone.',
                                    style: TextStyle(
                                      color: isLight
                                          ? AppColors.textPrimaryLight
                                          : Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          trans.cancel,
                                          style: TextStyle(
                                            color: isLight
                                                ? const Color(0xFF64748B)
                                                : Colors.white54,
                                          ),
                                        )),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(trans.delete,
                                            style: const TextStyle(
                                                color: Colors.red))),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              final navigator = Navigator.of(context);
                              final debt = widget.debt!;

                              // Delete linked transaction first (reverses balance impact)
                              if (debt.creationAccountId != null) {
                                final transactionDao = ref.read(transactionDaoProvider);
                                final linkedTx = await transactionDao.findDebtTransaction(
                                  accountId: debt.creationAccountId!,
                                  amount: debt.amount,
                                  date: debt.createdAt,
                                );
                                if (linkedTx != null) {
                                  await transactionDao.deleteTransaction(linkedTx.id);
                                }
                              }

                              await ref.read(debtDaoProvider).deleteDebt(debt.id);
                              if (mounted) navigator.pop();
                            }
                          },
                          child: Text('Delete Debt',
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                    SizedBox(height: math.max(24, MediaQuery.of(context).viewPadding.bottom)),
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
