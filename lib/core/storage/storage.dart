import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _jwtKey = 'jwt';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readToken() => _storage.read(key: _jwtKey);
  Future<void> writeToken(String token) => _storage.write(key: _jwtKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _jwtKey);
}
