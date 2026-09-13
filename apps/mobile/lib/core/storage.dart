import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Android Keystore / iOS Keychain. Web preview uses Supabase's web storage.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this.namespace);
  final String namespace;
  static const storage = FlutterSecureStorage();
  String get key => 'dopmi.$namespace.session';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: key);
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.namespace);
  final String namespace;
  @override
  Future<String?> getItem({required String key}) =>
      SecureSessionStorage.storage.read(key: 'dopmi.$namespace.pkce.$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      SecureSessionStorage.storage.write(
        key: 'dopmi.$namespace.pkce.$key',
        value: value,
      );
  @override
  Future<void> removeItem({required String key}) =>
      SecureSessionStorage.storage.delete(key: 'dopmi.$namespace.pkce.$key');
}
