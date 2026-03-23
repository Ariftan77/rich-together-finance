import 'package:flutter/material.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';

/// A searchable account selector with "Add New" option
class AccountSelector extends StatefulWidget {
  final List<Account> accounts;
  final int? selectedAccountId;
  final ValueChanged<int?> onAccountSelected;
  final Map<int, double>? balances;
  final bool showDecimal;
  final VoidCallback? onAddNew;

  const AccountSelector({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.balances,
    this.showDecimal = false,
    this.onAddNew,
  });

  @override
  State<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<AccountSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Account> _filteredAccounts = [];

  @override
  void initState() {
    super.initState();
    _filteredAccounts = widget.accounts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAccounts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAccounts = widget.accounts;
      } else {
        _filteredAccounts = widget.accounts
            .where((acc) => acc.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF2D2416), const Color(0xFF1A1410)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Account',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onAddNew != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onAddNew!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: AppColors.primaryGold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterAccounts,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search accounts...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.primaryGold.withValues(alpha: 0.8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Account List
          Expanded(
            child: _filteredAccounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No accounts found',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : const Color(0xFF64748B),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final account = _filteredAccounts[index];
                      final isSelected = account.id == widget.selectedAccountId;

                      return GestureDetector(
                        onTap: () {
                          widget.onAccountSelected(account.id);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold.withValues(alpha: 0.15)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF64748B),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primaryGold
                                            : isDark ? Colors.white : AppColors.textPrimaryLight,
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    if (widget.balances != null)
                                      Text(
                                        '${account.currency.code} ${Formatters.formatCurrency(
                                          widget.balances![account.id] ?? 0,
                                          currency: account.currency,
                                          showDecimal: widget.showDecimal,
                                        )}',
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primaryGold.withValues(alpha: 0.75)
                                              : isDark
                                                  ? Colors.white.withValues(alpha: 0.5)
                                                  : const Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryGold,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
