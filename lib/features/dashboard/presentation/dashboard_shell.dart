import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/theme/colors.dart';
import '../../accounts/presentation/screens/accounts_screen.dart';
import '../../transactions/presentation/screens/transactions_history_screen.dart';
import '../../transactions/presentation/screens/transaction_entry_screen.dart';
import '../../../core/providers/database_providers.dart';
import '../../accounts/presentation/screens/account_entry_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../../shared/widgets/fab_button.dart';
import '../../../shared/widgets/transaction_speed_dial_fab.dart';
import '../../../core/providers/app_init_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'screens/dashboard_screen.dart';
import '../../../core/services/ad_service.dart';
import '../../../shared/widgets/ad_banner_widget.dart';
import '../../../core/models/enums.dart';

import '../../budget/presentation/screens/budget_entry_screen.dart';
import '../../goals/presentation/screens/goal_entry_screen.dart';
import '../../wealth/presentation/screens/wealth_screen.dart';
import '../../debts/presentation/screens/debt_entry_screen.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _tabAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /// Tracks whether the transaction speed-dial is currently open so we can
  /// render a transparent barrier that dismisses it on outside tap.
  bool _speedDialOpen = false;
  final GlobalKey<TransactionSpeedDialFabState> _speedDialKey =
      GlobalKey<TransactionSpeedDialFabState>();

  @override
  void initState() {
    super.initState();
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tabAnimController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _tabAnimController, curve: Curves.easeOut),
    );
    _tabAnimController.value = 1.0; // Start fully visible

    // Show App Open ad once per day
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().loadAndShowAppOpen(context);
    });
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    // Close speed-dial if open when switching tabs.
    if (_speedDialOpen) {
      _speedDialKey.currentState?.close();
    }
    if (index == _currentIndex) return;
    final direction = index > _currentIndex ? 1.0 : -1.0;
    setState(() {
      _currentIndex = index;
      _slideAnimation = Tween<Offset>(
        begin: Offset(direction * 0.05, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _tabAnimController, curve: Curves.easeOut));
    });
    _tabAnimController.forward(from: 0.0);
  }

  final List<Widget> _screens = const [
    TransactionsHistoryScreen(), // 0: Transactions
    AccountsScreen(), // 1: Wallet (Accounts)
    DashboardScreen(), // 2: Overview (Dashboard)
    WealthScreen(), // 3: Wealth (Budget, Goals, Investment)
    SettingsScreen(), // 4: Settings
  ];

  void _onSpeedDialSelected(int optionIndex) {
    // Map option index to TransactionType:
    //   0 = Income, 1 = Expense, 2 = Transfer
    const typeMap = [
      TransactionType.income,
      TransactionType.expense,
      TransactionType.transfer,
    ];
    final selectedType = typeMap[optionIndex];

    // Pre-warm categories stream before navigating.
    ref.read(categoriesStreamProvider);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransactionEntryScreen(transactionType: selectedType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Trigger initialization (e.g. recurring transactions check)
    ref.watch(appInitProvider);
    // Pre-warm categories stream so TransactionEntryScreen gets an immediate
    // value instead of waiting for the first DB emission after navigation.
    ref.watch(categoriesStreamProvider);

    return Scaffold(
      extendBody: true, // Important for glass bottom nav
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient(context),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: IndexedStack(
                  index: _currentIndex < _screens.length ? _currentIndex : 0,
                  children: _screens,
                ),
              ),
            ),
          ),
          // Transparent barrier — only present when the speed-dial is open.
          // Tapping it closes the dial without navigating anywhere.
          if (_speedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _speedDialKey.currentState?.close(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBannerWidget(),
          GlassBottomNav(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
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
      case 0: // Transactions — speed-dial with Income / Expense / Transfer
        return TransactionSpeedDialFab(
          key: _speedDialKey,
          onSelected: _onSpeedDialSelected,
          onOpenChanged: (isOpen) {
            setState(() => _speedDialOpen = isOpen);
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
