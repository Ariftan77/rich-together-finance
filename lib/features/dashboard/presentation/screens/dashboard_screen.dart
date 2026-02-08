import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/utils/formatters.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/summary_card.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/category_pie_chart.dart';

/// Dashboard Overview Screen with Tabs
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: AppTypography.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Dashboard'),
                        Tab(text: 'Reports'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final totalBalanceAsync = ref.watch(dashboardTotalBalanceProvider);
    final netWorthAsync = ref.watch(dashboardNetWorthProvider);
    final monthlyIncomeAsync = ref.watch(dashboardMonthlyIncomeProvider);
    final monthlyExpenseAsync = ref.watch(dashboardMonthlyExpenseProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh all providers
        ref.invalidate(dashboardTotalBalanceProvider);
        ref.invalidate(dashboardNetWorthProvider);
        ref.invalidate(dashboardMonthlyIncomeProvider);
        ref.invalidate(dashboardMonthlyExpenseProvider);
        ref.invalidate(dashboardCategoryBreakdownProvider);
        ref.invalidate(dashboardCashFlowProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards Grid
            Row(
              children: [
                Expanded(
                  child: totalBalanceAsync.when(
                    data: (balance) => SummaryCard(
                      title: 'Total Balance',
                      value: Formatters.formatCurrency(balance),
                      icon: Icons.account_balance_wallet,
                      iconColor: AppColors.primaryGold,
                    ),
                    loading: () => const SummaryCard(
                      title: 'Total Balance',
                      value: '...',
                      icon: Icons.account_balance_wallet,
                    ),
                    error: (_, __) => const SummaryCard(
                      title: 'Total Balance',
                      value: 'Error',
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: netWorthAsync.when(
                    data: (netWorth) => SummaryCard(
                      title: 'Net Worth',
                      value: Formatters.formatCurrency(netWorth),
                      icon: Icons.trending_up,
                      iconColor: AppColors.success,
                    ),
                    loading: () => const SummaryCard(
                      title: 'Net Worth',
                      value: '...',
                      icon: Icons.trending_up,
                    ),
                    error: (_, __) => const SummaryCard(
                      title: 'Net Worth',
                      value: 'Error',
                      icon: Icons.trending_up,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: monthlyIncomeAsync.when(
                    data: (income) => SummaryCard(
                      title: 'This Month',
                      value: Formatters.formatCurrency(income),
                      icon: Icons.arrow_downward,
                      iconColor: AppColors.success,
                      subtitle: 'Income',
                    ),
                    loading: () => const SummaryCard(
                      title: 'This Month',
                      value: '...',
                      icon: Icons.arrow_downward,
                      subtitle: 'Income',
                    ),
                    error: (_, __) => const SummaryCard(
                      title: 'This Month',
                      value: 'Error',
                      icon: Icons.arrow_downward,
                      subtitle: 'Income',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: monthlyExpenseAsync.when(
                    data: (expense) => SummaryCard(
                      title: 'This Month',
                      value: Formatters.formatCurrency(expense),
                      icon: Icons.arrow_upward,
                      iconColor: AppColors.error,
                      subtitle: 'Expenses',
                    ),
                    loading: () => const SummaryCard(
                      title: 'This Month',
                      value: '...',
                      icon: Icons.arrow_upward,
                      subtitle: 'Expenses',
                    ),
                    error: (_, __) => const SummaryCard(
                      title: 'This Month',
                      value: 'Error',
                      icon: Icons.arrow_upward,
                      subtitle: 'Expenses',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    final categoryBreakdownAsync = ref.watch(dashboardCategoryBreakdownProvider);
    final cashFlowAsync = ref.watch(dashboardCashFlowProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardCategoryBreakdownProvider);
        ref.invalidate(dashboardCashFlowProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             // Cash Flow Chart (Income vs Expense)
            cashFlowAsync.when(
              data: (cashFlow) => CashFlowChart(data: cashFlow),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error loading cash flow: $error'),
              ),
            ),
            
            const SizedBox(height: 24),

            // Category Breakdown (Pie Chart)
            categoryBreakdownAsync.when(
              data: (breakdown) => CategoryPieChart(data: breakdown),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error loading categories: $error'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
