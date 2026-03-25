import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

class MonthYearPickerModal extends StatefulWidget {
  final DateTime initialMonth;
  /// The latest month that has a transaction — months beyond this are disabled.
  final DateTime maxMonth;

  const MonthYearPickerModal({
    super.key,
    required this.initialMonth,
    required this.maxMonth,
  });

  @override
  State<MonthYearPickerModal> createState() => _MonthYearPickerModalState();
}

class _MonthYearPickerModalState extends State<MonthYearPickerModal> {
  late int _selectedYear;
  late int _selectedMonth;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
  }

  bool _isDisabledMonth(int year, int month) {
    return year > widget.maxMonth.year ||
        (year == widget.maxMonth.year && month > widget.maxMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final canGoNextYear = _selectedYear < widget.maxMonth.year;
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Container(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF221D10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Month',
                  style: TextStyle(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Year selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedYear--),
                  icon: Icon(Icons.chevron_left, color: isLight ? AppColors.textPrimaryLight : Colors.white),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_selectedYear',
                  style: TextStyle(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: canGoNextYear
                      ? () => setState(() => _selectedYear++)
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: canGoNextYear
                        ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                        : (isLight
                            ? const Color(0xFFCBD5E1)
                            : Colors.white.withValues(alpha: 0.25)),
                  ),
                ),
              ],
            ),
          ),

          // Month grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isDisabled = _isDisabledMonth(_selectedYear, month);
                final highlighted = month == _selectedMonth;

                return GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() => _selectedMonth = month);
                          Navigator.pop(
                            context,
                            DateTime(_selectedYear, month, 1),
                          );
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: highlighted && !isDisabled
                          ? AppColors.primaryGold
                          : (isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.07)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: highlighted && !isDisabled
                            ? AppColors.primaryGold
                            : (isLight
                                ? Colors.black.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _monthNames[index],
                      style: TextStyle(
                        color: isDisabled
                            ? (isLight
                                ? const Color(0xFFCBD5E1)
                                : Colors.white.withValues(alpha: 0.25))
                            : highlighted
                                ? Colors.black
                                : (isLight ? AppColors.textPrimaryLight : Colors.white),
                        fontWeight: highlighted
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
