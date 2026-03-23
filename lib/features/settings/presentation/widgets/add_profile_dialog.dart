import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';

/// Dialog to add a new profile
class AddProfileDialog extends ConsumerStatefulWidget {
  const AddProfileDialog({super.key});

  @override
  ConsumerState<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends ConsumerState<AddProfileDialog> {
  final _nameController = TextEditingController();
  String _selectedAvatar = '👤';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _avatarOptions = [
    '👤', '👨', '👩', '👦', '👧', '🧑', 
    '💼', '🏠', '💰', '🎯', '📊', '🌟',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trans = ref.watch(translationsProvider);

    return Dialog(
      backgroundColor: isDark ? AppColors.bgDarkEnd : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trans.profileNew,
              style: AppTypography.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Avatar selector
            Text(
              trans.profileChooseAvatar,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _avatarOptions.map((avatar) => GestureDetector(
                onTap: () => setState(() => _selectedAvatar = avatar),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedAvatar == avatar
                        ? AppColors.primaryGold.withValues(alpha: 0.3)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(12),
                    border: _selectedAvatar == avatar
                        ? Border.all(color: AppColors.primaryGold, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(avatar, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Name input
            Text(
              trans.profileName,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: trans.profileNameHint,
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGold),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : AppColors.textPrimaryLight,
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(trans.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    onPressed: _isLoading ? () {} : _createProfile,
                    text: trans.save,
                    isFullWidth: true,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    final trans = ref.read(translationsProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = trans.profileNameEmpty);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileDao = ref.read(profileDaoProvider);

      final isUnique = await profileDao.isProfileNameUnique(name);
      if (!isUnique) {
        setState(() => _errorMessage = trans.profileNameExists);
        return;
      }

      final profileId = await profileDao.createProfile(
        name: name,
        avatar: _selectedAvatar,
      );

      await ref.read(settingsDaoProvider).createDefaultSettings(profileId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.profileCreated(name))),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
