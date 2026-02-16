import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../providers/database_providers.dart';
import '../constants/supabase_constants.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

class SyncService {
  final AppDatabase _db;
  final _supabase = Supabase.instance.client;

  SyncService(this._db);

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
  }

  /// Auth Wrappers
  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signUp(String email, String password, String name) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    // If signup successful, create a profile on Supabase? 
    // Triggers in Supabase (SQL) are better for this, but we can do it here too if needed.
    // Our local "Personal" profile should be synced/linked.
    return response;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Main Sync Method
  Future<void> syncData() async {
    if (currentUser == null) return;

    try {
      // 1. Push Local Changes
      await _pushProfiles();
      await _pushAccounts();
      await _pushCategories();
      await _pushTransactions();
      // Add other tables...

      // 2. Pull Remote Changes
      // For V1, let's just do a simple "Push everything unsynced" 
      // and "Pull everything new" for the active profile.
      
    } catch (e) {
      debugPrint('Sync Error: $e');
      rethrow;
    }
  }

  // --- Push Helpers ---

  Future<void> _pushProfiles() async {
    // Find unsynced profiles
    final unsynced = await (_db.select(_db.profiles)..where((t) => t.isSynced.equals(false))).get();
    
    for (final row in unsynced) {
      final data = {
        'name': row.name,
        'avatar': row.avatar,
        'is_active': row.isActive,
        'created_at': row.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(), // Force update time
        'user_id': currentUser!.id,
      };

      // If it already has a remote_id, we update. If not, we insert.
      // But Supabase 'upsert' works by Primary Key. 
      // We don't have the UUID PK locally if it's new.
      
      try {
        if (row.remoteId != null) {
           data['id'] = row.remoteId!;
        }

        final res = await _supabase.from('profiles').upsert(data).select().single();
        
        // Update local with remote ID and mark synced
        final remoteId = res['id'] as String;
        await (_db.update(_db.profiles)..where((t) => t.id.equals(row.id))).write(
          ProfilesCompanion(
            remoteId: Value(remoteId),
            isSynced: const Value(true),
            updatedAt: Value(DateTime.parse(res['updated_at'])),
          )
        );
      } catch (e) {
        debugPrint('Error pushing profile ${row.id}: $e');
      }
    }
  }

  Future<void> _pushAccounts() async {
    final unsynced = await (_db.select(_db.accounts)..where((t) => t.isSynced.equals(false))).get();
    
    for (final row in unsynced) {
      // We need the remote_id of the profile first!
      final profile = await (_db.select(_db.profiles)..where((t) => t.id.equals(row.profileId))).getSingleOrNull();
      if (profile?.remoteId == null) continue; // Skip if parent not synced

      final data = {
        'profile_id': profile!.remoteId,
        'name': row.name,
        'type': row.type.index,
        'currency': row.currency.index,
        'initial_balance': row.initialBalance,
        'icon': row.icon,
        'color': row.color,
        'is_active': row.isActive,
        'created_at': row.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (row.remoteId != null) data['id'] = row.remoteId!;

      try {
        final res = await _supabase.from('accounts').upsert(data).select().single();
        await (_db.update(_db.accounts)..where((t) => t.id.equals(row.id))).write(
          AccountsCompanion(
            remoteId: Value(res['id']),
            isSynced: const Value(true),
            updatedAt: Value(DateTime.parse(res['updated_at'])),
          )
        );
      } catch (e) {
         debugPrint('Error pushing account ${row.id}: $e');
      }
    }
  }

   Future<void> _pushCategories() async {
    final unsynced = await (_db.select(_db.categories)..where((t) => t.isSynced.equals(false))).get();
    
    for (final row in unsynced) {
      String? profileRemoteId;
      if (row.profileId != null) {
         final profile = await (_db.select(_db.profiles)..where((t) => t.id.equals(row.profileId!))).getSingleOrNull();
         if (profile?.remoteId == null && row.profileId != null) continue;
         profileRemoteId = profile?.remoteId;
      }
      
      // TODO: Handle parent category sync (recursion or order)

      final data = {
        'profile_id': profileRemoteId,
        'name': row.name,
        'type': row.type.index,
        'icon': row.icon,
        'color': row.color,
        'is_system': row.isSystem,
        'sort_order': row.sortOrder,
        // 'parent_id': ... need to resolve parent remote ID
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (row.remoteId != null) data['id'] = row.remoteId!;

      try {
        final res = await _supabase.from('categories').upsert(data).select().single();
        await (_db.update(_db.categories)..where((t) => t.id.equals(row.id))).write(
          CategoriesCompanion(
            remoteId: Value(res['id']),
            isSynced: const Value(true),
             updatedAt: Value(DateTime.parse(res['updated_at'])),
          )
        );
      } catch (e) {
        debugPrint('Error pushing category ${row.id}: $e');
      }
    }
  }

  Future<void> _pushTransactions() async {
    final unsynced = await (_db.select(_db.transactions)..where((t) => t.isSynced.equals(false))).get();

    for (final row in unsynced) {
       // Get parent keys
       final profile = await (_db.select(_db.profiles)..where((t) => t.id.equals(row.profileId))).getSingleOrNull();
       final account = await (_db.select(_db.accounts)..where((t) => t.id.equals(row.accountId))).getSingleOrNull();
       final category = row.categoryId != null 
          ? await (_db.select(_db.categories)..where((t) => t.id.equals(row.categoryId!))).getSingleOrNull()
          : null;

       if (profile?.remoteId == null || account?.remoteId == null) continue; // Dependency missing

       final data = {
         'profile_id': profile!.remoteId,
         'account_id': account!.remoteId,
         'category_id': category?.remoteId, // Might be null
         'type': row.type.index,
         'amount': row.amount,
         'date': row.date.toIso8601String(),
         'note': row.note,
         'title': row.title,
         'created_at': row.createdAt.toIso8601String(),
         'updated_at': DateTime.now().toIso8601String(),
       };
       // Handle transfers (to_account) and recurring if needed

       if (row.remoteId != null) data['id'] = row.remoteId!;

       try {
         final res = await _supabase.from('transactions').upsert(data).select().single();
         await (_db.update(_db.transactions)..where((t) => t.id.equals(row.id))).write(
           TransactionsCompanion(
             remoteId: Value(res['id']),
             isSynced: const Value(true),
             updatedAt: Value(DateTime.parse(res['updated_at'])),
           )
         );
       } catch (e) {
          debugPrint('Error pushing transaction ${row.id}: $e');
       }
    }
  }
}
