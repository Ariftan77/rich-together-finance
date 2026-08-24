import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../providers/history_search_provider.dart';
import '../widgets/date_range_filter_modal.dart';
import '../widgets/transaction_list_item.dart';

/// Full-history transaction search.
///
/// Opens blank on purpose: the transactions tab already covers "what happened
/// this month", this screen exists for digging up a single old record. Nothing
/// is queried until the user types or picks a date range, and results are paged
/// [historySearchPageSize] at a time so years of data never load at once.
class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  ConsumerState<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState
    extends ConsumerState<TransactionSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Debounced so a five-column LIKE across the whole table doesn't re-run on
  /// every keystroke.
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final text = _searchController.text.trim();
      if (ref.read(historySearchQueryProvider) == text) return;
      ref.read(historySearchQueryProvider.notifier).state = text;
      _resetPaging();
    });
  }

  void _resetPaging() {
    ref.read(historySearchLimitProvider.notifier).state = historySearchPageSize;
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    if (!ref.read(historySearchHasMoreProvider)) return;
    if (ref.read(historySearchResultsProvider).isLoading) return;
    ref.read(historySearchLimitProvider.notifier).state += historySearchPageSize;
  }

  Future<void> _openDateFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateRangeFilterModal(
        initialFrom: ref.read(historySearchDateFromProvider),
        initialTo: ref.read(historySearchDateToProvider),
        // Transactions can be recorded in advance, so allow future dates here.
        maxDate: DateTime(DateTime.now().year + 5, 12, 31),
        onApply: (from, to) {
          ref.read(historySearchDateFromProvider.notifier).state = from;
          ref.read(historySearchDateToProvider.notifier).state = to;
          _resetPaging();
        },
      ),
    );
  }

  void _clearSearchText() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(historySearchQueryProvider.notifier).state = '';
    _resetPaging();
    setState(() {}); // drop the clear icon
  }

  void _clearDateFilter() {
    ref.read(historySearchDateFromProvider.notifier).state = null;
    ref.read(historySearchDateToProvider.notifier).state = null;
    _resetPaging();
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final textPrimary =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;

    final isActive = ref.watch(historySearchIsActiveProvider);
    final dateFrom = ref.watch(historySearchDateFromProvider);
    final dateTo = ref.watch(historySearchDateToProvider);
    final hasDateFilter = dateFrom != null || dateTo != null;

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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          trans.historySearchTitle,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search box — one box across title, category, note, amount
                // and wallet account name.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GlassInput(
                    controller: _searchController,
                    hintText: trans.historySearchHint,
                    prefixIcon: Icons.search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: _clearSearchText,
                            child: const Icon(Icons.close, size: 18),
                          ),
                    // Only refreshes the clear icon; the query itself is
                    // updated by the debounced controller listener.
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // Date range filter + result count
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: _DateRangeChip(
                          label: hasDateFilter
                              ? _formatRange(dateFrom, dateTo)
                              : trans.historySearchDateRange,
                          isActive: hasDateFilter,
                          onTap: _openDateFilter,
                          onClear: hasDateFilter ? _clearDateFilter : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        Consumer(
                          builder: (context, ref, _) {
                            final results = ref
                                .watch(historySearchResultsProvider)
                                .valueOrNull;
                            // Hidden while a full page came back: the count
                            // would be the page size, not the real total.
                            if (results == null ||
                                results.isEmpty ||
                                ref.watch(historySearchHasMoreProvider)) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              trans.historySearchResults(results.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isLight
                                        ? AppColors.textTertiaryLight
                                        : AppColors.textTertiary,
                                  ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                Expanded(child: _buildBody(isActive)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isActive) {
    final trans = ref.watch(translationsProvider);

    if (!isActive) {
      return _EmptyState(
        icon: Icons.manage_search,
        title: trans.historySearchIntroTitle,
        hint: trans.historySearchIntroHint,
      );
    }

    final resultsAsync = ref.watch(historySearchResultsProvider);

    if (resultsAsync.isLoading && !resultsAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }
    if (resultsAsync.hasError && !resultsAsync.hasValue) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: trans.historySearchNoResults,
        hint: trans.historySearchNoResultsHint,
      );
    }

    final results = resultsAsync.valueOrNull ?? const <Transaction>[];
    if (results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: trans.historySearchNoResults,
        hint: trans.historySearchNoResultsHint,
      );
    }

    // Deactivated wallets still own old transactions, so the map includes them.
    final accountMap =
        ref.watch(historySearchAccountMapProvider).valueOrNull ??
            const <int, Account>{};
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? const <Category>[];
    final categoryMap = {for (final c in categories) c.id: c};

    final showLoader = resultsAsync.isLoading;
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: results.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            ),
          );
        }
        final tx = results[index];
        return TransactionListItem(
          key: ValueKey(tx.id),
          transaction: tx,
          category: categoryMap[tx.categoryId],
          account: accountMap[tx.accountId],
          showFullDate: true,
        );
      },
    );
  }

  String _formatRange(DateTime? from, DateTime? to) {
    final fmt = DateFormat('d MMM yyyy');
    if (from != null && to != null) {
      return '${fmt.format(from)} - ${fmt.format(to)}';
    }
    if (from != null) return '${fmt.format(from)} +';
    return '- ${fmt.format(to!)}';
  }
}

class _DateRangeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRangeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    // Gold on a white card needs the darker gold to stay readable.
    final Color activeText =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;
    final Color idleText =
        isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primaryGold
                : (isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: isActive ? activeText : idleText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive ? activeText : idleText,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: activeText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    final Color muted =
        isLight ? AppColors.textTertiaryLight : AppColors.textTertiary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isLight
                        ? AppColors.textSecondaryLight
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
