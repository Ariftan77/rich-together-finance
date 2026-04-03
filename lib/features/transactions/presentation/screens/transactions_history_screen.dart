import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/tour/tour_keys.dart';
import '../../../../shared/tour/tour_content.dart';
import '../../../../core/providers/nav_providers.dart';

import '../../../../shared/widgets/category_icon_widget.dart';
// import '../../../../shared/widgets/glass_item.dart'; // Removed
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_input.dart';

import '../../../../core/providers/date_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../accounts/presentation/providers/balance_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/date_range_filter_modal.dart';
import '../widgets/month_year_picker_modal.dart';
import 'transaction_entry_screen.dart';
import 'recurring_list_screen.dart';
import '../../../debts/presentation/screens/debt_entry_screen.dart';
import '../../../debts/presentation/screens/debt_payment_view_screen.dart';


class TransactionsHistoryScreen extends ConsumerStatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  ConsumerState<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends ConsumerState<TransactionsHistoryScreen> {
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  bool _filterExpanded = false;

  // --- Coach-mark tour keys (widgets owned by this screen) ---
  final GlobalKey _tourKeyRecurring  = GlobalKey(debugLabel: 'tour_recurring');
  final GlobalKey _tourKeyDateFilter = GlobalKey(debugLabel: 'tour_date_filter');
  final GlobalKey _tourKeyMonthNav   = GlobalKey(debugLabel: 'tour_month_nav');
  final GlobalKey _tourKeySearch     = GlobalKey(debugLabel: 'tour_search_filter');

