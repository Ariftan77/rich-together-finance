import 'package:flutter/material.dart';
import '../../core/models/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_card.dart';

/// A tappable field that opens a searchable multi-select currency picker modal.
class MultiCurrencyPickerField extends StatelessWidget {
  final Set<Currency> selected;
  final ValueChanged<Set<Currency>> onChanged;
  final String allLabel;

  const MultiCurrencyPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allLabel = 'All Currencies',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = selected.isNotEmpty;

    String displayText;
    if (!hasSelection) {
      displayText = allLabel;
    } else if (selected.length == 1) {
      final c = selected.first;
      displayText = '${c.flag}  ${c.code}';
    } else {
      displayText = selected.map((c) => c.code).join(', ');
    }

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 12,
        child: Row(
          children: [
            Icon(
              Icons.currency_exchange,
              color: hasSelection
                  ? AppColors.primaryGold
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8)),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  color: hasSelection
                      ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                      : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                  fontSize: 14,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasSelection) ...[
              GestureDetector(
                onTap: () => onChanged({}),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.close,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.expand_more,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiCurrencyPickerSheet(
        selected: selected,
        onChanged: (updated) {
          onChanged(updated);
        },
      ),
    );
  }
}

class _MultiCurrencyPickerSheet extends StatefulWidget {
  final Set<Currency> selected;
  final ValueChanged<Set<Currency>> onChanged;

  const _MultiCurrencyPickerSheet({
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_MultiCurrencyPickerSheet> createState() => _MultiCurrencyPickerSheetState();
}

class _MultiCurrencyPickerSheetState extends State<_MultiCurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Set<Currency> _current;
  late List<Currency> _filtered;

  List<Currency> _sorted(Iterable<Currency> currencies) {
    final list = currencies.toList();
    list.sort((a, b) {
      if (a == Currency.idr) return -1;
      if (b == Currency.idr) return 1;
      return a.countryName.compareTo(b.countryName);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _current = Set.from(widget.selected);
    _filtered = _sorted(Currency.values);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _sorted(Currency.values);
      } else {
        _filtered = _sorted(Currency.values.where((c) {
          return c.countryName.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q);
        }));
      }
    });
  }

  void _toggle(Currency c) {
    setState(() {
      if (_current.contains(c)) {
        _current.remove(c);
      } else {
        _current.add(c);
      }
    });
    widget.onChanged(Set.from(_current));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
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

          // Title + clear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter by Currency',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_current.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _current.clear());
                      widget.onChanged({});
                    },
                    child: Text(
                      'Clear all',
                      style: TextStyle(color: AppColors.primaryGold, fontSize: 13),
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
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final currency = _filtered[index];
                      final isSelected = _current.contains(currency);
                      return InkWell(
                        onTap: () => _toggle(currency),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          color: isSelected
                              ? AppColors.primaryGold.withValues(alpha: 0.1)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Text(
                                currency.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryGold
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.3)
                                            : const Color(0xFFCBD5E1)),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.black, size: 16)
                                    : null,
                              ),
                            ],
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
