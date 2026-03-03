import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

class EncryptionService {
  static const _keyId = 'db_encryption_key';
  final FlutterSecureStorage _storage;

  EncryptionService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  /// Returns the existing encryption key, or generates and stores a new 32-byte hex key.
  Future<String> getOrCreateKey() async {
    var key = await _storage.read(key: _keyId);
    if (key == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _keyId, value: key);
    }
    return key;
  }

  /// Returns true if the file at [dbPath] is an unencrypted SQLite database.
  Future<bool> isPlainSqlite(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) return false;
    final bytes = await file
        .openRead(0, 15)
        .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    if (bytes.length < 15) return false;
    final header = utf8.decode(bytes, allowMalformed: true);
    return header.startsWith('SQLite format 3');
  }

  /// If the DB at [dbPath] is plain SQLite, re-keys it in-place to be
  /// encrypted with [key]. No-op if the file is already encrypted or missing.
  Future<void> migrateToEncryptedIfNeeded(String dbPath, String key) async {
    if (!await isPlainSqlite(dbPath)) return;
    final db = sqlite3.open(dbPath);
    try {
      db.execute("PRAGMA rekey = \"x'$key'\"");
    } finally {
      db.dispose();
    }
  }

  /// Opens the plain SQLite at [plainPath] and writes an encrypted copy to
  /// [outputPath] using [key]. Both paths must be distinct.
  Future<void> encryptPlainDatabase(
      String plainPath, String outputPath, String key) async {
    final db = sqlite3.open(plainPath);
    try {
      db.execute("ATTACH DATABASE '$outputPath' AS encrypted KEY \"x'$key'\"");
      db.execute("SELECT sqlcipher_export('encrypted')");
      db.execute("DETACH DATABASE encrypted");
    } finally {
      db.dispose();
    }
  }
}
