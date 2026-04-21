import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final _storage = const FlutterSecureStorage();

  static const _kDatabaseKey = 'currenta_db_key';

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStorage] Write error for key $key: $e');
      // If we hit a key mismatch error, we might need to clear storage
      if (e.toString().contains('Key mismatch') || e.toString().contains('Algorithm changed')) {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
      }
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] Read error for key $key: $e');
       if (e.toString().contains('Key mismatch') || e.toString().contains('Algorithm changed')) {
        await _storage.deleteAll();
      }
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] Delete error for key $key: $e');
    }
  }

  /// Returns a persistent 256-bit encryption key for the database.
  /// If it doesn't exist, it generates a new one.
  Future<String> getOrCreateDatabaseKey() async {
    String? key = await read(_kDatabaseKey);
    if (key == null) {
      // Generate a random 32-byte (256-bit) key and encode it as hex
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      await write(_kDatabaseKey, key);
    }
    return key;
  }
}
