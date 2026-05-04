import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/premium_gate_modal.dart';
import 'add_profile_dialog.dart';
import 'edit_profile_dialog.dart';

// ---------------------------------------------------------------------------
// Private dialog widget — owns its controller so mounted checks work correctly
// ---------------------------------------------------------------------------
class _DeleteProfileDialog extends StatefulWidget {
  final Profile profile;
  final String title;
  final String content;
  final String confirmPrompt;
  final String keyword;
  final String cancelText;
  final String deleteButtonText;
  final Future<void> Function() onConfirmed;

  const _DeleteProfileDialog({
    required this.profile,
    required this.title,
    required this.content,
    required this.confirmPrompt,
    required this.keyword,
    required this.cancelText,
    required this.deleteButtonText,
    required this.onConfirmed,
  });

  @override
  State<_DeleteProfileDialog> createState() => _DeleteProfileDialogState();
}

class _DeleteProfileDialogState extends State<_DeleteProfileDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canProceed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    return AlertDialog(
      backgroundColor: isDefault
          ? AppColors.bgDarkEnd
          : isLight
              ? Colors.white
              : const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '${widget.title} "${widget.profile.name}"?',
        style: const TextStyle(color: Colors.red, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: TextStyle(
              color: isLight ? const Color(0xFF374151) : Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.confirmPrompt,
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          GlassInput(
            controller: _controller,
            hintText: widget.keyword,
            onChanged: (value) {
              if (mounted) setState(() => _canProceed = value == widget.keyword);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelText,
            style: TextStyle(
              color: isLight ? const Color(0xFF374151) : Colors.white70,
            ),
          ),
        ),
        TextButton(
          onPressed: _canProceed
              ? () async {
                  Navigator.pop(context);
                  await widget.onConfirmed();
                }
              : null,
          child: Text(
            widget.deleteButtonText,
            style: TextStyle(
              color: _canProceed
                  ? Colors.red
                  : (isLight ? const Color(0xFFCBD5E1) : Colors.white24),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Modal to switch between profiles or add a new one
class ProfileSelectorModal extends ConsumerWidget {
  const ProfileSelectorModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final profilesAsync = ref.watch(allProfilesProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final trans = ref.watch(translationsProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.bgDarkEnd
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trans.profileSwitchTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          profilesAsync.when(
            data: (profiles) => Column(
              children: [
                ...profiles.map((profile) => _buildProfileTile(
                  context,
                  ref,
                  profile,
                  isActive: profile.id == activeProfileId,
                  canDelete: profiles.length > 1,
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onPressed: () => _showAddProfileDialog(context, ref, profiles),
                    text: trans.profileAddNew,
                    icon: Icons.add,
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context,
    WidgetRef ref,
    Profile profile, {
    bool isActive = false,
    bool canDelete = false,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return InkWell(
      onTap: () async {
        if (!isActive) {
          await ref.read(profileDaoProvider).setActiveProfile(profile.id);
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : (isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppColors.primaryGold, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  profile.avatar,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                profile.name,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: AppColors.primaryGold),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showEditProfileDialog(context, ref, profile),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.primaryGold.withValues(alpha: 0.8),
                  size: 18,
                ),
              ),
            ),
            if (canDelete) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showDeleteProfileDialog(context, ref, profile),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    Navigator.pop(context); // close the modal
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(profile: profile),
    );
  }

  Future<void> _showDeleteProfileDialog(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final trans = ref.read(translationsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteProfileDialog(
        profile: profile,
        title: trans.deleteProfileTitle,
        content: trans.deleteProfileContent,
        confirmPrompt: trans.settingsClearDataConfirmPrompt,
        keyword: trans.settingsClearDataConfirmKeyword,
        cancelText: trans.genericCancel,
        deleteButtonText: trans.deleteProfileButton,
        onConfirmed: () => _performDeleteProfile(context, ref, profile),
      ),
    );
  }

  Future<void> _performDeleteProfile(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    if (!context.mounted) return;

    // Show loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
    );

    try {
      await ref.read(databaseProvider).clearAndDeleteProfile(profile.id);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      // Invalidate providers so active profile refreshes
      ref.invalidate(activeProfileIdProvider);
      ref.invalidate(activeProfileProvider);
      ref.invalidate(activeProfileSettingsProvider);

      if (!context.mounted) return;
      // Close the profile selector modal too
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(translationsProvider).deleteProfileSuccess),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ref.read(translationsProvider).profileErrorDeleting}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showAddProfileDialog(BuildContext context, WidgetRef ref, List<Profile> profiles) async {
    if (!context.mounted) return;

    // Premium gate: free-tier users can only have 1 profile.
    final premiumEnabled = ref.read(premiumEnabledProvider);
    final iapEnabled = ref.read(iapEnabledProvider);
    final isPremium = ref.read(premiumStatusProvider);
    if (premiumEnabled && iapEnabled && !isPremium && profiles.length >= 1) {
      final trans = ref.read(translationsProvider);
      await showPremiumGateModal(
        context,
        ref,
        title: trans.premiumGateProfileTitle,
        description: trans.premiumGateProfileDesc,
        icon: Icons.group_add_rounded,
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const AddProfileDialog(),
    );
  }
}
