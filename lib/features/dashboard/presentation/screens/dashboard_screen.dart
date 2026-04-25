import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/premium_gate_modal.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/savings_rate_chart.dart';
import '../widgets/compact_savings_rate_card.dart';
import '../widgets/month_over_month_card.dart';
import '../widgets/ytd_top_categories.dart';
import '../widgets/dow_spending_chart.dart';
import '../widgets/recurring_split_card.dart';
import '../widgets/budget_performance_chart.dart';
import '../widgets/financial_health_card.dart';
import '../../../reports/presentation/screens/report_details_screen.dart';
import '../../../reports/presentation/widgets/export_report_modal.dart';

/// Dashboard Overview Screen with Tabs
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _reportSubTabController;
  final ScrollController _reportScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackFirstOverviewVisit();
    final _dao = ref.read(transactionDaoProvider);
    final _profileId = ref.read(activeProfileIdProvider);
    if (_profileId != null) {
      unawaited(AnalyticsService.checkAndTrackNoTransactionsIn7Days(_dao, _profileId).catchError((_) {}));
    }
    _tabController = TabController(length: 2, vsync: this);
    // Free-tier users default to Monthly Details (index 1); premium users start
    // on Deep Analytics (index 0) — determined after first frame when context is ready.
    _reportSubTabController = TabController(length: 2, vsync: this);
    _reportScrollController.addListener(_onReportScroll);
    _reportSubTabController.addListener(_onReportSubTabChanged);
    // Set initial sub-tab based on premium status after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPremium = ref.read(premiumStatusProvider);
      if (!isPremium) {
        _reportSubTabController.index = 1;
      }
    });
  }

  /// Intercepts taps on the Deep Analytics sub-tab (index 0) for free-tier users.
  void _onReportSubTabChanged() {
    // Only fire on the indexIsChanging edge (user initiated tap, not animation frame)
    if (!_reportSubTabController.indexIsChanging) return;
    if (_reportSubTabController.index != 0) return; // Not Deep Analytics

    final isPremium = ref.read(premiumStatusProvider);
    if (isPremium) return; // Premium users can access freely

    // Snap back to Monthly Details before the animation completes
    _reportSubTabController.index = 1;

    // Show gate modal after the frame so the tab snap is visible first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trans = ref.read(translationsProvider);
      showPremiumGateModal(
        context,
        ref,
        title: trans.premiumGateDeepAnalyticsTitle,
        description: trans.premiumGateDeepAnalyticsDesc,
        icon: Icons.insights_rounded,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportSubTabController.removeListener(_onReportSubTabChanged);
    _reportSubTabController.dispose();
    _reportScrollController.removeListener(_onReportScroll);
    _reportScrollController.dispose();
    super.dispose();
  }

  void _onReportScroll() {
    if (_reportScrollController.position.pixels >=
        _reportScrollController.position.maxScrollExtent - 200) {
      // Don't increment while already loading to prevent double-trigger
      if (ref.read(monthlySummaryProvider).isLoading) return;
      final current = ref.read(reportMonthCountProvider);
      ref.read(reportMonthCountProvider.notifier).state = current + 6;
    }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(builder: (context) {
                        final themeMode = AppThemeProvider.of(context);
                        final isLight = themeMode == AppThemeMode.light ||
                            (themeMode == AppThemeMode.system &&
                                MediaQuery.platformBrightnessOf(context) == Brightness.light);
                        return Text(
                          ref.watch(translationsProvider).dashboardOverview,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white,
                          ),
                        );
                      }),
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (_, __) {
                          if (_tabController.index != 1) {
                            return const SizedBox(width: 40, height: 40);
                          }
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.file_download_outlined,
                              color: AppColors.primaryGold,
                            ),
                            onPressed: () =>
                                showExportReportModal(context),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final themeMode = AppThemeProvider.of(context);
                    final isLight = themeMode == AppThemeMode.light ||
                        (themeMode == AppThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) == Brightness.light);
                    return Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFE2E8F0)
                          : Colors.white.withValues(alpha: 0.1),
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
                      labelColor: isLight ? AppColors.textPrimaryLight : Colors.white,
                      unselectedLabelColor: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: ref.watch(translationsProvider).navDashboard),
                        Tab(text: ref.watch(translationsProvider).navReports),
                      ],
                    ),
                  );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
    final activeDebtAsync = ref.watch(dashboardActiveDebtProvider);
    final monthlyIncomeAsync = ref.watch(dashboardMonthlyIncomeProvider);
    final monthlyExpenseAsync = ref.watch(dashboardMonthlyExpenseProvider);
    final monthlyAdjustmentAsync = ref.watch(dashboardMonthlyAdjustmentProvider);
    final categoryBreakdownAsync = ref.watch(dashboardCategoryBreakdownProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final trans = ref.watch(translationsProvider);
    // Pre-load by-currency maps so data is ready when user taps rows
    ref.watch(dashboardBalanceByCurrencyProvider);
    ref.watch(dashboardMonthlyIncomeByCurrencyProvider);
    ref.watch(dashboardMonthlyExpenseByCurrencyProvider);
    ref.watch(dashboardActivePayableByCurrencyProvider);
    ref.watch(dashboardActiveReceivableByCurrencyProvider);
    final adjustmentByCurrencyAsync = ref.watch(dashboardMonthlyAdjustmentByCurrencyProvider);
    final hasAdjustments = adjustmentByCurrencyAsync.valueOrNull?.isNotEmpty ?? false;
    final activeDebt = activeDebtAsync.valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardTotalBalanceProvider);
        ref.invalidate(dashboardNetWorthProvider);
        ref.invalidate(dashboardActiveDebtProvider);
        ref.invalidate(convertedMonthlyTransactionsProvider);
        ref.invalidate(dashboardCashFlowProvider);
        ref.invalidate(dashboardBalanceByCurrencyProvider);
        ref.invalidate(financialHealthScoreProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Rows in a single GlassCard
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.primaryGold,
                    title: trans.dashboardTotalBalance,
                    value: totalBalanceAsync.when(
                      data: (v) => '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                      loading: () => '...',
                      error: (_, __) => 'Error',
                    ),
                    onTap: () => _showCurrencyBreakdown(context),
                    onLongPress: () => _showCurrencyBreakdown(context),
                  ),
                  _buildDivider(),
                  _SummaryRow(
                    icon: Icons.trending_up,
                    iconColor: AppColors.success,
                    title: trans.dashboardNetWorth,
                    value: netWorthAsync.when(
                      data: (v) => '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                      loading: () => '...',
                      error: (_, __) => 'Error',
                    ),
                    onTap: () => _showNetWorthBreakdown(context),
                    onLongPress: () => _showNetWorthBreakdown(context),
                  ),
                  // Active debts below Net Worth (all-time outstanding, cleared when settled)
                  if (activeDebt?.hasPayable == true) ...[
                    _buildDivider(),
                    _SummaryRow(
                      icon: Icons.people_outline,
                      iconColor: Colors.orange,
                      title: '${trans.debtTitle} (${trans.debtPayable})',
                      subtitle: null,
                      value: '${baseCurrency.symbol} ${Formatters.formatCurrency(activeDebt!.payable, showDecimal: showDecimal)}',
                      onTap: () => _showAmountBreakdown(
                        context,
                        title: '${trans.debtTitle} (${trans.debtPayable})',
                        icon: Icons.people_outline,
                        iconColor: Colors.orange,
                        breakdownAsync: ref.read(dashboardActivePayableByCurrencyProvider),
                      ),
                    ),
                  ],
                  if (activeDebt?.hasReceivable == true) ...[
                    _buildDivider(),
                    _SummaryRow(
                      icon: Icons.people_outline,
                      iconColor: const Color(0xFF60A5FA),
                      title: '${trans.debtTitle} (${trans.debtReceivable})',
                      subtitle: null,
                      value: '${baseCurrency.symbol} ${Formatters.formatCurrency(activeDebt!.receivable, showDecimal: showDecimal)}',
                      onTap: () => _showAmountBreakdown(
                        context,
                        title: '${trans.debtTitle} (${trans.debtReceivable})',
                        icon: Icons.people_outline,
                        iconColor: const Color(0xFF60A5FA),
                        breakdownAsync: ref.read(dashboardActiveReceivableByCurrencyProvider),
                      ),
                    ),
                  ],
                  _buildDivider(),
                  _SummaryRow(
                    icon: Icons.arrow_downward,
                    iconColor: AppColors.success,
                    title: trans.dashboardIncome,
                    subtitle: trans.commonThisMonth,
                    value: monthlyIncomeAsync.when(
                      data: (v) => '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                      loading: () => '...',
                      error: (_, __) => 'Error',
                    ),
                    onTap: () => _showAmountBreakdown(
                      context,
                      title: trans.dashboardIncome,
                      icon: Icons.arrow_downward,
                      iconColor: AppColors.success,
                      breakdownAsync: ref.read(dashboardMonthlyIncomeByCurrencyProvider),
                    ),
                  ),
                  _buildDivider(),
                  _SummaryRow(
                    icon: Icons.arrow_upward,
                    iconColor: AppColors.error,
                    title: trans.dashboardExpense,
                    subtitle: trans.commonThisMonth,
                    value: monthlyExpenseAsync.when(
                      data: (v) => '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                      loading: () => '...',
                      error: (_, __) => 'Error',
                    ),
                    onTap: () => _showAmountBreakdown(
                      context,
                      title: trans.dashboardExpense,
                      icon: Icons.arrow_upward,
                      iconColor: AppColors.error,
                      breakdownAsync: ref.read(dashboardMonthlyExpenseByCurrencyProvider),
                    ),
                  ),
                  if (hasAdjustments) ...[
                    _buildDivider(),
                    _SummaryRow(
                      icon: Icons.tune,
                      iconColor: const Color(0xFFa78bfa),
                      title: trans.accountBalanceAdjustment,
                      subtitle: trans.commonThisMonth,
                      value: monthlyAdjustmentAsync.when(
                        data: (v) {
                          final prefix = v >= 0 ? '+' : '-';
                          return '$prefix${baseCurrency.symbol} ${Formatters.formatCurrency(v.abs(), showDecimal: showDecimal)}';
                        },
                        loading: () => '...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => _showAmountBreakdown(
                        context,
                        title: trans.accountBalanceAdjustment,
                        icon: Icons.tune,
                        iconColor: const Color(0xFFa78bfa),
                        breakdownAsync: ref.read(dashboardMonthlyAdjustmentByCurrencyProvider),
                        signed: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Financial Health Score
            const FinancialHealthCard(),

            const SizedBox(height: 24),

            // Category Pie Chart
            categoryBreakdownAsync.when(
              data: (breakdown) => CategoryPieChart(data: breakdown, currencySymbol: baseCurrency.symbol, showDecimal: showDecimal),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                ),
              ),
              error: (error, _) => Center(
                child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
              ),
            ),

            const SizedBox(height: 16),

            // Month-over-Month Comparison (compact)
            MonthOverMonthCard(
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
            ),

            const SizedBox(height: 16),

            // Savings Rate (compact)
            const CompactSavingsRateCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Builder(builder: (context) {
      final themeMode = AppThemeProvider.of(context);
      final isLight = themeMode == AppThemeMode.light ||
          (themeMode == AppThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.light);
      return Divider(
        height: 1,
        thickness: 0.5,
        color: isLight
            ? Colors.black.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.08),
        indent: 16,
        endIndent: 16,
      );
    });
  }

  void _showAmountBreakdown(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required AsyncValue<Map<Currency, double>> breakdownAsync,
    bool signed = false,
  }) async {
    final breakdown = breakdownAsync.valueOrNull;
    if (breakdown == null || breakdown.isEmpty) return;

    final showDecimal = ref.read(showDecimalProvider);
    final baseCurrency = ref.read(defaultCurrencyProvider);
    final trans = ref.read(translationsProvider);
    final exchangeService = ref.read(currencyExchangeServiceProvider);

    final rateResult = await exchangeService.getRates();
    final rates = rateResult.rates;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return Dialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? Colors.white
                : const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...breakdown.entries.map((entry) {
                final currency = entry.key;
                final originalAmount = entry.value;
                final isForeign = currency != baseCurrency;
                final isNegative = originalAmount < 0;
                final absOriginal = originalAmount.abs();

                double convertedAmount;
                double rate = 1.0;
                if (isForeign) {
                  rate = CurrencyExchangeService.convertCurrency(
                    1.0, currency.code, baseCurrency.code, rates,
                  );
                  convertedAmount = absOriginal * rate;
                } else {
                  convertedAmount = absOriginal;
                }

                final prefix = signed ? (isNegative ? '-' : '+') : (isNegative ? '-' : '');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currency.code,
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$prefix${baseCurrency.symbol} ${Formatters.formatCurrency(convertedAmount, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight ? AppColors.textPrimaryLight : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isForeign) ...[
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${Formatters.formatRate(rate)} × ${isNegative ? '-' : ''}${currency.symbol} ${Formatters.formatCurrency(absOriginal, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    trans.close,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showCurrencyBreakdown(BuildContext context) async {
    final breakdownAsync = ref.read(dashboardBalanceByCurrencyProvider);
    final breakdown = breakdownAsync.valueOrNull;
    if (breakdown == null || breakdown.isEmpty) return;

    final showDecimal = ref.read(showDecimalProvider);
    final baseCurrency = ref.read(defaultCurrencyProvider);
    final trans = ref.read(translationsProvider);
    final exchangeService = ref.read(currencyExchangeServiceProvider);

    final rateResult = await exchangeService.getRates();
    final rates = rateResult.rates;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return Dialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? Colors.white
                : const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.primaryGold, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    trans.dashboardBalanceCurrency,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...breakdown.entries.map((entry) {
                final currency = entry.key;
                final originalAmount = entry.value;
                final isForeign = currency != baseCurrency;
                final isNegative = originalAmount < 0;
                final absOriginal = originalAmount.abs();

                double convertedAmount;
                double rate = 1.0;
                if (isForeign) {
                  rate = CurrencyExchangeService.convertCurrency(
                    1.0, currency.code, baseCurrency.code, rates,
                  );
                  convertedAmount = absOriginal * rate;
                } else {
                  convertedAmount = absOriginal;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currency.code,
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${isNegative ? '-' : ''}${baseCurrency.symbol} ${Formatters.formatCurrency(convertedAmount, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight ? AppColors.textPrimaryLight : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isForeign) ...[
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${Formatters.formatRate(rate)} × ${isNegative ? '-' : ''}${currency.symbol} ${Formatters.formatCurrency(absOriginal, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    trans.close,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showNetWorthBreakdown(BuildContext context) async {
    final breakdownAsync = ref.read(dashboardBalanceByCurrencyProvider);
    final breakdown = breakdownAsync.valueOrNull;
    if (breakdown == null || breakdown.isEmpty) return;

    final showDecimal = ref.read(showDecimalProvider);
    final baseCurrency = ref.read(defaultCurrencyProvider);
    final trans = ref.read(translationsProvider);
    final exchangeService = ref.read(currencyExchangeServiceProvider);
    final activeDebtAsync = ref.read(dashboardActiveDebtProvider);
    final activeDebt = activeDebtAsync.valueOrNull;

    final rateResult = await exchangeService.getRates();
    final rates = rateResult.rates;

    if (!mounted) return;

    // Calculate total balance (sum of all account balances converted to base)
    double totalBalance = 0;
    for (final entry in breakdown.entries) {
      final currency = entry.key;
      final amount = entry.value;
      if (currency == baseCurrency) {
        totalBalance += amount;
      } else {
        totalBalance += CurrencyExchangeService.convertCurrency(
          amount, currency.code, baseCurrency.code, rates,
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return Dialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? Colors.white
                : const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.success, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    trans.dashboardNetWorth,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Total Balance line
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.primaryGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    trans.dashboardTotalBalance,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${baseCurrency.symbol} ${Formatters.formatCurrency(totalBalance, showDecimal: showDecimal)}',
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Receivable debts (owed to me — adds to net worth)
              if (activeDebt != null && activeDebt.hasReceivable) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: Color(0xFF60A5FA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      trans.debtReceivable,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '+${baseCurrency.symbol} ${Formatters.formatCurrency(activeDebt.receivable, showDecimal: showDecimal)}',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              // Payable debts (I owe — subtracts from net worth)
              if (activeDebt != null && activeDebt.hasPayable) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      trans.debtPayable,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '-${baseCurrency.symbol} ${Formatters.formatCurrency(activeDebt.payable, showDecimal: showDecimal)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              // Divider + Net Worth total
              if (activeDebt != null && activeDebt.hasAny) ...[
                const SizedBox(height: 12),
                Divider(color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      trans.dashboardNetWorth,
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Builder(builder: (context) {
                      final netWorth = totalBalance
                          + (activeDebt.hasReceivable ? activeDebt.receivable : 0)
                          - (activeDebt.hasPayable ? activeDebt.payable : 0);
                      return Text(
                        '${baseCurrency.symbol} ${Formatters.formatCurrency(netWorth, showDecimal: showDecimal)}',
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    trans.close,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildReportsTab() {
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Column(
      children: [
        // Sub-tab bar: Deep Analytics | Monthly Details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFE2E8F0)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _reportSubTabController,
              indicator: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: isLight ? 0.2 : 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primaryGold,
              unselectedLabelColor: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: trans.deepAnalyticsTab),
                Tab(text: trans.monthlyDetailsTab),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _reportSubTabController,
            children: [
              _buildDeepAnalyticsSubTab(),
              _buildMonthlyDetailsSubTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeepAnalyticsSubTab() {
    final cashFlowAsync = ref.watch(dashboardCashFlowProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardCashFlowProvider);
        ref.invalidate(savingsRateTrendProvider);
        ref.invalidate(ytdTopCategoriesProvider);
        ref.invalidate(categoryMultiMonthTrendProvider);
        ref.invalidate(dowSpendingProvider);
        ref.invalidate(recurringVsDiscretionaryProvider);
        ref.invalidate(budgetPerformanceProvider);
        ref.invalidate(financialHealthScoreProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Trends section ──
            _buildSectionHeader(trans.sectionTrends, isLight),
            const SizedBox(height: 12),

            // Cash Flow Chart
            cashFlowAsync.when(
              data: (cashFlow) => CashFlowChart(
                data: cashFlow,
                currencySymbol: baseCurrency.symbol,
                showDecimal: showDecimal,
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                ),
              ),
              error: (error, _) => Center(
                child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
              ),
            ),

            const SizedBox(height: 16),

            // Savings Rate Trend (full chart)
            SavingsRateChart(
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
            ),

            const SizedBox(height: 24),

            // ── Spending Analysis section ──
            _buildSectionHeader(trans.sectionSpendingAnalysis, isLight),
            const SizedBox(height: 12),

            // YTD Top Categories (with inline category trend)
            YtdTopCategories(
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
            ),

            const SizedBox(height: 24),

            // ── Behavior Patterns section ──
            _buildSectionHeader(trans.sectionBehaviorPatterns, isLight),
            const SizedBox(height: 12),

            // Day-of-week spending pattern
            DowSpendingChart(
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
            ),

            const SizedBox(height: 16),

            // Recurring vs discretionary split
            RecurringSplitCard(
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
            ),

            const SizedBox(height: 16),

            // Budget performance history
            const BudgetPerformanceChart(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isLight) {
    return Text(
      title,
      style: TextStyle(
        color: isLight
            ? const Color(0xFF94A3B8)
            : Colors.white.withValues(alpha: 0.4),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMonthlyDetailsSubTab() {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlySummaryProvider);
      },
      child: summaryAsync.when(
        skipLoadingOnReload: true,
        data: (summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Text(
                trans.reportNoData,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            );
          }

          return ListView.builder(
            controller: _reportScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final s = summaries[index];
              final monthLabel = DateFormat.yMMMM(locale.toString()).format(s.month);
              final hasDebt = s.debtPayable > 0 || s.debtReceivable > 0;
              final hasAdjustment = s.adjustmentIn > 0 || s.adjustmentOut > 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportDetailsScreen(month: s.month),
                      ),
                    );
                  },
                  child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            monthLabel,
                            style: TextStyle(
                              color: isLight ? AppColors.textPrimaryLight : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Income
                      _ReportRow(
                        label: trans.entryTypeIncome,
                        amount: s.income,
                        color: AppColors.success,
                        prefix: '+',
                        currency: baseCurrency,
                        showDecimal: showDecimal,
                      ),
                      const SizedBox(height: 8),
                      // Expense
                      _ReportRow(
                        label: trans.entryTypeExpense,
                        amount: s.expense,
                        color: AppColors.error,
                        prefix: '-',
                        currency: baseCurrency,
                        showDecimal: showDecimal,
                      ),
                      if (hasAdjustment) ...[
                        const SizedBox(height: 8),
                        if (s.adjustmentIn > 0)
                          _ReportRow(
                            label: trans.entryTypeAdjustmentIn,
                            amount: s.adjustmentIn,
                            color: const Color(0xFFa78bfa),
                            prefix: '+',
                            currency: baseCurrency,
                            showDecimal: showDecimal,
                          ),
                        if (s.adjustmentOut > 0) ...[
                          const SizedBox(height: 8),
                          _ReportRow(
                            label: trans.entryTypeAdjustmentOut,
                            amount: s.adjustmentOut,
                            color: Colors.amber,
                            prefix: '-',
                            currency: baseCurrency,
                            showDecimal: showDecimal,
                          ),
                        ],
                      ],
                      if (hasDebt) ...[
                        const SizedBox(height: 8),
                        if (s.debtPayable > 0)
                          _ReportRow(
                            label: '${trans.debtTitle} (${trans.debtPayable})',
                            amount: s.debtPayable,
                            color: Colors.orange,
                            prefix: '-',
                            currency: baseCurrency,
                            showDecimal: showDecimal,
                          ),
                        if (s.debtReceivable > 0) ...[
                          const SizedBox(height: 8),
                          _ReportRow(
                            label: '${trans.debtTitle} (${trans.debtReceivable})',
                            amount: s.debtReceivable,
                            color: const Color(0xFF60A5FA),
                            prefix: '+',
                            currency: baseCurrency,
                            showDecimal: showDecimal,
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 10),
                      // Net
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            trans.reportNet,
                            style: TextStyle(
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${s.net >= 0 ? '+' : ''}${baseCurrency.symbol} ${Formatters.formatCurrency(s.net.abs(), showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: s.net >= 0 ? AppColors.success : AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
        error: (err, _) => Center(
          child: Text('${trans.error}: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SummaryRow({
    required this.icon,
    this.iconColor = Colors.white,
    required this.title,
    this.subtitle,
    required this.value,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // Amount
            Text(
              value,
              style: TextStyle(
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                fontSize: 12, // Reduced by 20% from 15
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 16,
              child: onTap != null
                  ? Icon(
                      Icons.chevron_right,
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.3),
                      size: 16,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;
  final Currency currency;
  final bool showDecimal;

  const _ReportRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
    required this.currency,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          '$prefix${currency.symbol} ${Formatters.formatCurrency(amount, showDecimal: showDecimal)}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
