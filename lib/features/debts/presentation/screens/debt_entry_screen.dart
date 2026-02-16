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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _personController =
        TextEditingController(text: widget.debt?.personName ?? '');
    _amountController = TextEditingController(
      text: widget.debt?.amount.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(text: widget.debt?.note ?? '');
    if (widget.debt != null) {
      _selectedType = widget.debt!.type;
      _selectedCurrency = widget.debt!.currency;
      _dueDate = widget.debt!.dueDate;
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
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      } else {
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