  static const String _tourPrefsKey = 'tour_seen_transactions';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      ref.read(transactionSearchQueryProvider.notifier).state = _searchController.text;
    });
    _scrollController.addListener(_onScroll);

    // Launch the tour on first run, after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLaunchTour());
  }

  Future<void> _maybeLaunchTour({bool delayed = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tourPrefsKey) ?? false;
    if (seen) return;
    if (!mounted) return;
    // Only launch when this screen's tab (index 0) is actually visible.
    // IndexedStack builds all children on first render, so without this check
    // every screen would fire its tour simultaneously on app start.
    if (ref.read(shellTabIndexProvider) != 0) return;
    // When triggered by a tab-switch, wait for the slide animation to finish
    // before showing the tour so all widgets are fully laid out.
    if (delayed) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    _launchTour();
  }

  void _launchTour() {
    final trans = ref.read(translationsProvider);

    // Build the list of targets.  Steps 1-4 highlight widgets in this screen;
    // step 5 highlights the FAB; steps 6-7 spotlight the bottom nav bar.
    final targets = <TargetFocus>[
      // 1. Recurring button
      TargetFocus(
        identify: 'recurring',
        keyTarget: _tourKeyRecurring,
        alignSkip: Alignment.bottomLeft,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => TourContent(
              step: 1, total: 7,
              title: trans.tourRecurringTitle,
              description: trans.tourRecurringDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.Circle,
        color: Colors.white,
      ),

      // 2. Date filter button
      TargetFocus(
        identify: 'date_filter',
        keyTarget: _tourKeyDateFilter,
        alignSkip: Alignment.bottomLeft,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => TourContent(
              step: 2, total: 7,
              title: trans.tourDateFilterTitle,
              description: trans.tourDateFilterDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.Circle,
        color: Colors.white,
      ),

      // 3. Month navigation row (left/right arrows + month label)
      TargetFocus(
        identify: 'month_nav',
        keyTarget: _tourKeyMonthNav,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => TourContent(
              step: 3, total: 7,
              title: trans.tourMonthNavTitle,
              description: trans.tourMonthNavDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.RRect,
        color: Colors.white,
      ),

      // 4. Search + filter section
      TargetFocus(
        identify: 'search_filter',
        keyTarget: _tourKeySearch,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => TourContent(
              step: 4, total: 7,
              title: trans.tourSearchTitle,
              description: trans.tourSearchDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.RRect,
        color: Colors.white,
      ),

      // 5. FAB (lives in DashboardShell — referenced via TourKeys.fab)
      // onClickTarget fires when the user taps the highlighted FAB area,
      // simulating the real FAB press so they land on TransactionEntryScreen.
      TargetFocus(
        identify: 'fab',
        keyTarget: TourKeys.fab,
        alignSkip: Alignment.topLeft,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TourContent(
              step: 5, total: 7,
              title: trans.tourAddTitle,
              description: trans.tourAddDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.Circle,
        color: Colors.white,
      ),

      // 6. Bottom nav bar
      TargetFocus(
        identify: 'navbar',
        keyTarget: TourKeys.bottomNav,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TourContent(
              step: 6, total: 7,
              title: trans.tourNavbarTitle,
              description: trans.tourNavbarDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.RRect,
        color: Colors.white,
      ),

      // 7. Wallet nav item — set initial balance first
      TargetFocus(
        identify: 'wallet_init',
        keyTarget: TourKeys.bottomNav,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TourContent(
              step: 7, total: 7,
              title: trans.tourWalletInitTitle,
              description: trans.tourWalletInitDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.RRect,
        color: Colors.white,
      ),
    ];

    Future<void> markSeen() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tourPrefsKey, true);
    }

    late TutorialCoachMark coachMark;
    coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.6,
      textSkip: 'SKIP',
      textStyleSkip: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      paddingFocus: 10,
      // When leaving step 4 (search_filter) → step 5 (fab), open the speed dial
      // so the user sees the 3 options as step 5 appears.
      // We do NOT call next() here — enableOverlayTab handles the advance.
      onClickOverlay: (target) {
        if (target.identify == 'search_filter') {
          TourKeys.speedDial.currentState?.toggle();
        }
      },
      onFinish: () => markSeen(),
      onSkip: () {
        markSeen();
        return true;
      },
    );
    coachMark.show(context: context);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    // Guard: don't fire again while already loading more
    if (ref.read(convertedFilteredTransactionsProvider).isLoading) return;
    final currentLimit = ref.read(transactionLimitProvider);
    ref.read(transactionLimitProvider.notifier).state = currentLimit + 20;
  }

  void _changeMonth(DateTime newMonth) {
    ref.read(selectedMonthProvider.notifier).state = newMonth;
    ref.read(dateFromFilterProvider.notifier).state = null;
    ref.read(dateToFilterProvider.notifier).state = null;
    ref.read(transactionLimitProvider.notifier).state = 20;
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    if (ref.read(dateFromFilterProvider) != null) return;

    final selectedMonth = ref.read(selectedMonthProvider);
    if (velocity < 0) {
      // swipe left = next month
      final latestTxDate = ref.read(latestTransactionDateProvider).valueOrNull;
      final latestTxMonth = latestTxDate != null
          ? DateTime(latestTxDate.year, latestTxDate.month, 1)
          : DateTime(DateTime.now().year, DateTime.now().month, 1);
      if (!selectedMonth.isBefore(latestTxMonth)) return;
      _changeMonth(DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
    } else {
      // swipe right = previous month
      _changeMonth(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
    }
  }

  Future<void> _openMonthPicker() async {
    final currentMonth = ref.read(selectedMonthProvider);
    final latestTxDate = ref.read(latestTransactionDateProvider).valueOrNull;
    final maxMonth = latestTxDate != null
        ? DateTime(latestTxDate.year, latestTxDate.month, 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthYearPickerModal(
        initialMonth: currentMonth,
        maxMonth: maxMonth,
      ),
    );
    if (result != null) {
      _changeMonth(result);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-trigger tour when the user navigates back to this tab after app start.
    // initState only fires once; ref.listen fires every time the tab index
    // changes to 0 while this screen is alive in the IndexedStack.
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next == 0) _maybeLaunchTour(delayed: true);
    });

    final filteredHelper = ref.watch(convertedFilteredTransactionsProvider);
    final currentTypeFilter = ref.watch(transactionTypeFilterProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final trans = ref.watch(translationsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final today = ref.watch(currentDateProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);

    // Pre-compute grouping once per build (outside Builder) to avoid
    // repeating O(n) HashMap insertions + sort on every widget subtree rebuild.
    final _allConvertedTxs = filteredHelper.valueOrNull ?? [];
    final _grouped = <DateTime, List<ConvertedTransaction>>{};
    for (var ct in _allConvertedTxs) {
      final date = DateTime(ct.transaction.date.year, ct.transaction.date.month, ct.transaction.date.day);
      _grouped.putIfAbsent(date, () => []).add(ct);
    }
    final _sortedDates = _grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final hasCustomRange = ref.watch(dateFromFilterProvider) != null || ref.watch(dateToFilterProvider) != null;
    final latestTxDate = ref.watch(latestTransactionDateProvider).valueOrNull;
    final latestTxMonth = latestTxDate != null
        ? DateTime(latestTxDate.year, latestTxDate.month, 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final canGoNext = selectedMonth.isBefore(latestTxMonth);

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final canPop = Navigator.canPop(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent, 
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                       if (canPop)
                         Padding(
                           padding: const EdgeInsets.only(right: 8.0),
                           child: IconButton(
                             icon: Icon(Icons.arrow_back, color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimary),
                             onPressed: () => Navigator.pop(context),
                           ),
                         ),
                      Text(
                        trans.navTransactions,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // Recurring button
                      IconButton(
                        key: _tourKeyRecurring,
                        icon: Icon(
                          Icons.repeat,
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecurringListScreen(),
                            ),
                          );
                        },
                        tooltip: 'Recurring',
                      ),
                      // Filter button — key is on the KeyedSubtree wrapper so it
                      // sits outside the Consumer's rebuild scope and always has
                      // a valid RenderBox when the coach-mark tour resolves it.
                      KeyedSubtree(
                        key: _tourKeyDateFilter,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final dateFrom = ref.watch(dateFromFilterProvider);
                            final dateTo = ref.watch(dateToFilterProvider);
                            final hasDateFilter = dateFrom != null || dateTo != null;

                            return Stack(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.filter_list,
                                    color: hasDateFilter
                                        ? AppColors.primaryGold
                                        : (AppThemeProvider.isLightMode(context)
                                            ? AppColors.textPrimaryLight
                                            : Colors.white),
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => const DateRangeFilterModal(),
                                    );
                                  },
                                ),
                                if (hasDateFilter)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Month Navigation Row
                Padding(
                  key: _tourKeyMonthNav,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: isLight ? AppColors.textPrimaryLight : Colors.white),
                        onPressed: () {
                          final prev = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                          _changeMonth(prev);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _openMonthPicker,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hasCustomRange
                                    ? trans.txnCustomRange
                                    : DateFormat('MMMM yyyy').format(selectedMonth),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: hasCustomRange
                                      ? AppColors.primaryGold
                                      : (isLight ? AppColors.textPrimaryLight : Colors.white),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: hasCustomRange
                                    ? AppColors.primaryGold
                                    : (isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7)),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: canGoNext || hasCustomRange
                              ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                              : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.25)),
                        ),
                        onPressed: canGoNext || hasCustomRange
                            ? () {
                                final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                                _changeMonth(next);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                // Filter toggle row — key on the outer SizedBox so the coach
                // mark gets a reliable full-width render object to spotlight.
                SizedBox(
                  key: _tourKeySearch,
                  width: double.infinity,
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterExpanded = !_filterExpanded),
                    child: Row(
                      children: [
                        Text(
                          'Filter',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          _filterExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        ),
                        if (currentTypeFilter != null || _searchController.text.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGold,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
                ),

                if (_filterExpanded) ...[
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: GlassInput(
                      controller: _searchController,
                      hintText: trans.commonSearch,
                      prefixIcon: Icons.search,
                    ),
                  ),
                  // Type filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: trans.filterAll,
                          isSelected: currentTypeFilter == null,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = null,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeIncome,
                          isSelected: currentTypeFilter?.contains(TransactionType.income) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.income],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeExpense,
                          isSelected: currentTypeFilter?.contains(TransactionType.expense) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.expense],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeTransfer,
                          isSelected: currentTypeFilter?.contains(TransactionType.transfer) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.transfer],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.txnFilterDebt,
                          isSelected: currentTypeFilter?.contains(TransactionType.debtIn) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.debtIn, TransactionType.debtOut, TransactionType.debtPaymentOut, TransactionType.debtPaymentIn],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.txnFilterAdjustment,
                          isSelected: currentTypeFilter?.contains(TransactionType.adjustmentIn) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.adjustmentIn, TransactionType.adjustmentOut],
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 8),

                // List
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: _onHorizontalSwipe,
                    child: Builder(
                      builder: (context) {
                      // Full spinner only on initial load (no data yet)
                      if (filteredHelper.isLoading && !filteredHelper.hasValue) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                      }
                      if (filteredHelper.hasError && !filteredHelper.hasValue) {
                        return Center(child: Text('Error: ${filteredHelper.error}', style: const TextStyle(color: Colors.red)));
                      }

                      final convertedTxs = filteredHelper.valueOrNull ?? [];

                      if (convertedTxs.isEmpty) {
                        final accounts = accountsAsync.valueOrNull ?? [];
                        final hasAccounts = accounts.isNotEmpty;
                        final balances = ref.watch(accountBalanceProvider);
                        final totalBalance = balances.values.fold(0.0, (sum, b) => sum + b);
                        final isZeroBalance = hasAccounts && totalBalance == 0.0;

                        final IconData emptyIcon;
                        final String emptyHint;
                        if (!hasAccounts) {
                          emptyIcon = Icons.account_balance_wallet_outlined;
                          emptyHint = trans.txnNoAccountHint;
                        } else if (isZeroBalance) {
                          emptyIcon = Icons.account_balance_outlined;
                          emptyHint = trans.txnZeroBalanceHint;
                        } else {
                          emptyIcon = Icons.receipt_long_outlined;
                          emptyHint = trans.txnNoTransactionsHint;
                        }

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                emptyIcon,
                                size: 64,
                                color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                trans.txnNoTransactions,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  emptyHint,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Use pre-computed grouping from build() level.
                      final grouped = _grouped;
                      final sortedDates = _sortedDates;

                      // Pre-fetch maps for efficient lookup
                      final categoryMap = categoriesAsync.valueOrNull != null
                          ? {for (var c in categoriesAsync.value!) c.id: c}
                          : <int, Category>{};
                      final accountMap = accountsAsync.valueOrNull != null
                          ? {for (var a in accountsAsync.value!) a.id: a}
                          : <int, Account>{};

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        // +1 for the bottom loading spinner while fetching more
                        itemCount: sortedDates.length + (filteredHelper.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == sortedDates.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: AppColors.primaryGold),
                              ),
                            );
                          }

                          final date = sortedDates[index];
                          final cts = grouped[date]!;

                          // Use convertedAmount so cross-currency totals are correct
                          final dayIncome = cts
                              .where((ct) => ct.transaction.type == TransactionType.income)
                              .fold(0.0, (sum, ct) => sum + ct.convertedAmount);
                          final dayExpense = cts
                              .where((ct) => ct.transaction.type == TransactionType.expense)
                              .fold(0.0, (sum, ct) => sum + ct.convertedAmount);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GlassCard(
                                margin: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                borderRadius: 12,
                                backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.black.withValues(alpha: 0.15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _formatDateSection(date, today, trans).toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                        color: isLight ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        if (dayIncome > 0)
                                          _DayStatChip(
                                            label: trans.dashboardIncome,
                                            value: '+${baseCurrency.symbol} ${Formatters.formatCurrency(dayIncome, showDecimal: showDecimal)}',
                                            color: const Color(0xFF34D399).withValues(alpha: 0.7),
                                          ),
                                        if (dayExpense > 0)
                                          _DayStatChip(
                                            label: trans.dashboardExpense,
                                            value: '-${baseCurrency.symbol} ${Formatters.formatCurrency(dayExpense, showDecimal: showDecimal)}',
                                            color: const Color(0xFFFB7185).withValues(alpha: 0.7),
                                          ),
                                        _DayStatChip(
                                          label: trans.txnDaySummaryTxn,
                                          value: '${cts.length}',
                                          color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ...cts.map((ct) => _TransactionItem(
                                key: ValueKey(ct.transaction.id),
                                transaction: ct.transaction,
                                category: categoryMap[ct.transaction.categoryId],
                                account: accountMap[ct.transaction.accountId],
                              )),
                            ],
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );  }

  String _formatDateSection(DateTime date, DateTime today, AppTranslations trans) {
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return trans.commonToday;
    if (date == yesterday) return trans.commonYesterday;
    return DateFormat('EEE, d MMM').format(date);
  }
}




