import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/multi_currency_picker_field.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../widgets/account_card.dart';
import '../providers/balance_provider.dart';
import 'account_entry_screen.dart';

/// Search query state for the wallet screen.
final _walletSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _walletCurrencyFilterProvider = StateProvider.autoDispose<Set<Currency>>((ref) => {});
final _walletTypeFilterProvider = StateProvider.autoDispose<Set<AccountType>>((ref) => {});
final _walletFilterExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Total balance across filtered accounts, converted to base currency.
final _walletFilteredTotalBalanceProvider = StreamProvider.autoDispose<double>((ref) async* {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  final balances = ref.watch(accountBalanceProvider);
  final selectedCurrencies = ref.watch(_walletCurrencyFilterProvider);
  final selectedTypes = ref.watch(_walletTypeFilterProvider);
  final searchQuery = ref.watch(_walletSearchProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(currencyExchangeServiceProvider);

  var filtered = accounts;
  if (selectedCurrencies.isNotEmpty) {
    filtered = filtered.where((a) => selectedCurrencies.contains(a.currency)).toList();
  }
  if (selectedTypes.isNotEmpty) {
    filtered = filtered.where((a) => selectedTypes.contains(a.type)).toList();
  }
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    filtered = filtered.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.type.displayName.toLowerCase().contains(q) ||
          a.currency.code.toLowerCase().contains(q) ||
          a.currency.name.toLowerCase().contains(q) ||
          a.currency.symbol.toLowerCase().contains(q);
    }).toList();
  }

  final rateResult = await exchangeService.getRates();
  final rates = rateResult.rates;

  double total = 0;
  for (final account in filtered) {
    final balance = balances[account.id] ?? account.initialBalance;
    if (account.currency == baseCurrency) {
      total += balance;
    } else {
      total += CurrencyExchangeService.convertCurrency(
        balance, account.currency.code, baseCurrency.code, rates,
      );
    }
  }

  yield total;
});

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balances = ref.watch(accountBalanceProvider);
    final trans = ref.watch(translationsProvider);
    final searchQuery = ref.watch(_walletSearchProvider);
    final selectedCurrencies = ref.watch(_walletCurrencyFilterProvider);
    final selectedTypes = ref.watch(_walletTypeFilterProvider);
    final isExpanded = ref.watch(_walletFilterExpandedProvider);
    final totalBalanceAsync = ref.watch(_walletFilteredTotalBalanceProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title
              Text(
                trans.walletTitle,
                style: AppTypography.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              // Total Balance Card
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trans.dashboardTotalBalance,
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          totalBalanceAsync.when(
                            data: (v) => Text(
                              '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            loading: () => Text(
                              '...',
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight, fontSize: 20),
                            ),
                            error: (_, __) => const Text(
                              '--',
                              style: TextStyle(color: Colors.white54, fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search bar
              TextField(
                onChanged: (value) =>
                    ref.read(_walletSearchProvider.notifier).state = value,
                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                decoration: InputDecoration(
                  hintText: trans.walletSearch,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter Toggle
              GestureDetector(
                onTap: () => ref.read(_walletFilterExpandedProvider.notifier).state = !isExpanded,
                child: Row(
                  children: [
                    Text(
                      'Filter',
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    if (selectedCurrencies.isNotEmpty || selectedTypes.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 4, height: 4),
                      ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text('Currency', style: AppTypography.textTheme.labelMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 8),
                MultiCurrencyPickerField(
                  selected: selectedCurrencies,
                  onChanged: (updated) =>
                      ref.read(_walletCurrencyFilterProvider.notifier).state = updated,
                ),
                const SizedBox(height: 16),
                Text('Account Type', style: AppTypography.textTheme.labelMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: selectedTypes.isEmpty,
                        onTap: () => ref.read(_walletTypeFilterProvider.notifier).state = {},
                      ),
                      const SizedBox(width: 8),
                      ...AccountType.values.map((t) {
                        final isSelected = selectedTypes.contains(t);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _FilterChip(
                            label: t.displayName,
                            isSelected: isSelected,
                            onTap: () {
                              final current = Set<AccountType>.from(ref.read(_walletTypeFilterProvider));
                              if (isSelected) {
                                current.remove(t);
                              } else {
                                current.add(t);
                              }
                              ref.read(_walletTypeFilterProvider.notifier).state = current;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return Center(
                        child: Text(
                          trans.walletNoAccounts,
                          textAlign: TextAlign.center,
                          style: AppTypography.textTheme.bodyLarge,
                        ),
                      );
                    }

                    final filtered = _filterAccounts(
                      accounts,
                      searchQuery,
                      selectedCurrencies,
                      selectedTypes,
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 48,
                                color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              trans.walletNoResults,
                              style: AppTypography.textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        return AccountCard(
                          account: account,
                          balance: balances[account.id] ?? account.initialBalance,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AccountEntryScreen(account: account),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Account> _filterAccounts(
    List<Account> accounts,
    String query,
    Set<Currency> currencies,
    Set<AccountType> types,
  ) {
    var result = accounts;
    if (currencies.isNotEmpty) {
      result = result.where((a) => currencies.contains(a.currency)).toList();
    }
    if (types.isNotEmpty) {
      result = result.where((a) => types.contains(a.type)).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((account) {
        final nameMatch = account.name.toLowerCase().contains(q);
        final typeMatch = account.type.displayName.toLowerCase().contains(q);
        final currencyMatch = account.currency.code.toLowerCase().contains(q) ||
            account.currency.name.toLowerCase().contains(q) ||
            account.currency.symbol.toLowerCase().contains(q);
        return nameMatch || typeMatch || currencyMatch;
      }).toList();
    }
    
    result.sort((a, b) {
      if (a.lastActivityDate != null && b.lastActivityDate != null) {
        return b.lastActivityDate!.compareTo(a.lastActivityDate!);
      } else if (a.lastActivityDate != null) {
        return -1;
      } else if (b.lastActivityDate != null) {
        return 1;
      }
      return a.name.compareTo(b.name);
    });

    return result;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium!.copyWith(
            color: isSelected ? Colors.black : (isDark ? Colors.white : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
