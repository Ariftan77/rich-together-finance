import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../providers/search_provider.dart';

/// Modal bottom sheet for filtering transactions by date range.
///
/// By default it reads and writes the transactions-tab filter providers.
/// Pass [initialFrom]/[initialTo] together with [onApply] to drive a different
/// pair of providers (the full-history search screen does this), and [maxDate]
/// to allow picking beyond today for advance-recorded transactions.
class DateRangeFilterModal extends ConsumerStatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final void Function(DateTime? from, DateTime? to)? onApply;
  final DateTime? maxDate;

  const DateRangeFilterModal({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.onApply,
    this.maxDate,
  });

  @override
  ConsumerState<DateRangeFilterModal> createState() => _DateRangeFilterModalState();
}

class _DateRangeFilterModalState extends ConsumerState<DateRangeFilterModal> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load current filter values — from the caller when it owns the state,
    // otherwise from the transactions-tab providers.
    _dateFrom = widget.onApply != null ? widget.initialFrom : ref.read(dateFromFilterProvider);
    _dateTo = widget.onApply != null ? widget.initialTo : ref.read(dateToFilterProvider);
  }

  /// The picker must follow the app theme — a dark picker on a light sheet is
  /// the bug light mode always hides.
  ThemeData _pickerTheme(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    return (isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
      colorScheme: isLight
          ? const ColorScheme.light(
              primary: AppColors.primaryGold,
              onPrimary: Colors.black,
              surface: Color(0xFFF8FAFC),
              onSurface: AppColors.textPrimaryLight,
            )
          : const ColorScheme.dark(
              primary: AppColors.primaryGold,
              onPrimary: Colors.black,
              surface: Color(0xFF221D10),
            ),
    );
  }

  DateTime get _lastDate => widget.maxDate ?? DateTime.now();

  /// Keeps the picker's initial date inside [firstDate, lastDate] — showDatePicker
  /// asserts otherwise.
  DateTime _initialFor(DateTime? current) {
    final candidate = current ?? DateTime.now();
    return candidate.isAfter(_lastDate) ? _lastDate : candidate;
  }

  Future<void> _selectDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialFor(_dateFrom),
      firstDate: DateTime(2000),
      lastDate: _lastDate,
      builder: (context, child) => Theme(data: _pickerTheme(context), child: child!),
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        _errorMessage = null;
        // Validate: dateTo must be > dateFrom
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _errorMessage = ref.read(translationsProvider).filterDateToAfterFrom;
        }
      });
    }
  }

  Future<void> _selectDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialFor(_dateTo),
      firstDate: DateTime(2000),
      lastDate: _lastDate,
      builder: (context, child) => Theme(data: _pickerTheme(context), child: child!),
    );

    if (picked != null) {
      setState(() {
        _dateTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _errorMessage = null;
        // Validate: dateTo must be > dateFrom
        if (_dateFrom != null && picked.isBefore(_dateFrom!)) {
          _errorMessage = ref.read(translationsProvider).filterDateToAfterFrom;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _errorMessage = null;
    });
  }

  void _applyFilter() {
    // Validate before applying
    if (_dateFrom != null && _dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
      setState(() {
        _errorMessage = ref.read(translationsProvider).filterDateToAfterFrom;
      });
      return;
    }
    
    // Apply filters
    final onApply = widget.onApply;
    if (onApply != null) {
      onApply(_dateFrom, _dateTo);
    } else {
      ref.read(dateFromFilterProvider.notifier).state = _dateFrom;
      ref.read(dateToFilterProvider.notifier).state = _dateTo;
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF221D10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trans.filterByDateRange,
                  style: TextStyle(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    trans.filterClear,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date From
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: InkWell(
              onTap: _selectDateFrom,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trans.filterDateFrom,
                            style: TextStyle(
                              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateFrom != null
                                ? DateFormat('MMM dd, yyyy').format(_dateFrom!)
                                : trans.filterDateFromPlaceholder,
                            style: TextStyle(
                              color: _dateFrom != null
                                  ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                  : (isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4)),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dateFrom != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setState(() => _dateFrom = null),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Date To
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: InkWell(
              onTap: _selectDateTo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trans.filterDateTo,
                            style: TextStyle(
                              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateTo != null
                                ? DateFormat('MMM dd, yyyy').format(_dateTo!)
                                : trans.filterDateToPlaceholder,
                            style: TextStyle(
                              color: _dateTo != null
                                  ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                  : (isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4)),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dateTo != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setState(() => _dateTo = null),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Info text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              trans.filterEmptyHint,
              style: TextStyle(
                color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _errorMessage == null ? _applyFilter : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  trans.filterApply,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
