import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../providers/search_provider.dart';

/// Modal bottom sheet for filtering transactions by date range
class DateRangeFilterModal extends ConsumerStatefulWidget {
  const DateRangeFilterModal({super.key});

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
    // Load current filter values
    _dateFrom = ref.read(dateFromFilterProvider);
    _dateTo = ref.read(dateToFilterProvider);
  }

  Future<void> _selectDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGold,
              surface: Color(0xFF221D10),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        _errorMessage = null;
        // Validate: dateTo must be > dateFrom
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _errorMessage = 'Date To must be after Date From';
        }
      });
    }
  }

  Future<void> _selectDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGold,
              surface: Color(0xFF221D10),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateTo = picked;
        _errorMessage = null;
        // Validate: dateTo must be > dateFrom
        if (_dateFrom != null && picked.isBefore(_dateFrom!)) {
          _errorMessage = 'Date To must be after Date From';
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
        _errorMessage = 'Date To must be after Date From';
      });
      return;
    }

    print('📅 Applying date filter: From=$_dateFrom, To=$_dateTo');
    
    // Apply filters
    ref.read(dateFromFilterProvider.notifier).state = _dateFrom;
    ref.read(dateToFilterProvider.notifier).state = _dateTo;
    
    print('✅ Date filter applied successfully');
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF221D10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: Colors.white.withValues(alpha: 0.3),
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
                  'Filter by Date Range',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear',
                    style: TextStyle(
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
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date From',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateFrom != null
                                ? DateFormat('MMM dd, yyyy').format(_dateFrom!)
                                : 'Select start date',
                            style: TextStyle(
                              color: _dateFrom != null ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dateFrom != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.6)),
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
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date To',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateTo != null
                                ? DateFormat('MMM dd, yyyy').format(_dateTo!)
                                : 'Select end date',
                            style: TextStyle(
                              color: _dateTo != null ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dateTo != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.6)),
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
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
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
              'Empty Date From = first transaction\nEmpty Date To = today',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
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
                  'Apply Filter',
                  style: TextStyle(
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
