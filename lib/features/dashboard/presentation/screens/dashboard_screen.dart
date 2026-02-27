import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../providers/dashboard_providers.dart';
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
  final ScrollController _reportScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reportScrollController.addListener(_onReportScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportScrollController.removeListener(_onReportScroll);
    _reportScrollController.dispose();
    super.dispose();
  }

  void _onReportScroll() {
    if (_reportScrollController.position.pixels >=
        _reportScrollController.position.maxScrollExtent - 200) {
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
                  Text(
                    ref.watch(translationsProvider).dashboardOverview,
                    style: AppTypography.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
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
                      tabs: [
                        Tab(text: ref.watch(translationsProvider).navDashboard),
                        Tab(text: ref.watch(translationsProvider).navReports),
                      ],
                    ),
                  ),
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
    final cashFlowAsync = ref.watch(dashboardCashFlowProvider);
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
                    onTap: () => _showCurrencyBreakdown(context),
                    onLongPress: () => _showCurrencyBreakdown(context),
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

            const SizedBox(height: 24),

            // Cash Flow Chart
            cashFlowAsync.when(
              data: (cashFlow) => CashFlowChart(data: cashFlow, currencySymbol: baseCurrency.symbol, showDecimal: showDecimal),
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.white.withValues(alpha: 0.08),
      indent: 16,
      endIndent: 16,
    );
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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2D2416),
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
                      style: const TextStyle(
                        color: Colors.white,
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
                            style: const TextStyle(
                              color: Colors.white,
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
                            '${Formatters.formatNumber(rate)} × ${isNegative ? '-' : ''}${currency.symbol} ${Formatters.formatCurrency(absOriginal, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
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
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2D2416),
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
                    style: const TextStyle(
                      color: Colors.white,
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
                            style: const TextStyle(
                              color: Colors.white,
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
                            '${Formatters.formatNumber(rate)} × ${isNegative ? '-' : ''}${currency.symbol} ${Formatters.formatCurrency(absOriginal, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
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
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlySummaryProvider);
      },
      child: summaryAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Text(
                trans.reportNoData,
                style: AppTypography.textTheme.bodyLarge!.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
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
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month header
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                            label: '${trans.debtTitle} (${trans.debtPayable})', // "Debts (I Owe)"
                            amount: s.debtPayable,
                            color: Colors.orange,
                            prefix: '-',
                            currency: baseCurrency,
                            showDecimal: showDecimal,
                          ),
                        if (s.debtReceivable > 0) ...[
                          const SizedBox(height: 8),
                          _ReportRow(
                            label: '${trans.debtTitle} (${trans.debtReceivable})', // "Debts (Owed to Me)"
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
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 10),
                      // Net
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            trans.reportNet,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // Amount
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.7),
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
