import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../../shared/widgets/currency_picker_field.dart';

/// Dialog for quickly creating a new account from the transaction entry screen.
/// Returns the newly created account ID via Navigator.pop.
class AddAccountDialog extends ConsumerStatefulWidget {
  const AddAccountDialog({super.key});

  @override
  ConsumerState<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<AddAccountDialog> {
  final TextEditingController _nameController = TextEditingController();
  late Currency _selectedCurrency;
  AccountType _selectedType = AccountType.cash;
  double _rawBalance = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = ref.read(defaultCurrencyProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openBalanceCalculator() async {
    final result = await CalculatorBottomSheet.show(
      context,
      initialValue: _rawBalance != 0 ? _rawBalance.abs() : null,
      currency: _selectedCurrency,
      showDecimal: ref.read(showDecimalProvider),
    );
    if (result != null && mounted) {
      setState(() => _rawBalance = result);
    }
  }

  void _showBalanceInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2416),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 8),
            const Text('Initial Balance', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Enter the current balance of this account.\n\n'
          'For most account types (Cash, Bank, E-Wallet, Investment), '
          'this should be a positive number.\n\n'
          'For Credit Cards, a negative value represents the amount you currently owe.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an account name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dao = ref.read(accountDaoProvider);
      final profileId = ref.read(activeProfileIdProvider);

      if (profileId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active profile'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Duplicate name check
      final existing = await dao.getAllAccountsIncludingInactive(profileId);
      if (existing.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(translationsProvider).accountNameExists),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final newId = await dao.insertAccount(
        AccountsCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(name),
          type: drift.Value(_selectedType),
          currency: drift.Value(_selectedCurrency),
          initialBalance: drift.Value(_rawBalance),
          icon: const drift.Value('wallet'),
          color: const drift.Value('0xFFD4AF37'),
          isActive: const drift.Value(true),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) Navigator.pop(context, newId);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDecimal = ref.watch(showDecimalProvider);
    final balanceText = _rawBalance != 0
        ? Formatters.formatCurrency(_rawBalance, currency: _selectedCurrency, showDecimal: showDecimal)
        : 'Tap to enter amount';

    return Dialog(
      backgroundColor: const Color(0xFF2D2416),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  Icon(Icons.account_balance_wallet, color: AppColors.primaryGold, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Add Account',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Currency picker (full width)
              Text(
                'CURRENCY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              CurrencyPickerField(
                value: _selectedCurrency,
                onChanged: (val) => setState(() {
                  _selectedCurrency = val;
                  _rawBalance = 0;
                }),
              ),
              const SizedBox(height: 14),

              // Account type dropdown
              _CompactDropdown<AccountType>(
                label: 'Type',
                value: _selectedType,
                items: AccountType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 14),

              // Row 2: Initial Balance
              Row(
                children: [
                  Text(
                    'INITIAL BALANCE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _showBalanceInfo,
                    child: Icon(
                      Icons.info_outline,
                      color: AppColors.primaryGold.withValues(alpha: 0.75),
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openBalanceCalculator,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on, color: AppColors.primaryGold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          balanceText,
                          style: TextStyle(
                            color: _rawBalance != 0 ? Colors.white : Colors.white54,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(Icons.calculate_outlined, color: Colors.white.withValues(alpha: 0.4), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Row 3: Account Name
              Text(
                'ACCOUNT NAME',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'e.g. My BCA Account',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
                    prefixIcon: Icon(Icons.label_outline, color: AppColors.primaryGold.withValues(alpha: 0.7), size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1410)),
                            )
                          : const Text(
                              'Save',
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
      ),
    );
  }
}

/// Compact labeled dropdown for use in row layouts within the dialog.
class _CompactDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: const Color(0xFF221D10),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: Icon(Icons.expand_more, color: Colors.white.withValues(alpha: 0.3), size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
