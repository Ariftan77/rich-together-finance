import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../features/accounts/presentation/providers/balance_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';

/// A searchable account selector with "Add New" option.
///
/// Balances are watched internally via [accountBalanceStreamProvider] so the
/// widget always shows live data regardless of when it was built.  The
/// [balances] constructor parameter has been removed — callers no longer need
/// to pass it.
class AccountSelector extends ConsumerStatefulWidget {
  final List<Account> accounts;
  final int? selectedAccountId;
  final ValueChanged<int?> onAccountSelected;
  final bool showDecimal;
  final VoidCallback? onAddNew;

  const AccountSelector({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.showDecimal = false,
    this.onAddNew,
  });

  @override
  ConsumerState<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends ConsumerState<AccountSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Account> _filteredAccounts = [];

  List<Account> _sortedByRecentUse(List<Account> accounts) {
    final sorted = List<Account>.from(accounts);
    sorted.sort((a, b) {
      final aDate = a.lastActivityDate;
      final bDate = b.lastActivityDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _filteredAccounts = _sortedByRecentUse(widget.accounts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAccounts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAccounts = _sortedByRecentUse(widget.accounts);
      } else {
        _filteredAccounts = _sortedByRecentUse(
          widget.accounts
              .where((acc) => acc.name.toLowerCase().contains(query.toLowerCase()))
              .toList(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    // Watch balances reactively — never stale, shows loading state correctly.
    final balancesAsync = ref.watch(accountBalanceStreamProvider);
    final balances = balancesAsync.valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDefault
            ? const Color(0xFF1A1A2E)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A),
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
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
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
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.6),
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
                color: isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterAccounts,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search accounts...',
                  hintStyle: TextStyle(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
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
                          color: isLight
                              ? const Color(0xFFCBD5E1)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No accounts found',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF64748B)
                                : Colors.white.withValues(alpha: 0.6),
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

                      // Determine balance display text.
                      // null balances = still loading → show placeholder dash.
                      // non-null but missing key = account not yet in map → show dash.
                      final balanceText = balances == null
                          ? '-'
                          : '${account.currency.code} ${Formatters.formatCurrency(
                              balances[account.id] ?? 0,
                              currency: account.currency,
                              showDecimal: widget.showDecimal,
                            )}';

                      return GestureDetector(
                        onTap: () {
                          widget.onAccountSelected(account.id);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold.withValues(alpha: 0.15)
                                : isLight
                                    ? Colors.black.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : isLight
                                      ? Colors.black.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.15),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : isLight
                                        ? const Color(0xFF64748B)
                                        : Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primaryGold
                                            : isLight ? AppColors.textPrimaryLight : Colors.white,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      balanceText,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primaryGold.withValues(alpha: 0.75)
                                            : isLight
                                                ? const Color(0xFF94A3B8)
                                                : Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryGold,
                                  size: 16,
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
