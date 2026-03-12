import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementModel {
  final String id;
  final String judulEn;
  final String isiEn;
  final String judulId;
  final String isiId;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.judulEn,
    required this.isiEn,
    required this.judulId,
    required this.isiId,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      judulEn: json['judul_en'] as String,
      isiEn: json['isi_en'] as String,
      judulId: json['judul_id'] as String,
      isiId: json['isi_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String title(String languageCode) => languageCode == 'id' ? judulId : judulEn;
  String body(String languageCode) => languageCode == 'id' ? isiId : isiEn;
}

class AnnouncementService {
  static const _prefsKey = 'read_announcement_ids';

  Future<List<AnnouncementModel>> fetchActiveAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('app_announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Set<String>> getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? []).toSet();
  }

  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getStringList(_prefsKey) ?? []).toSet();
    existing.addAll(ids);
    await prefs.setStringList(_prefsKey, existing.toList());
  }
}
