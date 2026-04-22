import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/models/enums.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

import 'glass_card.dart';

/// A tappable field that opens a searchable currency picker modal.
/// Shows flag, country name, currency code and symbol.
///
/// Pass [isDark] to explicitly force dark or light styling regardless of the
/// ambient theme. When omitted (null) the widget reads the AppThemeProvider,
/// which is the correct default for all existing call sites.
class CurrencyPickerField extends StatelessWidget {
  final Currency value;
  final ValueChanged<Currency> onChanged;
  final String? label;

  /// Override the brightness used for this field and the picker sheet.
  /// When null, the ambient AppThemeProvider is used.
  final bool? isDark;

  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve effective light/dark. Explicit isDark override takes precedence.
    final bool effectiveIsLight;
    if (isDark != null) {
      effectiveIsLight = !isDark!;
    } else {
      final themeMode = AppThemeProvider.of(context);
      effectiveIsLight = themeMode == AppThemeMode.light ||
          (themeMode == AppThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.light);
    }

    return GestureDetector(
      onTap: () => _showPicker(context, effectiveIsLight),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 20,
        child: Row(
          children: [
            Text(
              value.flag,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.countryName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: effectiveIsLight
                          ? AppColors.textPrimaryLight
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${value.code} · ${value.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: effectiveIsLight
                          ? AppColors.textSecondaryLight
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value.symbol,
                style: const TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: effectiveIsLight
                  ? AppColors.textSecondaryLight
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, bool effectiveIsLight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CurrencyPickerSheet(
        selected: value,
        isLight: effectiveIsLight,
        onSelected: (currency) {
          Navigator.pop(ctx);
          onChanged(currency);
        },
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  final Currency selected;
  final ValueChanged<Currency> onSelected;

  /// Whether to render in light mode. Forwarded from [CurrencyPickerField].
  final bool isLight;

  const _CurrencyPickerSheet({
    required this.selected,
    required this.onSelected,
    required this.isLight,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Full sorted list computed once — IDR pinned first, then alphabetical.
  late final List<Currency> _allSorted;

  late List<Currency> _filtered;

  @override
  void initState() {
    super.initState();
    // Build and cache the full sorted list exactly once.
    final list = Currency.values.toList();
    list.sort((a, b) {
      if (a == Currency.idr) return -1;
      if (b == Currency.idr) return 1;
      return a.countryName.compareTo(b.countryName);
    });
    _allSorted = list;
    _filtered = _allSorted;

    // Scroll to the selected item after the first frame so the ListView is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Jumps the list so the selected currency is visible near the top.
  void _scrollToSelected() {
    final index = _filtered.indexOf(widget.selected);
    if (index <= 0 || !_scrollController.hasClients) return;

    // Each item is approximately 64 px tall; subtract two items worth of
    // height so the selected item appears comfortably in view, not at the edge.
    const itemHeight = 64.0;
    final offset = ((index - 2) * itemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        // Reuse cached list — no sort work needed.
        _filtered = _allSorted;
      } else {
        // Filter first, then sort only the smaller subset.
        final subset = _allSorted.where((c) {
          return c.countryName.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q);
        }).toList();
        // _allSorted is already ordered so the filtered subset keeps the same
        // relative order (IDR first when present, then alphabetical). No
        // additional sort pass is required.
        _filtered = subset;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLight;

    // Also resolve themeMode to distinguish default from dark for bg color
    final themeMode = AppThemeProvider.of(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    // Modal background:
    // default=warm, dark=true black, light=light gray
    final Color bgColor = isDefault
        ? const Color(0xFF1A1A2E)
        : isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0A0A0A);

    final Color borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.1);

    // Keyboard-aware height: shrink the sheet so it is not hidden behind the
    // software keyboard when the search field is focused.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height * 0.75 - MediaQuery.of(context).viewPadding.bottom;

    // Text colors
    final Color primaryTextColor = isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color secondaryTextColor = isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    // Search field fill
    final Color searchBg = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.08);

    // Handle color
    final Color handleColor = isLight
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.3);

    return Container(
      height: availableHeight,
      padding: EdgeInsets.only(bottom: math.max(keyboardInset, MediaQuery.of(context).viewPadding.bottom)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by country or currency...',
                  hintStyle: TextStyle(
                    color: isLight ? AppColors.textTertiaryLight : AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Divider(color: borderColor, height: 1),

          // Currency list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(0, 4, 0, MediaQuery.of(context).viewPadding.bottom + 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final currency = _filtered[index];
                      final isSelected = currency == widget.selected;
                      return Semantics(
                        label: '${currency.countryName}, ${currency.code}, ${currency.name}',
                        selected: isSelected,
                        button: true,
                        child: InkWell(
                          onTap: () => widget.onSelected(currency),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            color: isSelected
                                ? AppColors.primaryGold.withValues(alpha: 0.1)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Text(
                                    currency.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currency.countryName,
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${currency.code} · ${currency.name}',
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryGold.withValues(alpha: 0.2)
                                        : (isLight
                                            ? Colors.black.withValues(alpha: 0.06)
                                            : Colors.white.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currency.symbol,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryGold
                                          : secondaryTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.check_circle,
                                      color: AppColors.primaryGold, size: 18),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
