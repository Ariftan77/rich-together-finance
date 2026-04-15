import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/nav_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/tour/tour_content.dart';
import '../../../../shared/tour/tour_keys.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/multi_currency_picker_field.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../widgets/account_card.dart';
import '../providers/balance_provider.dart';
import 'account_entry_screen.dart';

/// Search query state for the wallet screen.
final _walletSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _walletCurrencyFilterProvider = StateProvider.autoDispose<Set<Currency>>((ref) => {});
final _walletTypeFilterProvider = StateProvider.autoDispose<Set<AccountType>>((ref) => {});
final _walletFilterExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Total balance across filtered accounts, converted to base currency.
final _walletFilteredTotalBalanceProvider = StreamProvider.autoDispose<double>((ref) async* {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  final balances = ref.watch(accountBalanceProvider);
  final selectedCurrencies = ref.watch(_walletCurrencyFilterProvider);
  final selectedTypes = ref.watch(_walletTypeFilterProvider);
  final searchQuery = ref.watch(_walletSearchProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);

  var filtered = accounts;
  if (selectedCurrencies.isNotEmpty) {
    filtered = filtered.where((a) => selectedCurrencies.contains(a.currency)).toList();
  }
  if (selectedTypes.isNotEmpty) {
    filtered = filtered.where((a) => selectedTypes.contains(a.type)).toList();
  }
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    filtered = filtered.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.type.displayName.toLowerCase().contains(q) ||
          a.currency.code.toLowerCase().contains(q) ||
          a.currency.name.toLowerCase().contains(q) ||
          a.currency.symbol.toLowerCase().contains(q);
    }).toList();
  }

  double total = 0;
  for (final account in filtered) {
    final balance = balances[account.id] ?? account.initialBalance;
    if (account.currency == baseCurrency) {
      total += balance;
    } else {
      total += CurrencyExchangeService.convertCurrency(
        balance, account.currency.code, baseCurrency.code, rates,
      );
    }
  }

  yield total;
});

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final GlobalKey _tourKeyBalance = GlobalKey(debugLabel: 'tour_wallet_balance');
  final GlobalKey _tourKeyAccountCard = GlobalKey(debugLabel: 'tour_wallet_card');
  static const String _tourPrefsKey = 'tour_seen_wallet';
  final TextEditingController _walletSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _walletSearchController.addListener(() {
      ref.read(_walletSearchProvider.notifier).state = _walletSearchController.text;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLaunchTour());
  }

  @override
  void dispose() {
    _walletSearchController.dispose();
    super.dispose();
  }

  Future<void> _maybeLaunchTour({bool delayed = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tourPrefsKey) ?? false;
    if (seen) return;
    if (!mounted) return;
    // Only launch when wallet tab (index 1) is visible.
    if (ref.read(shellTabIndexProvider) != 1) return;
    if (delayed) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    _launchTour();
  }

  void _launchTour() {
    final trans = ref.read(translationsProvider);

    final targets = <TargetFocus>[
      // 1. Total balance card
      TargetFocus(
        identify: 'wallet_balance',
        keyTarget: _tourKeyBalance,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, _) => TourContent(
              step: 1, total: 3,
              title: trans.tourWalletBalanceTitle,
              description: trans.tourWalletBalanceDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.RRect,
        color: Colors.white,
      ),
      // 2. Add account FAB
      TargetFocus(
        identify: 'wallet_fab',
        keyTarget: TourKeys.walletFab,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, _) => TourContent(
              step: 2, total: 3,
              title: trans.tourWalletFabTitle,
              description: trans.tourWalletFabDesc,
            ),
          ),
        ],
        shape: ShapeLightFocus.Circle,
        color: Colors.white,
      ),
      // 3. Tap account card to edit
      TargetFocus(
        identify: 'wallet_card',
        keyTarget: _tourKeyAccountCard,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, _) => TourContent(
              step: 3, total: 3,
              title: trans.tourWalletCardTitle,
              description: trans.tourWalletCardDesc,
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

    TutorialCoachMark(
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
      onFinish: () => markSeen(),
      onSkip: () {
        markSeen();
        return true;
      },
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next == 1) _maybeLaunchTour(delayed: true);
    });

    final accountsAsync = ref.watch(accountsStreamProvider);
    final balances = ref.watch(accountBalanceProvider);
    final trans = ref.watch(translationsProvider);
    final searchQuery = ref.watch(_walletSearchProvider);
    final selectedCurrencies = ref.watch(_walletCurrencyFilterProvider);
    final selectedTypes = ref.watch(_walletTypeFilterProvider);
    final isExpanded = ref.watch(_walletFilterExpandedProvider);
    final totalBalanceAsync = ref.watch(_walletFilteredTotalBalanceProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title
              Text(
                trans.walletTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // Total Balance Card
              GlassCard(
                key: _tourKeyBalance,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trans.dashboardTotalBalance,
                            style: TextStyle(
                              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          totalBalanceAsync.when(
                            data: (v) => Text(
                              '${baseCurrency.symbol} ${Formatters.formatCurrency(v, showDecimal: showDecimal)}',
                              style: TextStyle(
                                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            loading: () => Text(
                              '...',
                              style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 20),
                            ),
                            error: (e, s) => Text(
                              '--',
                              style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54, fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Filter Toggle
              GestureDetector(
                onTap: () => ref.read(_walletFilterExpandedProvider.notifier).state = !isExpanded,
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
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    ),
                    if (selectedCurrencies.isNotEmpty || selectedTypes.isNotEmpty || searchQuery.isNotEmpty)
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
              if (isExpanded) ...[
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  controller: _walletSearchController,
                  style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                  decoration: InputDecoration(
                    hintText: trans.walletSearch,
                    hintStyle: TextStyle(
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                    ),
                    suffixIcon: _walletSearchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _walletSearchController.clear(),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Currency', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: isLight ? const Color(0xFF64748B) : Colors.white70)),
                const SizedBox(height: 8),
                MultiCurrencyPickerField(
                  selected: selectedCurrencies,
                  onChanged: (updated) =>
                      ref.read(_walletCurrencyFilterProvider.notifier).state = updated,
                ),
                const SizedBox(height: 16),
                Text('Account Type', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: isLight ? const Color(0xFF64748B) : Colors.white70)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: selectedTypes.isEmpty,
                        onTap: () => ref.read(_walletTypeFilterProvider.notifier).state = {},
                      ),
                      const SizedBox(width: 8),
                      ...AccountType.values.map((t) {
                        final isSelected = selectedTypes.contains(t);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _FilterChip(
                            label: t.displayName,
                            isSelected: isSelected,
                            onTap: () {
                              final current = Set<AccountType>.from(ref.read(_walletTypeFilterProvider));
                              if (isSelected) {
                                current.remove(t);
                              } else {
                                current.add(t);
                              }
                              ref.read(_walletTypeFilterProvider.notifier).state = current;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return Center(
                        child: Text(
                          trans.walletNoAccounts,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }

                    final filtered = _filterAccounts(
                      accounts,
                      searchQuery,
                      selectedCurrencies,
                      selectedTypes,
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 48,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              trans.walletNoResults,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: isLight ? const Color(0xFF94A3B8) : Colors.white54),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        final card = AccountCard(
                          account: account,
                          balance: balances[account.id] ?? account.initialBalance,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AccountEntryScreen(account: account),
                              ),
                            );
                          },
                        );
                        return index == 0
                            ? KeyedSubtree(key: _tourKeyAccountCard, child: card)
                            : card;
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

  List<Account> _filterAccounts(
    List<Account> accounts,
    String query,
    Set<Currency> currencies,
    Set<AccountType> types,
  ) {
    var result = accounts;
    if (currencies.isNotEmpty) {
      result = result.where((a) => currencies.contains(a.currency)).toList();
    }
    if (types.isNotEmpty) {
      result = result.where((a) => types.contains(a.type)).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((account) {
        final nameMatch = account.name.toLowerCase().contains(q);
        final typeMatch = account.type.displayName.toLowerCase().contains(q);
        final currencyMatch = account.currency.code.toLowerCase().contains(q) ||
            account.currency.name.toLowerCase().contains(q) ||
            account.currency.symbol.toLowerCase().contains(q);
        return nameMatch || typeMatch || currencyMatch;
      }).toList();
    }
    
    result.sort((a, b) {
      if (a.lastActivityDate != null && b.lastActivityDate != null) {
        return b.lastActivityDate!.compareTo(a.lastActivityDate!);
      } else if (a.lastActivityDate != null) {
        return -1;
      } else if (b.lastActivityDate != null) {
        return 1;
      }
      return a.name.compareTo(b.name);
    });

    return result;
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
                : isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: isSelected ? Colors.black : (isLight ? AppColors.textPrimaryLight : Colors.white),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
