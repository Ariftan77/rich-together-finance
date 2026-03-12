import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/announcement_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

void showAnnouncementsSheet(BuildContext context, WidgetRef ref) {
  // Mark all as read immediately so badge clears
  final announcements = ref.read(announcementsProvider).valueOrNull ?? [];
  if (announcements.isNotEmpty) {
    ref.read(readIdsProvider.notifier).markAsRead(
      announcements.map((a) => a.id).toList(),
    );
  }

  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _AnnouncementsSheet(),
    ),
  );
}

class _AnnouncementsSheet extends ConsumerWidget {
  const _AnnouncementsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final announcementsAsync = ref.watch(announcementsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDarkEnd,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.campaign_outlined, color: AppColors.primaryGold, size: 22),
                const SizedBox(width: 10),
                Text(trans.settingsWhatsNew, style: AppTypography.textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Content
          Flexible(
            child: announcementsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    trans.settingsNoAnnouncements,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primaryGold,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            trans.settingsNoAnnouncements,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title(locale.languageCode),
                            style: AppTypography.textTheme.titleSmall?.copyWith(
                              color: AppColors.primaryGold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.body(locale.languageCode),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
