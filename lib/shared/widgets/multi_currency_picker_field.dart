import 'package:flutter/material.dart';
import '../../core/models/enums.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

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

    // Icon color when no selection
    final Color emptyIconColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.5);

    // Text color
    final Color selectedTextColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final Color emptyTextColor = isLight ? const Color(0xFF94A3B8) : Colors.white54;

    // Close/chevron icon color
    final Color actionIconColor = isLight
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 12,
        child: Row(
          children: [
            Icon(
              Icons.currency_exchange,
              color: hasSelection ? AppColors.primaryGold : emptyIconColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  color: hasSelection ? selectedTextColor : emptyTextColor,
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
                  color: actionIconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.expand_more,
              color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondary,
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    // Modal background:
    // default=warm dark, dark=true black, light=light gray
    final Color bgColor = isDefault
        ? const Color(0xFF1A1A2E)
        : isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0A0A0A);

    final Color borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.1);

    // Handle color
    final Color handleColor = isLight
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.3);

    // Title and text colors
    final Color titleColor = isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;

    // Search field fill
    final Color searchBg = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.08);

    // Item text colors
    final Color itemPrimaryColor = isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color itemSecondaryColor = isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    // Checkbox border when unselected
    final Color checkboxBorderColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.3);

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
              color: handleColor,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: titleColor,
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
                color: searchBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: TextStyle(
                  color: itemPrimaryColor,
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
                    color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondary,
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
                        color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondary,
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
                                        color: itemPrimaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${currency.code} · ${currency.name}',
                                      style: TextStyle(
                                        color: itemSecondaryColor,
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
                                        : checkboxBorderColor,
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
