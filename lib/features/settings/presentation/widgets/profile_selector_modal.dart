import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_button.dart';
import 'add_profile_dialog.dart';

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
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onPressed: () => _showAddProfileDialog(context),
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
          ],
        ),
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const AddProfileDialog(),
    );
  }
}
