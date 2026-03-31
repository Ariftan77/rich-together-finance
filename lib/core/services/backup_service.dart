import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/database_providers.dart';
import '../providers/service_providers.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});

class BackupService {
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  BackupService(this._ref);

  Future<String> get _dbPath async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'rich_together.sqlite');
  }

  // ==========================================
  // Manual Backup (Export/Import)
  // ==========================================

  Future<void> exportDatabase() async {
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'rich_together_backup_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.sqlite';
    final tempPath = p.join(tempDir.path, fileName);
    try {
      final db = _ref.read(databaseProvider);
      await db.exportDecrypted(tempPath);

      await Share.shareXFiles(
        [XFile(tempPath)],
        text: 'Rich Together Database Backup',
      );
    } finally {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  Future<void> importDatabase() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final enc = _ref.read(encryptionServiceProvider);
    if (!await enc.isPlainSqlite(path)) {
      throw Exception('Selected file is not a valid plain SQLite backup');
    }

    final key = await enc.getOrCreateKey();
    final tempDir = await getTemporaryDirectory();
    final tempEncPath = p.join(tempDir.path, 'import_enc_temp.sqlite');
    try {
      await enc.encryptPlainDatabase(path, tempEncPath, key);

      final currentDbPath = await _dbPath;
      final db = _ref.read(databaseProvider);
      // Wipe existing data first so the migration on re-open won't try to
      // seed a second default "Personal" profile on top of the restored data.
      await db.clearAllData();
      await db.close();
      await File(tempEncPath).copy(currentDbPath);
      // Remove stale WAL/SHM files so the restored DB opens cleanly.
      for (final suffix in ['-wal', '-shm']) {
        final f = File('$currentDbPath$suffix');
        if (await f.exists()) await f.delete();
      }
      
      // Force Riverpod to recreate the database instance and cascade to all DAO/Stream providers
      _ref.invalidate(databaseProvider);
      
    } finally {
      try {
        await File(tempEncPath).delete();
      } catch (_) {}
    }
  }

  // ==========================================
  // Google Drive Backup
  // ==========================================

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {

      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {

      return null;
    }
  }

  Future<void> signOutFromGoogle() async {
    await _googleSignIn.signOut();
  }

  Stream<GoogleSignInAccount?> get currentUserStream => _googleSignIn.onCurrentUserChanged;

  Future<dynamic> _getAuthenticatedClient() async {
    if (_googleSignIn.currentUser == null) throw Exception('User not signed in');

    final granted = await _googleSignIn.requestScopes([drive.DriveApi.driveAppdataScope]);
    if (!granted) throw Exception('Drive access denied. Please reconnect Google Drive.');

    var client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      // Token is invalid/expired — force a fresh sign-in
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Sign in was cancelled');
      client = await _googleSignIn.authenticatedClient();
      if (client == null) throw Exception('Could not get authenticated client');
    }
    return client;
  }

  Future<void> uploadToDrive() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'drive_export_temp.sqlite');
    try {
      final db = _ref.read(databaseProvider);
      await db.exportDecrypted(tempPath);

      final httpClient = await _getAuthenticatedClient();
      final driveApi = drive.DriveApi(httpClient);

      final file = File(tempPath);
      final fileSize = await file.length();

      final now = DateTime.now();
      final fileName =
          'rich_together_backup_${now.year}-${now.month}-${now.day}.sqlite';

      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];

      await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), fileSize),
      );

      // Rotate: keep only the latest 14 backups
      final allFiles = await driveApi.files.list(
        q: "name contains 'rich_together_backup_' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, createdTime)',
        orderBy: 'createdTime desc',
      );
      final files = allFiles.files ?? [];
      if (files.length > 14) {
        for (final old in files.sublist(14)) {
          if (old.id != null) {
            try { await driveApi.files.delete(old.id!); } catch (_) {}
          }
        }
      }
    } finally {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  Future<List<drive.File>> listBackups() async {
    try {
      final httpClient = await _getAuthenticatedClient();
      final driveApi = drive.DriveApi(httpClient);

      final fileList = await driveApi.files.list(
        q: "name contains 'rich_together_backup_' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, createdTime, size)',
      );

      return fileList.files ?? [];
    } catch (e) {

      rethrow;
    }
  }

  Future<void> restoreFromDrive(String fileId) async {
    final tempDir = await getTemporaryDirectory();
    final tempPlainPath = p.join(tempDir.path, 'restore_plain_temp.sqlite');
    final tempEncPath = p.join(tempDir.path, 'restore_enc_temp.sqlite');
    try {
      final httpClient = await _getAuthenticatedClient();
      final driveApi = drive.DriveApi(httpClient);

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await media.stream.listen((data) {
        dataStore.addAll(data);
      }).asFuture();
      await File(tempPlainPath).writeAsBytes(dataStore);

      final enc = _ref.read(encryptionServiceProvider);
      final key = await enc.getOrCreateKey();
      await enc.encryptPlainDatabase(tempPlainPath, tempEncPath, key);

      final currentDbPath = await _dbPath;
      final db = _ref.read(databaseProvider);
      await db.clearAllData();
      await db.close();
      await File(tempEncPath).copy(currentDbPath);
      // Remove stale WAL/SHM files so the restored DB opens cleanly.
      for (final suffix in ['-wal', '-shm']) {
        final f = File('$currentDbPath$suffix');
        if (await f.exists()) await f.delete();
      }
      
      // Force Riverpod to recreate the database instance and cascade to all DAO/Stream providers
      _ref.invalidate(databaseProvider);
      
    } finally {
      try {
        await File(tempPlainPath).delete();
      } catch (_) {}
      try {
        await File(tempEncPath).delete();
      } catch (_) {}
    }
  }
}
