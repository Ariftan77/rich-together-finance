import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

enum _AdvancedReportType {
  monthlySpendingBreakdown,
  spendingByAccountType,
  topMerchantAnalysis,
  monthlyCashFlowStatement,
  incomeStabilityReport,
  budgetVsActual,
  netWorthSnapshot,
  netWorthTrend,
  // investmentPortfolio,   // coming soon
  // investmentReturns,     // coming soon
  debtPayoffPlanner,
  recurringAudit,
  goalPlanner,
  yearInReview,
}

const _reportMeta = <_AdvancedReportType, ({String title, String description, IconData icon})>{
  _AdvancedReportType.monthlySpendingBreakdown: (
    title: 'Monthly Spending Breakdown',
    description: 'Category spending pivot with month-over-month trends',
    icon: Icons.pie_chart,
  ),
  _AdvancedReportType.spendingByAccountType: (
    title: 'Spending by Account Type',
    description: 'Expense breakdown by cash, bank, e-wallet, credit card',
    icon: Icons.account_balance_wallet,
  ),
  _AdvancedReportType.topMerchantAnalysis: (
    title: 'Top Merchant / Title Analysis',
    description: 'Top merchants, recurring patterns, large transactions',
    icon: Icons.receipt_long,
  ),
  _AdvancedReportType.monthlyCashFlowStatement: (
    title: 'Monthly Cash Flow Statement',
    description: 'Income vs expense, savings rate, fixed vs variable costs',
    icon: Icons.waterfall_chart,
  ),
  _AdvancedReportType.incomeStabilityReport: (
    title: 'Income Stability Report',
    description: 'Income sources, stability, volatility analysis',
    icon: Icons.trending_up,
  ),
  _AdvancedReportType.budgetVsActual: (
    title: 'Budget vs Actual',
    description: 'Budget adherence, uncovered spend, historical performance',
    icon: Icons.bar_chart,
  ),
  _AdvancedReportType.netWorthSnapshot: (
    title: 'Net Worth Snapshot',
    description: 'Balance sheet, accounts, debts, and goal progress',
    icon: Icons.account_balance,
  ),
  _AdvancedReportType.netWorthTrend: (
    title: 'Net Worth Trend',
    description: 'Monthly net worth history and asset composition',
    icon: Icons.show_chart,
  ),
  _AdvancedReportType.debtPayoffPlanner: (
    title: 'Debt Payoff Planner',
    description: 'Payoff projections, receivables aging, payment history',
    icon: Icons.credit_card_off,
  ),
  _AdvancedReportType.recurringAudit: (
    title: 'Recurring Commitment Audit',
    description: 'Annual cost, % of income, orphaned rules',
    icon: Icons.repeat,
  ),
  _AdvancedReportType.goalPlanner: (
    title: 'Goal Achievement Planner',
    description: 'Progress, timeline projections, and achieved goals',
    icon: Icons.flag,
  ),
  _AdvancedReportType.yearInReview: (
    title: 'Year in Review',
    description: 'Annual summary, month scorecard, financial health score',
    icon: Icons.calendar_month,
  ),
};

void showAdvancedReportModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AdvancedReportModal(),
  );
}

class _AdvancedReportModal extends ConsumerStatefulWidget {
  const _AdvancedReportModal();

  @override
  ConsumerState<_AdvancedReportModal> createState() =>
      _AdvancedReportModalState();
}

