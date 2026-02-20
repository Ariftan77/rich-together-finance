import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/theme/colors.dart';
import '../../accounts/presentation/screens/accounts_screen.dart';
import '../../transactions/presentation/screens/transactions_history_screen.dart';
import '../../transactions/presentation/screens/transaction_entry_screen.dart';
import '../../accounts/presentation/screens/account_entry_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../../shared/widgets/fab_button.dart';
import '../../../core/providers/app_init_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'screens/dashboard_screen.dart';
import '../../../core/services/ad_service.dart';
import '../../../shared/widgets/ad_banner_widget.dart';

import '../../budget/presentation/screens/budget_entry_screen.dart';
import '../../goals/presentation/screens/goal_entry_screen.dart';
import '../../wealth/presentation/screens/wealth_screen.dart';
import '../../debts/presentation/screens/debt_entry_screen.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Show App Open ad once per day
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().loadAndShowAppOpen(context);
    });
  }

  final List<Widget> _screens = const [
    TransactionsHistoryScreen(), // 0: Transactions
    AccountsScreen(), // 1: Wallet (Accounts)
    DashboardScreen(), // 2: Overview (Dashboard)
    WealthScreen(), // 3: Wealth (Budget, Goals, Investment)
    SettingsScreen(), // 4: Settings
  ];

  @override
  Widget build(BuildContext context) {
    // Trigger initialization (e.g. recurring transactions check)
    ref.watch(appInitProvider);

    // Determine if using light theme
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBody: true, // Important for glass bottom nav
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: IndexedStack(
          index: _currentIndex < _screens.length ? _currentIndex : 0,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBannerWidget(),
          GlassBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavItem(
                icon: Icons.receipt_long_outlined, 
                activeIcon: Icons.receipt_long, 
                label: ref.watch(translationsProvider).navTransactions,
              ),
              BottomNavItem(
                icon: Icons.account_balance_wallet_outlined, 
                activeIcon: Icons.account_balance_wallet, 
                label: ref.watch(translationsProvider).navWallet,
              ),
              BottomNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: ref.watch(translationsProvider).dashboardOverview,
              ),
              BottomNavItem(
                icon: Icons.trending_up_outlined,
                activeIcon: Icons.trending_up,
                label: ref.watch(translationsProvider).navWealth,
              ),
              BottomNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: ref.watch(translationsProvider).navSettings,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _getFab(context),
    );
  }

  Widget? _getFab(BuildContext context) {
    switch (_currentIndex) {
      case 0: // Transactions
        return FabButton(
          icon: Icons.add,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionEntryScreen(),
              ),
            );
          },
        );
      case 1: // Wallet (Accounts)
        return FabButton(
          icon: Icons.add_card,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccountEntryScreen(),
              ),
            );
          },
        );
      case 2: // Overview
        return null;
      case 3: // Wealth
        final wealthTab = ref.watch(wealthTabIndexProvider);
        if (wealthTab == 0) {
          return FabButton(
            icon: Icons.add,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BudgetEntryScreen(),
                ),
              );
            },
          );
        }
        if (wealthTab == 1) {
          return FabButton(
            icon: Icons.add,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GoalEntryScreen(),
                ),
              );
            },
          );
        }
        if (wealthTab == 2) {
          return FabButton(
            icon: Icons.add,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebtEntryScreen(),
                ),
              );
            },
          );
        }
        return null;
      case 4: // Settings
        return null;
      default:
        return null;
    }
  }
}
