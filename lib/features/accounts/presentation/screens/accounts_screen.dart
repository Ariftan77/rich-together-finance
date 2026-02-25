import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/typography.dart';
import '../widgets/account_card.dart';
import '../providers/balance_provider.dart';
import 'account_entry_screen.dart';

/// Search query state for the wallet screen.
final _walletSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balances = ref.watch(accountBalanceProvider);
    final trans = ref.watch(translationsProvider);
    final searchQuery = ref.watch(_walletSearchProvider);

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

                    final filtered = _filterAccounts(accounts, searchQuery);

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

  List<Account> _filterAccounts(List<Account> accounts, String query) {
    if (query.isEmpty) return accounts;
    final q = query.toLowerCase();
    return accounts.where((account) {
      final nameMatch = account.name.toLowerCase().contains(q);
      final typeMatch = account.type.displayName.toLowerCase().contains(q);
      final currencyMatch = account.currency.code.toLowerCase().contains(q) ||
          account.currency.name.toLowerCase().contains(q) ||
          account.currency.symbol.toLowerCase().contains(q);
      return nameMatch || typeMatch || currencyMatch;
    }).toList();
  }
}
