import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../widgets/account_card.dart';
import '../providers/balance_provider.dart';
import 'account_entry_screen.dart';

/// Search query state for the wallet screen.
final _walletSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _walletCurrencyFilterProvider = StateProvider.autoDispose<Set<Currency>>((ref) => {});
final _walletTypeFilterProvider = StateProvider.autoDispose<Set<AccountType>>((ref) => {});
final _walletFilterExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

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
              // Search bar
              TextField(
                onChanged: (value) =>
                    ref.read(_walletSearchProvider.notifier).state = value,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: trans.walletSearch,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white,
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: selectedCurrencies.isEmpty,
                        onTap: () => ref.read(_walletCurrencyFilterProvider.notifier).state = {},
                      ),
                      const SizedBox(width: 8),
                      ...Currency.values.map((c) {
                        final isSelected = selectedCurrencies.contains(c);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _FilterChip(
                            label: c.code,
                            isSelected: isSelected,
                            onTap: () {
                              final current = Set<Currency>.from(ref.read(_walletCurrencyFilterProvider));
                              if (isSelected) {
                                current.remove(c);
                              } else {
                                current.add(c);
                              }
                              ref.read(_walletCurrencyFilterProvider.notifier).state = current;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
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
                                color: Colors.white.withValues(alpha: 0.3)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium!.copyWith(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
