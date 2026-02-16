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
  late TextEditingController _amountController;
  Currency _selectedCurrency = Currency.idr;
  DateTime? _deadline;
  bool _isLoading = false;
  List<int> _linkedAccountIds = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _amountController = TextEditingController(
      text: widget.goal?.targetAmount.toStringAsFixed(0) ?? '',
    );
    if (widget.goal != null) {
      _selectedCurrency = widget.goal!.targetCurrency;
      _deadline = widget.goal!.deadline;
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

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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

    setState(() => _isLoading = true);

    try {
      final amountStr =
          _amountController.text.replaceAll('.', '').replaceAll(',', '');
      final amount = double.parse(amountStr);
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
    final trans = ref.watch(translationsProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balances = ref.watch(accountBalanceProvider);

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
              widget.goal == null ? trans.goalTitleAdd : trans.goalTitleEdit,
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
                    GlassInput(
                      controller: _amountController,
                      hintText: trans.goalTargetAmount,
                      prefixIcon: Icons.monetization_on,
                      keyboardType: TextInputType.number,
                      inputFormatters: [IndonesianCurrencyInputFormatter()],
                      validator: (v) {
                        if (v == null || v.isEmpty || v == '0') {
                          return trans.goalTargetAmount;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Currency
                    Text(trans.goalCurrency,
                        style: AppTypography.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: Currency.values.map((currency) {
                        final isSelected = _selectedCurrency == currency;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(currency.code),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCurrency = currency);
                              }
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
                    const SizedBox(height: 24),

                    // Deadline
                    Text(trans.goalDeadline,
                        style: AppTypography.textTheme.labelLarge),
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
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (_deadline != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _deadline = null),
                                child: const Icon(Icons.clear,
                                    color: Colors.white54, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Link Accounts
                    Text(trans.goalLinkAccounts,
                        style: AppTypography.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    accountsAsync.when(
                      data: (accounts) {
                        if (accounts.isEmpty) {
                          return Text(
                            'No accounts available',
                            style: TextStyle(color: Colors.white54),
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
                                          : Colors.white30,
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
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${account.currency.code} ${NumberFormat.decimalPattern().format(balance)}',
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12),
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
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2D2416),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Text('Delete Goal?',
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
