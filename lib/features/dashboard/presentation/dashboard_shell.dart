import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/backup_service.dart';
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
import '../../../shared/widgets/debt_speed_dial_fab.dart';
import '../../../core/providers/app_init_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'screens/dashboard_screen.dart';
import '../../../core/models/enums.dart';

import '../../budget/presentation/screens/budget_entry_screen.dart';
import '../../budget/presentation/providers/budget_provider.dart';
import '../../goals/presentation/screens/goal_entry_screen.dart';
import '../../goals/presentation/providers/goal_provider.dart';
import '../../wealth/presentation/screens/wealth_screen.dart';
import '../../debts/presentation/screens/debt_entry_screen.dart';
import '../../../shared/tour/tour_keys.dart';
import '../../../core/providers/nav_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/analytics_service.dart';
import '../../transactions/presentation/providers/search_provider.dart';
import '../../feedback/presentation/founder_feedback_modal.dart';
import '../../feedback/services/founder_feedback_service.dart';
import '../../../shared/widgets/premium_gate_modal.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _tabAnimController;
  late final CurvedAnimation _tabCurvedAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final AnimationController _fabPulseController;
  late final Animation<double> _fabPulseAnimation;
  bool _fabEverTapped = false;

  /// Tracks whether the transaction speed-dial is currently open so we can
  /// render a transparent barrier that dismisses it on outside tap.
  bool _speedDialOpen = false;
  /// Typed key for [TransactionSpeedDialFab] — allows the tour to call toggle().
  /// Separate from [TourKeys.fab] which is on the [KeyedSubtree] for spotlight positioning.
  final GlobalKey<TransactionSpeedDialFabState> _speedDialKey = TourKeys.speedDial;

  bool _debtDialOpen = false;
  final GlobalKey<DebtSpeedDialFabState> _debtDialKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackScreenView('Dashboard_Home');
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tabCurvedAnimation = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOut,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _tabCurvedAnimation,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
      _tabCurvedAnimation,
    );
    _tabAnimController.value = 1.0; // Start fully visible

    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fabPulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );

    _loadFabTappedState();

    // Show "Feedback from the Founder" modal on the 3rd app open — once ever.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final show = await FounderFeedbackService.shouldShowModal();
      if (!show) return;
      if (!mounted) return;
      final locale = ref.read(localeProvider);
      showFounderFeedbackModal(context, isIndonesian: locale.languageCode == 'id');
    });

    _triggerAutoBackup();
  }

  Future<void> _loadFabTappedState() async {
    final prefs = await SharedPreferences.getInstance();
    final tapped = prefs.getBool('fab_first_tapped') ?? false;
    if (!mounted) return;
    if (tapped) {
      setState(() => _fabEverTapped = true);
    } else {
      _fabPulseController.repeat(reverse: true);
    }
  }

  Future<void> _onFabFirstTap() async {
    if (_fabEverTapped) return;
    setState(() => _fabEverTapped = true);
    _fabPulseController.stop();
    _fabPulseController.animateTo(1.0, duration: const Duration(milliseconds: 150));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fab_first_tapped', true);
  }

  Future<void> _triggerAutoBackup() async {
    // Fire-and-forget: run after first frame so no UI is blocked
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('cloud_backup_enabled') ?? false)) return;
      final lastBackupMs = prefs.getInt('last_drive_backup_ms') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDayMs = 86400000;
      if (now - lastBackupMs < oneDayMs) return;

      // Try silent sign-in first; only proceed if already connected
      final backupService = ref.read(backupServiceProvider);
      final account = await backupService.signInSilently();
      if (account == null) return;

      try {
        await backupService.uploadToDrive();
        await prefs.setInt('last_drive_backup_ms', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {
        // Silent failure — user can manually back up from settings
      }
    });
  }

  @override
  void dispose() {
    _tabCurvedAnimation.dispose();
    _tabAnimController.dispose();
    _fabPulseController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    // Close speed-dials if open when switching tabs.
    if (_speedDialOpen) {
      _speedDialKey.currentState?.close();
    }
    if (_debtDialOpen) {
      _debtDialKey.currentState?.close();
    }
    if (index == _currentIndex) return;
    final direction = index > _currentIndex ? 1.0 : -1.0;
    setState(() {
      _currentIndex = index;
      _slideAnimation = Tween<Offset>(
        begin: Offset(direction * 0.05, 0),
        end: Offset.zero,
      ).animate(_tabCurvedAnimation);
    });
    _tabAnimController.forward(from: 0.0);
    // Keep the provider in sync so screens can gate their coach-mark tours.
    ref.read(shellTabIndexProvider.notifier).state = index;
  }

  final List<Widget> _screens = const [
    TransactionsHistoryScreen(), // 0: Transactions
    AccountsScreen(), // 1: Wallet (Accounts)
    DashboardScreen(), // 2: Overview (Dashboard)
    WealthScreen(), // 3: Wealth (Budget, Goals, Investment)
    SettingsScreen(), // 4: Settings
  ];

  void _onDebtDialSelected(int optionIndex) {
    // 0 = payable (I Owe), 1 = receivable (Owed to Me)
    const typeMap = [DebtType.payable, DebtType.receivable];
    final selectedType = typeMap[optionIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebtEntryScreen(initialType: selectedType),
      ),
    );
  }

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
    // Pre-warm categories and accounts streams so TransactionEntryScreen gets
    // immediate values instead of waiting for the first DB emission after navigation.
    ref.watch(categoriesStreamProvider);
    ref.watch(accountsStreamProvider);
    // Pre-warm transactions provider so data is ready before the user taps
    // the Transactions tab — avoids DB query + currency conversion competing
    // with the slide-in animation on first open.
    ref.watch(convertedFilteredTransactionsProvider);

    return Scaffold(
      extendBody: true, // Important for glass bottom nav
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient(context),
            ),
          ),
          RepaintBoundary(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _LazyIndexedStack(
                  index: _currentIndex < _screens.length ? _currentIndex : 0,
                  children: _screens,
                ),
              ),
            ),
          ),
          // Transparent barrier — only present when a speed-dial is open.
          // Tapping it closes the dial without navigating anywhere.
          if (_speedDialOpen || _debtDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _speedDialKey.currentState?.close();
                  _debtDialKey.currentState?.close();
                },
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
          GlassBottomNav(
            key: TourKeys.bottomNav,
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
        return KeyedSubtree(
          key: TourKeys.fab,
          child: AnimatedBuilder(
            animation: _fabPulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _fabEverTapped ? 1.0 : _fabPulseAnimation.value,
              child: child,
            ),
            child: TransactionSpeedDialFab(
              key: _speedDialKey,
              onSelected: (index) {
                _onFabFirstTap();
                _onSpeedDialSelected(index);
              },
              onOpenChanged: (isOpen) {
                if (isOpen) _onFabFirstTap();
                setState(() => _speedDialOpen = isOpen);
              },
            ),
          ),
        );
      case 1: // Wallet (Accounts)
        return KeyedSubtree(
          key: TourKeys.walletFab,
          child: FabButton(
            icon: Icons.add_card,
            onPressed: () async {
              final premiumEnabled = ref.read(premiumEnabledProvider);
              final iapEnabled = ref.read(iapEnabledProvider);
              final isPremium = ref.read(premiumStatusProvider);
              final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
              if (premiumEnabled && iapEnabled && !isPremium && accounts.length >= 5) {
                final trans = ref.read(translationsProvider);
                await showPremiumGateModal(
                  context,
                  ref,
                  title: trans.premiumGateAccountTitle,
                  description: trans.premiumGateAccountDesc,
                );
                return;
              }
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountEntryScreen(),
                ),
              );
            },
          ),
        );
      case 2: // Overview
        return null;
      case 3: // Wealth
        final wealthTab = ref.watch(wealthTabIndexProvider);
        if (wealthTab == 0) {
          return FabButton(
            icon: Icons.add,
            onPressed: () async {
              final premiumEnabled = ref.read(premiumEnabledProvider);
              final iapEnabled = ref.read(iapEnabledProvider);
              final isPremium = ref.read(premiumStatusProvider);
              final budgets = ref.read(budgetsWithSpendingProvider).valueOrNull ?? [];
              if (premiumEnabled && iapEnabled && !isPremium && budgets.length >= 3) {
                final trans = ref.read(translationsProvider);
                await showPremiumGateModal(
                  context,
                  ref,
                  title: trans.premiumGateBudgetTitle,
                  description: trans.premiumGateBudgetDesc,
                );
                return;
              }
              if (!mounted) return;
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
            onPressed: () async {
              final premiumEnabled = ref.read(premiumEnabledProvider);
              final iapEnabled = ref.read(iapEnabledProvider);
              final isPremium = ref.read(premiumStatusProvider);
              final goals = ref.read(goalsWithProgressProvider).valueOrNull ?? [];
              if (premiumEnabled && iapEnabled && !isPremium && goals.length >= 3) {
                final trans = ref.read(translationsProvider);
                await showPremiumGateModal(
                  context,
                  ref,
                  title: trans.premiumGateGoalTitle,
                  description: trans.premiumGateGoalDesc,
                );
                return;
              }
              if (!mounted) return;
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
          return DebtSpeedDialFab(
            key: _debtDialKey,
            onSelected: _onDebtDialSelected,
            onOpenChanged: (isOpen) {
              setState(() => _debtDialOpen = isOpen);
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

/// An IndexedStack variant that builds each child only on first activation.
/// Once built, a child stays alive (same behaviour as IndexedStack thereafter).
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _LazyIndexedStack({required this.index, required this.children});

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List.generate(widget.children.length, (i) => i == widget.index);
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activated[widget.index]) {
      _activated[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        if (!_activated[i]) return const SizedBox.shrink();
        return widget.children[i];
      }),
    );
  }
}
