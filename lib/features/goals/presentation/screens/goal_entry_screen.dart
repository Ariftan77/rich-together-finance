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

import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../accounts/presentation/providers/balance_provider.dart';

class GoalEntryScreen extends ConsumerStatefulWidget {
  final Goal? goal;

  const GoalEntryScreen({super.key, this.goal});

  @override
  ConsumerState<GoalEntryScreen> createState() => _GoalEntryScreenState();
}

class _GoalEntryScreenState extends ConsumerState<GoalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  double _rawAmount = 0;
  Currency _selectedCurrency = Currency.idr; // overwritten in initState
  DateTime? _deadline;
  bool _isLoading = false;
  List<int> _linkedAccountIds = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    if (widget.goal != null) {
      _rawAmount = widget.goal!.targetAmount;
      _selectedCurrency = widget.goal!.targetCurrency;
      _deadline = widget.goal!.deadline;
    } else {
      _selectedCurrency = ref.read(defaultCurrencyProvider);
    }
    if (widget.goal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLinkedAccounts();
      });
    }
  }

  Future<void> _loadLinkedAccounts() async {
    final goalDao = ref.read(goalDaoProvider);
    final accounts = await goalDao.getGoalAccounts(widget.goal!.id);
    if (mounted) {
      setState(() {
        _linkedAccountIds = accounts.map((ga) => ga.accountId).toList();
      });
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
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
      setState(() => _deadline = picked);
    }
  }

  Future<void> _saveGoal() async {
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
      final goalDao = ref.read(goalDaoProvider);

      if (widget.goal == null) {
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
        final goalId = await goalDao.createGoal(
          GoalsCompanion(
            profileId: drift.Value(profileId),
            name: drift.Value(_nameController.text.trim()),
            targetAmount: drift.Value(amount),
            targetCurrency: drift.Value(_selectedCurrency),
            deadline: drift.Value(_deadline),
            isAchieved: const drift.Value(false),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

        // Link accounts
        for (final accountId in _linkedAccountIds) {
          await goalDao.linkAccountToGoal(
            GoalAccountsCompanion(
              goalId: drift.Value(goalId),
              accountId: drift.Value(accountId),
            ),
          );
        }
      } else {
        await goalDao.updateGoal(
          widget.goal!.copyWith(
            name: _nameController.text.trim(),
            targetAmount: amount,
            targetCurrency: _selectedCurrency,
            deadline: drift.Value(_deadline),
            updatedAt: DateTime.now(),
          ),
        );

        // Update linked accounts: remove all, re-add
        final existing = await goalDao.getGoalAccounts(widget.goal!.id);
        for (final ga in existing) {
          await goalDao.unlinkAccountFromGoal(widget.goal!.id, ga.accountId);
        }
        for (final accountId in _linkedAccountIds) {
          await goalDao.linkAccountToGoal(
            GoalAccountsCompanion(
              goalId: drift.Value(widget.goal!.id),
              accountId: drift.Value(accountId),
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goal: $e')),
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
    final balances = ref.watch(accountBalanceProvider);
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
              widget.goal == null ? trans.goalTitleAdd : trans.goalTitleEdit,
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
                    // Goal Name
                    GlassInput(
                      controller: _nameController,
                      hintText: trans.goalNameHint,
                      prefixIcon: Icons.flag_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return trans.goalName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Target Amount
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

                    // Currency
                    Text(trans.goalCurrency,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    CurrencyPickerField(
                      value: _selectedCurrency,
                      onChanged: (currency) => setState(() => _selectedCurrency = currency),
                    ),
                    const SizedBox(height: 24),

                    // Deadline
                    Text(trans.goalDeadline,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDeadline,
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
                              _deadline != null
                                  ? DateFormat.yMMMd().format(_deadline!)
                                  : trans.goalNoDeadline,
                              style: TextStyle(
                                color: _deadline != null
                                    ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                    : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (_deadline != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _deadline = null),
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
                    const SizedBox(height: 24),

                    // Link Accounts
                    Text(trans.goalLinkAccounts,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    accountsAsync.when(
                      data: (accounts) {
                        if (accounts.isEmpty) {
                          return Text(
                            'No accounts available',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white54,
                            ),
                          );
                        }
                        return Column(
                          children: accounts.map((account) {
                            final isLinked =
                                _linkedAccountIds.contains(account.id);
                            final balance = balances[account.id] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                borderRadius: 12,
                                onTap: () {
                                  setState(() {
                                    if (isLinked) {
                                      _linkedAccountIds.remove(account.id);
                                    } else {
                                      _linkedAccountIds.add(account.id);
                                    }
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      isLinked
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isLinked
                                          ? AppColors.primaryGold
                                          : (isLight
                                              ? const Color(0xFFCBD5E1)
                                              : Colors.white30),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account.name,
                                            style: TextStyle(
                                              color: isLight
                                                  ? AppColors.textPrimaryLight
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${account.currency.code} ${NumberFormat.decimalPattern().format(balance)}',
                                            style: TextStyle(
                                              color: isLight
                                                  ? const Color(0xFF64748B)
                                                  : Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryGold)),
                      error: (err, _) => Text('Error: $err'),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    GlassButton(
                      text: ref.watch(translationsProvider).save,
                      isFullWidth: true,
                      size: GlassButtonSize.large,
                      onPressed: () => _saveGoal(),
                      isLoading: _isLoading,
                    ),

                    // Delete Button (edit mode)
                    if (widget.goal != null) ...[
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
                                    'Delete Goal?',
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
                              await ref
                                  .read(goalDaoProvider)
                                  .deleteGoal(widget.goal!.id);
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          child: Text('Delete Goal',
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
