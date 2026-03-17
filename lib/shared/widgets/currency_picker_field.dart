import 'package:flutter/material.dart';
import '../../core/models/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_card.dart';

/// A tappable field that opens a searchable currency picker modal.
/// Shows flag, country name, currency code and symbol.
class CurrencyPickerField extends StatelessWidget {
  final Currency value;
  final ValueChanged<Currency> onChanged;
  final String? label;

  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showPicker(context),
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
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${value.code} · ${value.name}',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
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
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
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
      builder: (ctx) => _CurrencyPickerSheet(
        selected: value,
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

  const _CurrencyPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<Currency> _filtered;

  /// IDR pinned first, then rest sorted alphabetically by country name.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
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
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final currency = _filtered[index];
                      final isSelected = currency == widget.selected;
                      return InkWell(
                        onTap: () => widget.onSelected(currency),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${currency.code} · ${currency.name}',
                                      style: TextStyle(
                                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGold.withValues(alpha: 0.2)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.06)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  currency.symbol,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primaryGold
                                        : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle, color: AppColors.primaryGold, size: 18),
                              ],
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
