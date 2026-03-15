import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';

void showExportReportModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ExportReportModal(),
  );
}

class _ExportReportModal extends ConsumerStatefulWidget {
  const _ExportReportModal();

  @override
  ConsumerState<_ExportReportModal> createState() => _ExportReportModalState();
}

class _ExportReportModalState extends ConsumerState<_ExportReportModal> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryGold,
            surface: Color(0xFF221D10),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  Future<void> _export(AppTranslations trans, String locale) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      final hasData = await exportService.exportReport(
        profileId: profileId,
        start: _dateFrom,
        end: _dateTo,
        trans: trans,
        locale: locale,
      );

      if (!mounted) return;

      if (!hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.exportNoData),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.exportSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.exportError),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider).toString();
    final dateFormat = DateFormat('MMM dd, yyyy', locale);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF221D10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                const Icon(Icons.file_download_outlined,
                    color: AppColors.primaryGold, size: 24),
                const SizedBox(width: 12),
                Text(
                  trans.exportReport,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Date From
          _DateField(
            label: trans.exportDateFrom,
            value: dateFormat.format(_dateFrom),
            onTap: () => _pickDate(isFrom: true),
          ),

          const SizedBox(height: 12),

          // Date To
          _DateField(
            label: trans.exportDateTo,
            value: dateFormat.format(_dateTo),
            onTap: () => _pickDate(isFrom: false),
          ),

          const SizedBox(height: 24),

          // Export button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isExporting ? null : () => _export(trans, locale),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  disabledBackgroundColor:
                      AppColors.primaryGold.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isExporting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            trans.exportGenerating,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        trans.exportButton,
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

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.primaryGold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
