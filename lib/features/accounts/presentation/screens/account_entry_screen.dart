import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';

class AccountEntryScreen extends ConsumerStatefulWidget {
  final Account? account; // Null for new, non-null for edit

  const AccountEntryScreen({super.key, this.account});

  @override
  ConsumerState<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends ConsumerState<AccountEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  AccountType _selectedType = AccountType.cash;
  Currency _selectedCurrency = Currency.idr;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.account?.initialBalance.toString() ?? '',
    );
    if (widget.account != null) {
      _selectedType = widget.account!.type;
      _selectedCurrency = widget.account!.currency;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    // Remove formatting (dots) and parse
    final balanceText = _balanceController.text.replaceAll('.', '').replaceAll(',', '');
    final balance = double.tryParse(balanceText) ?? 0.0;

    // Check for duplicate account name (only for new accounts or if name changed)
    final dao = ref.read(accountDaoProvider);
    final existingAccounts = await dao.getAllAccountsIncludingInactive();
    
    final isDuplicate = existingAccounts.any((account) {
      // For new account: check if name exists
      if (widget.account == null) {
        return account.name.toLowerCase() == name.toLowerCase();
      }
      // For edit: check if name exists in other accounts
      return account.id != widget.account!.id && 
             account.name.toLowerCase() == name.toLowerCase();
    });

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account name already exists. Please use a different name.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }



    if (widget.account == null) {
      // Create
      await dao.insertAccount(
        AccountsCompanion(
          name: drift.Value(name),
          type: drift.Value(_selectedType), 
          currency: drift.Value(_selectedCurrency),
          initialBalance: drift.Value(balance),
          icon: const drift.Value('wallet'), // Default
          color: const drift.Value('0xFFD4AF37'), // Default Gold
          isActive: const drift.Value(true),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } else {
      // Update
      await dao.updateAccount(
        widget.account!.copyWith(
          name: name,
          type: _selectedType, 
          currency: _selectedCurrency,
          initialBalance: balance,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.account == null ? 'New Account' : 'Edit Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassInput(
                  controller: _nameController,
                  hintText: 'Account Name',
                  prefixIcon: Icons.label,
                  validator: (v) => v!.isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 16),
                GlassInput(
                  controller: _balanceController,
                  hintText: 'Initial Balance',
                  prefixIcon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    IndonesianCurrencyInputFormatter(),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty || v == '0') {
                      return 'Balance required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text('Type', style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AccountType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedType = type);
                      },
                      selectedColor: AppColors.primaryGold,
                      backgroundColor: AppColors.glassBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Currency', style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Currency.values.map((currency) {
                    final isSelected = _selectedCurrency == currency;
                    return ChoiceChip(
                      label: Text(currency.code),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCurrency = currency);
                      },
                      selectedColor: AppColors.primaryGold,
                      backgroundColor: AppColors.glassBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                GlassButton(
                  text: 'Save Account',
                  isFullWidth: true,
                  size: GlassButtonSize.large,
                  onPressed: _saveAccount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
