import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/typography.dart';
import '../widgets/account_card.dart';
import '../providers/balance_provider.dart';
import 'account_entry_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balances = ref.watch(accountBalanceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and add button
              Text(
                'My Accounts',
                style: AppTypography.textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return Center(
                        child: Text(
                          'No accounts yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: AppTypography.textTheme.bodyLarge,
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return AccountCard(
                          account: account,
                          balance: balances[account.id] ?? account.initialBalance,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AccountEntryScreen(account: account),
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
}
