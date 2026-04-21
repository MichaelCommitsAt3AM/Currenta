import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

/// A secure storage implementation for Supabase session persistence.
class SecureAuthStorage extends LocalStorage {
  const SecureAuthStorage();

  @override
  Future<void> initialize() async {}

  SecureStorageService get _secureStorage => SecureStorageService.instance;

  static const _persistSessionKey = 'supabase_session';

  @override
  Future<bool> hasAccessToken() async {
    final session = await _secureStorage.read(_persistSessionKey);
    return session != null;
  }

  @override
  Future<String?> accessToken() async {
    return await _secureStorage.read(_persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    await _secureStorage.delete(_persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secureStorage.write(_persistSessionKey, persistSessionString);
  }
}