class _DayStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DayStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : (isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium!.copyWith( // Fixed
            color: isSelected ? Colors.black : (isLight ? AppColors.textPrimaryLight : Colors.white),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;

  const _TransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = AppThemeProvider.isLightMode(context);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isAdjustmentIn = transaction.type == TransactionType.adjustmentIn;
    final isAdjustmentOut = transaction.type == TransactionType.adjustmentOut;
    final isDebtIn = transaction.type == TransactionType.debtIn;
    final isDebtOut = transaction.type == TransactionType.debtOut;
    final isDebtPaymentOut = transaction.type == TransactionType.debtPaymentOut;
    final isDebtPaymentIn = transaction.type == TransactionType.debtPaymentIn;

    // Localized transaction type name
    String localizedTypeName(TransactionType type) {
      switch (type) {
        case TransactionType.income: return trans.entryTypeIncome;
        case TransactionType.expense: return trans.entryTypeExpense;
        case TransactionType.transfer: return trans.entryTypeTransfer;
        case TransactionType.adjustmentIn: return trans.entryTypeAdjustmentIn;
        case TransactionType.adjustmentOut: return trans.entryTypeAdjustmentOut;
        case TransactionType.debtIn: return trans.entryTypeDebtIn;
        case TransactionType.debtOut: return trans.entryTypeDebtOut;
        case TransactionType.debtPaymentOut: return trans.entryTypeDebtPaymentOut;
        case TransactionType.debtPaymentIn: return trans.entryTypeDebtPaymentIn;
      }
    }

    final color = isExpense
        ? const Color(0xFFFB7185)
        : isIncome
            ? const Color(0xFF34D399)
            : (isAdjustmentIn || isAdjustmentOut)
                ? Colors.amber
                : isDebtIn
                    ? Colors.orange   // borrowed (I owe) — matches overview orange
                    : isDebtOut
                        ? const Color(0xFF60A5FA) // lent (owed to me) — matches overview blue
                        : isDebtPaymentOut
                            ? const Color(0xFFFB7185) // debt payment out — red (money leaving)
                            : isDebtPaymentIn
                                ? const Color(0xFF34D399) // debt payment in — green (money returning)
                                : const Color(0xFF60A5FA);
    final prefix = isExpense || isAdjustmentOut || isDebtOut || isDebtPaymentOut ? '-' : (isIncome || isAdjustmentIn || isDebtIn || isDebtPaymentIn ? '+' : '');
    
    // Data is now passed in, no need for Futures

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () async {
          if (isDebtIn || isDebtOut) {
            // Debt transactions — navigate to the corresponding DebtEntryScreen.
            // Parse person name from title "Debt: <name>" or fall back to the
            // raw title / empty string.
            final title = transaction.title ?? '';
            final personName = title.startsWith('Debt: ')
                ? title.substring(6).trim()
                : title.trim();

            final debtType = isDebtIn ? DebtType.payable : DebtType.receivable;
            final profileId = ref.read(activeProfileIdProvider);
            final navigator = Navigator.of(context);

            if (profileId != null && personName.isNotEmpty) {
              final debt = await ref.read(debtDaoProvider).findDebtByNameAndType(
                profileId,
                personName,
                debtType,
                accountId: transaction.accountId,
                date: transaction.date,
              );
              if (!context.mounted) return;
              if (debt != null) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => DebtEntryScreen(debt: debt),
                  ),
                );
                return;
              }
            }
            // Fallback: debt record not found — open normal transaction editor.
            navigator.push(
              MaterialPageRoute(
                builder: (context) => (transaction.type == TransactionType.debtPaymentOut ||
                        transaction.type == TransactionType.debtPaymentIn)
                    ? DebtPaymentViewScreen(transactionId: transaction.id)
                    : TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
              ),
            );
          } else {
            // Navigate to edit page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => (transaction.type == TransactionType.debtPaymentOut ||
                        transaction.type == TransactionType.debtPaymentIn)
                    ? DebtPaymentViewScreen(transactionId: transaction.id)
                    : TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
              ),
            );
          }
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Icon with colored background
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isIncome || isExpense) && category != null
                    ? _categoryBgColor(category!.color)
                    : color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: (isIncome || isExpense) && category != null && category!.icon.isNotEmpty
                  ? Center(child: CategoryIconWidget(iconString: category!.icon, size: 20, color: color))
                  : Icon(_getIcon(transaction.type), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction title (or fallback to type)
                  Text(
                    transaction.title != null && transaction.title!.isNotEmpty 
                      ? transaction.title! 
                      : localizedTypeName(transaction.type),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time and category
                  Builder(
                    builder: (context) {
                      final categoryName = category?.name ?? localizedTypeName(transaction.type);
                      final timeStr = _formatTime(transaction.date);
                      return Text(
                        '$timeStr • $categoryName',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Amount and Account
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final currencySymbol = account?.currency.code ?? 'IDR';
                    return Text(
                      '$currencySymbol $prefix${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final accountName = account?.name ?? trans.loading;
                    return Text(
                      accountName,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Color _categoryBgColor(String? hex) {
    if (hex == null || hex == 'transparent' || hex.isEmpty) return Colors.transparent;
    final cleaned = hex.replaceFirst('#', '0xFF');
    return Color(int.tryParse(cleaned) ?? 0xFF808080).withValues(alpha: 0.25);
  }

  IconData _getIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income: return Icons.arrow_downward;
      case TransactionType.expense: return Icons.arrow_upward;
      case TransactionType.transfer: return Icons.swap_horiz;
      case TransactionType.adjustmentIn: return Icons.tune;
      case TransactionType.adjustmentOut: return Icons.tune;
      case TransactionType.debtIn: return Icons.people_outline;
      case TransactionType.debtOut: return Icons.people_outline;
      case TransactionType.debtPaymentOut:
      case TransactionType.debtPaymentIn:
        return Icons.handshake_outlined;
    }
  }
}
