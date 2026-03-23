import 'package:flutter/material.dart';
import '../../core/models/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_card.dart';

/// A tappable field that opens a searchable currency picker modal.
/// Shows flag, country name, currency code and symbol.
///
/// Pass [isDark] to explicitly force dark or light styling regardless of the
/// ambient [Theme]. When omitted (null) the widget reads brightness from the
/// inherited theme, which is the correct default for all existing call sites.
class CurrencyPickerField extends StatelessWidget {
  final Currency value;
  final ValueChanged<Currency> onChanged;
  final String? label;

  /// Override the brightness used for this field and the picker sheet.
  /// When null, the ambient [Theme.brightness] is used.
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
    final effectiveDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return GestureDetector(
      onTap: () => _showPicker(context, effectiveDark),
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
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: effectiveDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${value.code} · ${value.name}',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: effectiveDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
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
              color: effectiveDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, bool effectiveDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CurrencyPickerSheet(
        selected: value,
        isDark: effectiveDark,
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

  /// Whether to render in dark mode. Forwarded from [CurrencyPickerField].
  final bool isDark;

  const _CurrencyPickerSheet({
    required this.selected,
    required this.onSelected,
    required this.isDark,
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
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    // Keyboard-aware height: shrink the sheet so it is not hidden behind the
    // software keyboard when the search field is focused.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: availableHeight,
      padding: EdgeInsets.only(bottom: keyboardInset),
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
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
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by country or currency...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
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
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currency.countryName,
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textPrimary
                                              : AppColors.textPrimaryLight,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${currency.code} · ${currency.name}',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.textSecondaryLight,
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
                                        ? AppColors.primaryGold
                                            .withValues(alpha: 0.2)
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.06)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currency.symbol,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryGold
                                          : (isDark
                                              ? AppColors.textSecondary
                                              : AppColors.textSecondaryLight),
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
