import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';

class DebtPaymentViewScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const DebtPaymentViewScreen({super.key, required this.transactionId});

  @override
  ConsumerState<DebtPaymentViewScreen> createState() => _DebtPaymentViewScreenState();
}

class _DebtPaymentViewScreenState extends ConsumerState<DebtPaymentViewScreen> {
  late TextEditingController _noteController;

  bool _isLoading = true;
  bool _isSaving = false;

  // Loaded transaction data (read-only display)
  Transaction? _transaction;
  Account? _account;

  // Stored for delete reversal — never changed after load
  double? _originalAmount;
  String? _originalTitle;
  TransactionType? _originalType;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTransaction());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    final txDao = ref.read(transactionDaoProvider);
    final tx = await txDao.getTransactionById(widget.transactionId);
    if (tx == null || !mounted) return;

    final accountDao = ref.read(accountDaoProvider);
    final account = await accountDao.getAccountById(tx.accountId);
    if (!mounted) return;

    setState(() {
      _transaction = tx;
      _account = account;
      _noteController.text = tx.note ?? '';
      _originalAmount = tx.amount;
      _originalTitle = tx.title;
      _originalType = tx.type;
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (_transaction == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(transactionDaoProvider).updateTransaction(
        widget.transactionId,
        TransactionsCompanion(
          note: drift.Value(_noteController.text.trim()),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction() async {
    FocusScope.of(context).unfocus();

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight ? Colors.white : const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Transaction?',
              style: TextStyle(
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reverse the debt payment. The debt balance will be restored.',
          style: TextStyle(
            color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(transactionDaoProvider).deleteTransaction(widget.transactionId);

      final profileId = ref.read(activeProfileIdProvider);

      // Reverse debt payment — check both "Debt Payment: " prefix and "Group Debt Payment: " prefix
      if (_originalAmount != null && profileId != null && _originalTitle != null) {
        const paymentPrefix = 'Debt Payment: ';
        const groupPrefix = 'Group Debt Payment: ';
        String? personName;
        if (_originalTitle!.startsWith(paymentPrefix)) {
          personName = _originalTitle!.substring(paymentPrefix.length).trim();
        } else if (_originalTitle!.startsWith(groupPrefix)) {
          personName = _originalTitle!.substring(groupPrefix.length).trim();
        }
        if (personName != null && personName.isNotEmpty) {
          await ref.read(debtDaoProvider).reverseDebtPayment(profileId, personName, _originalAmount!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final showDecimal = ref.watch(showDecimalProvider);
    final locale = ref.watch(localeProvider);

    final isPaymentOut = _originalType == TransactionType.debtPaymentOut;
    final typeLabel = isPaymentOut ? 'Debt Payment' : 'Debt Received';
    final typeColor = isPaymentOut ? AppColors.error : AppColors.success;
    final typeIcon = Icons.handshake_outlined;

    final currency = _account?.currency ?? Currency.idr;
    final amountFormatted = _transaction != null
        ? Formatters.formatCurrency(_transaction!.amount, currency: currency, showDecimal: showDecimal)
        : '—';
    final dateFormatted = _transaction != null
        ? DateFormat.yMMMd(locale.languageCode).add_jm().format(_transaction!.date)
        : '—';

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient(context)),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            title: Text(
              'Debt Payment',
              style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            ),
            actions: [
              if (!_isLoading)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteTransaction,
                  tooltip: 'Delete',
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, color: typeColor, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount (read-only)
                        Text(
                          'Amount',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on, color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                amountFormatted,
                                style: TextStyle(
                                  color: typeColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.lock_outline,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Account (read-only)
                        Text(
                          'Account',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _account?.name ?? 'Unknown',
                                style: TextStyle(
                                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.lock_outline,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date (read-only)
                        Text(
                          'Date',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                dateFormatted,
                                style: TextStyle(
                                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.lock_outline,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title (read-only — used for debt reversal)
                        Text(
                          'Title',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              Icon(Icons.title, color: isLight ? const Color(0xFF64748B) : Colors.white54, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _originalTitle ?? '',
                                  style: TextStyle(
                                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.lock_outline,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Note (editable)
                        GlassInput(
                          controller: _noteController,
                          hintText: 'Note (optional)',
                          prefixIcon: Icons.note_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),

                        // Save button
                        GlassButton(
                          text: 'Save',
                          isFullWidth: true,
                          size: GlassButtonSize.large,
                          onPressed: _saveChanges,
                          isLoading: _isSaving,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
