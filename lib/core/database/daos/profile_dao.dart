import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/profiles.dart';
import '../tables/user_settings.dart';

part 'profile_dao.g.dart';

/// Data Access Object for Profile operations
@DriftAccessor(tables: [Profiles, UserSettings])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// Get the currently active profile
  Future<Profile?> getActiveProfile() {
    return (select(profiles)..where((p) => p.isActive.equals(true))).getSingleOrNull();
  }

  /// Get all profiles
  Future<List<Profile>> getAllProfiles() {
    return select(profiles).get();
  }

  /// Watch all profiles for reactive UI
  Stream<List<Profile>> watchAllProfiles() {
    return select(profiles).watch();
  }

  /// Watch the active profile
  Stream<Profile?> watchActiveProfile() {
    return (select(profiles)..where((p) => p.isActive.equals(true))).watchSingleOrNull();
  }

  /// Create a new profile
  Future<int> createProfile({required String name, String avatar = '👤'}) async {
    // Check if name is unique
    final existing = await (select(profiles)..where((p) => p.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      throw Exception('Profile name "$name" already exists');
    }

    return into(profiles).insert(
      ProfilesCompanion.insert(
        name: name,
        avatar: Value(avatar),
        isActive: const Value(false),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Set a profile as active (deactivates other profiles)
  Future<void> setActiveProfile(int profileId) async {
    await transaction(() async {
      // Deactivate all profiles
      await (update(profiles)..where((p) => p.isActive.equals(true)))
          .write(const ProfilesCompanion(isActive: Value(false)));
      // Activate the selected profile
      await (update(profiles)..where((p) => p.id.equals(profileId)))
          .write(const ProfilesCompanion(isActive: Value(true)));
    });
  }

  /// Update profile details
  Future<bool> updateProfile(int profileId, {String? name, String? avatar}) async {
    if (name != null) {
      // Check if new name is unique (excluding current profile)
      final existing = await (select(profiles)
            ..where((p) => p.name.equals(name) & p.id.equals(profileId).not()))
          .getSingleOrNull();
      if (existing != null) {
        throw Exception('Profile name "$name" already exists');
      }
    }

    final updated = await (update(profiles)..where((p) => p.id.equals(profileId))).write(
      ProfilesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        avatar: avatar != null ? Value(avatar) : const Value.absent(),
      ),
    );
    return updated > 0;
  }

  /// Delete a profile (only if not the last one)
  Future<bool> deleteProfile(int profileId) async {
    final count = await profiles.count().getSingle();
    if (count <= 1) {
      throw Exception('Cannot delete the last profile');
    }

    // Check if deleting active profile
    final profile = await (select(profiles)..where((p) => p.id.equals(profileId))).getSingleOrNull();
    if (profile != null && profile.isActive) {
      // Switch to another profile first
      final otherProfile = await (select(profiles)..where((p) => p.id.equals(profileId).not())).getSingle();
      await setActiveProfile(otherProfile.id);
    }

    // Delete profile and related data (cascade should handle this)
    return await (delete(profiles)..where((p) => p.id.equals(profileId))).go() > 0;
  }

  /// Check if a profile name is unique
  Future<bool> isProfileNameUnique(String name, {int? excludeProfileId}) async {
    var query = select(profiles)..where((p) => p.name.equals(name));
    if (excludeProfileId != null) {
      query = query..where((p) => p.id.equals(excludeProfileId).not());
    }
    final existing = await query.getSingleOrNull();
    return existing == null;
  }
}
