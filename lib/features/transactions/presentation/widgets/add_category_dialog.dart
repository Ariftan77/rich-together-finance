import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';

/// Dialog for creating a new category
class AddCategoryDialog extends ConsumerStatefulWidget {
  final CategoryType type;
  final String? initialName;
  final bool canChangeType;

  const AddCategoryDialog({
    super.key,
    required this.type,
    this.initialName,
    this.canChangeType = false,
  });

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  late CategoryType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
    // Pre-fill with initial name if provided
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(translationsProvider).errorEnterCategoryName),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Return Map with name and type
      Navigator.pop(context, {
        'name': name,
        'type': _selectedType,
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);

    return Dialog(
      backgroundColor: const Color(0xFF2D2416),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trans.entryAddCategory,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Type Selector (if allowed)
            if (widget.canChangeType) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = CategoryType.expense),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedType == CategoryType.expense ? AppColors.primaryGold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGold),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          trans.entryTypeExpense,
                          style: TextStyle(
                            color: _selectedType == CategoryType.expense ? Colors.black : AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = CategoryType.income),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedType == CategoryType.income ? AppColors.primaryGold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGold),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          trans.entryTypeIncome,
                          style: TextStyle(
                            color: _selectedType == CategoryType.income ? Colors.black : AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Static Type indicator
              Text(
                '${trans.entryCategory}: ${widget.type == CategoryType.income ? trans.entryTypeIncome : trans.entryTypeExpense}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Name input
            Text(
              trans.entryCategory.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: trans.entrySearchCategory,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onSubmitted: (_) => _saveCategory(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      trans.cancel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primaryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A1410),
                            ),
                          )
                        : Text(
                            trans.save,
                            style: TextStyle(
                              color: Color(0xFF1A1410),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
