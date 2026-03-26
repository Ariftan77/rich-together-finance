import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
import '../../core/localization/app_translations.dart';
import '../../core/models/enums.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';
import 'glass_card.dart';

/// A tappable field that opens a searchable multi-select account picker modal.
/// Shows selected account chips above the dropdown trigger.
class MultiAccountPickerField extends StatelessWidget {
  final List<Account> accounts;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;
  final Map<int, double>? balances;
  final bool showDecimal;
  final AppTranslations trans;

  const MultiAccountPickerField({
    super.key,
    required this.accounts,
    required this.selectedIds,
    required this.onChanged,
    required this.trans,
    this.balances,
    this.showDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final hasSelection = selectedIds.isNotEmpty;
    final selectedAccounts =
        accounts.where((a) => selectedIds.contains(a.id)).toList();

    String displayText;
    if (!hasSelection) {
      displayText = trans.goalSelectAccounts;
    } else if (selectedAccounts.length == 1) {
      displayText = selectedAccounts.first.name;
    } else {
      displayText =
          '${selectedAccounts.length} ${trans.goalAccountsSelected}';
    }

    final Color emptyIconColor =
        isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5);
    final Color selectedTextColor =
        isLight ? AppColors.textPrimaryLight : Colors.white;
    final Color emptyTextColor =
        isLight ? const Color(0xFF94A3B8) : Colors.white54;
    final Color actionIconColor =
        isLight ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected chips
        if (hasSelection) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedAccounts.map((account) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _accountTypeIcon(account.type),
                      color: AppColors.primaryGold,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      account.name,
                      style: TextStyle(
                        color: isLight
                            ? AppColors.textPrimaryLight
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final updated = Set<int>.from(selectedIds);
                        updated.remove(account.id);
                        onChanged(updated);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.close,
                        color: isLight
                            ? const Color(0xFF64748B)
                            : Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Dropdown trigger
        GestureDetector(
          onTap: () => _showPicker(context),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 12,
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color:
                      hasSelection ? AppColors.primaryGold : emptyIconColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color:
                          hasSelection ? selectedTextColor : emptyTextColor,
                      fontSize: 14,
                      fontWeight:
                          hasSelection ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSelection) ...[
                  GestureDetector(
                    onTap: () => onChanged({}),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      color: actionIconColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.expand_more,
                  color: isLight
                      ? AppColors.textSecondaryLight
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiAccountPickerSheet(
        accounts: accounts,
        selected: selectedIds,
        onChanged: onChanged,
        balances: balances,
        showDecimal: showDecimal,
        trans: trans,
      ),
    );
  }

  IconData _accountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.money;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.eWallet:
        return Icons.phone_android;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }
}

class _MultiAccountPickerSheet extends StatefulWidget {
  final List<Account> accounts;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final Map<int, double>? balances;
  final bool showDecimal;
  final AppTranslations trans;

  const _MultiAccountPickerSheet({
    required this.accounts,
    required this.selected,
    required this.onChanged,
    required this.trans,
    this.balances,
    this.showDecimal = false,
  });

  @override
  State<_MultiAccountPickerSheet> createState() =>
      _MultiAccountPickerSheetState();
}

class _MultiAccountPickerSheetState extends State<_MultiAccountPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Set<int> _current;
  late List<Account> _filtered;

  @override
  void initState() {
    super.initState();
    _current = Set.from(widget.selected);
    _filtered = widget.accounts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.accounts;
      } else {
        _filtered = widget.accounts.where((a) {
          return a.name.toLowerCase().contains(q) ||
              a.type.displayName.toLowerCase().contains(q) ||
              a.currency.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggle(int accountId) {
    setState(() {
      if (_current.contains(accountId)) {
        _current.remove(accountId);
      } else {
        _current.add(accountId);
      }
    });
    widget.onChanged(Set.from(_current));
  }

  IconData _accountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.money;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.eWallet:
        return Icons.phone_android;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final Color bgColor = isDefault
        ? const Color(0xFF1A1A2E)
        : isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0A0A0A);

    final Color borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.1);

    final Color handleColor = isLight
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.3);

    final Color titleColor =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;

    final Color searchBg = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.08);

    final Color itemPrimaryColor =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color itemSecondaryColor =
        isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    final Color checkboxBorderColor =
        isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3);

    final trans = widget.trans;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title + clear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trans.goalSelectAccounts,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_current.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _current.clear());
                      widget.onChanged({});
                    },
                    child: Text(
                      trans.goalClearAll,
                      style: const TextStyle(
                          color: AppColors.primaryGold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: TextStyle(
                  color: itemPrimaryColor,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: trans.goalSearchAccounts,
                  hintStyle: TextStyle(
                    color: isLight
                        ? AppColors.textTertiaryLight
                        : AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isLight
                        ? AppColors.textSecondaryLight
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),

          // Account list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      trans.goalNoAccountsAvailable,
                      style: TextStyle(
                        color: isLight
                            ? AppColors.textSecondaryLight
                            : AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final account = _filtered[index];
                      final isSelected = _current.contains(account.id);
                      final balance =
                          widget.balances?[account.id] ?? account.initialBalance;

                      return InkWell(
                        onTap: () => _toggle(account.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          color: isSelected
                              ? AppColors.primaryGold.withValues(alpha: 0.1)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                _accountTypeIcon(account.type),
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : itemSecondaryColor,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: TextStyle(
                                        color: itemPrimaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${account.currency.code} ${NumberFormat.decimalPattern().format(balance)} · ${account.type.displayName}',
                                      style: TextStyle(
                                        color: itemSecondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryGold
                                        : checkboxBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.black, size: 16)
                                    : null,
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
