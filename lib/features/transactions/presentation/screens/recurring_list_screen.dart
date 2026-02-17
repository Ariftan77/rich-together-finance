import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';

class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);

    final categoryMap = categoriesAsync.valueOrNull != null
        ? {for (var c in categoriesAsync.value!) c.id: c}
        : <int, Category>{};
    final accountMap = accountsAsync.valueOrNull != null
        ? {for (var a in accountsAsync.value!) a.id: a}
        : <int, Account>{};

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trans.recurringTitle,
                      style: AppTypography.textTheme.displaySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: recurringAsync.when(
                  data: (recurringList) {
                    if (recurringList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              trans.recurringNoRecurring,
                              style: AppTypography.textTheme.bodyLarge!.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              trans.recurringNoRecurringHint,
                              style: AppTypography.textTheme.bodySmall!.copyWith(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: recurringList.length,
                      itemBuilder: (context, index) {
                        final item = recurringList[index];
                        final category = categoryMap[item.categoryId];
                        final account = accountMap[item.accountId];
                        final isExpense = item.type == TransactionType.expense;
                        final isIncome = item.type == TransactionType.income;
                        final color = isExpense
                            ? const Color(0xFFFB7185)
                            : (isIncome ? const Color(0xFF34D399) : const Color(0xFF60A5FA));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _showEditDialog(context, ref, item, category, account),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.repeat,
                                      color: color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: AppTypography.textTheme.bodyMedium!.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.frequency.displayName} • ${category?.name ?? item.type.displayName} • ${account?.name ?? 'Unknown'}',
                                          style: AppTypography.textTheme.bodySmall!.copyWith(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Created ${DateFormat.yMMMd().format(item.createdAt)}',
                                          style: AppTypography.textTheme.bodySmall!.copyWith(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount & next date
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isExpense ? '-' : '+'}${Formatters.formatCurrency(item.amount, showDecimal: showDecimal)}',
                                        style: AppTypography.textTheme.bodyMedium!.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${trans.recurringNextRun}: ${DateFormat.MMMd().format(item.nextDate)}',
                                        style: AppTypography.textTheme.bodySmall!.copyWith(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGold),
                  ),
                  error: (err, _) => Center(
                    child: Text('${trans.error}: $err', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    RecurringData item,
    Category? category,
    Account? account,
  ) {
    showDialog(
      context: context,
      builder: (context) => _RecurringEditDialog(
        item: item,
        category: category,
        account: account,
      ),
    );
  }
}

class _RecurringEditDialog extends ConsumerStatefulWidget {
  final RecurringData item;
  final Category? category;
  final Account? account;

  const _RecurringEditDialog({
    required this.item,
    this.category,
    this.account,
  });

  @override
  ConsumerState<_RecurringEditDialog> createState() => _RecurringEditDialogState();
}

class _RecurringEditDialogState extends ConsumerState<_RecurringEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late RecurringFrequency _frequency;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(
      text: Formatters.formatNumber(widget.item.amount),
    );
    _frequency = widget.item.frequency;
    _isActive = widget.item.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.item.type == TransactionType.expense;
    final color = isExpense ? const Color(0xFFFB7185) : const Color(0xFF34D399);
    final trans = ref.watch(translationsProvider);

    return Dialog(
      backgroundColor: const Color(0xFF2D2416),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.repeat, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trans.recurringTitleEdit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    onPressed: () => _deleteRecurring(context),
                    tooltip: trans.delete,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Name field
              _buildLabel(trans.goalName.toUpperCase()),
              const SizedBox(height: 8),
              _buildTextField(_nameController, trans.goalNameHint),

              const SizedBox(height: 16),

              // Amount field
              _buildLabel(trans.entryAmount.toUpperCase()),
              const SizedBox(height: 8),
              _buildTextField(_amountController, trans.entryAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),

              const SizedBox(height: 16),

              // Frequency
              _buildLabel(trans.recurringFrequency.toUpperCase()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecurringFrequency.values.map((freq) {
                  final isSelected = _frequency == freq;
                  String freqName = freq.displayName;
                  // Map frequency enum to localized string manually since enum extension is hardcoded
                  switch (freq) {
                    case RecurringFrequency.daily: freqName = trans.recurringDaily; break;
                    case RecurringFrequency.weekly: freqName = trans.recurringWeekly; break;
                    case RecurringFrequency.monthly: freqName = trans.recurringMonthly; break;
                    case RecurringFrequency.yearly: freqName = trans.recurringYearly; break;
                  }

                  return GestureDetector(
                    onTap: () => setState(() => _frequency = freq),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        freqName,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1A1410)
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Info: Category & Account (read-only)
              _buildLabel('INFO'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(trans.accountType, widget.item.type.displayName),
                    const SizedBox(height: 6),
                    _buildInfoRow(trans.entryCategory, widget.category?.name ?? '-'),
                    const SizedBox(height: 6),
                    _buildInfoRow(trans.entryAccount, widget.account?.name ?? '-'),
                    const SizedBox(height: 6),
                    _buildInfoRow(trans.recurringNextRun, DateFormat.yMMMd().format(widget.item.nextDate)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Active toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                      activeColor: AppColors.primaryGold,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Cancel / Save buttons
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
                        trans.cancel,
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
                      onPressed: _saveRecurring,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        trans.save,
                        style: TextStyle(
                          color: const Color(0xFF1A1410),
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
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _saveRecurring() async {
    final trans = ref.read(translationsProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')), // TODO: Add translation for validation
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    ) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trans.errorInvalidAmount)),
      );
      return;
    }

    try {
      final dao = ref.read(recurringDaoProvider);
      final updated = widget.item.copyWith(
        name: name,
        amount: amount,
        frequency: _frequency,
        isActive: _isActive,
      );
      await dao.updateRecurring(updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.success),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trans.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecurring(BuildContext context) async {
    final trans = ref.read(translationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2416),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Delete Recurring?', // TODO: Add translation
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This will permanently remove this recurring transaction.', // TODO: Add translation
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              trans.cancel,
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
              trans.delete,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dao = ref.read(recurringDaoProvider);
      await dao.deleteRecurring(widget.item.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.success),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trans.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
