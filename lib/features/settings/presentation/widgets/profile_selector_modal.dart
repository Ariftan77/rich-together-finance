import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import 'add_profile_dialog.dart';

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
    return AlertDialog(
      backgroundColor: AppColors.bgDarkEnd,
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
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.confirmPrompt,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
          child: Text(widget.cancelText, style: const TextStyle(color: Colors.white70)),
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
              color: _canProceed ? Colors.red : Colors.white24,
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
    final profilesAsync = ref.watch(allProfilesProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDarkEnd,
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
                'Switch Profile',
                style: AppTypography.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
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
                    text: 'Add New Profile',
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
              : Colors.white.withValues(alpha: 0.05),
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: AppColors.primaryGold),
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
          content: Text('Error deleting profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showAddProfileDialog(BuildContext context, WidgetRef ref, List<Profile> profiles) async {


    if (RemoteConfigService().rewardedEnabled && profiles.length >= 1) {
      // Show confirmation BEFORE popping — context must still be attached
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgDarkEnd,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add New Profile', style: AppTypography.textTheme.titleLarge),
          content: const Text(
            'Watch a short ad to create a new profile.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Watch Ad', style: TextStyle(color: AppColors.primaryGold)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!context.mounted) return;


      final rewarded = await AdService().showRewarded();
      if (!rewarded) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad not completed. Please try again.')),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context); // close modal after ad or if gate not needed
    showDialog(
      context: context,
      builder: (context) => const AddProfileDialog(),
    );
  }
}
