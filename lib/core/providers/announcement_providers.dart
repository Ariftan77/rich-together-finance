import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/announcement_service.dart';

final announcementsProvider = FutureProvider<List<AnnouncementModel>>((ref) async {
  return AnnouncementService().fetchActiveAnnouncements();
});

class _ReadIdsNotifier extends StateNotifier<Set<String>> {
  _ReadIdsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await AnnouncementService().getReadIds();
  }

  Future<void> markAsRead(List<String> ids) async {
    await AnnouncementService().markAsRead(ids);
    state = {...state, ...ids};
  }
}

final readIdsProvider = StateNotifierProvider<_ReadIdsNotifier, Set<String>>(
  (_) => _ReadIdsNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  final announcementsAsync = ref.watch(announcementsProvider);
  final readIds = ref.watch(readIdsProvider);
  return announcementsAsync.whenOrNull(
        data: (list) => list.where((a) => !readIds.contains(a.id)).length,
      ) ??
      0;
});