class _AdvancedReportModalState extends ConsumerState<_AdvancedReportModal> {
  final Set<_AdvancedReportType> _selected = {};
  late DateTime _dateFrom;
  late DateTime _dateTo;
  bool _isExporting = false;
  int _exportProgress = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: isLight
            ? ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primaryGold,
                  surface: Colors.white,
                ),
              )
            : ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primaryGold,
                  surface: Color(0xFF221D10),
                ),
              ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  void _openReportPicker(bool isLight, Color bgColor) {
    showDialog(
      context: context,
      builder: (ctx) => _ReportPickerDialog(
        initialSelected: Set.from(_selected),
        isLight: isLight,
        bgColor: bgColor,
        onConfirm: (chosen) => setState(() {
          _selected
            ..clear()
            ..addAll(chosen);
        }),
      ),
    );
  }

  Future<void> _export() async {
    if (_selected.isEmpty) return;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });

    final locale = ref.read(localeProvider).toString();
    final exportService = ref.read(exportServiceProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    int exported = 0;
    int noData = 0;

    try {
      final ordered = _AdvancedReportType.values
          .where(_selected.contains)
          .toList();

      for (final report in ordered) {
        final bool hasData;
        switch (report) {
          case _AdvancedReportType.monthlySpendingBreakdown:
            hasData = await exportService.exportMonthlySpendingBreakdown(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_monthly_spend');
          case _AdvancedReportType.spendingByAccountType:
            hasData = await exportService.exportSpendingByAccountType(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_by_account');
          case _AdvancedReportType.topMerchantAnalysis:
            hasData = await exportService.exportTopMerchantAnalysis(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_top_merchant');
          case _AdvancedReportType.monthlyCashFlowStatement:
            hasData = await exportService.exportMonthlyCashFlowStatement(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_cashflow');
          case _AdvancedReportType.incomeStabilityReport:
            hasData = await exportService.exportIncomeStabilityReport(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_income_stability');
          case _AdvancedReportType.budgetVsActual:
            hasData = await exportService.exportBudgetVsActual(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_budget_vs_actual');
          case _AdvancedReportType.netWorthSnapshot:
            hasData = await exportService.exportNetWorthSnapshot(
              profileId: profileId, locale: locale);
            AnalyticsService.logReportExported('report_networth_snap');
          case _AdvancedReportType.netWorthTrend:
            hasData = await exportService.exportNetWorthTrend(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_networth_trend');
          case _AdvancedReportType.debtPayoffPlanner:
            hasData = await exportService.exportDebtPayoffPlanner(
              profileId: profileId, locale: locale);
            AnalyticsService.logReportExported('report_debt_planner');
          case _AdvancedReportType.recurringAudit:
            hasData = await exportService.exportRecurringAudit(
              profileId: profileId, start: _dateFrom, end: _dateTo, locale: locale);
            AnalyticsService.logReportExported('report_recurring');
          case _AdvancedReportType.goalPlanner:
            hasData = await exportService.exportGoalPlanner(
              profileId: profileId, locale: locale);
            AnalyticsService.logReportExported('report_goal_planner');
          case _AdvancedReportType.yearInReview:
            hasData = await exportService.exportYearInReview(
              profileId: profileId, year: _dateFrom.year, locale: locale);
            AnalyticsService.logReportExported('report_year_review');
        }
        if (hasData) exported++; else noData++;
        if (mounted) setState(() => _exportProgress++);
      }

      if (!mounted) return;

      if (exported == 0) {
        messenger.showSnackBar(const SnackBar(
          content: Text('No data found in selected range'),
          backgroundColor: Colors.orange,
        ));
      } else {
        navigator.pop();
        final label = exported == 1
            ? '1 report exported'
            : '$exported reports exported';
        messenger.showSnackBar(SnackBar(
          content: Text(noData > 0 ? '$label ($noData had no data)' : label),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Export failed. Please try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _selectionLabel() {
    if (_selected.isEmpty) return 'Tap to select reports';
    if (_selected.length == 1) {
      return _reportMeta[_selected.first]!.title;
    }
    return '${_selected.length} reports selected';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final locale = ref.watch(localeProvider).toString();
    final dateFormat = DateFormat('MMM dd, yyyy', locale);

    final bgColor = isDefault
        ? const Color(0xFF221D10)
        : isLight
            ? Colors.white
            : const Color(0xFF111111);

    final total = _selected.length;
    final exportLabel = _isExporting
        ? 'Exporting $_exportProgress / $total...'
        : total == 0
            ? 'Export Report'
            : total == 1
                ? 'Export 1 Report'
                : 'Export $total Reports';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFCBD5E1)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart,
                        color: AppColors.primaryGold, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Advanced Reports',
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Select one or more reports to export',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Report selector dropdown
                      Text(
                        'Reports',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF64748B)
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isExporting
                            ? null
                            : () => _openReportPicker(isLight, bgColor),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selected.isNotEmpty
                                ? AppColors.primaryGold.withValues(alpha: 0.08)
                                : isLight
                                    ? Colors.black.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selected.isNotEmpty
                                  ? AppColors.primaryGold.withValues(alpha: 0.5)
                                  : isLight
                                      ? Colors.black.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                color: _selected.isNotEmpty
                                    ? AppColors.primaryGold
                                    : isLight
                                        ? const Color(0xFF94A3B8)
                                        : Colors.white.withValues(alpha: 0.4),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectionLabel(),
                                  style: TextStyle(
                                    color: _selected.isNotEmpty
                                        ? (isLight
                                            ? AppColors.textPrimaryLight
                                            : Colors.white)
                                        : isLight
                                            ? const Color(0xFF94A3B8)
                                            : Colors.white.withValues(alpha: 0.4),
                                    fontSize: 15,
                                    fontWeight: _selected.isNotEmpty
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                color: isLight
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Chips showing selected reports
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _AdvancedReportType.values
                              .where(_selected.contains)
                              .map((t) => _SelectedChip(
                                    label: _reportMeta[t]!.title,
                                    isLight: isLight,
                                    onRemove: _isExporting
                                        ? null
                                        : () => setState(() => _selected.remove(t)),
                                  ))
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Date From
                      Text(
                        'Date Range',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF64748B)
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _DateField(
                        label: 'From',
                        value: dateFormat.format(_dateFrom),
                        onTap: () => _pickDate(isFrom: true),
                      ),
                      const SizedBox(height: 10),
                      _DateField(
                        label: 'To',
                        value: dateFormat.format(_dateTo),
                        onTap: () => _pickDate(isFrom: false),
                      ),

                      const SizedBox(height: 24),

                      // Export button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isExporting || _selected.isEmpty)
                              ? null
                              : _export,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            disabledBackgroundColor:
                                AppColors.primaryGold.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isExporting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      exportLabel,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  exportLabel,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom + 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Report picker dialog (multi-select checkboxes)
// ---------------------------------------------------------------------------

class _ReportPickerDialog extends StatefulWidget {
  final Set<_AdvancedReportType> initialSelected;
  final bool isLight;
  final Color bgColor;
  final void Function(Set<_AdvancedReportType>) onConfirm;

  const _ReportPickerDialog({
    required this.initialSelected,
    required this.isLight,
    required this.bgColor,
    required this.onConfirm,
  });

  @override
  State<_ReportPickerDialog> createState() => _ReportPickerDialogState();
}

class _ReportPickerDialogState extends State<_ReportPickerDialog> {
  late final Set<_AdvancedReportType> _chosen;

  @override
  void initState() {
    super.initState();
    _chosen = Set.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLight;
    final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final subColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    return Dialog(
      backgroundColor: widget.bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Reports',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_chosen.length == _reportMeta.length) {
                      _chosen.clear();
                    } else {
                      _chosen.addAll(_reportMeta.keys);
                    }
                  }),
                  child: Text(
                    _chosen.length == _reportMeta.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView(
              shrinkWrap: true,
              children: _AdvancedReportType.values.map((type) {
                final meta = _reportMeta[type]!;
                final isChecked = _chosen.contains(type);
                return InkWell(
                  onTap: () => setState(() {
                    if (isChecked) {
                      _chosen.remove(type);
                    } else {
                      _chosen.add(type);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          meta.icon,
                          size: 20,
                          color: isChecked
                              ? AppColors.primaryGold
                              : subColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.title,
                                style: TextStyle(
                                  color: isChecked
                                      ? AppColors.primaryGold
                                      : textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                meta.description,
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isChecked
                                ? AppColors.primaryGold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isChecked
                                  ? AppColors.primaryGold
                                  : isLight
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.black)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: subColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(_chosen);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _chosen.isEmpty
                          ? 'Done'
                          : 'Done (${_chosen.length})',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected chip
// ---------------------------------------------------------------------------

class _SelectedChip extends StatelessWidget {
  final String label;
  final bool isLight;
  final VoidCallback? onRemove;

  const _SelectedChip({
    required this.label,
    required this.isLight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 14,
                color: isLight
                    ? const Color(0xFF64748B)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date field
// ---------------------------------------------------------------------------

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.black.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
